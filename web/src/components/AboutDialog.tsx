import { useEffect, useCallback } from 'react'
import { BookOpenIcon, ArrowsClockwiseIcon } from '@phosphor-icons/react'
import { postMessage } from '@/lib/bridge'

interface AboutInfo {
  version: string
  commit: string
  build: string
}

export function AboutDialog({ info, onClose }: { info: AboutInfo | null; onClose: () => void }) {
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (e.key === 'Escape' || e.key === 'Enter') {
      e.preventDefault()
      onClose()
    }
  }, [onClose])

  useEffect(() => {
    if (!info) return
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [info, handleKeyDown])

  if (!info) return null

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/40 backdrop-blur-sm transition-opacity duration-200"
      onClick={onClose}
    >
      <div
        className="w-[280px] rounded-2xl bg-card border border-border/50 shadow-2xl p-8 flex flex-col items-center gap-4 animate-in fade-in zoom-in-95 duration-200"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-16 h-16 rounded-xl bg-[oklch(0.25_0.02_260)] flex items-center justify-center">
          <BookOpenIcon size={32} weight="fill" className="text-white/90" />
        </div>

        <div className="flex flex-col items-center gap-0.5">
          <h1 className="text-lg font-semibold text-foreground tracking-tight">mdreader</h1>
          <span className="text-xs text-muted-foreground tabular-nums">
            v{info.version}{info.commit ? ` (${info.commit})` : ''}
          </span>
        </div>

        <p className="text-sm text-muted-foreground text-center leading-relaxed">
          A beautiful macOS markdown reader
        </p>

        <button
          onClick={() => {
            postMessage('checkForUpdates')
            onClose()
          }}
          className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors duration-150 cursor-default"
        >
          <ArrowsClockwiseIcon size={12} />
          Check for Updates
        </button>

        <a
          href="#"
          onClick={(e) => {
            e.preventDefault()
            postMessage('openURL', { url: 'https://robinvanbaalen.nl/projects/mdreader' })
          }}
          className="text-xs text-accent-foreground/70 hover:text-accent-foreground transition-colors duration-150 underline underline-offset-2"
        >
          robinvanbaalen.nl/projects/mdreader
        </a>
      </div>
    </div>
  )
}
