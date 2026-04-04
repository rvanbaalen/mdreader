import { FileTextIcon, FolderIcon, ClockIcon } from '@phosphor-icons/react'
import { postMessage } from '../lib/bridge'

interface RecentItem {
  path: string
  name: string
  isDir: boolean
}

export function Recents({ items }: { items: RecentItem[] }) {
  if (items.length === 0) return null

  return (
    <div className="mt-12 w-[320px] animate-[fadeUp_0.5s_ease-out_0.6s_both]">
      <div className="flex items-center gap-2 mb-3">
        <ClockIcon size={14} className="text-dim" />
        <span className="font-sans text-[11px] font-medium text-dim uppercase tracking-wider">Recent</span>
      </div>
      <div className="flex flex-col gap-1">
        {items.slice(0, 5).map((item) => (
          <button
            key={item.path}
            onClick={() => postMessage('openFilePath', { path: item.path })}
            className="flex items-center gap-2 w-full px-3 py-2 rounded-lg bg-transparent border-none font-sans text-sm text-card-foreground cursor-pointer transition-all duration-150 hover:bg-muted hover:text-foreground group text-left"
          >
            {item.isDir
              ? <FolderIcon size={16} className="text-muted-foreground shrink-0" />
              : <FileTextIcon size={16} className="text-muted-foreground shrink-0" />
            }
            <span className="truncate">{item.name}</span>
            <span className="ml-auto text-xs text-dim truncate max-w-[140px] opacity-0 group-hover:opacity-100 transition-opacity duration-150">
              {item.path.replace(/^\/Users\/[^/]+/, '~')}
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}
