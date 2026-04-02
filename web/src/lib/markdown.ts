import { marked } from 'marked'
import hljs from 'highlight.js'
import DOMPurify from 'dompurify'

// Configure marked with highlight.js
const renderer = new marked.Renderer()
renderer.code = function ({ text, lang }) {
  const highlighted = lang && hljs.getLanguage(lang)
    ? hljs.highlight(text, { language: lang }).value
    : hljs.highlightAuto(text).value
  const langAttr = lang ? ` data-lang="${lang}"` : ''
  const escaped = text.replace(/&/g, '&amp;').replace(/"/g, '&quot;')
  return `<pre${langAttr}><button class="copy-btn" data-code="${escaped}"><svg width="14" height="14" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><polyline points="168 168 216 168 216 40 88 40 88 88"/><rect x="40" y="88" width="128" height="128" rx="8"/></svg></button><code class="hljs">${highlighted}</code></pre>`
}
marked.use({ renderer, gfm: true, breaks: false })

let _fileDir: string | null = null

export function setFileDir(dir: string | null) {
  _fileDir = dir
}

export function renderMarkdown(md: string): string {
  // Resolve relative image paths to mdfile:// URLs (served by Swift)
  let processed = md
  if (_fileDir) {
    const dir = _fileDir
    processed = md.replace(/!\[([^\]]*)\]\((?!https?:\/\/|data:|mdfile:\/\/)([^)]+)\)/g,
      (_, alt, src) => `![${alt}](mdfile://${dir}/${src})`)
  }

  return DOMPurify.sanitize(marked.parse(processed) as string, {
    ADD_TAGS: ['input', 'button'],
    ADD_ATTR: ['type', 'checked', 'disabled', 'data-lang', 'data-code', 'class'],
    ALLOW_UNKNOWN_PROTOCOLS: true,
  })
}

export interface Heading {
  id: string
  text: string
  level: number
}

export function extractHeadings(container: HTMLElement): Heading[] {
  const headings: Heading[] = []
  container.querySelectorAll('h1, h2, h3, h4').forEach((h, i) => {
    const id = `h-${i}`
    h.id = id
    headings.push({ id, text: h.textContent || '', level: parseInt(h.tagName[1]) })
  })
  return headings
}
