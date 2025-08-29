#!/usr/bin/env pwsh

# Live Todo Monitor with Spectre.Console - Beautiful terminal UI for todos
# Run this in a separate terminal window for real-time updates

# Ensure Spectre.Console is installed
function Ensure-SpectreConsole {
    $moduleName = "PwshSpectreConsole"
    
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Write-Host "Installing Spectre.Console for PowerShell..." -ForegroundColor Yellow
        try {
            Install-Module -Name $moduleName -Force -Scope CurrentUser -AllowClobber
            Write-Host "Spectre.Console installed successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Failed to install Spectre.Console: $_" -ForegroundColor Red
            Write-Host "Trying alternative installation method..." -ForegroundColor Yellow
            
            # Try with NuGet provider
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
            }
            Install-Module -Name $moduleName -Force -Scope CurrentUser -Repository PSGallery
        }
    }
    
    Import-Module $moduleName -ErrorAction Stop
}

# Install and import Spectre.Console
Ensure-SpectreConsole

# Use OS-dependent path separators
$ClaudeDir = Join-Path ~ ".claude"
$LogsDir = Join-Path $ClaudeDir "logs"
$TodoDataFile = Join-Path $LogsDir "current_todos.json"
$TodosDir = Join-Path $ClaudeDir "todos"
$ProjectsDir = Join-Path $ClaudeDir "projects"

# Global variables
$script:LastRefreshTime = [DateTime]::Now
$script:RefreshIntervalSeconds = 300  # 5 minutes
$script:Running = $true

# Function to find project path for a session ID
function Get-ProjectPathForSession {
    param([string]$SessionId)
    
    if (-not (Test-Path $ProjectsDir)) {
        return $null
    }
    
    # Search all project directories for this session ID
    $projectDirs = Get-ChildItem -Path $ProjectsDir -Directory -ErrorAction SilentlyContinue
    
    foreach ($projDir in $projectDirs) {
        # Check if this project contains a file for this session
        $sessionFiles = Get-ChildItem -Path $projDir.FullName -Filter "$SessionId*.jsonl" -File -ErrorAction SilentlyContinue
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
    $sessions = @()
    
    # Get all todo files from the todos directory
    if (Test-Path $TodosDir) {
        $todoFiles = Get-ChildItem -Path $TodosDir -Filter "*.json" -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.Length -gt 10 } |  # Skip empty/tiny files
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 20  # Increased limit for Spectre display
        
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
                    ProjectPath = $null
                }) + $sessions
            }
        } catch {
            # Skip if can't parse
        }
    }
    
    return $sessions
}

# Function to create the display
function Update-Display {
    Clear-Host
    
    # Create fancy header with Spectre
    Write-SpectreRule -Title "CLAUDE CODE TODO MONITOR" -Alignment Center -Color Blue
    
    # Get all sessions
    $sessions = Get-AllActiveTodos
    
    # Calculate stats
    $totalTodos = ($sessions | ForEach-Object { $_.Todos.Count } | Measure-Object -Sum).Sum
    $totalCompleted = ($sessions | ForEach-Object { 
        ($_.Todos | Where-Object { $_.status -eq "completed" }).Count 
    } | Measure-Object -Sum).Sum
    $totalActive = ($sessions | ForEach-Object { 
        ($_.Todos | Where-Object { $_.status -in "active", "in_progress", "working" }).Count 
    } | Measure-Object -Sum).Sum
    $totalPending = $totalTodos - $totalCompleted - $totalActive
    
    # Calculate countdown
    $secondsSinceRefresh = [int]((Get-Date) - $script:LastRefreshTime).TotalSeconds
    $secondsUntilRefresh = [Math]::Max(0, $script:RefreshIntervalSeconds - $secondsSinceRefresh)
    $minutes = [Math]::Floor($secondsUntilRefresh / 60)
    $seconds = $secondsUntilRefresh % 60
    $countdownText = "{0:00}:{1:00}" -f $minutes, $seconds
    
    # Create status panel
    $statusPanel = New-SpectrePanel -Header "Status" -Data @"
Sessions: [cyan]$($sessions.Count)[/] | Total: [yellow]$totalTodos[/] | ✓ [green]$totalCompleted[/] | ▶ [blue]$totalActive[/] | ○ [grey]$totalPending[/]
Last Update: [cyan]$(Get-Date -Format 'HH:mm:ss')[/] | Next Refresh: [yellow]$countdownText[/]
"@ -Expand
    
    Write-Host ""
    $statusPanel | Write-Host
    Write-Host ""
    
    if ($sessions.Count -eq 0) {
        Write-SpectreHost "[yellow]No active todo sessions found[/]"
        return
    }
    
    # Display each session in a nice table
    foreach ($session in $sessions) {
        # Create session header
        $sessionTitle = if ($session.ProjectPath) {
            $session.ProjectPath
        } else {
            "Session: $($session.SessionId)"
        }
        
        Write-SpectreRule -Title $sessionTitle -Alignment Left -Color Cyan
        Write-SpectreHost "[dim]Last updated: $($session.LastModified.ToString('HH:mm:ss')) | $($session.Todos.Count) todos[/]"
        Write-Host ""
        
        # Sort todos by status
        $sortedTodos = $session.Todos | Sort-Object -Property @{
            Expression = {
                switch ($_.status) {
                    "completed" { 0 }
                    { $_ -in "active", "in_progress", "working" } { 1 }
                    default { 2 }
                }
            }
        }
        
        # Create table for todos
        $table = [Spectre.Console.Table]::new()
        $table.AddColumn([Spectre.Console.TableColumn]::new("[grey]#[/]").Width(3))
        $table.AddColumn([Spectre.Console.TableColumn]::new("Status").Width(8))
        $table.AddColumn([Spectre.Console.TableColumn]::new("Task"))
        $table.Border = [Spectre.Console.TableBorder]::Rounded
        
        $todoNumber = 1
        foreach ($todo in $sortedTodos) {
            $content = if ($todo.status -eq "in_progress" -and $todo.activeForm) {
                $todo.activeForm
            } else {
                $todo.content
            }
            
            $statusIcon = switch ($todo.status) {
                "completed" { "[green]✓[/]" }
                { $_ -in "active", "in_progress", "working" } { "[blue]▶[/]" }
                default { "[grey]○[/]" }
            }
            
            $taskColor = switch ($todo.status) {
                "completed" { "[green]$content[/]" }
                { $_ -in "active", "in_progress", "working" } { "[blue]$content[/]" }
                default { "$content" }
            }
            
            $table.AddRow(@(
                "[grey]$todoNumber[/]",
                $statusIcon,
                $taskColor
            ))
            
            $todoNumber++
        }
        
        [Spectre.Console.AnsiConsole]::Write($table)
        Write-Host ""
    }
    
    # Footer
    Write-SpectreRule -Title "Press Ctrl+C to exit" -Alignment Center -Color DarkGray
}

# Function to start monitoring
function Start-Monitoring {
    # Set up file watcher
    $resolvedLogsDir = (Resolve-Path $LogsDir -ErrorAction SilentlyContinue) ?? $LogsDir
    
    # Ensure the directory exists
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
        Update-Display
    }
    
    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action | Out-Null
    
    # Initial display
    Update-Display
    
    # Main loop
    try {
        $lastDisplayUpdate = [DateTime]::Now
        
        while ($script:Running) {
            Start-Sleep -Milliseconds 1000
            
            # Update display every second for countdown
            if (((Get-Date) - $lastDisplayUpdate).TotalSeconds -ge 1) {
                Update-Display
                $lastDisplayUpdate = [DateTime]::Now
            }
            
            # Check if it's time to refresh (5 minutes)
            $secondsSinceRefresh = ((Get-Date) - $script:LastRefreshTime).TotalSeconds
            if ($secondsSinceRefresh -ge $script:RefreshIntervalSeconds) {
                $script:LastRefreshTime = [DateTime]::Now
                Update-Display
            }
        }
    } finally {
        # Cleanup
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
        Write-SpectreHost "[yellow]Todo Monitor stopped[/]"
    }
}

# Handle Ctrl+C gracefully
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $script:Running = $false
}

# Console settings for better display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "Claude Code Todo Monitor"

# Start monitoring
Start-Monitoring