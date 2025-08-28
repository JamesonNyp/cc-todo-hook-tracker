#!/bin/bash

# Live Todo Monitor - Displays current todos with color coding
# Run this in a separate terminal window for real-time updates

TODO_DATA_FILE="$HOME/.claude/logs/current_todos.json"

# ANSI Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'
STRIKETHROUGH='\033[9m'

# Global variables for in-place updates
HEADER_LINES=0
TODO_SECTION_START=0
LAST_TODO_COUNT=0
LAST_UPDATE_TIME=0

# Function to display static header (only once)
display_header() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ ! -f "$TODO_DATA_FILE" ]]; then
        echo -e "${RED}No todo data available yet...${NC}"
        echo "Waiting for TodoWrite events from Claude Code..."
        echo -e "${DIM}Press Ctrl+C to exit monitor${NC}"
        HEADER_LINES=3
        return
    fi
    
    # Parse JSON and display header
    local json_content=$(cat "$TODO_DATA_FILE")
    local session_id=$(echo "$json_content" | jq -r '.session_id // "unknown"')
    local cwd=$(echo "$json_content" | jq -r '.cwd // "unknown"')
    
    # Static header
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}                    CLAUDE CODE TODO MONITOR                    ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${DIM}Session: ${session_id:0:8}... | Directory: $(basename "$cwd")${NC}"
    echo -e "${DIM}Legend: ${GREEN}${STRIKETHROUGH}✓ Completed${NC} ${DIM}| ${BLUE}${BOLD}▶ Active${NC} ${DIM}| ○ Pending | Press Ctrl+C to exit${NC}"
    echo
    
    HEADER_LINES=7
    TODO_SECTION_START=$((HEADER_LINES + 1))
}

# Function to update only the todo section
update_todos() {
    local current_time=$(date +%s)
    local timestamp=$(date '+%H:%M:%S')
    
    # Debounce: prevent updates more frequent than once per second
    if [[ $((current_time - LAST_UPDATE_TIME)) -lt 1 ]]; then
        return
    fi
    LAST_UPDATE_TIME=$current_time
    
    if [[ ! -f "$TODO_DATA_FILE" ]]; then
        return
    fi
    
    # Parse JSON
    local json_content=$(cat "$TODO_DATA_FILE")
    local todo_count=$(echo "$json_content" | jq '.todos | length')
    
    # Move cursor to todo section start
    printf '\033[%d;1H' $TODO_SECTION_START
    
    if [[ "$todo_count" == "0" || "$todo_count" == "null" ]]; then
        # Clear everything from cursor to end of screen for empty list
        printf '\033[0J'
        echo -e "${YELLOW}No todos found | Last update: $timestamp${NC}"
        LAST_TODO_COUNT=0
        return
    fi
    
    # Clear current line and display todo header
    printf '\033[2K'
    echo -e "${BOLD}Current Todos (${todo_count}) | Updated: $timestamp${NC}"
    
    # Collect todo lines first to avoid flicker
    local todo_lines=()
    while IFS= read -r todo_json; do
        local content=$(echo "$todo_json" | jq -r '.content')
        local status=$(echo "$todo_json" | jq -r '.status')
        
        # Determine color and formatting based on status
        case "$status" in
            "completed")
                todo_lines+=("  ${GREEN}${STRIKETHROUGH}✓ $content${NC}")
                ;;
            "active"|"in_progress"|"working")
                todo_lines+=("  ${BLUE}${BOLD}▶ $content${NC}")
                ;;
            *)
                todo_lines+=("  ○ $content")
                ;;
        esac
    done < <(echo "$json_content" | jq -r '.todos[] | @json')
    
    # Display all todo lines
    for line in "${todo_lines[@]}"; do
        printf '\033[2K'  # Clear line before writing
        echo -e "$line"
    done
    
    # Clear any extra lines if the new list is shorter than the previous one
    if [[ $LAST_TODO_COUNT -gt ${#todo_lines[@]} ]]; then
        local lines_to_clear=$((LAST_TODO_COUNT - ${#todo_lines[@]}))
        for ((i=1; i<=lines_to_clear; i++)); do
            printf '\033[2K\n'
        done
        # Move cursor back up to the end of the todo list
        if [[ $lines_to_clear -gt 0 ]]; then
            printf '\033[%dA' $lines_to_clear
        fi
    fi
    
    LAST_TODO_COUNT=${#todo_lines[@]}
}

# Function to monitor for changes
start_monitoring() {
    # Clear screen and display initial header
    printf '\033[2J\033[H'
    display_header
    update_todos
    
    # Choose monitoring method based on available tools
    if command -v inotifywait &> /dev/null; then
        # Linux - use inotifywait with output properly handled
        while true; do
            # Run inotifywait and capture its exit status, suppress all output
            if inotifywait -e modify "$TODO_DATA_FILE" &>/dev/null; then
                update_todos
            fi
        done
    elif command -v fswatch &> /dev/null; then
        # macOS - use fswatch with debouncing (watch only JSON file)
        fswatch -l 0.5 "$TODO_DATA_FILE" 2>/dev/null | while read file_path; do
            update_todos
        done
    else
        # Fallback - polling method with longer interval
        echo -e "${YELLOW}Note: Using polling method (install inotifywait or fswatch for better performance)${NC}"
        local last_mtime=""
        while true; do
            if [[ -f "$TODO_DATA_FILE" ]]; then
                local current_mtime=$(stat -f "%m" "$TODO_DATA_FILE" 2>/dev/null || stat -c "%Y" "$TODO_DATA_FILE" 2>/dev/null)
                if [[ "$current_mtime" != "$last_mtime" ]]; then
                    update_todos
                    last_mtime="$current_mtime"
                fi
            fi
            sleep 3  # Increased polling interval
        done
    fi
}

# Handle Ctrl+C gracefully
trap 'printf "\n"; echo -e "${YELLOW}Todo Monitor stopped${NC}"; exit 0' SIGINT

# Start monitoring
start_monitoring