import { useRef, useEffect } from 'react'
import { useApp } from '../hooks/useStore'
import { renderMarkdown, extractHeadings } from '../lib/markdown'
import { showToast } from './Toast'

export function Reader() {
  const { markdown, sourceVisible, setHeadings, setActiveHeading } = useApp()
  const contentRef = useRef<HTMLDivElement>(null)
  const readerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (sourceVisible || !contentRef.current) return
    // renderMarkdown uses DOMPurify — output is sanitized
    const sanitizedHtml = renderMarkdown(markdown)
    const el = contentRef.current
    while (el.firstChild) el.removeChild(el.firstChild)
    const tpl = document.createElement('template')
    tpl.innerHTML = sanitizedHtml
    el.appendChild(tpl.content)

    // Copy buttons on code blocks
    el.querySelectorAll('.copy-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const code = btn.getAttribute('data-code')?.replace(/&amp;/g, '&').replace(/&quot;/g, '"') || ''
        navigator.clipboard.writeText(code).then(() => {
          btn.classList.add('copied')
          setTimeout(() => btn.classList.remove('copied'), 2000)
          showToast('Copied to clipboard')
        })
      })
    })

    // Click-to-copy on inline code
    el.querySelectorAll('code:not(.hljs)').forEach(code => {
      ;(code as HTMLElement).style.cursor = 'pointer'
      code.setAttribute('title', 'Click to copy')
      code.addEventListener('click', () => {
        navigator.clipboard.writeText(code.textContent || '').then(() => {
          code.classList.add('copied-inline')
          setTimeout(() => code.classList.remove('copied-inline'), 1500)
          showToast('Copied to clipboard')
        })
      })
    })

    setHeadings(extractHeadings(el))

    // Stagger animation
    el.classList.remove('animate-content')
    void el.offsetWidth
    el.classList.add('animate-content')
  }, [markdown, sourceVisible, setHeadings])

  // Scroll tracking for ToC
  useEffect(() => {
    const reader = readerRef.current
    if (!reader) return
    let ticking = false
    const onScroll = () => {
      if (!ticking) {
        requestAnimationFrame(() => {
          const headings = contentRef.current?.querySelectorAll('h1, h2, h3, h4')
          let activeId = ''
          headings?.forEach(h => {
            if (h.getBoundingClientRect().top <= 80) activeId = h.id
          })
          setActiveHeading(activeId)
          ticking = false
        })
        ticking = true
      }
    }
    reader.addEventListener('scroll', onScroll, { passive: true })
    return () => reader.removeEventListener('scroll', onScroll)
  }, [setActiveHeading])

  if (sourceVisible) {
    return (
      <div ref={readerRef} className="flex-1 overflow-y-auto overflow-x-hidden relative" style={{ WebkitOverflowScrolling: 'touch' }}>
        <pre className="max-w-[720px] mx-auto px-16 py-12 font-mono text-sm leading-[1.7] text-secondary whitespace-pre-wrap break-words select-text">
          {markdown}
        </pre>
      </div>
    )
  }

  return (
    <div ref={readerRef} className="flex-1 overflow-y-auto overflow-x-hidden relative" style={{ WebkitOverflowScrolling: 'touch' }}>
      <div className="fixed inset-0 pointer-events-none z-0" style={{
        background: 'radial-gradient(ellipse at 8% 15%, var(--color-accent-glow), transparent 50%)',
        top: 38,
      }} />
      <div ref={contentRef} className="content relative z-[1] max-w-[720px] mx-auto px-16 py-12" />
    </div>
  )
}
