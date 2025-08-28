#!/usr/bin/env pwsh

# Simple test to verify the scripts work
Write-Host "Simple Todo Hook Test" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$TodoDataFile = Join-Path ~ ".claude\logs\current_todos.json"

# Test data
$testData = @{
    timestamp = "2025-08-28T17:00:00Z"
    session_id = "simple-test"
    cwd = (Get-Location).Path
    todos = @(
        @{
            content = "Task 1: Complete"
            status = "completed"  
            activeForm = "Completing Task 1"
        },
        @{
            content = "Task 2: In Progress"
            status = "in_progress"
            activeForm = "Working on Task 2"
        },
        @{
            content = "Task 3: Pending"
            status = "pending"
            activeForm = "Starting Task 3"
        }
    )
    last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

# Save test data
Write-Host "`nSaving test data to: $TodoDataFile" -ForegroundColor Yellow
$testData | ConvertTo-Json | Out-File -FilePath $TodoDataFile -Encoding UTF8

# Verify file was created
if (Test-Path $TodoDataFile) {
    Write-Host "✓ File created successfully" -ForegroundColor Green
    
    # Read and display the content
    $content = Get-Content $TodoDataFile -Raw | ConvertFrom-Json
    Write-Host "`nFile contents:" -ForegroundColor Yellow
    Write-Host "  Session ID: $($content.session_id)" -ForegroundColor Gray
    Write-Host "  CWD: $($content.cwd)" -ForegroundColor Gray
    Write-Host "  Todos count: $($content.todos.Count)" -ForegroundColor Gray
    Write-Host "  Last updated: $($content.last_updated)" -ForegroundColor Gray
    
    Write-Host "`nTodos:" -ForegroundColor Yellow
    foreach ($todo in $content.todos) {
        $icon = switch ($todo.status) {
            "completed" { "✓" }
            "in_progress" { "▶" }
            default { "○" }
        }
        $color = switch ($todo.status) {
            "completed" { "Green" }
            "in_progress" { "Blue" }
            default { "White" }
        }
        Write-Host "  $icon $($todo.content)" -ForegroundColor $color
    }
} else {
    Write-Host "✗ File was not created" -ForegroundColor Red
}

Write-Host "`nTest complete!" -ForegroundColor Cyan

# Cleanup test data
Write-Host "Cleaning up test data..." -ForegroundColor DarkGray
try {
    @{
        timestamp = $null
        session_id = $null
        cwd = $null
        todos = $null
        last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } | ConvertTo-Json | Out-File -FilePath $TodoDataFile -Encoding UTF8
    Write-Host "✓ Test data cleared" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not clean up test data: $_" -ForegroundColor Yellow
}