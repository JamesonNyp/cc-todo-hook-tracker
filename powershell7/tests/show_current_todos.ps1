#!/usr/bin/env pwsh

# Simple script to display current todos from the JSON file
$TodoDataFile = Join-Path ~ ".claude\logs\current_todos.json"

if (-not (Test-Path $TodoDataFile)) {
    Write-Host "No todo data file found at: $TodoDataFile" -ForegroundColor Red
    exit 1
}

$data = Get-Content $TodoDataFile -Raw | ConvertFrom-Json

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "                    CURRENT CLAUDE CODE TODOS                    " -ForegroundColor Cyan  
Write-Host "==================================================================`n" -ForegroundColor Cyan

Write-Host "Session: $($data.session_id)" -ForegroundColor DarkGray
Write-Host "Directory: $($data.cwd)" -ForegroundColor DarkGray
Write-Host "Last Updated: $($data.last_updated)`n" -ForegroundColor DarkGray

if ($data.todos -and $data.todos.Count -gt 0) {
    Write-Host "Todos ($($data.todos.Count)):" -ForegroundColor White
    foreach ($todo in $data.todos) {
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
    Write-Host "No todos found" -ForegroundColor Yellow
}

Write-Host ""