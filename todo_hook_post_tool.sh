#!/bin/bash

# PostToolUse hook for TodoWrite tool
# Captures todo data and writes to a JSON file for monitoring

TODO_DATA_FILE="$HOME/.claude/logs/current_todos.json"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Read the hook input from stdin
HOOK_INPUT=$(cat)

# Parse the JSON to extract todo information
echo "$HOOK_INPUT" | jq '{
    timestamp: .timestamp,
    session_id: .session_id,
    cwd: .cwd,
    todos: .tool_response.newTodos,
    last_updated: "'"$TIMESTAMP"'"
}' > "$TODO_DATA_FILE"

# Create a simple flag file to trigger monitors
touch "$HOME/.claude/todos_updated.flag"

# Exit successfully
exit 0
