# PowerShell 7 Testing Guide

This guide explains how to test the PowerShell 7 implementation of the Claude Code Todo Hook Tracker.

## Test Suite Overview

The `powershell7/tests/` directory contains several test scripts that validate the functionality of the todo hook tracker:

- **test_real_hook.ps1** - Simulates realistic Claude Code hook data
- **test_todo_hook.ps1** - Comprehensive test suite with multiple scenarios
- **simple_test.ps1** - Quick validation test
- **test_monitor.ps1** - Tests the live monitor with dynamic updates
- **show_current_todos.ps1** - Displays current todo state
- **test_input.json** - Sample JSON input for testing

## Prerequisites

- PowerShell 7 or later installed
- Scripts cloned to local directory
- Write access to `~/.claude/logs/` directory

## Running Tests

### Basic Test Execution

From the repository root:
```powershell
# Run individual tests
pwsh powershell7/tests/test_real_hook.ps1
pwsh powershell7/tests/test_todo_hook.ps1
pwsh powershell7/tests/simple_test.ps1
```

From the tests directory:
```powershell
cd powershell7/tests
.\test_real_hook.ps1
.\test_todo_hook.ps1
.\simple_test.ps1
```

### Test Descriptions

#### 1. test_real_hook.ps1
Simulates the exact JSON structure that Claude Code sends to PostToolUse hooks.

**What it tests:**
- Proper JSON parsing from pipeline input
- Todo data extraction from nested structure
- File creation and formatting
- Session and directory tracking

**Expected output:**
```
Simulating Real Claude Code TodoWrite Hook
==================================================
Sending hook data to todo_hook_post_tool.ps1...
✓ Hook processed
Saved todo data:
  Session: cc-session-xxxxxxxx
  ...
  Total Todos: 5
```

#### 2. test_todo_hook.ps1
Comprehensive test suite covering edge cases and various scenarios.

**Test scenarios:**
1. Valid JSON input with multiple todos
2. Empty todos array
3. Complex nested structure with special characters
4. File timestamp verification
5. Large dataset (50 todos) performance test

**Expected output:**
```
Testing todo_hook_post_tool.ps1
================================
Test 1: Valid JSON input with todos
✓ Output file created successfully
...
All tests completed!
✓ Test data cleared
```

#### 3. simple_test.ps1
Quick test that directly creates and verifies todo data.

**What it tests:**
- Direct JSON file creation
- Data persistence
- Display formatting

**Usage:**
```powershell
.\simple_test.ps1
```

### Viewing Test Results

After running tests, check the current todo state:
```powershell
# From tests directory
.\show_current_todos.ps1

# From repository root
pwsh powershell7/tests/show_current_todos.ps1
```

## Test Data Cleanup

All test scripts now automatically clean up test data after completion to avoid leaving test artifacts in your logs. The cleanup process:

1. Checks for backup files
2. Either restores original data or clears test data
3. Reports cleanup status

**Note:** Test data is stored in `~/.claude/logs/current_todos.json`

## Testing the Live Monitor

### Basic Monitor Test

1. Start the monitor in one terminal:
```powershell
pwsh powershell7/todo_live_monitor.ps1
```

2. In another terminal, run a test to update todos:
```powershell
pwsh powershell7/tests/test_real_hook.ps1
```

3. Observe the monitor update automatically

### Dynamic Update Test

The `test_monitor.ps1` script creates multiple todo updates:
```powershell
# This will create initial todos, update them, mark as complete, then clear
pwsh powershell7/tests/test_monitor.ps1
```

Watch the monitor to see real-time updates as the test progresses.

## Troubleshooting Tests

### Common Issues

#### Permission Denied
```powershell
# Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Path Not Found
Ensure you're in the correct directory:
```powershell
# Check current location
Get-Location

# Navigate to tests
cd powershell7/tests
```

#### JSON Parse Errors
Verify test data format:
```powershell
# Check if JSON file exists and is valid
$file = Join-Path ~ ".claude\logs\current_todos.json"
if (Test-Path $file) {
    Get-Content $file -Raw | ConvertFrom-Json
}
```

#### Monitor Not Updating
1. Check if FileSystemWatcher is working:
```powershell
# Test file watching
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = Join-Path ~ ".claude\logs"
$watcher.EnableRaisingEvents
```

2. Manually trigger an update:
```powershell
# Touch the file to trigger update
$file = Join-Path ~ ".claude\logs\current_todos.json"
(Get-Item $file).LastWriteTime = Get-Date
```

## Integration Testing

### Testing with Claude Code

1. Configure the hook in Claude Code (see README-ps.md)
2. Start the monitor:
```powershell
pwsh powershell7/todo_live_monitor.ps1
```
3. In Claude Code, create a task that uses todos
4. Verify the monitor updates with real data

### Sample Claude Code Commands
```
# In Claude Code
Create a todo list for implementing a new feature
Add unit tests to the current project
```

## Performance Testing

Test with large datasets:
```powershell
# test_todo_hook.ps1 includes a 50-item test
.\test_todo_hook.ps1

# Check performance metrics
Measure-Command { .\test_todo_hook.ps1 }
```

## Continuous Testing

For repeated testing during development:
```powershell
# Create a test loop
while ($true) {
    Clear-Host
    Write-Host "Running tests..." -ForegroundColor Cyan
    .\test_real_hook.ps1
    Start-Sleep -Seconds 5
    .\show_current_todos.ps1
    Start-Sleep -Seconds 10
}
```

## Expected Test Data Structure

The tests create JSON data in this format:
```json
{
  "timestamp": "2025-08-28T17:00:00Z",
  "session_id": "cc-session-xxxxxxxx",
  "cwd": "C:\\current\\working\\directory",
  "todos": [
    {
      "content": "Task description",
      "status": "pending|in_progress|completed",
      "activeForm": "Active form description"
    }
  ],
  "last_updated": "2025-08-28 17:00:00"
}
```

## Validation Checklist

- [ ] All test scripts execute without errors
- [ ] JSON file is created at `~/.claude/logs/current_todos.json`
- [ ] Monitor displays todos with correct colors
- [ ] Test data is cleaned up after tests complete
- [ ] File watching triggers updates in monitor
- [ ] Special characters in todos are handled correctly
- [ ] Large datasets (50+ todos) are processed efficiently