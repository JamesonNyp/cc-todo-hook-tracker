#!/usr/bin/env pwsh

# Test script that simulates real Claude Code TodoWrite hook data
Write-Host "Simulating Real Claude Code TodoWrite Hook" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

# This is the actual structure Claude Code sends to post-tool hooks
$realHookData = @{
    timestamp = "2025-08-28T17:00:00.000Z"
    session_id = "cc-session-" + (New-Guid).ToString().Substring(0, 8)
    cwd = (Get-Location).Path
    tool_name = "TodoWrite"
    tool_response = @{
        newTodos = @(
            @{
                content = "Implement authentication system"
                status = "pending"
                activeForm = "Implementing authentication system"
            },
            @{
                content = "Add error handling to API endpoints"
                status = "in_progress" 
                activeForm = "Adding error handling to API endpoints"
            },
            @{
                content = "Write unit tests for user service"
                status = "pending"
                activeForm = "Writing unit tests for user service"
            },
            @{
                content = "Update database schema"
                status = "completed"
                activeForm = "Updating database schema"
            },
            @{
                content = "Configure CI/CD pipeline"
                status = "in_progress"
                activeForm = "Configuring CI/CD pipeline"
            }
        )
        success = $true
    }
}

Write-Host "`nSending hook data to todo_hook_post_tool.ps1..." -ForegroundColor Yellow

# Simulate the hook being called by Claude Code
$jsonData = $realHookData | ConvertTo-Json -Depth 10
$jsonData | & "..\todo_hook_post_tool.ps1"

Write-Host "✓ Hook processed" -ForegroundColor Green

# Verify the output
$TodoDataFile = Join-Path ~ ".claude\logs\current_todos.json"
if (Test-Path $TodoDataFile) {
    $savedData = Get-Content $TodoDataFile -Raw | ConvertFrom-Json
    
    Write-Host "`nSaved todo data:" -ForegroundColor Yellow
    Write-Host "  Session: $($savedData.session_id)" -ForegroundColor Gray
    Write-Host "  Timestamp: $($savedData.timestamp)" -ForegroundColor Gray
    Write-Host "  Directory: $($savedData.cwd)" -ForegroundColor Gray
    Write-Host "  Last Updated: $($savedData.last_updated)" -ForegroundColor Gray
    Write-Host "  Total Todos: $($savedData.todos.Count)" -ForegroundColor Gray
    
    Write-Host "`nTodo Items:" -ForegroundColor Yellow
    foreach ($todo in $savedData.todos) {
        $color = switch ($todo.status) {
            "completed" { "Green" }
            "in_progress" { "Blue" }
            default { "White" }
        }
        $icon = switch ($todo.status) {
            "completed" { "✓" }
            "in_progress" { "▶" }
            default { "○" }
        }
        Write-Host "  $icon $($todo.content) [$($todo.status)]" -ForegroundColor $color
    }
    
    Write-Host "`nThe monitor should now display these real-looking todos!" -ForegroundColor Cyan
    Write-Host "Run ..\todo_live_monitor.ps1 in another terminal to see them." -ForegroundColor DarkGray
} else {
    Write-Host "✗ Todo file was not created" -ForegroundColor Red
}

# Cleanup test data
Write-Host "`nCleaning up test data..." -ForegroundColor DarkGray
try {
    # Save original data if it exists
    $backupFile = Join-Path ~ ".claude\logs\current_todos.backup.json"
    if (Test-Path $backupFile) {
        # Restore from backup
        Move-Item -Path $backupFile -Destination $TodoDataFile -Force
        Write-Host "✓ Restored original todo data" -ForegroundColor Green
    } else {
        # Clear the test data
        @{
            timestamp = $null
            session_id = $null
            cwd = $null
            todos = $null
            last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        } | ConvertTo-Json | Out-File -FilePath $TodoDataFile -Encoding UTF8
        Write-Host "✓ Test data cleared" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Could not clean up test data: $_" -ForegroundColor Yellow
}