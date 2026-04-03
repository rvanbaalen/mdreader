import { useApp } from '../hooks/useStore'

export function Toc() {
  const { tocVisible, headings, activeHeadingId } = useApp()

  return (
    <div
      className={`absolute top-12 bottom-4 right-4 z-10 w-[220px] transition-all duration-150 ease-out ${tocVisible ? 'opacity-100 translate-x-0' : 'opacity-0 translate-x-4 pointer-events-none'}`}
    >
      <div className="h-full rounded-xl border border-border/40 bg-card/60 backdrop-blur-[16px] py-6 overflow-y-auto shadow-lg shadow-background/50">
        <div className="px-6 pb-3 font-sans text-[11px] font-medium text-muted-foreground uppercase tracking-wider">
          On this page
        </div>
        <div className="flex flex-col">
          {headings.map(h => {
            const isActive = h.id === activeHeadingId
            const indent = Math.max(0, h.level - 2)
            return (
              <button
                key={h.id}
                onClick={() => document.getElementById(h.id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
                className={`flex items-center gap-2 w-full border-none bg-transparent font-sans text-left cursor-pointer px-6 py-2 transition-colors duration-100 truncate
                  ${h.level <= 1 ? 'text-[13px] font-medium' : 'text-xs'}
                  ${isActive ? 'text-accent-bright' : 'text-muted-foreground hover:text-foreground hover:bg-muted'}`}
                style={{ paddingLeft: `${24 + indent * 12}px` }}
              >
                {isActive && (
                  <span className="w-0.5 h-4 rounded-full bg-accent shrink-0 -ml-2" />
                )}
                <span className="truncate">{h.text}</span>
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}
