import SwiftUI

enum MDColors {
    // Dark
    static let darkBase = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
    static let darkSurface = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
    static let darkSurfaceHover = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    static let darkEdge = NSColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
    static let darkEdgeSubtle = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
    static let darkPrimary = NSColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 1)
    static let darkSecondary = NSColor(red: 0.62, green: 0.60, blue: 0.57, alpha: 1)
    static let darkMuted = NSColor(red: 0.38, green: 0.38, blue: 0.41, alpha: 1)
    static let darkDim = NSColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1)
    static let darkAccent = NSColor(red: 0.52, green: 0.54, blue: 0.60, alpha: 1)
    static let darkAccentBright = NSColor(red: 0.62, green: 0.64, blue: 0.71, alpha: 1)

    // Light
    static let lightBase = NSColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1)
    static let lightSurface = NSColor.white
    static let lightSurfaceHover = NSColor(red: 0.94, green: 0.93, blue: 0.92, alpha: 1)
    static let lightEdge = NSColor(red: 0.83, green: 0.82, blue: 0.80, alpha: 1)
    static let lightPrimary = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
    static let lightSecondary = NSColor(red: 0.28, green: 0.28, blue: 0.31, alpha: 1)
    static let lightMuted = NSColor(red: 0.48, green: 0.48, blue: 0.50, alpha: 1)
    static let lightDim = NSColor(red: 0.65, green: 0.65, blue: 0.67, alpha: 1)
    static let lightAccent = NSColor(red: 0.34, green: 0.36, blue: 0.42, alpha: 1)

    // Adaptive SwiftUI colors
    static func base(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkBase : lightBase) }
    static func surface(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkSurface : lightSurface) }
    static func surfaceHover(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkSurfaceHover : lightSurfaceHover) }
    static func edge(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkEdge : lightEdge) }
    static func primary(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkPrimary : lightPrimary) }
    static func secondary(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkSecondary : lightSecondary) }
    static func muted(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkMuted : lightMuted) }
    static func dim(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkDim : lightDim) }
    static func accent(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkAccent : lightAccent) }
    static func accentBright(_ scheme: ColorScheme) -> Color { Color(nsColor: scheme == .dark ? darkAccentBright : lightAccent) }
}
