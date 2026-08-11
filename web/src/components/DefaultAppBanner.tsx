import { BookOpenIcon, XIcon } from '@phosphor-icons/react'
import { postMessage } from '../lib/bridge'

/**
 * Bottom-center prompt offering to make mdreader the default markdown
 * reader. Swift triggers it once per install when another app owns
 * the .md file type.
 *
 * @param onDismiss - Hides the banner after either choice.
 */
export function DefaultAppBanner({ onDismiss }: { onDismiss: () => void }) {
  return (
    <div className="animate-fade-up">
      <div className="flex items-center gap-3 px-4 py-2 rounded-xl border border-border bg-card/90 backdrop-blur-md shadow-lg">
        <span className="font-sans text-sm text-card-foreground">
          Make mdreader your default markdown reader?
        </span>
        <button
          onClick={() => {
            postMessage('setDefaultApp')
            onDismiss()
          }}
          className="flex items-center gap-2 px-3 py-1 rounded-lg bg-accent/20 text-accent-bright font-sans text-xs font-medium cursor-pointer border-none transition-all duration-150 hover:bg-accent/30 active:scale-95"
        >
          <BookOpenIcon size={13} />
          Set as default
        </button>
        <button
          onClick={() => {
            postMessage('dismissDefaultBanner')
            onDismiss()
          }}
          className="w-5 h-5 flex items-center justify-center rounded text-dim cursor-pointer border-none bg-transparent transition-colors hover:text-muted-foreground"
        >
          <XIcon size={12} />
        </button>
      </div>
    </div>
  )
}
