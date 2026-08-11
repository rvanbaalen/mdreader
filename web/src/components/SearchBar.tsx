import { useEffect, useRef, useState, useCallback } from 'react'
import { MagnifyingGlassIcon, CaretUpIcon, CaretDownIcon, XIcon } from '@phosphor-icons/react'
import { useApp } from '../hooks/useStore'

/**
 * Unwraps every search mark under root, restoring the original text
 * nodes so repeated searches never accumulate wrapper elements.
 *
 * @param root - Container whose marks are removed.
 */
function clearMarks(root: HTMLElement) {
  root.querySelectorAll('mark.search-hit').forEach(mark => {
    const parent = mark.parentNode
    if (!parent) return
    parent.replaceChild(document.createTextNode(mark.textContent || ''), mark)
    parent.normalize()
  })
}

/**
 * Wraps every case-insensitive occurrence of query inside root's text nodes
 * in a mark.search-hit element and returns the marks in document order.
 * Matches cannot span element boundaries.
 *
 * @param root - Container to search.
 * @param query - Text to look for; caller guarantees it is non-empty.
 * @returns The created mark elements.
 */
function markMatches(root: HTMLElement, query: string): HTMLElement[] {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
  const textNodes: Text[] = []
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    if (n.textContent?.toLowerCase().includes(query.toLowerCase())) textNodes.push(n as Text)
  }

  const marks: HTMLElement[] = []
  const q = query.toLowerCase()
  for (const node of textNodes) {
    const text = node.textContent || ''
    const frag = document.createDocumentFragment()
    let pos = 0
    let idx = text.toLowerCase().indexOf(q)
    while (idx !== -1) {
      frag.appendChild(document.createTextNode(text.slice(pos, idx)))
      const mark = document.createElement('mark')
      mark.className = 'search-hit'
      mark.textContent = text.slice(idx, idx + query.length)
      frag.appendChild(mark)
      marks.push(mark)
      pos = idx + query.length
      idx = text.toLowerCase().indexOf(q, pos)
    }
    frag.appendChild(document.createTextNode(text.slice(pos)))
    node.parentNode?.replaceChild(frag, node)
  }
  return marks
}

/**
 * Floating in-document search bar (⌘F). Highlights matches inside the
 * container returned by getRoot, with Enter / Shift+Enter cycling
 * and Escape closing.
 *
 * @param getRoot - Returns the element whose text is searched.
 * @param renderKey - Changes when the container re-renders, to re-apply marks.
 */
export function SearchBar({ getRoot, renderKey }: { getRoot: () => HTMLElement | null; renderKey: unknown }) {
  const { searchOpen, setSearchOpen } = useApp()
  const [query, setQuery] = useState('')
  const [total, setTotal] = useState(0)
  const [active, setActive] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const marksRef = useRef<HTMLElement[]>([])

  const goTo = useCallback((index: number) => {
    const marks = marksRef.current
    if (marks.length === 0) return
    const i = ((index % marks.length) + marks.length) % marks.length
    marks.forEach(m => m.classList.remove('search-hit-active'))
    marks[i].classList.add('search-hit-active')
    marks[i].scrollIntoView({ block: 'center', behavior: 'smooth' })
    setActive(i)
  }, [])

  // Re-apply marks when the query changes or the content re-renders
  useEffect(() => {
    const root = getRoot()
    if (!root) return
    clearMarks(root)
    if (!searchOpen || !query) {
      marksRef.current = []
      setTotal(0)
      setActive(0)
      return
    }
    const marks = markMatches(root, query)
    marksRef.current = marks
    setTotal(marks.length)
    if (marks.length > 0) goTo(0)
    return () => {
      const r = getRoot()
      if (r) clearMarks(r)
    }
  }, [query, searchOpen, renderKey, getRoot, goTo])

  useEffect(() => {
    if (searchOpen) {
      inputRef.current?.focus()
      inputRef.current?.select()
    }
  }, [searchOpen])

  if (!searchOpen) return null

  return (
    <div className="absolute top-12 right-4 z-20 animate-[fadeUp_0.2s_ease-out]">
      <div className="flex items-center gap-2 pl-3 pr-2 py-1.5 rounded-xl border border-border bg-card/90 backdrop-blur-md shadow-lg">
        <MagnifyingGlassIcon size={14} className="text-muted-foreground shrink-0" />
        <input
          ref={inputRef}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Escape') {
              e.preventDefault()
              setSearchOpen(false)
            } else if (e.key === 'Enter') {
              e.preventDefault()
              goTo(e.shiftKey ? active - 1 : active + 1)
            }
          }}
          placeholder="Find in document"
          className="w-44 bg-transparent border-none outline-none font-sans text-xs text-card-foreground placeholder:text-dim"
          spellCheck={false}
        />
        <span className="font-sans text-xs text-dim tabular-nums whitespace-nowrap min-w-10 text-right">
          {query ? (total > 0 ? `${active + 1}/${total}` : '0/0') : ''}
        </span>
        <button
          onClick={() => goTo(active - 1)}
          disabled={total === 0}
          className="size-6 flex items-center justify-center rounded-md text-muted-foreground cursor-pointer border-none bg-transparent transition-colors duration-150 hover:text-card-foreground hover:bg-muted disabled:opacity-30 disabled:cursor-default"
        >
          <CaretUpIcon size={12} />
        </button>
        <button
          onClick={() => goTo(active + 1)}
          disabled={total === 0}
          className="size-6 flex items-center justify-center rounded-md text-muted-foreground cursor-pointer border-none bg-transparent transition-colors duration-150 hover:text-card-foreground hover:bg-muted disabled:opacity-30 disabled:cursor-default"
        >
          <CaretDownIcon size={12} />
        </button>
        <button
          onClick={() => setSearchOpen(false)}
          className="size-6 flex items-center justify-center rounded-md text-dim cursor-pointer border-none bg-transparent transition-colors duration-150 hover:text-muted-foreground hover:bg-muted"
        >
          <XIcon size={12} />
        </button>
      </div>
    </div>
  )
}
