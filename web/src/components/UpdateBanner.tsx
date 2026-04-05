import { DownloadSimpleIcon, XIcon, ArrowsClockwiseIcon } from '@phosphor-icons/react'
import { postMessage } from '../lib/bridge'
import { useState } from 'react'

interface UpdateBannerProps {
  latest: string
  onDismiss: () => void
}

export function UpdateBanner({ latest, onDismiss }: UpdateBannerProps) {
  const [installing, setInstalling] = useState(false)
  const [done, setDone] = useState(false)
  const [failed, setFailed] = useState(false)

  // Expose completion callbacks for Swift
  window.__updateComplete = () => setDone(true)
  window.__updateFailed = () => setFailed(true)

  const handleInstall = () => {
    setInstalling(true)
    setFailed(false)
    postMessage('installUpdate')
  }

  const handleRestart = () => {
    postMessage('restartApp')
  }

  return (
    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-20 animate-[fadeUp_0.4s_ease-out]">
      <div className="flex items-center gap-3 px-4 py-2 rounded-xl border border-border bg-card/90 backdrop-blur-md shadow-lg">
        <span className="font-sans text-sm text-card-foreground">
          {done
            ? 'Update installed — restart to use the new version'
            : failed
              ? 'Update failed — try again or update manually'
              : installing
                ? 'Installing update...'
                : `mdreader ${latest} is available`}
        </span>
        {done ? (
          <button
            onClick={handleRestart}
            className="flex items-center gap-2 px-3 py-1 rounded-lg bg-accent/20 text-accent-bright font-sans text-xs font-medium cursor-pointer border-none transition-all duration-150 hover:bg-accent/30 active:scale-95"
          >
            <ArrowsClockwiseIcon size={13} />
            Restart
          </button>
        ) : failed ? (
          <button
            onClick={handleInstall}
            className="flex items-center gap-2 px-3 py-1 rounded-lg bg-accent/20 text-accent-bright font-sans text-xs font-medium cursor-pointer border-none transition-all duration-150 hover:bg-accent/30 active:scale-95"
          >
            <ArrowsClockwiseIcon size={13} />
            Retry
          </button>
        ) : !installing ? (
          <button
            onClick={handleInstall}
            className="flex items-center gap-2 px-3 py-1 rounded-lg bg-accent/20 text-accent-bright font-sans text-xs font-medium cursor-pointer border-none transition-all duration-150 hover:bg-accent/30 active:scale-95"
          >
            <DownloadSimpleIcon size={13} />
            Install
          </button>
        ) : null}
        {!done && (
          <button
            onClick={onDismiss}
            className="w-5 h-5 flex items-center justify-center rounded text-dim cursor-pointer border-none bg-transparent transition-colors hover:text-muted-foreground"
          >
            <XIcon size={12} />
          </button>
        )}
      </div>
    </div>
  )
}
