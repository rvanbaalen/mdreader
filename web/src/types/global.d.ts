interface RecentItem {
  path: string
  name: string
  isDir: boolean
}

interface AppBridge {
  openFile: (md: string, name: string, folder: string, dir?: string) => void
  openFolder: (name: string, tree: import('../hooks/useStore').FileNode[]) => void
  updateContent: (md: string) => void
  setTheme: (t: 'dark' | 'light') => void
  cycleTheme: () => void
  toggleSidebar: () => void
  toggleToc: () => void
  toggleSource: () => void
  toggleEdit: () => void
  showDefaultBanner: () => void
  setRecents: (items: RecentItem[]) => void
  showUpdateBanner: (current: string, latest: string) => void
  showToast: (msg: string) => void
  save: () => void
  onSaveComplete: (success: boolean) => void
  nativeAction: (action: string) => void
}

interface Window {
  app: AppBridge
  __updateComplete?: () => void
}

/** Electron/WKWebView file drop includes a path property */
interface File {
  readonly path?: string
}
