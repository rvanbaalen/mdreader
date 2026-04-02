import { useState } from 'react'
import { useApp, type FileNode } from '../hooks/useStore'
import { postMessage } from '../lib/bridge'

// Phosphor SVG icons
const FolderIcon = () => (
  <svg width="16" height="16" viewBox="0 0 256 256" fill="none" stroke="currentColor" strokeWidth="16" strokeLinecap="round" strokeLinejoin="round">
    <path d="M216,72H131.31L104,44.69A15.86,15.86,0,0,0,92.69,40H40A16,16,0,0,0,24,56V200.62A15.4,15.4,0,0,0,39.38,216H216.89A15.13,15.13,0,0,0,232,200.89V88A16,16,0,0,0,216,72Z"/>
  </svg>
)
const FolderOpenIcon = () => (
  <svg width="16" height="16" viewBox="0 0 256 256" fill="none" stroke="currentColor" strokeWidth="16" strokeLinecap="round" strokeLinejoin="round">
    <path d="M228.42,136H69.58a8,8,0,0,0-7.72,5.91L42,216"/>
    <path d="M216,72H131.31L104,44.69A15.86,15.86,0,0,0,92.69,40H40A16,16,0,0,0,24,56V200.62A15.4,15.4,0,0,0,39.38,216H216.89A15.13,15.13,0,0,0,232,200.89V88A16,16,0,0,0,216,72Z"/>
  </svg>
)
const FileIcon = () => (
  <svg width="16" height="16" viewBox="0 0 256 256" fill="none" stroke="currentColor" strokeWidth="16" strokeLinecap="round" strokeLinejoin="round">
    <path d="M200,224H56a8,8,0,0,1-8-8V40a8,8,0,0,1,8-8h96l56,56V216A8,8,0,0,1,200,224Z"/>
    <polyline points="152 32 152 88 208 88"/><line x1="96" y1="136" x2="160" y2="136"/><line x1="96" y1="168" x2="160" y2="168"/>
  </svg>
)
const ChevronIcon = ({ open }: { open: boolean }) => (
  <svg width="10" height="10" viewBox="0 0 256 256" fill="none" stroke="currentColor" strokeWidth="24" strokeLinecap="round" strokeLinejoin="round"
    className={`transition-transform duration-150 ${open ? 'rotate-90' : ''}`}>
    <polyline points="96 48 176 128 96 208"/>
  </svg>
)

function FolderRow({ node }: { node: FileNode }) {
  const [open, setOpen] = useState(false)

  return (
    <div>
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1 w-full h-[30px] px-2.5 border-none bg-transparent font-sans text-[13px] font-medium text-muted cursor-pointer rounded-md transition-colors duration-100 hover:bg-surface-hover hover:text-secondary"
      >
        <span className="w-3.5 shrink-0 flex items-center justify-center text-dim">
          <ChevronIcon open={open} />
        </span>
        <span className="w-4 shrink-0 flex items-center justify-center text-muted">
          {open ? <FolderOpenIcon /> : <FolderIcon />}
        </span>
        <span className="truncate min-w-0 ml-1.5">{node.name}</span>
      </button>
      {open && node.children && (
        <div className="ml-4 pl-3.5 border-l border-edge-subtle">
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
      className={`relative flex items-center gap-1 w-full h-[30px] px-2.5 border-none bg-transparent font-sans text-[13px] cursor-pointer rounded-md transition-colors duration-100
        ${isActive ? 'bg-accent-glow text-accent-bright' : 'text-secondary hover:bg-surface-hover'}`}
    >
      <span className={`w-4 shrink-0 flex items-center justify-center ${isActive ? 'text-accent' : 'text-muted'}`}>
        <FileIcon />
      </span>
      <span className="tree-name truncate min-w-0 ml-1.5">{node.name}</span>
      {showTip && (
        <span className="absolute left-0 top-full bg-surface border border-edge rounded px-2 py-1 text-xs text-primary whitespace-nowrap shadow-lg z-50 animate-[fadeIn_0.15s_ease-out]">
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
      className={`shrink-0 transition-all duration-300 ease-out ${sidebarVisible ? 'w-[276px] p-4 pr-0' : 'w-0 p-0 overflow-hidden opacity-0'}`}
    >
      <div className="h-full rounded-xl border border-edge/40 bg-surface/60 backdrop-blur-[16px] py-6 overflow-y-auto">
        {currentFolder && (
          <div className="px-6 pb-3 font-sans text-[11px] font-medium text-muted uppercase tracking-wider">
            {currentFolder}
          </div>
        )}
        <div className="px-1.5">
          <FileTree nodes={folderTree} />
        </div>
      </div>
    </div>
  )
}
