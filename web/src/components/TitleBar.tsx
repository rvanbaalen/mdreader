import { Sidebar, ListBullets, Code, Sun, Moon } from '@phosphor-icons/react'
import { useApp } from '../hooks/useStore'
import { postMessage } from '../lib/bridge'

function IconButton({ children, onClick, active, title }: {
  children: React.ReactNode
  onClick: () => void
  active?: boolean
  title?: string
}) {
  return (
    <button
      onClick={onClick}
      title={title}
      className={`w-7 h-7 flex items-center justify-center rounded border-none cursor-pointer transition-all duration-150
        ${active ? 'text-accent' : 'text-muted'} hover:text-secondary hover:bg-surface-hover active:scale-90`}
    >
      {children}
    </button>
  )
}

export function TitleBar() {
  const { theme, currentFile, currentFolder, sidebarVisible, tocVisible, sourceVisible,
    cycleTheme, toggleSidebar, toggleToc, toggleSource, folderTree } = useApp()

  const hasFile = !!currentFile
  const hasFolder = folderTree.length > 0

  return (
    <div
      className="h-9.5 flex items-center pl-20 pr-3.5 select-none absolute top-0 left-0 right-0 z-10 bg-base/70 backdrop-blur-md"
      onMouseDown={(e) => {
        if ((e.target as HTMLElement).closest('button')) return
        postMessage('startDrag')
      }}
    >
      <div className="flex-1 text-center overflow-hidden text-ellipsis whitespace-nowrap font-sans text-xs text-muted">
        {currentFile && (
          <>
            {currentFolder && <><span className="text-dim">{currentFolder}</span><span className="text-dim/30"> / </span></>}
            {currentFile}
          </>
        )}
      </div>

      <div className="flex gap-0.5">
        {hasFile && hasFolder && (
          <IconButton onClick={toggleSidebar} active={sidebarVisible} title="Toggle Sidebar (⌘\)">
            <Sidebar size={14} />
          </IconButton>
        )}
        {hasFile && (
          <>
            <IconButton onClick={toggleToc} active={tocVisible} title="Table of Contents (⌘⇧E)">
              <ListBullets size={14} />
            </IconButton>
            <IconButton onClick={toggleSource} active={sourceVisible} title="Source View (⌘⇧S)">
              <Code size={14} />
            </IconButton>
          </>
        )}
        <IconButton onClick={cycleTheme} title="Toggle Theme (⌘⇧T)">
          {theme === 'dark' ? <Sun size={14} /> : <Moon size={14} />}
        </IconButton>
      </div>
    </div>
  )
}
