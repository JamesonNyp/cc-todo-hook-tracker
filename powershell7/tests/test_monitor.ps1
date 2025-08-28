#!/usr/bin/env pwsh

# Test script to update todos and test the monitor
Write-Host "Testing todo monitor with dynamic updates" -ForegroundColor Cyan

$TodoDataFile = Join-Path ~ ".claude\logs\current_todos.json"

# Ensure directory exists
$LogsDir = Join-Path ~ ".claude\logs"
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}

# Test 1: Initial todos
Write-Host "`nCreating initial todo list..." -ForegroundColor Yellow
$initialTodos = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    session_id = "test-monitor-001"
    cwd = Get-Location
    todos = @(
        @{
            content = "Setup development environment"
            status = "completed"
            activeForm = "Setting up development environment"
        },
        @{
            content = "Write unit tests"
            status = "in_progress"
            activeForm = "Writing unit tests"
        },
        @{
            content = "Update documentation"
            status = "pending"
            activeForm = "Updating documentation"
        }
    )
    last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$initialTodos | ConvertTo-Json -Depth 10 | Out-File -FilePath $TodoDataFile -Encoding UTF8
Write-Host "Initial todos created. Monitor should show 3 todos." -ForegroundColor Green

Start-Sleep -Seconds 3

# Test 2: Add more todos
Write-Host "`nAdding more todos..." -ForegroundColor Yellow
$moreTodos = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    session_id = "test-monitor-001"
    cwd = Get-Location
    todos = @(
        @{
            content = "Setup development environment"
            status = "completed"
            activeForm = "Setting up development environment"
        },
        @{
            content = "Write unit tests"
            status = "completed"
            activeForm = "Writing unit tests"
        },
        @{
            content = "Update documentation"
            status = "in_progress"
            activeForm = "Updating documentation"
        },
        @{
            content = "Code review"
            status = "pending"
            activeForm = "Reviewing code"
        },
        @{
            content = "Deploy to staging"
            status = "pending"
            activeForm = "Deploying to staging"
        }
    )
    last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$moreTodos | ConvertTo-Json -Depth 10 | Out-File -FilePath $TodoDataFile -Encoding UTF8
Write-Host "Updated todos. Monitor should now show 5 todos." -ForegroundColor Green

Start-Sleep -Seconds 3

# Test 3: Complete all todos
Write-Host "`nCompleting all todos..." -ForegroundColor Yellow
$completedTodos = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    session_id = "test-monitor-001"
    cwd = Get-Location
    todos = @(
        @{
            content = "Setup development environment"
            status = "completed"
            activeForm = "Setting up development environment"
        },
        @{
            content = "Write unit tests"
            status = "completed"
            activeForm = "Writing unit tests"
        },
        @{
            content = "Update documentation"
            status = "completed"
            activeForm = "Updating documentation"
        },
        @{
            content = "Code review"
            status = "completed"
            activeForm = "Reviewing code"
        },
        @{
            content = "Deploy to staging"
            status = "completed"
            activeForm = "Deploying to staging"
        }
    )
    last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$completedTodos | ConvertTo-Json -Depth 10 | Out-File -FilePath $TodoDataFile -Encoding UTF8
Write-Host "All todos completed! Monitor should show all items as completed." -ForegroundColor Green

Start-Sleep -Seconds 3

# Test 4: Empty todo list
Write-Host "`nClearing todo list..." -ForegroundColor Yellow
$emptyTodos = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    session_id = "test-monitor-001"
    cwd = Get-Location
    todos = @()
    last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$emptyTodos | ConvertTo-Json -Depth 10 | Out-File -FilePath $TodoDataFile -Encoding UTF8
Write-Host "Todo list cleared. Monitor should show 'No todos found'." -ForegroundColor Green

Write-Host "`nTest complete! The monitor should have updated automatically for each change." -ForegroundColor Cyan