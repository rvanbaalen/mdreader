import { CommandIcon } from '@phosphor-icons/react'
import { postMessage } from '../lib/bridge'
import { Button } from '@/components/ui/button'
import { Recents } from './Recents'

interface RecentItem {
  path: string
  name: string
  isDir: boolean
}

export function Welcome({ recents }: { recents: RecentItem[] }) {
  return (
    <div className="flex flex-col items-center justify-center flex-1 w-full p-12">
      <h1
        className="font-serif text-5xl font-bold text-foreground tracking-tight mb-2 animate-[fadeUp_0.6s_ease-out_0.1s_both]"
      >
        mdreader
      </h1>
      <p className="font-serif text-lg text-muted-foreground mb-8 animate-[fadeUp_0.6s_ease-out_0.25s_both]">
        A beautiful markdown reader
      </p>

      <div className="animate-[fadeUp_0.5s_ease-out_0.4s_both] group">
        <button
          onClick={() => postMessage('open')}
          className="flex items-center justify-between w-[220px] px-4 py-2 rounded-lg bg-secondary text-secondary-foreground font-sans text-sm font-medium cursor-pointer transition-all duration-150 hover:bg-secondary/80"
        >
          Open
          <span className="flex items-center gap-0.5 opacity-0 translate-x-2 transition-[opacity] duration-75 group-hover:opacity-60 group-hover:translate-x-0 group-hover:transition-all group-hover:duration-150 text-xs">
            <CommandIcon size={11} />
            <span>O</span>
          </span>
        </button>
      </div>

      <p className="font-sans text-xs text-dim mt-4 animate-[fadeIn_0.5s_ease-out_0.55s_both]">
        or drag a .md file anywhere
      </p>

      <Recents items={recents} />
    </div>
  )
}
