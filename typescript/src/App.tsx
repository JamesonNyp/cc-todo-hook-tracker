import React, { useState, useEffect } from 'react';
import './App.css';

interface Todo {
  content: string;
  status: 'pending' | 'in_progress' | 'completed';
  activeForm?: string;
}

interface Session {
  id: string;
  todos: Todo[];
  lastModified: Date;
  created?: Date;
}

interface Project {
  path: string;
  sessions: Session[];
}

declare global {
  interface Window {
    electronAPI: {
      getTodos: () => Promise<Project[]>;
    };
  }
}

type SortMethod = 0 | 1 | 2; // 0=alphabetic, 1=recent, 2=todos
type PaddingMode = 0 | 1 | 2; // 0=normal, 1=compact, 2=none

function App() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedProject, setSelectedProject] = useState<Project | null>(null);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [sortMethod, setSortMethod] = useState<SortMethod>(1); // recent
  const [paddingMode, setPaddingMode] = useState<PaddingMode>(2); // none

  // Load todos data
  useEffect(() => {
    loadTodos();
    // Refresh every 5 seconds
    const interval = setInterval(loadTodos, 5000);
    return () => clearInterval(interval);
  }, []);

  const loadTodos = async () => {
    try {
      const data = await window.electronAPI.getTodos();
      
      // Deduplicate sessions within each project
      const deduplicatedData = data.map(project => ({
        ...project,
        sessions: project.sessions.reduce((unique: Session[], session) => {
          const existing = unique.find(s => s.id === session.id);
          if (existing) {
            // Merge todos and use latest modified date
            const allTodos = [...existing.todos, ...session.todos];
            const uniqueTodos = allTodos.filter((todo, index, self) => 
              index === self.findIndex(t => t.content === todo.content && t.status === todo.status)
            );
            existing.todos = uniqueTodos;
            existing.lastModified = new Date(Math.max(existing.lastModified.getTime(), session.lastModified.getTime()));
          } else {
            unique.push(session);
          }
          return unique;
        }, [])
      }));
      
      setProjects(deduplicatedData);
      
      // If a project was selected, update it
      if (selectedProject) {
        const updated = deduplicatedData.find(p => p.path === selectedProject.path);
        if (updated) {
          setSelectedProject(updated);
          // Update selected session if it exists
          if (selectedSession) {
            const updatedSession = updated.sessions.find(s => s.id === selectedSession.id);
            if (updatedSession) {
              setSelectedSession(updatedSession);
            }
          }
        }
      }
      
      setLoading(false);
    } catch (error) {
      console.error('Failed to load todos:', error);
      setLoading(false);
    }
  };

  const selectProject = (project: Project) => {
    setSelectedProject(project);
    setSelectedSession(project.sessions[0] || null);
  };

  const getTodoStats = (todos: Todo[]) => {
    const completed = todos.filter(t => t.status === 'completed').length;
    const active = todos.filter(t => t.status === 'in_progress').length;
    const pending = todos.filter(t => t.status === 'pending').length;
    return { completed, active, pending, total: todos.length };
  };

  const sortTodos = (todos: Todo[]) => {
    return [...todos].sort((a, b) => {
      const order = { completed: 0, in_progress: 1, pending: 2 };
      return order[a.status] - order[b.status];
    });
  };

  const sortProjects = (projects: Project[]) => {
    return [...projects].sort((a, b) => {
      switch (sortMethod) {
        case 0: // alphabetic
          const nameA = a.path.split(/[\\\/]/).pop() || a.path;
          const nameB = b.path.split(/[\\\/]/).pop() || b.path;
          return nameA.localeCompare(nameB);
        
        case 1: // recent
          const latestA = Math.max(...a.sessions.map(s => s.lastModified.getTime()));
          const latestB = Math.max(...b.sessions.map(s => s.lastModified.getTime()));
          return latestB - latestA; // Most recent first
        
        case 2: // todos
          const countA = a.sessions.reduce((sum, s) => sum + s.todos.length, 0);
          const countB = b.sessions.reduce((sum, s) => sum + s.todos.length, 0);
          return countB - countA; // Most todos first
        
        default:
          return 0;
      }
    });
  };

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        <p>Loading todos...</p>
      </div>
    );
  }

  return (
    <div className="app">
      {/* Sidebar with projects */}
      <div className="sidebar">
        <div className="sidebar-header">
          <h2>Projects</h2>
          <span className="project-count">{projects.length}</span>
        </div>
        
        <div className="sort-controls">
          <div className="sort-title">Sort by:</div>
          <div className="tristate-toggle" onClick={() => setSortMethod((prev) => ((prev + 1) % 3) as SortMethod)}>
            <div className={`toggle-option ${sortMethod === 0 ? 'active' : ''}`}>Name</div>
            <div className={`toggle-option ${sortMethod === 1 ? 'active' : ''}`}>Recent</div>
            <div className={`toggle-option ${sortMethod === 2 ? 'active' : ''}`}>Todo Count</div>
          </div>
        </div>
        
        <div className="project-list">
          {sortProjects(projects).map((project, idx) => {
            const totalTodos = project.sessions.reduce((sum, s) => sum + s.todos.length, 0);
            const mostRecentDate = project.sessions.length > 0 
              ? Math.max(...project.sessions.map(s => s.lastModified.getTime()))
              : 0;
            const isSelected = selectedProject?.path === project.path;
            
            return (
              <div
                key={idx}
                className={`project-item ${isSelected ? 'selected' : ''}`}
                onClick={() => selectProject(project)}
              >
                <div className="project-name">
                  {project.path.split(/[\\\/]/).pop() || project.path}
                </div>
                <div className="project-meta">
                  <div className="meta-row">
                    <span className="session-count">{project.sessions.length} sessions</span>
                    <span className="todo-count">{totalTodos} todos</span>
                  </div>
                  {mostRecentDate > 0 && (
                    <div className="meta-row">
                      <span className="recent-date">
                        Last: {new Date(mostRecentDate).toLocaleDateString()}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Main content area */}
      <div className="main-content">
        {selectedProject ? (
          <>
            {/* Project header with tabs */}
            <div className="content-header">
              <div className="header-top">
                <h1>{selectedProject.path}</h1>
                <div className="padding-controls">
                  <div className="padding-title">Spacing:</div>
                  <div className="tristate-toggle" onClick={() => setPaddingMode((prev) => ((prev + 1) % 3) as PaddingMode)}>
                    <div className={`toggle-option ${paddingMode === 0 ? 'active' : ''}`}>Normal</div>
                    <div className={`toggle-option ${paddingMode === 1 ? 'active' : ''}`}>Compact</div>
                    <div className={`toggle-option ${paddingMode === 2 ? 'active' : ''}`}>None</div>
                  </div>
                </div>
              </div>
              <div className="tabs">
                {[...selectedProject.sessions]
                  .sort((a, b) => b.lastModified.getTime() - a.lastModified.getTime())
                  .map((session) => (
                  <button
                    key={session.id}
                    className={`tab ${selectedSession?.id === session.id ? 'active' : ''}`}
                    onClick={() => setSelectedSession(session)}
                  >
                    <div className="tab-header">
                      <span className="tab-title">Session {session.id}</span>
                      <span className="tab-badge">{session.todos.length}</span>
                    </div>
                    <div className="tab-meta">
                      <div className="tab-date">Updated: {new Date(session.lastModified).toLocaleDateString()}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Todo list for selected session */}
            {selectedSession && (
              <div className="todo-container">
                <div className="session-stats">
                  {(() => {
                    const stats = getTodoStats(selectedSession.todos);
                    return (
                      <>
                        <div className="stat">
                          <span className="stat-label">Total:</span>
                          <span className="stat-value">{stats.total}</span>
                        </div>
                        <div className="stat completed">
                          <span className="stat-label">Completed:</span>
                          <span className="stat-value">{stats.completed}</span>
                        </div>
                        <div className="stat active">
                          <span className="stat-label">Active:</span>
                          <span className="stat-value">{stats.active}</span>
                        </div>
                        <div className="stat pending">
                          <span className="stat-label">Pending:</span>
                          <span className="stat-value">{stats.pending}</span>
                        </div>
                        <div className="stat">
                          <span className="stat-label">Updated:</span>
                          <span className="stat-value">
                            {new Date(selectedSession.lastModified).toLocaleTimeString()}
                          </span>
                        </div>
                      </>
                    );
                  })()}
                </div>

                <div className={`todo-list padding-${paddingMode === 0 ? 'normal' : paddingMode === 1 ? 'compact' : 'none'}`}>
                  {sortTodos(selectedSession.todos).map((todo, idx) => (
                    <div key={idx} className={`todo-item ${todo.status}`}>
                      <span className="todo-number">{idx + 1}.</span>
                      <span className="todo-icon">
                        {todo.status === 'completed' && '✓'}
                        {todo.status === 'in_progress' && '▶'}
                        {todo.status === 'pending' && '○'}
                      </span>
                      <span className="todo-content">
                        {todo.status === 'in_progress' && todo.activeForm
                          ? todo.activeForm
                          : todo.content}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        ) : (
          <div className="empty-state">
            <h2>Select a project to view todos</h2>
            <p>Choose from {projects.length} projects with active todo lists</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;