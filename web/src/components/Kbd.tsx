import { Command, ArrowFatUp, Option, Control } from '@phosphor-icons/react'

interface KbdProps {
  children: React.ReactNode
}

const metaIcons: Record<string, React.ReactNode> = {
  '⌘': <Command size={12} />,
  '⇧': <ArrowFatUp size={12} />,
  '⌥': <Option size={12} />,
  '⌃': <Control size={12} />,
}

export function Kbd({ children }: KbdProps) {
  const text = typeof children === 'string' ? children : ''
  const icon = metaIcons[text]

  return (
    <kbd className="inline-flex items-center justify-center min-w-[22px] h-[22px] rounded-[4px] border border-edge border-b-2 bg-surface px-1 font-mono text-[11px] text-muted leading-none select-none">
      {icon || children}
    </kbd>
  )
}

export function KbdGroup({ children }: KbdProps) {
  return (
    <span className="inline-flex items-center gap-[2px]">
      {children}
    </span>
  )
}
