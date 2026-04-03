import { SidebarIcon, SidebarSimpleIcon, CodeIcon, BookOpenIcon, PencilSimpleIcon, FloppyDiskIcon, SunIcon, MoonIcon, CommandIcon, ArrowUpIcon } from '@phosphor-icons/react'
import { Tooltip, TooltipTrigger, TooltipContent } from '@/components/ui/tooltip'
import { Kbd, KbdGroup } from '@/components/ui/kbd'
import { cn } from '@/lib/utils'
import { useApp } from '../hooks/useStore'
import { postMessage } from '../lib/bridge'

function ToolbarItem({ children, onClick, active, disabled, label, shortcut }: {
  children: React.ReactNode
  onClick: () => void
  active?: boolean
  disabled?: boolean
  label: string
  shortcut?: React.ReactNode
}) {
  return (
    <Tooltip>
      <TooltipTrigger
        onClick={onClick}
        disabled={disabled}
        className={cn(
          'size-7 flex items-center justify-center rounded-lg border-none cursor-pointer transition-all duration-150',
          active ? 'text-accent' : 'text-muted-foreground',
          disabled ? 'opacity-30 cursor-default' : 'hover:text-card-foreground hover:bg-muted active:scale-90',
        )}
      >
        {children}
      </TooltipTrigger>
      <TooltipContent>
        {label}
        {shortcut}
      </TooltipContent>
    </Tooltip>
  )
}

export function TitleBar() {
  const { theme, currentFile, currentFolder, sidebarVisible, tocVisible, sourceVisible, editMode, dirty,
    cycleTheme, toggleSidebar, toggleToc, toggleSource, toggleEdit, folderTree } = useApp()

  const hasFile = !!currentFile
  const hasFolder = folderTree.length > 0

  return (
    <div
      className="h-10 flex items-center pl-20 pr-4 select-none absolute top-0 left-0 right-0 z-10 bg-background backdrop-blur-md"
      onMouseDown={(e) => {
        if ((e.target as HTMLElement).closest('button')) return
        postMessage('startDrag')
      }}
    >
      <div className="flex-1 text-center overflow-hidden text-ellipsis whitespace-nowrap font-sans text-xs text-muted-foreground">
        {currentFile && (
          <>
            {currentFolder && <><span className="text-dim">{currentFolder}</span><span className="text-dim/30"> / </span></>}
            {currentFile}
            {dirty && <span className="text-accent ml-1">●</span>}
          </>
        )}
      </div>

      <div className="flex gap-1">
        {hasFile && hasFolder && (
          <ToolbarItem onClick={toggleSidebar} active={sidebarVisible} label="Sidebar" shortcut={<KbdGroup><Kbd><CommandIcon size={10} /></Kbd><Kbd>\</Kbd></KbdGroup>}>
            <SidebarIcon size={14} />
          </ToolbarItem>
        )}
        {hasFile && (
          <>
            <ToolbarItem onClick={toggleToc} active={tocVisible} label="Contents" shortcut={<KbdGroup><Kbd><CommandIcon size={10} /></Kbd><Kbd><ArrowUpIcon size={10} /></Kbd><Kbd>E</Kbd></KbdGroup>}>
              <SidebarSimpleIcon size={14} className="rotate-180" />
            </ToolbarItem>
            <ToolbarItem onClick={toggleSource} active={sourceVisible && !editMode} label={sourceVisible && !editMode ? 'Reader' : 'Source'} shortcut={<KbdGroup><Kbd><CommandIcon size={10} /></Kbd><Kbd><ArrowUpIcon size={10} /></Kbd><Kbd>S</Kbd></KbdGroup>}>
              <span key={sourceVisible && !editMode ? 'source' : 'reader'} className="animate-[spin-fade_0.3s_ease-out_both]">
                {sourceVisible && !editMode ? <BookOpenIcon size={14} /> : <CodeIcon size={14} />}
              </span>
            </ToolbarItem>
            <ToolbarItem onClick={toggleEdit} active={editMode} label="Edit" shortcut={<KbdGroup><Kbd><CommandIcon size={10} /></Kbd><Kbd>E</Kbd></KbdGroup>}>
              <PencilSimpleIcon size={14} />
            </ToolbarItem>
            {editMode && (
              <ToolbarItem onClick={() => window.app.save()} active={dirty} disabled={!dirty} label="Save" shortcut={<KbdGroup><Kbd><CommandIcon size={10} /></Kbd><Kbd>S</Kbd></KbdGroup>}>
                <FloppyDiskIcon size={14} />
              </ToolbarItem>
            )}
          </>
        )}
        <ToolbarItem onClick={cycleTheme} label={theme === 'dark' ? 'Light mode' : 'Dark mode'} shortcut={<KbdGroup><Kbd><CommandIcon size={10} /></Kbd><Kbd><ArrowUpIcon size={10} /></Kbd><Kbd>T</Kbd></KbdGroup>}>
          <span key={theme} className="animate-[spin-fade_0.3s_ease-out_0.25s_both]">
            {theme === 'dark' ? <SunIcon size={14} /> : <MoonIcon size={14} />}
          </span>
        </ToolbarItem>
      </div>
    </div>
  )
}
