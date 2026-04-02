import { postMessage } from '../lib/bridge'
import { Kbd, KbdGroup } from './Kbd'

export function Welcome() {
  return (
    <div className="flex flex-col items-center justify-center flex-1 w-full p-12">
      <h1
        className="font-serif text-5xl font-bold text-primary tracking-tight mb-2 animate-[fadeUp_0.6s_ease-out_0.1s_both]"
      >
        mdreader
      </h1>
      <p className="font-serif text-lg text-muted mb-8 animate-[fadeUp_0.6s_ease-out_0.25s_both]">
        A beautiful markdown reader
      </p>

      <div className="flex flex-col gap-2 animate-[fadeUp_0.5s_ease-out_0.4s_both]">
        <button
          onClick={() => postMessage('openFile')}
          className="flex items-center justify-between w-[220px] px-4 py-2.5 bg-surface border border-edge rounded-lg text-primary font-sans text-sm font-[450] cursor-pointer transition-all duration-150 hover:bg-surface-hover hover:-translate-y-px hover:shadow-md"
        >
          <span>Open File</span>
          <KbdGroup><Kbd>⌘</Kbd><Kbd>O</Kbd></KbdGroup>
        </button>
        <button
          onClick={() => postMessage('openFolder')}
          className="flex items-center justify-between w-[220px] px-4 py-2.5 bg-surface border border-edge rounded-lg text-primary font-sans text-sm font-[450] cursor-pointer transition-all duration-150 hover:bg-surface-hover hover:-translate-y-px hover:shadow-md"
        >
          <span>Open Folder</span>
          <KbdGroup><Kbd>⌘</Kbd><Kbd>⇧</Kbd><Kbd>O</Kbd></KbdGroup>
        </button>
      </div>

      <p className="font-sans text-xs text-dim mt-4 animate-[fadeIn_0.5s_ease-out_0.55s_both]">
        or drag a .md file anywhere
      </p>
    </div>
  )
}
