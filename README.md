# Claude Code Todo Hook Tracker

A real-time todo monitoring system for Claude Code that displays live updates of todo items as they are created, modified, and completed. This tool provides a visual dashboard in your terminal that automatically updates whenever Claude Code uses the TodoWrite tool.

## Features

- 🔄 **Live Updates**: Automatically refreshes when Claude Code modifies todos
- 🎨 **Color-Coded Status**: Visual indicators for different todo states
  - ✅ Green strikethrough for completed items
  - ▶️ Blue bold for active/in-progress items  
  - ○ Normal text for pending items
- 📊 **Session Tracking**: Displays session ID and working directory
- ⚡ **Efficient Monitoring**: Uses native file watching (inotify/fswatch) for minimal resource usage

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
chmod +x todo_hook_post_tool.sh
chmod +x todo_live_monitor.sh

# Copy scripts to Claude Code scripts directory
mkdir -p ~/.claude/scripts
cp todo_hook_post_tool.sh ~/.claude/scripts/claude-todo-hook.sh
cp todo_live_monitor.sh ~/.claude/scripts/todo-monitor.sh
```

### Step 2: Configure Claude Code Hook

#### Option A: Using Claude Code CLI

1. In Claude Code, run the `/hooks` command
2. Select **PostToolUse** hook event
3. Add a new matcher: `TodoWrite`
4. Add the hook command:
   ```bash
   ~/.claude/scripts/claude-todo-hook.sh
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
            "command": "~/.claude/scripts/claude-todo-hook.sh"
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
   ~/.claude/scripts/todo-monitor.sh
   # Or if running from repo directory:
   ./todo_live_monitor.sh
   ```

2. **Work with Claude Code**: In another terminal, use Claude Code normally. Any task that triggers the TodoWrite tool will automatically update the monitor.

3. **View Live Updates**: The monitor will show:
   - Session information and working directory
   - Real-time todo list with color-coded status
   - Timestamp of last update
   - Total count of todos

## How It Works

1. **Hook Script** (`todo_hook_post_tool.sh`):
   - Intercepts PostToolUse events for TodoWrite
   - Extracts todo data from the tool response
   - Saves formatted JSON to `~/.claude/logs/current_todos.json`

2. **Monitor Script** (`todo_live_monitor.sh`):
   - Watches the JSON file for changes
   - Parses and displays todos with color coding
   - Updates display in place without scrolling
   - Uses efficient file watching (inotify/fswatch) or falls back to polling

## File Structure

```
~/.claude/
├── settings.json               # Claude Code configuration
├── logs/
│   └── current_todos.json      # Current todo state data
└── scripts/
    ├── claude-todo-hook.sh     # PostToolUse hook script
    └── todo-monitor.sh         # Live monitoring display script
```

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

## License

MIT License - Feel free to modify and distribute

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Author

Created by Jameson Nyp (@JamesonNyp)