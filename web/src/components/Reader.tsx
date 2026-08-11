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
  const { markdown, sourceVisible, dirty, fileDir, sidebarVisible, tocVisible, setHeadings, setActiveHeading, setDirty } = useApp()
  setFileDir(fileDir)
  const contentRef = useRef<HTMLDivElement>(null)
  const renderedRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const sourceRef = useRef<HTMLPreElement>(null)
  // Bumped after the markdown DOM is rebuilt so SearchBar re-applies marks
  const [renderTick, setRenderTick] = useState(0)
  // Editable source buffer; follows `markdown` while there are no unsaved edits
  const [draft, setDraft] = useState(markdown)
  const getContentRoot = useCallback(() => contentRef.current, [])
  const getSourceRoot = useCallback(() => sourceRef.current, [])

  useEffect(() => {
    if (!dirty) {
      setDraft(markdown)
      editorContentRef.current = markdown
    }
  }, [markdown, dirty, editorContentRef])

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

  // Focus the editor when entering source view, without scroll-jumping
  useEffect(() => {
    if (sourceVisible) textareaRef.current?.focus({ preventScroll: true })
  }, [sourceVisible])

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

  const highlightedDraft = useMemo(() => {
    if (!sourceVisible || !draft) return ''
    const html = hljs.highlight(draft, { language: 'markdown' }).value
    // A trailing space keeps the final empty line rendered so the
    // highlight layer stays exactly as tall as the textarea
    return draft.endsWith('\n') ? html + ' ' : html
  }, [sourceVisible, draft])

  const onDraftChange = (value: string) => {
    setDraft(value)
    editorContentRef.current = value
    setDirty(value !== markdown)
  }

  // Tab indents and Shift+Tab outdents (line-wise over selections)
  // instead of the browser default of moving focus out of the editor
  const onEditorKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== 'Tab') return
    e.preventDefault()
    const ta = e.currentTarget
    const { selectionStart, selectionEnd, value } = ta
    const lineStart = value.lastIndexOf('\n', selectionStart - 1) + 1
    const spansLines = value.slice(selectionStart, selectionEnd).includes('\n')

    // execCommand keeps the native undo stack intact, unlike setRangeText
    if (!e.shiftKey && !spansLines) {
      document.execCommand('insertText', false, '  ')
      return
    }

    const nextBreak = value.indexOf('\n', selectionEnd)
    const blockEnd = nextBreak === -1 ? value.length : nextBreak
    const block = value.slice(lineStart, blockEnd)
    const shifted = block
      .split('\n')
      .map(line => (e.shiftKey ? line.replace(/^ {1,2}/, '') : '  ' + line))
      .join('\n')
    if (shifted === block) return
    ta.setSelectionRange(lineStart, blockEnd)
    document.execCommand('insertText', false, shifted)
    ta.setSelectionRange(lineStart, lineStart + shifted.length)
  }

  // Panel compensation lives on the scroller so the 800px column (DESIGN.md
  // max content width) centers in the space the panels leave over: panel
  // footprint = 16px margin + width + 24px gap on each side
  const panelPad = `${sidebarVisible ? 'pl-75' : 'pl-16'} ${tocVisible ? 'pr-65' : 'pr-16'}`
  const scrollerClass = `h-full overflow-y-scroll overflow-x-hidden relative scroll-smooth transition-[padding] duration-300 ease-move ${panelPad}`
  const columnClass = 'max-w-200 mx-auto pt-24 pb-24'

  // Source view: syntax-highlighted editor. A transparent textarea overlays
  // the highlighted pre with identical text metrics, so the pre paints the
  // colors while the textarea owns input, caret, and selection.
  if (sourceVisible) {
    const editorMetrics = 'pt-24 pb-24 font-mono text-xs leading-body whitespace-pre-wrap break-words'
    return (
      <div className="flex-1 relative overflow-hidden">
        <SearchBar getRoot={getSourceRoot} renderKey={draft} />
        <div className={scrollerClass}>
          <div className="relative max-w-200 mx-auto min-h-full">
            <pre ref={sourceRef} aria-hidden className={`${editorMetrics} m-0`}>
              <code className="hljs" dangerouslySetInnerHTML={{ __html: highlightedDraft }} />
            </pre>
            <textarea
              ref={textareaRef}
              value={draft}
              onChange={(e) => onDraftChange(e.target.value)}
              onKeyDown={onEditorKeyDown}
              className={`absolute inset-0 w-full h-full ${editorMetrics} bg-transparent text-transparent caret-foreground border-none outline-none resize-none overflow-hidden`}
              spellCheck={false}
            />
          </div>
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
