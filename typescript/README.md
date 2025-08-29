# Claude Todo Monitor - Electron App

A beautiful Slack-like Electron app for monitoring Claude Code todo lists across all projects and sessions.

## Features

- **Slack-like UI**: Clean, modern interface with dark theme
- **Project Sidebar**: All projects with active todos listed on the left
- **Session Tabs**: Each project shows tabs for different Claude Code sessions
- **Live Updates**: Auto-refreshes every 5 seconds
- **Status Indicators**: Visual indicators for completed (✓), active (▶), and pending (○) todos
- **Sorted Display**: Todos sorted by status - completed first, then active, then pending

## Installation

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Build for production
npm run build

# Start the built app
npm start

# Package for distribution
npm run dist
```

## Development

The app uses:
- **Electron** for desktop app framework
- **React** for UI components
- **TypeScript** for type safety
- **Vite** for fast development builds

### Project Structure

```
typescript/
├── src/
│   ├── main/           # Electron main process
│   │   ├── main.ts     # Main process entry point
│   │   └── preload.ts  # Preload script for IPC
│   ├── App.tsx         # Main React component
│   ├── App.css         # Slack-like styling
│   └── main.tsx        # Renderer entry point
├── package.json
├── tsconfig.json       # TypeScript config for renderer
├── tsconfig.main.json  # TypeScript config for main process
└── vite.config.ts      # Vite configuration
```

## How It Works

1. **Main Process** (`main.ts`):
   - Reads todo files from `~/.claude/todos/`
   - Reads project mappings from `~/.claude/projects/`
   - Converts flattened paths back to real paths
   - Provides IPC endpoint for renderer to fetch data

2. **Preload Script** (`preload.ts`):
   - Safely exposes `getTodos` API to renderer

3. **Renderer Process** (`App.tsx`):
   - Fetches todo data via IPC
   - Displays projects in sidebar
   - Shows session tabs for selected project
   - Renders todos with status indicators
   - Auto-refreshes every 5 seconds

## Building for Distribution

```bash
# Windows
npm run dist

# The packaged app will be in the `release` folder
```

## Usage

1. Start the app
2. Projects with todos appear in the left sidebar
3. Click a project to view its sessions
4. Click session tabs to switch between different Claude Code sessions
5. Todos are displayed with:
   - Numbers for easy reference
   - Status icons and colors
   - Sorted by completion status

The app automatically refreshes every 5 seconds to show the latest todos.