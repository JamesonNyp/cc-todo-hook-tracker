#!/usr/bin/env pwsh

# Live Todo Monitor - Displays current todos with color coding
# Run this in a separate terminal window for real-time updates

# Use OS-dependent path separators
$ClaudeDir = Join-Path ~ ".claude"
$LogsDir = Join-Path $ClaudeDir "logs"
$TodoDataFile = Join-Path $LogsDir "current_todos.json"
$TodosDir = Join-Path $ClaudeDir "todos"
$ProjectsDir = Join-Path $ClaudeDir "projects"

# Global variables for tracking state
$script:HeaderLines = 0
$script:TodoSectionStart = 0
$script:LastTodoCount = 0
$script:LastUpdateTime = [DateTime]::MinValue
$script:LastRefreshTime = [DateTime]::Now
$script:RefreshIntervalSeconds = 300  # 5 minutes
$script:LastSessionFiles = @{}

# Function to find project path for a session ID
function Get-ProjectPathForSession {
    param([string]$SessionId)
    
    if (-not (Test-Path $ProjectsDir)) {
        return $null
    }
    
    # Search all project directories for this session ID
    $projectDirs = Get-ChildItem -Path $ProjectsDir -Directory
    
    foreach ($projDir in $projectDirs) {
        # Check if this project contains a file for this session
        $sessionFiles = Get-ChildItem -Path $projDir.FullName -Filter "$SessionId*.jsonl" -File 2>$null
        if ($sessionFiles) {
            # Found it! Convert the flattened directory name back to a real path
            return Convert-FlattenedPath -FlatPath $projDir.Name
        }
    }
    
    return $null
}

# Function to convert flattened path back to real path
function Convert-FlattenedPath {
    param([string]$FlatPath)
    
    # Determine OS path separator
    $pathSep = if ($PSVersionTable.Platform -eq 'Unix' -or $PSVersionTable.PSEdition -eq 'Core' -and -not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        '/'
    } else {
        '\'
    }
    
    # Convert flattened path back to real path
    # C--Users-name-folder -> C:\Users\name\folder (Windows)
    # -home-user-project -> /home/user/project (Unix)
    
    if ($FlatPath -match '^([A-Z])--(.+)$') {
        # Windows path with drive letter
        $driveLetter = $matches[1]
        $restOfPath = $matches[2] -replace '-', $pathSep
        return "${driveLetter}:${pathSep}${restOfPath}"
    } elseif ($FlatPath -match '^-(.+)$') {
        # Unix absolute path
        $restOfPath = $matches[1] -replace '-', '/'
        return "/${restOfPath}"
    } else {
        # Relative or other path format
        return $FlatPath -replace '-', $pathSep
    }
}

# Function to get all active todo sessions
function Get-AllActiveTodos {
    $allTodos = @()
    $sessions = @()
    
    # Get all todo files from the todos directory
    if (Test-Path $TodosDir) {
        $todoFiles = Get-ChildItem -Path $TodosDir -Filter "*.json" -File | 
            Where-Object { $_.Length -gt 10 } |  # Skip empty/tiny files
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10  # Limit to 10 most recent sessions
        
        foreach ($file in $todoFiles) {
            try {
                $content = Get-Content $file.FullName -Raw
                if ($content -and $content.Trim() -ne "[]" -and $content.Trim() -ne "null") {
                    $todos = $content | ConvertFrom-Json
                    if ($todos -and $todos.Count -gt 0) {
                        # Extract session ID from filename
                        $fullSessionId = if ($file.Name -match '^([a-f0-9-]+)-agent') {
                            $matches[1]
                        } else {
                            "unknown"
                        }
                        
                        $sessionId = if ($fullSessionId.Length -ge 8) {
                            $fullSessionId.Substring(0, 8)
                        } else {
                            $fullSessionId
                        }
                        
                        # Find project path for this session
                        $projectPath = Get-ProjectPathForSession -SessionId $fullSessionId
                        
                        $sessions += [PSCustomObject]@{
                            SessionId = $sessionId
                            ProjectPath = $projectPath
                            Todos = $todos
                            File = $file.Name
                            LastModified = $file.LastWriteTime
                        }
                    }
                }
            } catch {
                # Skip files that can't be parsed
            }
        }
    }
    
    # Also check the current_todos.json file
    if (Test-Path $TodoDataFile) {
        try {
            $jsonContent = Get-Content $TodoDataFile -Raw | ConvertFrom-Json
            if ($jsonContent.todos -and $jsonContent.todos.Count -gt 0) {
                $sessionId = if ($jsonContent.session_id) { 
                    $jsonContent.session_id.Substring(0, [Math]::Min(8, $jsonContent.session_id.Length))
                } else { 
                    "current" 
                }
                
                $sessions = @([PSCustomObject]@{
                    SessionId = $sessionId
                    Todos = $jsonContent.todos
                    File = "current_todos.json"
                    LastModified = (Get-Item $TodoDataFile).LastWriteTime
                    IsCurrent = $true
                }) + $sessions
            }
        } catch {
            # Skip if can't parse
        }
    }
    
    return $sessions
}

# Function to display static header (only once)
function Show-Header {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Static header
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "                CLAUDE CODE TODO MONITOR (ALL SESSIONS)         " -ForegroundColor Cyan
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Legend: " -NoNewline -ForegroundColor DarkGray
    Write-Host "✓ Completed" -NoNewline -ForegroundColor Green
    Write-Host " | " -NoNewline -ForegroundColor DarkGray
    Write-Host "▶ Active" -NoNewline -ForegroundColor Blue
    Write-Host " | " -NoNewline -ForegroundColor DarkGray
    Write-Host "○ Pending" -NoNewline -ForegroundColor DarkGray
    Write-Host " | Press Ctrl+C to exit" -ForegroundColor DarkGray
    Write-Host ""
    
    $script:HeaderLines = 6
    $script:TodoSectionStart = $script:HeaderLines + 1
}

# Function to update just the countdown timer (without full refresh)
function Update-Countdown {
    # This function now only updates the countdown in place, not the full display
    # The full display is handled by Update-Todos
    return  # Disabled to prevent duplication
}

# Function to update only the todo section
function Update-Todos {
    param(
        [switch]$ForceUpdate,
        [switch]$CountdownOnly
    )
    
    $currentTime = Get-Date
    $timestamp = $currentTime.ToString("HH:mm:ss")
    
    # For countdown-only updates, skip the debounce check
    if (-not $CountdownOnly) {
        # Debounce: prevent updates more frequent than once per second (unless forced)
        if (-not $ForceUpdate -and ($currentTime - $script:LastUpdateTime).TotalSeconds -lt 1) {
            return
        }
        $script:LastUpdateTime = $currentTime
    }
    
    # Calculate countdown timer
    $secondsSinceRefresh = [int]((Get-Date) - $script:LastRefreshTime).TotalSeconds
    $secondsUntilRefresh = [Math]::Max(0, $script:RefreshIntervalSeconds - $secondsSinceRefresh)
    $minutes = [Math]::Floor($secondsUntilRefresh / 60)
    $seconds = $secondsUntilRefresh % 60
    $countdownText = "Next refresh: {0:00}:{1:00}" -f $minutes, $seconds
    
    # Get all active todo sessions
    $sessions = Get-AllActiveTodos
    
    # Save cursor position and move to status line
    $statusLinePosition = $script:TodoSectionStart - 1
    [Console]::SetCursorPosition(0, $statusLinePosition)
    
    if ($sessions.Count -eq 0) {
        # Clear the status line
        Write-Host (" " * [Console]::WindowWidth) -NoNewline
        [Console]::SetCursorPosition(0, $statusLinePosition)
        Write-Host "No active todo sessions found | Last update: $timestamp | $countdownText" -ForegroundColor Yellow
        
        # Clear everything below
        $currentPos = [Console]::CursorTop + 1
        for ($i = $currentPos; $i -lt [Console]::WindowHeight; $i++) {
            [Console]::SetCursorPosition(0, $i)
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
        }
        $script:LastTodoCount = 0
        return
    }
    
    # Calculate total todos
    $totalTodos = ($sessions | ForEach-Object { $_.Todos.Count } | Measure-Object -Sum).Sum
    
    # Clear and update the status line
    Write-Host (" " * [Console]::WindowWidth) -NoNewline
    [Console]::SetCursorPosition(0, $statusLinePosition)
    Write-Host "Active Sessions: $($sessions.Count) | Total Todos: $totalTodos | Updated: $timestamp | $countdownText" -ForegroundColor White
    
    # If this is just a countdown update, stop here
    if ($CountdownOnly) {
        return
    }
    
    # Move to the line after status for todos display
    [Console]::SetCursorPosition(0, $statusLinePosition + 1)
    
    # Display todos from all sessions
    $displayedLines = 1  # Start at 1 to account for status line
    
    foreach ($session in $sessions) {
        # Clear current line
        $currentLine = [Console]::CursorTop
        if ($currentLine -lt [Console]::WindowHeight - 1) {
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
            [Console]::SetCursorPosition(0, $currentLine)
        }
        
        # Display blank line then session header
        Write-Host ""
        $currentLine = [Console]::CursorTop
        if ($currentLine -lt [Console]::WindowHeight - 1) {
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
            [Console]::SetCursorPosition(0, $currentLine)
        }
        
        # Display session with project path if available
        $sessionDisplay = if ($session.ProjectPath) {
            "[Project: $($session.ProjectPath)]"
        } else {
            "[Session: $($session.SessionId)]"
        }
        
        Write-Host "$sessionDisplay - $($session.Todos.Count) todos - Updated: $($session.LastModified.ToString('HH:mm:ss'))" -ForegroundColor Cyan
        $displayedLines += 2
        
        # Sort todos by status: completed first, then active/in_progress, then pending
        $sortedTodos = $session.Todos | Sort-Object -Property @{
            Expression = {
                switch ($_.status) {
                    "completed" { 0 }
                    { $_ -in "active", "in_progress", "working" } { 1 }
                    default { 2 }
                }
            }
        }
        
        # Display todos for this session with numbering
        $todoNumber = 1
        foreach ($todo in $sortedTodos) {
            $content = if ($todo.status -eq "in_progress" -and $todo.activeForm) {
                $todo.activeForm
            } else {
                $todo.content
            }
            
            # DON'T truncate - show full text
            # Users want to see everything
            
            # Clear current line
            $currentLine = [Console]::CursorTop
            if ($currentLine -lt [Console]::WindowHeight - 1) {
                Write-Host (" " * [Console]::WindowWidth) -NoNewline
                [Console]::SetCursorPosition(0, $currentLine)
            }
            
            # Display based on status with numbering
            $numberStr = "{0,2}." -f $todoNumber
            switch ($todo.status) {
                "completed" {
                    Write-Host "  $numberStr ✓ $content" -ForegroundColor Green
                }
                { $_ -in "active", "in_progress", "working" } {
                    Write-Host "  $numberStr ▶ $content" -ForegroundColor Blue
                }
                default {
                    Write-Host "  $numberStr ○ $content" -ForegroundColor DarkGray
                }
            }
            $displayedLines++
            $todoNumber++
            
            # Continue showing ALL todos - no truncation!
        }
    }
    
    # Clear any extra lines if the new list is shorter
    if ($script:LastTodoCount -gt $displayedLines) {
        $linesToClear = $script:LastTodoCount - $displayedLines
        for ($i = 0; $i -lt $linesToClear; $i++) {
            if ([Console]::CursorTop -lt [Console]::WindowHeight - 1) {
                Write-Host (" " * [Console]::WindowWidth)
            }
        }
    }
    
    $script:LastTodoCount = $displayedLines
}

# Function to start monitoring
function Start-Monitoring {
    # Clear screen and display initial header
    Clear-Host
    Show-Header
    Update-Todos
    
    # Create FileSystemWatcher for monitoring
    # Resolve ~ to actual path for FileSystemWatcher
    $resolvedLogsDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogsDir)
    
    # Ensure the directory exists before watching
    if (-not (Test-Path $resolvedLogsDir)) {
        New-Item -Path $resolvedLogsDir -ItemType Directory -Force | Out-Null
    }
    
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $resolvedLogsDir
    $watcher.Filter = "current_todos.json"
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
    $watcher.EnableRaisingEvents = $true
    
    # Register event handler
    $action = {
        $script:LastRefreshTime = [DateTime]::Now  # Reset countdown on file change
        Update-Todos
    }
    
    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action | Out-Null
    
    Write-Host "`nMonitoring for changes... (Press Ctrl+C to stop)" -ForegroundColor DarkGray
    
    # Keep the script running
    try {
        $lastDisplayUpdate = [DateTime]::MinValue
        
        while ($true) {
            Start-Sleep -Milliseconds 500
            
            # Update countdown only every second
            if (((Get-Date) - $lastDisplayUpdate).TotalSeconds -ge 1) {
                Update-Todos -CountdownOnly
                $lastDisplayUpdate = [DateTime]::Now
            }
            
            # Check if it's time to refresh (5 minutes)
            $secondsSinceRefresh = ((Get-Date) - $script:LastRefreshTime).TotalSeconds
            if ($secondsSinceRefresh -ge $script:RefreshIntervalSeconds) {
                $script:LastRefreshTime = [DateTime]::Now
                # Force full update
                Update-Todos -ForceUpdate
            }
            
            # Also check for manual updates (fallback)
            if (Test-Path $TodoDataFile) {
                $currentMTime = (Get-Item $TodoDataFile).LastWriteTime
                if ($currentMTime -gt $script:LastUpdateTime) {
                    $script:LastRefreshTime = [DateTime]::Now  # Reset countdown on actual update
                    Update-Todos -ForceUpdate
                }
            }
        }
    } finally {
        # Cleanup
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
        Write-Host "`nTodo Monitor stopped" -ForegroundColor Yellow
    }
}

# Handle Ctrl+C gracefully
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Host "`nTodo Monitor stopped" -ForegroundColor Yellow
}

# Start monitoring
Start-Monitoring