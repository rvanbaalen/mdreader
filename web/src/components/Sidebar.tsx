import { useState } from 'react'
import { FolderIcon, FolderOpenIcon, FileTextIcon, CaretRightIcon } from '@phosphor-icons/react'
import { useApp, type FileNode } from '../hooks/useStore'
import { postMessage } from '../lib/bridge'

function FolderRow({ node }: { node: FileNode }) {
  const [open, setOpen] = useState(false)

  return (
    <div>
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1 w-full h-[30px] px-2 border-none bg-transparent font-sans text-[13px] font-medium text-muted-foreground cursor-pointer rounded-md transition-colors duration-100 hover:bg-muted hover:text-card-foreground"
      >
        <span className="w-4 shrink-0 flex items-center justify-center text-dim">
          <CaretRightIcon size={10} className={`transition-transform duration-150 ${open ? 'rotate-90' : ''}`} />
        </span>
        <span className="w-4 shrink-0 flex items-center justify-center text-muted-foreground">
          {open ? <FolderOpenIcon size={16} /> : <FolderIcon size={16} />}
        </span>
        <span className="truncate min-w-0 ml-2">{node.name}</span>
      </button>
      {open && node.children && (
        <div className="ml-4 pl-4 border-l border-edge-subtle">
          <FileTree nodes={node.children} />
        </div>
      )}
    </div>
  )
}

function FileRow({ node }: { node: FileNode }) {
  const { currentFile } = useApp()
  const isActive = currentFile === node.name
  const [showTip, setShowTip] = useState(false)
  const nameRef = useState<HTMLSpanElement | null>(null)

  return (
    <button
      onClick={() => postMessage('openFilePath', { path: node.path })}
      onMouseEnter={(e) => {
        const span = e.currentTarget.querySelector('.tree-name') as HTMLSpanElement
        if (span && span.scrollWidth > span.clientWidth) setShowTip(true)
      }}
      onMouseLeave={() => setShowTip(false)}
      className={`relative flex items-center gap-1 w-full h-[30px] px-2 border-none bg-transparent font-sans text-[13px] cursor-pointer rounded-md transition-colors duration-100
        ${isActive ? 'bg-accent-glow text-accent-bright' : 'text-card-foreground hover:bg-muted'}`}
    >
      <span className={`w-4 shrink-0 flex items-center justify-center ${isActive ? 'text-accent' : 'text-muted-foreground'}`}>
        <FileTextIcon size={16} />
      </span>
      <span className="tree-name truncate min-w-0 ml-2">{node.name}</span>
      {showTip && (
        <span className="absolute left-0 top-full bg-card border border-border rounded px-2 py-1 text-xs text-foreground whitespace-nowrap shadow-lg z-50 animate-[fadeIn_0.15s_ease-out]">
          {node.name}
        </span>
      )}
    </button>
  )
}

function FileTree({ nodes }: { nodes: FileNode[] }) {
  return (
    <>
      {nodes.map((node, i) =>
        node.isDir
          ? <FolderRow key={`${node.name}-${i}`} node={node} />
          : <FileRow key={`${node.name}-${i}`} node={node} />
      )}
    </>
  )
}

export function Sidebar() {
  const { sidebarVisible, folderTree, currentFolder } = useApp()

  return (
    <div
      className={`absolute top-12 bottom-4 left-4 z-10 w-[260px] transition-all duration-300 ease-out ${sidebarVisible ? 'opacity-100 translate-x-0' : 'opacity-0 -translate-x-4 pointer-events-none'}`}
    >
      <div className="h-full rounded-xl border border-border/40 bg-card/60 backdrop-blur-[16px] py-6 overflow-y-auto shadow-lg shadow-background/50">
        {currentFolder && (
          <div className="px-6 pb-3 font-sans text-[11px] font-medium text-muted-foreground uppercase tracking-wider">
            {currentFolder}
          </div>
        )}
        <div className="px-2">
          <FileTree nodes={folderTree} />
        </div>
      </div>
    </div>
  )
}
