#!/usr/bin/env pwsh

# Live Todo Monitor - Displays current todos with color coding
# Run this in a separate terminal window for real-time updates

# Use OS-dependent path separators
$ClaudeDir = Join-Path ~ ".claude"
$LogsDir = Join-Path $ClaudeDir "logs"
$TodoDataFile = Join-Path $LogsDir "current_todos.json"

# Global variables for tracking state
$script:HeaderLines = 0
$script:TodoSectionStart = 0
$script:LastTodoCount = 0
$script:LastUpdateTime = [DateTime]::MinValue

# Function to display static header (only once)
function Show-Header {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    if (-not (Test-Path $TodoDataFile)) {
        Write-Host "No todo data available yet..." -ForegroundColor Red
        Write-Host "Waiting for TodoWrite events from Claude Code..."
        Write-Host "Press Ctrl+C to exit monitor" -ForegroundColor DarkGray
        $script:HeaderLines = 3
        return
    }
    
    # Parse JSON and display header
    $jsonContent = Get-Content $TodoDataFile -Raw | ConvertFrom-Json
    $sessionId = if ($jsonContent.session_id) { $jsonContent.session_id } else { "unknown" }
    $cwd = if ($jsonContent.cwd) { $jsonContent.cwd } else { "unknown" }
    
    # Static header
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "                    CLAUDE CODE TODO MONITOR                    " -ForegroundColor Cyan
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host ""
    
    $sessionDisplay = if ($sessionId.Length -gt 8) { "$($sessionId.Substring(0, 8))..." } else { $sessionId }
    $dirDisplay = Split-Path $cwd -Leaf
    Write-Host "Session: $sessionDisplay | Directory: $dirDisplay" -ForegroundColor DarkGray
    Write-Host "Legend: " -NoNewline -ForegroundColor DarkGray
    Write-Host "✓ Completed" -NoNewline -ForegroundColor Green
    Write-Host " | " -NoNewline -ForegroundColor DarkGray
    Write-Host "▶ Active" -NoNewline -ForegroundColor Blue
    Write-Host " | ○ Pending | Press Ctrl+C to exit" -ForegroundColor DarkGray
    Write-Host ""
    
    $script:HeaderLines = 7
    $script:TodoSectionStart = $script:HeaderLines + 1
}

# Function to update only the todo section
function Update-Todos {
    $currentTime = Get-Date
    $timestamp = $currentTime.ToString("HH:mm:ss")
    
    # Debounce: prevent updates more frequent than once per second
    if (($currentTime - $script:LastUpdateTime).TotalSeconds -lt 1) {
        return
    }
    $script:LastUpdateTime = $currentTime
    
    if (-not (Test-Path $TodoDataFile)) {
        return
    }
    
    # Parse JSON
    try {
        $jsonContent = Get-Content $TodoDataFile -Raw | ConvertFrom-Json
        $todos = $jsonContent.todos
    } catch {
        return
    }
    
    # Move cursor to todo section start
    [Console]::SetCursorPosition(0, $script:TodoSectionStart - 1)
    
    if (-not $todos -or $todos.Count -eq 0) {
        # Clear from cursor to end of screen
        $currentPos = [Console]::CursorTop
        for ($i = $currentPos; $i -lt [Console]::WindowHeight; $i++) {
            [Console]::SetCursorPosition(0, $i)
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
        }
        [Console]::SetCursorPosition(0, $currentPos)
        Write-Host "No todos found | Last update: $timestamp" -ForegroundColor Yellow
        $script:LastTodoCount = 0
        return
    }
    
    # Display todo header
    $currentLine = [Console]::CursorTop
    Write-Host (" " * [Console]::WindowWidth) -NoNewline
    [Console]::SetCursorPosition(0, $currentLine)
    Write-Host "Current Todos ($($todos.Count)) | Updated: $timestamp" -ForegroundColor White
    
    # Display todos
    $todoLines = @()
    foreach ($todo in $todos) {
        $content = $todo.content
        $status = $todo.status
        
        # Clear current line
        $currentLine = [Console]::CursorTop
        if ($currentLine -lt [Console]::WindowHeight - 1) {
            Write-Host (" " * [Console]::WindowWidth) -NoNewline
            [Console]::SetCursorPosition(0, $currentLine)
        }
        
        # Display based on status
        switch ($status) {
            "completed" {
                Write-Host "  ✓ $content" -ForegroundColor Green
                $todoLines += 1
            }
            { $_ -in "active", "in_progress", "working" } {
                Write-Host "  ▶ $content" -ForegroundColor Blue
                $todoLines += 1
            }
            default {
                Write-Host "  ○ $content"
                $todoLines += 1
            }
        }
    }
    
    # Clear any extra lines if the new list is shorter
    if ($script:LastTodoCount -gt $todoLines.Count) {
        $linesToClear = $script:LastTodoCount - $todoLines.Count
        for ($i = 0; $i -lt $linesToClear; $i++) {
            if ([Console]::CursorTop -lt [Console]::WindowHeight - 1) {
                Write-Host (" " * [Console]::WindowWidth)
            }
        }
    }
    
    $script:LastTodoCount = $todoLines.Count
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
        Update-Todos
    }
    
    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action | Out-Null
    
    Write-Host "`nMonitoring for changes... (Press Ctrl+C to stop)" -ForegroundColor DarkGray
    
    # Keep the script running
    try {
        while ($true) {
            Start-Sleep -Seconds 1
            
            # Also check for manual updates (fallback)
            if (Test-Path $TodoDataFile) {
                $currentMTime = (Get-Item $TodoDataFile).LastWriteTime
                if ($currentMTime -gt $script:LastUpdateTime) {
                    Update-Todos
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