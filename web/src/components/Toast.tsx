import { useState, useEffect, useCallback } from 'react'

interface ToastItem {
  id: number
  message: string
}

let toastId = 0
let addToastFn: ((msg: string) => void) | null = null

// Global function — call from anywhere
export function showToast(message: string) {
  addToastFn?.(message)
}

export function ToastContainer() {
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const [hovered, setHovered] = useState(false)

  const addToast = useCallback((message: string) => {
    const id = ++toastId
    setToasts(prev => [...prev.slice(-2), { id, message }])
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id))
    }, 3000)
  }, [])

  useEffect(() => {
    addToastFn = addToast
    return () => { addToastFn = null }
  }, [addToast])

  if (toasts.length === 0) return null

  return (
    <div
      className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex flex-col-reverse items-center"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {toasts.map((toast, i) => {
        const fromTop = toasts.length - 1 - i
        const stacked = !hovered && fromTop > 0
        return (
          <div
            key={toast.id}
            className="bg-surface border border-edge rounded-xl px-4 py-2 font-sans text-[13px] text-secondary shadow-lg whitespace-nowrap transition-all duration-300 ease-out"
            style={{
              position: hovered ? 'relative' : 'absolute',
              bottom: hovered ? 0 : undefined,
              marginBottom: hovered ? 6 : 0,
              transform: stacked
                ? `translateY(-${fromTop * 8}px) scale(${1 - fromTop * 0.03})`
                : 'translateY(0) scale(1)',
              opacity: stacked ? Math.max(0, 1 - fromTop * 0.35) : 1,
            }}
          >
            {toast.message}
          </div>
        )
      })}
    </div>
  )
}
