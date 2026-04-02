// Swift ↔ JS bridge
// In WKWebView: window.webkit.messageHandlers.app.postMessage({...})
// In dev mode (browser): logs to console

interface WebKitBridge {
  webkit?: {
    messageHandlers: {
      app: {
        postMessage: (msg: Record<string, unknown>) => void
      }
    }
  }
}

export function postMessage(action: string, data?: Record<string, unknown>) {
  const w = window as unknown as WebKitBridge
  if (w.webkit?.messageHandlers?.app) {
    w.webkit.messageHandlers.app.postMessage({ action, ...data })
  } else {
    console.log('[bridge]', action, data)
  }
}

export function isNative(): boolean {
  const w = window as unknown as WebKitBridge
  return !!w.webkit?.messageHandlers?.app
}
