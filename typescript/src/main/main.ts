import { app, BrowserWindow, ipcMain } from 'electron';
import * as path from 'path';
import * as fs from 'fs/promises';
import * as os from 'os';

let mainWindow: BrowserWindow | null = null;

// Paths to Claude directories
const claudeDir = path.join(os.homedir(), '.claude');
const todosDir = path.join(claudeDir, 'todos');
const projectsDir = path.join(claudeDir, 'projects');
const logsDir = path.join(claudeDir, 'logs');

interface Todo {
  content: string;
  status: 'pending' | 'in_progress' | 'completed';
  activeForm?: string;
}

interface Session {
  id: string;
  todos: Todo[];
  lastModified: Date;
}

interface Project {
  path: string;
  sessions: Session[];
}

// Convert flattened path back to real path
function convertFlattenedPath(flatPath: string): string {
  const isWindows = process.platform === 'win32';
  const pathSep = isWindows ? '\\' : '/';
  
  // Windows path with drive letter
  const windowsMatch = flatPath.match(/^([A-Z])--(.+)$/);
  if (windowsMatch) {
    const [, driveLetter, restOfPath] = windowsMatch;
    return `${driveLetter}:${pathSep}${restOfPath.replace(/-/g, pathSep)}`;
  }
  
  // Unix absolute path
  if (flatPath.startsWith('-')) {
    return '/' + flatPath.slice(1).replace(/-/g, '/');
  }
  
  // Relative or other path format
  return flatPath.replace(/-/g, pathSep);
}

// Find project path for a session ID
async function findProjectForSession(sessionId: string): Promise<string | null> {
  try {
    const projectDirs = await fs.readdir(projectsDir);
    
    for (const projDir of projectDirs) {
      const projPath = path.join(projectsDir, projDir);
      const files = await fs.readdir(projPath);
      
      if (files.some(f => f.startsWith(sessionId))) {
        return convertFlattenedPath(projDir);
      }
    }
  } catch (error) {
    console.error('Error finding project for session:', error);
  }
  
  return null;
}

// Load all todos data
async function loadTodosData(): Promise<Project[]> {
  const projects = new Map<string, Project>();
  
  try {
    // Read all todo files
    const todoFiles = await fs.readdir(todosDir);
    
    for (const file of todoFiles) {
      if (!file.endsWith('.json')) continue;
      
      try {
        const filePath = path.join(todosDir, file);
        const stats = await fs.stat(filePath);
        
        // Skip small files
        if (stats.size < 10) continue;
        
        const content = await fs.readFile(filePath, 'utf-8');
        const todos = JSON.parse(content);
        
        if (!Array.isArray(todos) || todos.length === 0) continue;
        
        // Extract session ID
        const sessionMatch = file.match(/^([a-f0-9-]+)-agent/);
        const fullSessionId = sessionMatch ? sessionMatch[1] : 'unknown';
        const sessionId = fullSessionId.substring(0, 8);
        
        // Find project path
        const projectPath = await findProjectForSession(fullSessionId) || 'Unknown Project';
        
        // Get or create project
        if (!projects.has(projectPath)) {
          projects.set(projectPath, {
            path: projectPath,
            sessions: []
          });
        }
        
        const project = projects.get(projectPath)!;
        project.sessions.push({
          id: sessionId,
          todos: todos,
          lastModified: stats.mtime
        });
        
      } catch (error) {
        console.error(`Error reading ${file}:`, error);
      }
    }
    
    // Also check current_todos.json
    try {
      const currentTodosPath = path.join(logsDir, 'current_todos.json');
      const content = await fs.readFile(currentTodosPath, 'utf-8');
      const data = JSON.parse(content);
      
      if (data.todos && data.todos.length > 0) {
        const sessionId = data.session_id ? data.session_id.substring(0, 8) : 'current';
        const projectPath = 'Current Session';
        
        if (!projects.has(projectPath)) {
          projects.set(projectPath, {
            path: projectPath,
            sessions: []
          });
        }
        
        const project = projects.get(projectPath)!;
        project.sessions.push({
          id: sessionId,
          todos: data.todos,
          lastModified: new Date()
        });
      }
    } catch (error) {
      // Current todos file might not exist
    }
    
  } catch (error) {
    console.error('Error loading todos:', error);
  }
  
  return Array.from(projects.values());
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#1a1d21',
    icon: path.join(__dirname, '../../assets/icon.png')
  });

  // In development, load from Vite dev server
  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    // In production, load the built files
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  // Handle IPC requests for todos data
  ipcMain.handle('get-todos', async () => {
    return await loadTodosData();
  });
  
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});