# Bash Implementation - Setup Guide

This guide covers the installation and configuration of the Bash version of the Claude Code Todo Hook Tracker.

## Prerequisites

- Claude Code CLI installed
- `jq` for JSON parsing: 
  - Linux: `sudo apt install jq`
  - macOS: `brew install jq`
- Optional (recommended for better performance):
  - Linux: `sudo apt install inotify-tools`
  - macOS: `brew install fswatch`

## Installation

### Step 1: Clone and Setup Scripts

```bash
# Clone this repository
git clone https://github.com/JamesonNyp/cc-todo-hook-tracker.git
cd cc-todo-hook-tracker

# Make scripts executable
chmod +x bash/todo_hook_post_tool.sh
chmod +x bash/todo_live_monitor.sh

# Copy scripts to Claude Code scripts directory
mkdir -p ~/.claude/scripts
cp bash/todo_hook_post_tool.sh ~/.claude/scripts/todo_hook_post_tool.sh
cp bash/todo_live_monitor.sh ~/.claude/scripts/todo_live_monitor.sh
```

### Step 2: Configure Claude Code Hook

#### Option A: Using Claude Code CLI

1. In Claude Code, run the `/hooks` command
2. Select **PostToolUse** hook event
3. Add a new matcher: `TodoWrite`
4. Add the hook command:
   ```bash
   ~/.claude/scripts/todo_hook_post_tool.sh
   ```
5. Save to **User settings** to apply globally

#### Option B: Manual Configuration

Edit your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "TodoWrite",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/todo_hook_post_tool.sh"
          }
        ]
      }
    ]
  }
}
```

### Step 3: Create Required Directories

```bash
# Create logs directory for todo data
mkdir -p ~/.claude/logs
```

## Usage

1. **Start the Monitor**: In a separate terminal window, run:
   ```bash
   ~/.claude/scripts/todo_live_monitor.sh
   # Or if running from repo directory:
   ./bash/todo_live_monitor.sh
   ```

2. **Work with Claude Code**: In another terminal, use Claude Code normally. Any task that triggers the TodoWrite tool will automatically update the monitor.

3. **View Live Updates**: The monitor will show:
   - Session information and working directory
   - Real-time todo list with color-coded status
   - Timestamp of last update
   - Total count of todos

## Troubleshooting

### Monitor not updating
- Verify hook is registered: Run `/hooks` in Claude Code
- Check if `~/.claude/logs/current_todos.json` is being created
- Ensure scripts have execute permissions

### Colors not displaying
- Ensure your terminal supports ANSI color codes
- Try running in a different terminal emulator

### High CPU usage
- Install `inotify-tools` (Linux) or `fswatch` (macOS or Linux) for efficient file watching
- Without these tools, the script falls back to polling which uses more resources

## Customization

You can modify the color scheme by editing the ANSI color codes in `todo_live_monitor.sh`:

```bash
GREEN='\033[0;32m'   # Completed items
BLUE='\033[0;34m'    # Active items
YELLOW='\033[1;33m'  # Warnings
CYAN='\033[0;36m'    # Headers
```

## File Locations

- **Scripts**: `bash/` directory or `~/.claude/scripts/`
- **Todo Data**: `~/.claude/logs/current_todos.json`
- **Flag File**: `~/.claude/todos_updated.flag`

## Performance Notes

The monitor script automatically detects and uses the most efficient file watching method available:
1. **inotifywait** (Linux) - Most efficient
2. **fswatch** (macOS/Linux) - Very efficient  
3. **Polling** (Fallback) - Less efficient, checks every 3 seconds