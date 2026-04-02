import { Sidebar, ListBullets, Code, Sun, Moon } from '@phosphor-icons/react'
import { useApp } from '../hooks/useStore'
import { postMessage } from '../lib/bridge'

function TrafficLight({ color, action }: { color: string; action: string }) {
  return (
    <button
      className={`w-3 h-3 rounded-full border-none cursor-pointer transition-opacity ${color}`}
      onClick={() => postMessage(action)}
    />
  )
}

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
      className="h-[38px] flex items-center px-3.5 shrink-0 bg-transparent select-none"
      onMouseDown={(e) => {
        if ((e.target as HTMLElement).closest('button')) return
        postMessage('startDrag')
      }}
    >
      <div className="flex gap-2 pl-1.5 shrink-0 animate-[fadeIn_0.4s_ease-out]">
        <TrafficLight color="bg-[#ff5f57]" action="close" />
        <TrafficLight color="bg-[#febc2e]" action="minimize" />
        <TrafficLight color="bg-[#28c840]" action="zoom" />
      </div>

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
