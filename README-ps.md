# PowerShell 7 Implementation - Setup Guide

This guide covers the installation and configuration of the PowerShell 7 version of the Claude Code Todo Hook Tracker.

## Prerequisites

- **PowerShell 7 or later** (cross-platform)
  - Windows: Download from [Microsoft](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
  - macOS: `brew install --cask powershell`
  - Linux: [Installation guide](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)
- Claude Code CLI installed
- No additional dependencies required (JSON parsing and file watching are built-in)

## Installation

### Step 1: Clone and Setup Scripts

```powershell
# Clone this repository
git clone https://github.com/JamesonNyp/cc-todo-hook-tracker.git
cd cc-todo-hook-tracker

# Copy scripts to Claude Code scripts directory
New-Item -Path "~\.claude\scripts" -ItemType Directory -Force
Copy-Item "powershell7\todo_hook_post_tool.ps1" "~\.claude\scripts\todo_hook_post_tool.ps1"
Copy-Item "powershell7\todo_live_monitor.ps1" "~\.claude\scripts\todo_live_monitor.ps1"
```

### Step 2: Configure Claude Code Hook

#### Option A: Using Claude Code CLI

1. In Claude Code, run the `/hooks` command
2. Select **PostToolUse** hook event
3. Add a new matcher: `TodoWrite`
4. Add the hook command:
   ```
   pwsh -File ~/.claude/scripts/todo_hook_post_tool.ps1
   ```
   Note: On Windows, you may need to use the full path to pwsh.exe:
   ```
   C:\Program Files\PowerShell\7\pwsh.exe -File ~/.claude/scripts/todo_hook_post_tool.ps1
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
            "command": "pwsh -File ~/.claude/scripts/todo_hook_post_tool.ps1"
          }
        ]
      }
    ]
  }
}
```

### Step 3: Create Required Directories

```powershell
# Create logs directory for todo data
New-Item -Path "~\.claude\logs" -ItemType Directory -Force
```

## Usage

1. **Start the Monitor**: In a separate terminal window, run:
   ```powershell
   # From scripts directory
   pwsh ~/.claude/scripts/todo_live_monitor.ps1
   
   # Or if running from repo directory:
   pwsh powershell7/todo_live_monitor.ps1
   ```

2. **Work with Claude Code**: In another terminal, use Claude Code normally. Any task that triggers the TodoWrite tool will automatically update the monitor.

3. **View Live Updates**: The monitor will show:
   - Session information and working directory
   - Real-time todo list with color-coded status
   - Timestamp of last update
   - Total count of todos

## Running from Repository

If you prefer to run the scripts directly from the repository without installing:

```powershell
# Start the monitor
pwsh powershell7/todo_live_monitor.ps1

# For hooks, use the full path in Claude Code settings:
# Windows example:
C:\Users\YourName\repos\cc-todo-hook-tracker\powershell7\todo_hook_post_tool.ps1

# macOS/Linux example:
/home/username/repos/cc-todo-hook-tracker/powershell7/todo_hook_post_tool.ps1
```

## Testing

See [TESTING-ps.md](TESTING-ps.md) for detailed testing instructions.

Quick test to verify installation:
```powershell
# Run from powershell7/tests directory
cd powershell7/tests
.\test_real_hook.ps1
.\show_current_todos.ps1
```

## Troubleshooting

### Monitor not updating
- Verify hook is registered: Run `/hooks` in Claude Code
- Check if `~/.claude/logs/current_todos.json` is being created
- Ensure PowerShell 7 is installed (not Windows PowerShell 5.1)
- Test with: `pwsh -Version`

### Permission Issues (Windows)
If you get execution policy errors:
```powershell
# Allow script execution for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Console errors when running in background
The monitor script uses console positioning that requires an interactive terminal. Always run `todo_live_monitor.ps1` in a visible terminal window, not as a background process.

### Path Issues
- The scripts use `~` which PowerShell expands to the user's home directory
- Ensure paths don't contain special characters that need escaping
- Use `Join-Path` for path construction (already implemented in scripts)

## Key Advantages

- **No External Dependencies**: Unlike the Bash version, no need for `jq`, `inotifywait`, or `fswatch`
- **Cross-Platform**: Same scripts work on Windows, macOS, and Linux
- **Built-in Features**: 
  - Native JSON parsing with `ConvertFrom-Json`
  - FileSystemWatcher for efficient file monitoring
  - Consistent path handling with `Join-Path`

## File Locations

- **Scripts**: `powershell7/` directory or `~/.claude/scripts/`
- **Todo Data**: `~/.claude/logs/current_todos.json`
- **Flag File**: `~/.claude/todos_updated.flag`
- **Test Scripts**: `powershell7/tests/`

## Customization

You can modify colors by editing the switch statements in `todo_live_monitor.ps1`:

```powershell
$color = switch ($todo.status) {
    "completed" { "Green" }
    "in_progress" { "Blue" }
    default { "White" }
}
```

Available colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White