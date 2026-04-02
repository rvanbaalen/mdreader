import { useState, useCallback, useEffect } from 'react'
import { AppContext, type FileNode } from './hooks/useStore'
import { TitleBar } from './components/TitleBar'
import { Welcome } from './components/Welcome'
import { Reader } from './components/Reader'
import { Sidebar } from './components/Sidebar'
import { Toc } from './components/Toc'
import { ToastContainer } from './components/Toast'
import { postMessage } from './lib/bridge'
import type { Heading } from './lib/markdown'

export default function App() {
  const [theme, setThemeState] = useState<'dark' | 'light'>('dark')
  const [currentFile, setCurrentFile] = useState<string | null>(null)
  const [currentFolder, setCurrentFolder] = useState<string | null>(null)
  const [markdown, setMarkdown] = useState('')
  const [headings, setHeadings] = useState<Heading[]>([])
  const [activeHeadingId, setActiveHeading] = useState('')
  const [sidebarVisible, setSidebarVisible] = useState(false)
  const [tocVisible, setTocVisible] = useState(false)
  const [sourceVisible, setSourceVisible] = useState(false)
  const [folderTree, setFolderTree] = useState<FileNode[]>([])

  const setTheme = useCallback((t: 'dark' | 'light') => {
    setThemeState(t)
    document.documentElement.dataset.theme = t
    postMessage('setTheme', { mode: t })
  }, [])

  const cycleTheme = useCallback(() => {
    setThemeState(prev => {
      const next = prev === 'dark' ? 'light' : 'dark'
      document.documentElement.dataset.theme = next
      postMessage('setTheme', { mode: next })
      return next
    })
  }, [])

  const openFile = useCallback((md: string, name: string, folder: string) => {
    setCurrentFile(name)
    if (folder) setCurrentFolder(folder)
    setMarkdown(md)
    setSourceVisible(false)
  }, [])

  const openFolder = useCallback((name: string, tree: FileNode[]) => {
    setCurrentFolder(name)
    setFolderTree(tree)
    setSidebarVisible(true)
  }, [])

  const updateContent = useCallback((md: string) => {
    setMarkdown(md)
  }, [])

  // Expose API for Swift bridge
  useEffect(() => {
    const app = {
      openFile,
      openFolder,
      updateContent,
      setTheme,
      cycleTheme,
      toggleSidebar: () => setSidebarVisible(v => !v),
      toggleToc: () => setTocVisible(v => !v),
      toggleSource: () => setSourceVisible(v => !v),
      showDefaultBanner: () => {}, // TODO
      nativeAction: (action: string) => postMessage(action),
    }
    ;(window as any).app = app

    // Signal ready
    postMessage('ready')

    // Drag and drop
    const onDragOver = (e: DragEvent) => e.preventDefault()
    const onDrop = (e: DragEvent) => {
      e.preventDefault()
      const file = e.dataTransfer?.files[0]
      if (file) postMessage('openFilePath', { path: (file as any).path })
    }
    document.addEventListener('dragover', onDragOver)
    document.addEventListener('drop', onDrop)
    return () => {
      document.removeEventListener('dragover', onDragOver)
      document.removeEventListener('drop', onDrop)
    }
  }, [openFile, openFolder, updateContent, setTheme, cycleTheme])

  const ctx = {
    theme, currentFile, currentFolder, markdown, headings, activeHeadingId,
    sidebarVisible, tocVisible, sourceVisible, folderTree,
    setTheme, cycleTheme,
    toggleSidebar: () => setSidebarVisible(v => !v),
    toggleToc: () => setTocVisible(v => !v),
    toggleSource: () => setSourceVisible(v => !v),
    setHeadings, setActiveHeading, openFile, openFolder, updateContent,
  }

  return (
    <AppContext.Provider value={ctx}>
      <div className="flex flex-col h-screen bg-base">
        <TitleBar />
        <div className="flex flex-1 overflow-hidden">
          {currentFile ? (
            <>
              <Sidebar />
              <Reader />
              <Toc />
            </>
          ) : (
            <Welcome />
          )}
        </div>
        <ToastContainer />
      </div>
    </AppContext.Provider>
  )
}
