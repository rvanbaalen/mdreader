import { createContext, useContext } from 'react'
import type { Heading } from '../lib/markdown'

export interface FileNode {
  name: string
  path: string
  isDir: boolean
  children?: FileNode[]
}

export interface AppState {
  theme: 'dark' | 'light'
  currentFile: string | null
  currentFolder: string | null
  markdown: string
  headings: Heading[]
  activeHeadingId: string
  sidebarVisible: boolean
  tocVisible: boolean
  sourceVisible: boolean
  folderTree: FileNode[]
  // Actions
  setTheme: (t: 'dark' | 'light') => void
  cycleTheme: () => void
  toggleSidebar: () => void
  toggleToc: () => void
  toggleSource: () => void
  setHeadings: (h: Heading[]) => void
  setActiveHeading: (id: string) => void
  openFile: (md: string, name: string, folder: string) => void
  openFolder: (name: string, tree: FileNode[]) => void
  updateContent: (md: string) => void
}

export const AppContext = createContext<AppState>(null!)
export const useApp = () => useContext(AppContext)
