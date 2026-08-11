import { useRef, useEffect, useMemo, useState, useCallback, type MutableRefObject } from 'react'
import { useApp } from '../hooks/useStore'
import { renderMarkdown, extractHeadings, setFileDir } from '../lib/markdown'
import { toast } from 'sonner'
import hljs from 'highlight.js'
import { SearchBar } from './SearchBar'

interface ReaderProps {
  editorContentRef: MutableRefObject<string>
}

export function Reader({ editorContentRef }: ReaderProps) {
  const { markdown, sourceVisible, editMode, fileDir, sidebarVisible, tocVisible, setHeadings, setActiveHeading, setDirty } = useApp()
  setFileDir(fileDir)
  const contentRef = useRef<HTMLDivElement>(null)
  const renderedRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const sourceRef = useRef<HTMLPreElement>(null)
  // Bumped after the markdown DOM is rebuilt so SearchBar re-applies marks
  const [renderTick, setRenderTick] = useState(0)
  const getContentRoot = useCallback(() => contentRef.current, [])
  const getSourceRoot = useCallback(() => sourceRef.current, [])

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
    setRenderTick(t => t + 1)
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

  // Panel compensation lives on the scroller so the 800px column (DESIGN.md
  // max content width) centers in the space the panels leave over: panel
  // footprint = 16px margin + width + 24px gap on each side
  const panelPad = `${sidebarVisible ? 'pl-75' : 'pl-16'} ${tocVisible ? 'pr-65' : 'pr-16'}`
  const scrollerClass = `h-full overflow-y-scroll overflow-x-hidden relative scroll-smooth transition-[padding] duration-300 ease-move ${panelPad}`
  const columnClass = 'max-w-200 mx-auto pt-24 pb-24'

  // Edit mode: editable textarea
  if (editMode) {
    return (
      <div className={`flex-1 overflow-hidden relative transition-[padding] duration-300 ease-move ${panelPad}`}>
        <textarea
          ref={textareaRef}
          defaultValue={markdown}
          onChange={(e) => {
            editorContentRef.current = e.target.value
            setDirty(e.target.value !== markdown)
          }}
          className={`block w-full h-full ${columnClass} font-mono text-xs leading-body text-card-foreground bg-transparent border-none outline-none resize-none whitespace-pre-wrap break-words`}
          spellCheck={false}
        />
      </div>
    )
  }

  // Source view: read-only highlighted
  if (sourceVisible) {
    return (
      <div className="flex-1 relative overflow-hidden">
        <SearchBar getRoot={getSourceRoot} renderKey={markdown} />
        <div className={scrollerClass}>
          <pre ref={sourceRef} className={`${columnClass} font-mono text-xs leading-body whitespace-pre-wrap break-words select-text`}>
            <code className="hljs" dangerouslySetInnerHTML={{ __html: highlightedSource }} />
          </pre>
        </div>
      </div>
    )
  }

  // Rendered markdown view
  return (
    <div className="flex-1 relative overflow-hidden">
      {/* Full-bleed so the glow spans the padded scroller's left/right insets */}
      <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(ellipse_at_8%_15%,var(--color-accent-glow),transparent_50%)]" />
      <SearchBar getRoot={getContentRoot} renderKey={renderTick} />
      <div ref={renderedRef} className={scrollerClass}>
        <div ref={contentRef} className={`content relative z-1 ${columnClass}`} />
      </div>
    </div>
  )
}
