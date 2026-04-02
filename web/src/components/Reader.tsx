import { useRef, useEffect, useMemo } from 'react'
import { useApp } from '../hooks/useStore'
import { renderMarkdown, extractHeadings, setFileDir } from '../lib/markdown'
import { showToast } from './Toast'
import hljs from 'highlight.js'

export function Reader() {
  const { markdown, sourceVisible, fileDir, setHeadings, setActiveHeading } = useApp()
  setFileDir(fileDir)
  const contentRef = useRef<HTMLDivElement>(null)
  const renderedRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (sourceVisible || !contentRef.current) return
    // renderMarkdown uses DOMPurify — output is sanitized
    const sanitizedHtml = renderMarkdown(markdown)
    const el = contentRef.current
    while (el.firstChild) el.removeChild(el.firstChild)
    const tpl = document.createElement('template')
    tpl.innerHTML = sanitizedHtml
    el.appendChild(tpl.content)

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

    el.classList.remove('animate-content')
    void el.offsetWidth
    el.classList.add('animate-content')
  }, [markdown, sourceVisible, setHeadings])

  // Scroll tracking for ToC
  useEffect(() => {
    const reader = renderedRef.current
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

  const highlightedSource = useMemo(() => {
    if (!sourceVisible || !markdown) return ''
    return hljs.highlight(markdown, { language: 'markdown' }).value
  }, [sourceVisible, markdown])

  if (sourceVisible) {
    return (
      <div className="flex-1 overflow-y-scroll overflow-x-hidden relative scroll-smooth">
        <pre className="max-w-[720px] mx-auto px-16 py-12 font-mono text-sm leading-[1.7] whitespace-pre-wrap break-words select-text">
          {/* hljs.highlight only produces <span> tags with class names — safe output */}
          <code className="hljs" dangerouslySetInnerHTML={{ __html: highlightedSource }} />
        </pre>
      </div>
    )
  }

  return (
    <div ref={renderedRef} className="flex-1 overflow-y-scroll overflow-x-hidden relative scroll-smooth">
      <div className="sticky top-0 h-0 pointer-events-none z-0 overflow-visible">
        <div className="h-screen w-full" style={{
          background: 'radial-gradient(ellipse at 8% 15%, var(--color-accent-glow), transparent 50%)',
        }} />
      </div>
      <div ref={contentRef} className="content relative z-[1] max-w-[720px] mx-auto px-16 py-12" />
    </div>
  )
}
