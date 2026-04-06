import { useState, useCallback, useEffect, useRef } from 'react'
import { AppContext, type FileNode } from './hooks/useStore'
import { TitleBar } from './components/TitleBar'
import { Welcome } from './components/Welcome'
import { Reader } from './components/Reader'
import { Sidebar } from './components/Sidebar'
import { Toc } from './components/Toc'
import { toast } from 'sonner'
import { Toaster } from '@/components/ui/sonner'
import { TooltipProvider } from '@/components/ui/tooltip'
import { UpdateBanner } from './components/UpdateBanner'
import { AboutDialog } from './components/AboutDialog'
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
  const [editMode, setEditMode] = useState(false)
  const [dirty, setDirty] = useState(false)
  const [fileDir, setFileDir] = useState<string | null>(null)
  const [updateVersion, setUpdateVersion] = useState<string | null>(null)
  const [folderTree, setFolderTree] = useState<FileNode[]>([])
  const [recents, setRecents] = useState<RecentItem[]>([])
  const [aboutInfo, setAboutInfo] = useState<{ version: string; commit: string; build: string } | null>(null)

  const editorContentRef = useRef<string>('')
  const dirtyRef = useRef(false)
  const editModeRef = useRef(false)

  // Keep refs in sync
  dirtyRef.current = dirty
  editModeRef.current = editMode

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

  const openFile = useCallback((md: string, name: string, folder: string, dir?: string) => {
    setCurrentFile(name)
    if (folder) setCurrentFolder(folder)
    if (dir) setFileDir(dir)
    setMarkdown(md)
    editorContentRef.current = md
    setSourceVisible(false)
    setEditMode(false)
    setDirty(false)
  }, [])

  const openFolder = useCallback((name: string, tree: FileNode[]) => {
    setCurrentFolder(name)
    setFolderTree(tree)
    setSidebarVisible(true)
  }, [])

  const updateContent = useCallback((md: string) => {
    setMarkdown(md)
    editorContentRef.current = md
    setDirty(false)
  }, [])

  const toggleEdit = useCallback(() => {
    setEditMode(prev => {
      if (!prev) {
        setSourceVisible(true)
      }
      return !prev
    })
  }, [])

  // Expose API for Swift bridge — use refs to avoid stale closures
  useEffect(() => {
    window.app = {
      openFile,
      openFolder,
      updateContent,
      setTheme,
      cycleTheme,
      toggleSidebar: () => setSidebarVisible(v => !v),
      toggleToc: () => setTocVisible(v => !v),
      toggleSource: () => { setSourceVisible(v => !v); setEditMode(false) },
      toggleEdit: () => toggleEdit(),
      showDefaultBanner: () => {},
      setRecents: (items: RecentItem[]) => setRecents(items),
      showUpdateBanner: (_current: string, latest: string) => setUpdateVersion(latest),
      showToast: (type: string, msg: string) => {
        const fn = type === 'success' ? toast.success : type === 'error' ? toast.error : toast
        fn(msg)
      },
      save: () => {
        if (!editModeRef.current) {
          toast('Switch to edit mode to save changes', { icon: '✏️' })
          return
        }
        if (!dirtyRef.current) {
          toast('No changes to save')
          return
        }
        postMessage('saveFile', { content: editorContentRef.current })
      },
      onSaveComplete: (success: boolean) => {
        if (success) {
          setMarkdown(editorContentRef.current)
          setDirty(false)
          setEditMode(false)
          setSourceVisible(false)
          toast('Saved')
        } else {
          toast.error('Could not save the file')
        }
      },
      showAbout: (version: string, commit: string, build: string) => setAboutInfo({ version, commit, build }),
      nativeAction: (action: string) => postMessage(action),
    }

    postMessage('ready')

    const onDragOver = (e: DragEvent) => e.preventDefault()
    const onDrop = (e: DragEvent) => {
      e.preventDefault()
      const file = e.dataTransfer?.files[0]
      if (file?.path) postMessage('openFilePath', { path: file.path })
    }
    document.addEventListener('dragover', onDragOver)
    document.addEventListener('drop', onDrop)
    return () => {
      document.removeEventListener('dragover', onDragOver)
      document.removeEventListener('drop', onDrop)
    }
  }, [openFile, openFolder, updateContent, setTheme, cycleTheme, toggleEdit])

  const ctx = {
    theme, currentFile, currentFolder, markdown, headings, activeHeadingId,
    sidebarVisible, tocVisible, sourceVisible, editMode, dirty, fileDir, folderTree,
    setTheme, cycleTheme,
    toggleSidebar: () => setSidebarVisible(v => !v),
    toggleToc: () => setTocVisible(v => !v),
    toggleSource: () => { setSourceVisible(v => !v); setEditMode(false) },
    toggleEdit,
    setDirty,
    setHeadings, setActiveHeading, openFile, openFolder, updateContent,
  }

  return (
    <TooltipProvider>
    <AppContext.Provider value={ctx}>
      <div className="relative h-screen bg-background">
        <TitleBar />
        <div className="flex h-full overflow-hidden">
          {currentFile ? (
            <>
              <Sidebar />
              <Reader editorContentRef={editorContentRef} />
              <Toc />
            </>
          ) : (
            <Welcome recents={recents} />
          )}
        </div>
        {updateVersion && (
          <UpdateBanner
            latest={updateVersion}
            onDismiss={() => setUpdateVersion(null)}
          />
        )}
        <Toaster />
        <AboutDialog info={aboutInfo} onClose={() => setAboutInfo(null)} />
      </div>
    </AppContext.Provider>
    </TooltipProvider>
  )
}
