import { useApp } from '../hooks/useStore'

export function Toc() {
  const { tocVisible, headings, activeHeadingId } = useApp()

  return (
    <div
      className={`shrink-0 pt-12 pb-4 transition-all duration-300 ease-out ${tocVisible ? 'w-[220px] pr-4' : 'w-0 pr-0 overflow-hidden opacity-0'}`}
    >
      <div className="h-full rounded-xl border border-edge/40 bg-surface/60 backdrop-blur-[16px] py-6 overflow-y-auto">
        <div className="px-6 pb-3 font-sans text-[11px] font-medium text-muted uppercase tracking-wider">
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
                className={`flex items-center gap-2.5 w-full border-none bg-transparent font-sans text-left cursor-pointer px-6 py-1.5 transition-colors duration-100 truncate
                  ${h.level <= 1 ? 'text-[13px] font-medium' : 'text-xs'}
                  ${isActive ? 'text-accent-bright' : 'text-muted hover:text-primary hover:bg-surface-hover'}`}
                style={{ paddingLeft: `${24 + indent * 12}px` }}
              >
                {isActive && (
                  <span className="w-0.5 h-3.5 rounded-full bg-accent shrink-0 -ml-2.5" />
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
