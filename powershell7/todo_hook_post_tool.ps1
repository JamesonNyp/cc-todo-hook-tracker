#!/usr/bin/env pwsh

# PostToolUse hook for TodoWrite tool
# Captures todo data and writes to a JSON file for monitoring

# Use OS-dependent path separators
$ClaudeDir = Join-Path ~ ".claude"
$LogsDir = Join-Path $ClaudeDir "logs"
$TodoDataFile = Join-Path $LogsDir "current_todos.json"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Read the hook input from stdin
# Use $input automatic variable for pipeline input
if ($input) {
    $HookInput = $input | Out-String
} else {
    # Fallback to Console.In for direct stdin
    $HookInput = [Console]::In.ReadToEnd()
}

# Parse the JSON to extract todo information
$InputData = $HookInput | ConvertFrom-Json

# Create the output object with extracted todo information
$OutputData = @{
    timestamp = $InputData.timestamp
    session_id = $InputData.session_id
    cwd = $InputData.cwd
    todos = $InputData.tool_response.newTodos
    last_updated = $Timestamp
}

# Ensure the logs directory exists
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}

# Convert to JSON and save to file
$OutputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $TodoDataFile -Encoding UTF8

# Create a simple flag file to trigger monitors
$FlagFile = Join-Path $ClaudeDir "todos_updated.flag"
New-Item -Path $FlagFile -ItemType File -Force | Out-Null

# Exit successfully
exit 0