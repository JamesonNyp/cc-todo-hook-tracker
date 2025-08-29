#!/usr/bin/env pwsh

# Test script for todo_hook_post_tool.ps1
Write-Host "Testing todo_hook_post_tool.ps1" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Test 1: Basic functionality with valid JSON
Write-Host "`nTest 1: Valid JSON input with todos" -ForegroundColor Yellow
$testJson1 = @'
{
  "timestamp": "2025-08-28T14:45:00.000Z",
  "session_id": "test-session-001",
  "cwd": "C:\\test\\directory",
  "tool_response": {
    "newTodos": [
      {
        "content": "Write unit tests",
        "status": "pending",
        "activeForm": "Writing unit tests"
      },
      {
        "content": "Update documentation",
        "status": "in_progress",
        "activeForm": "Updating documentation"
      },
      {
        "content": "Review code",
        "status": "completed",
        "activeForm": "Reviewing code"
      }
    ]
  }
}
'@

# Run the script with test input
$testJson1 | & "..\todo_hook_post_tool.ps1"

# Check the output
$outputFile = Join-Path ~ ".claude\logs\current_todos.json"
$flagFile = Join-Path ~ ".claude\todos_updated.flag"

if (Test-Path $outputFile) {
    Write-Host "✓ Output file created successfully" -ForegroundColor Green
    $content = Get-Content $outputFile -Raw | ConvertFrom-Json
    Write-Host "  - Session ID: $($content.session_id)" -ForegroundColor Gray
    Write-Host "  - CWD: $($content.cwd)" -ForegroundColor Gray
    Write-Host "  - Todos count: $($content.todos.Count)" -ForegroundColor Gray
    Write-Host "  - Last updated: $($content.last_updated)" -ForegroundColor Gray
} else {
    Write-Host "✗ Output file not created" -ForegroundColor Red
}

if (Test-Path $flagFile) {
    Write-Host "✓ Flag file created successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Flag file not created" -ForegroundColor Red
}

# Test 2: Empty todos array
Write-Host "`nTest 2: Empty todos array" -ForegroundColor Yellow
$testJson2 = @'
{
  "timestamp": "2025-08-28T15:00:00.000Z",
  "session_id": "test-session-002",
  "cwd": "C:\\empty\\test",
  "tool_response": {
    "newTodos": []
  }
}
'@

$testJson2 | & "..\todo_hook_post_tool.ps1"
$content2 = Get-Content $outputFile -Raw | ConvertFrom-Json
Write-Host "  - Session ID: $($content2.session_id)" -ForegroundColor Gray
Write-Host "  - Todos count: $($content2.todos.Count)" -ForegroundColor Gray

# Test 3: Complex nested structure
Write-Host "`nTest 3: Complex todo with nested data" -ForegroundColor Yellow
$testJson3 = @'
{
  "timestamp": "2025-08-28T16:00:00.000Z",
  "session_id": "complex-session-003",
  "cwd": "C:\\Users\\test\\complex\\path with spaces",
  "tool_response": {
    "newTodos": [
      {
        "content": "Task with special chars: @#$%",
        "status": "pending",
        "activeForm": "Working on special task",
        "metadata": {
          "priority": "high",
          "tags": ["urgent", "bug-fix"]
        }
      }
    ]
  }
}
'@

$testJson3 | & "..\todo_hook_post_tool.ps1"
$content3 = Get-Content $outputFile -Raw | ConvertFrom-Json
Write-Host "  - Session ID: $($content3.session_id)" -ForegroundColor Gray
Write-Host "  - CWD: $($content3.cwd)" -ForegroundColor Gray
if ($content3.todos[0].content) {
    Write-Host "  - First todo: $($content3.todos[0].content)" -ForegroundColor Gray
}

# Test 4: Verify file timestamps
Write-Host "`nTest 4: File timestamp verification" -ForegroundColor Yellow
$flagInfo = Get-Item $flagFile
$outputInfo = Get-Item $outputFile
Write-Host "  - Flag file modified: $($flagInfo.LastWriteTime)" -ForegroundColor Gray
Write-Host "  - JSON file modified: $($outputInfo.LastWriteTime)" -ForegroundColor Gray

# Test 5: Large dataset
Write-Host "`nTest 5: Large dataset with many todos" -ForegroundColor Yellow
$largeTodos = @()
for ($i = 1; $i -le 50; $i++) {
    $largeTodos += @{
        content = "Task number $i"
        status = @("pending", "in_progress", "completed")[$i % 3]
        activeForm = "Working on task $i"
    }
}

$testJson5 = @{
    timestamp = "2025-08-28T17:00:00.000Z"
    session_id = "large-session-005"
    cwd = "C:\\large\\test"
    tool_response = @{
        newTodos = $largeTodos
    }
} | ConvertTo-Json -Depth 10

$testJson5 | & "..\todo_hook_post_tool.ps1"
$content5 = Get-Content $outputFile -Raw | ConvertFrom-Json
Write-Host "  - Todos count: $($content5.todos.Count)" -ForegroundColor Gray
Write-Host "  - File size: $((Get-Item $outputFile).Length) bytes" -ForegroundColor Gray

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "All tests completed!" -ForegroundColor Cyan

# Cleanup test data
Write-Host "`nCleaning up test data..." -ForegroundColor DarkGray
try {
    $TodoDataFile = Join-Path ~ ".claude\logs\current_todos.json"
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