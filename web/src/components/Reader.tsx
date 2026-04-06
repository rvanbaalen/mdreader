import { useRef, useEffect, useMemo, type MutableRefObject } from 'react'
import { useApp } from '../hooks/useStore'
import { renderMarkdown, extractHeadings, setFileDir } from '../lib/markdown'
import { toast } from 'sonner'
import hljs from 'highlight.js'

interface ReaderProps {
  editorContentRef: MutableRefObject<string>
}

export function Reader({ editorContentRef }: ReaderProps) {
  const { markdown, sourceVisible, editMode, fileDir, sidebarVisible, tocVisible, setHeadings, setActiveHeading, setDirty } = useApp()
  setFileDir(fileDir)
  const contentRef = useRef<HTMLDivElement>(null)
  const renderedRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

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
          toast('Copied to clipboard')
        })
      })
    })

    el.querySelectorAll('code:not(.hljs)').forEach(code => {
      const codeEl = code as HTMLElement
      codeEl.classList.add('cursor-pointer')
      code.setAttribute('title', 'Click to copy')
      code.addEventListener('click', () => {
        navigator.clipboard.writeText(code.textContent || '').then(() => {
          code.classList.add('copied-inline')
          setTimeout(() => code.classList.remove('copied-inline'), 1500)
          toast('Copied to clipboard')
        })
      })
    })

    setHeadings(extractHeadings(el))

    el.classList.remove('animate-content')
    void el.offsetWidth
    el.classList.add('animate-content')
  }, [markdown, sourceVisible, setHeadings])

  // Sync textarea when entering edit mode
  useEffect(() => {
    if (editMode && textareaRef.current) {
      textareaRef.current.value = markdown
      editorContentRef.current = markdown
      textareaRef.current.focus()
    }
  }, [editMode, markdown, editorContentRef])

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
    if (!sourceVisible || editMode || !markdown) return ''
    return hljs.highlight(markdown, { language: 'markdown' }).value
  }, [sourceVisible, editMode, markdown])

  const plClass = sidebarVisible ? 'pl-[360px]' : 'pl-16'
  const prClass = tocVisible ? 'pr-[296px]' : 'pr-16'
  const contentPadding = `${plClass} ${prClass}`

  // Edit mode: editable textarea
  if (editMode) {
    return (
      <div className="flex-1 overflow-hidden relative">
        <textarea
          ref={textareaRef}
          defaultValue={markdown}
          onChange={(e) => {
            editorContentRef.current = e.target.value
            setDirty(e.target.value !== markdown)
          }}
          className={`absolute inset-0 max-w-7xl mx-auto pt-24 pb-12 font-mono text-sm leading-[1.7] text-card-foreground bg-transparent border-none outline-none resize-none whitespace-pre-wrap break-words ${contentPadding}`}
          spellCheck={false}
        />
      </div>
    )
  }

  // Source view: read-only highlighted
  if (sourceVisible) {
    return (
      <div className="flex-1 overflow-y-scroll overflow-x-hidden relative scroll-smooth">
        <pre className={`max-w-7xl mx-auto pt-24 pb-12 font-mono text-sm leading-[1.7] whitespace-pre-wrap break-words select-text ${contentPadding}`}>
          <code className="hljs" dangerouslySetInnerHTML={{ __html: highlightedSource }} />
        </pre>
      </div>
    )
  }

  // Rendered markdown view
  return (
    <div ref={renderedRef} className="flex-1 overflow-y-scroll overflow-x-hidden relative scroll-smooth">
      <div className="sticky top-0 h-0 pointer-events-none z-0 overflow-visible">
        <div className="h-screen w-full bg-[radial-gradient(ellipse_at_8%_15%,var(--color-accent-glow),transparent_50%)]" />
      </div>
      <div ref={contentRef} className={`content relative z-[1] max-w-7xl mx-auto pt-24 pb-12 ${contentPadding}`} />
    </div>
  )
}
