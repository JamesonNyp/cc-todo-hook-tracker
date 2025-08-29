# Claude Code Todo Hook Tracker

A real-time todo monitoring system for Claude Code that displays live updates of todo items as they are created, modified, and completed. This tool provides a visual dashboard in your terminal that automatically updates whenever Claude Code uses the TodoWrite tool.

![Claude Code Todo Tracker Live Monitor](Todo%20Tracker.png)

## Overview

This project provides scripts that integrate with Claude Code's hook system to capture and display todo updates in real-time. When Claude Code uses its TodoWrite tool, these scripts intercept the data and provide a live monitoring dashboard showing the current state of all todos.

## Features

- 🔄 **Live Updates**: Automatically refreshes when Claude Code modifies todos
- 🎨 **Color-Coded Status**: Visual indicators for different todo states
  - ✅ Green for completed items
  - ▶️ Blue for active/in-progress items  
  - ○ Default for pending items
- 📊 **Session Tracking**: Displays session ID and working directory
- ⚡ **Efficient Monitoring**: Uses native file watching for minimal resource usage
- 🌍 **Cross-Platform**: Available in both Bash and PowerShell implementations

## How It Works

1. **Hook Script**: Intercepts PostToolUse events for TodoWrite
   - Captures todo data from Claude Code
   - Extracts relevant information (todos, session, directory)
   - Saves formatted JSON to `~/.claude/logs/current_todos.json`

2. **Monitor Script**: Displays live todo updates
   - Watches the JSON file for changes
   - Parses and displays todos with color coding
   - Updates display in real-time
   - Uses efficient file watching mechanisms

## Available Implementations

### Bash Version (`bash/`)
- Works on Linux, macOS, and WSL2 (not native Windows)
- Requires `jq` for JSON parsing
- Optionally uses `inotifywait` (Linux) or `fswatch` (macOS) for file monitoring
- See [README-sh.md](README-sh.md) for setup instructions

### PowerShell 7 Version (`powershell7/`) - Recommended for Cross-Platform Use
- **Truly cross-platform**: Runs natively on Windows, macOS, and Linux
- No external dependencies required
- Built-in JSON parsing and file watching
- While PowerShell may seem unfamiliar to Unix users, it solves many traditional shell scripting limitations:
  - Consistent behavior across all platforms
  - Structured data handling (objects vs text streams)
  - No need for external tools like `jq`, `sed`, or `awk`
  - Robust error handling and debugging
- See [README-ps.md](README-ps.md) for setup instructions

## Project Structure

```
cc-todo-hook-tracker/
├── README.md           # This file
├── README-sh.md        # Bash setup guide
├── README-ps.md        # PowerShell setup guide
├── TESTING-ps.md       # PowerShell testing guide
├── Todo Tracker.png    # Screenshot of the monitor
├── bash/               # Bash implementation
│   ├── todo_hook_post_tool.sh
│   └── todo_live_monitor.sh
└── powershell7/        # PowerShell 7 implementation
    ├── todo_hook_post_tool.ps1
    ├── todo_live_monitor.ps1
    └── tests/          # Test scripts
```

## Quick Start

1. Choose your preferred implementation:
   - **Bash**: Follow [README-sh.md](README-sh.md)
   - **PowerShell 7**: Follow [README-ps.md](README-ps.md)

2. Configure Claude Code hooks to use the appropriate script

3. Start the monitor in a separate terminal

4. Use Claude Code normally - todos will appear automatically!

## File Storage

Both implementations use the same file structure:
```
~/.claude/
├── settings.json               # Claude Code configuration
├── logs/
│   └── current_todos.json      # Current todo state data
└── scripts/                    # (Optional) Script installation location
```

## License

MIT License - Feel free to modify and distribute

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Author

Originally created by Jameson Nyp (@JamesonNyp)
PowerShell implementation by Dimension Zero (@dimension-zero)