# Design System — mdreader

Inherited from the robinvanbaalen.nl design system. mdreader is a product of the same brand, so visual language stays consistent.

## Product Context
- **What this is:** A beautiful macOS markdown reader
- **Who it's for:** Developers, writers, anyone who reads markdown files
- **Space/industry:** Developer tools / productivity
- **Project type:** Native macOS app with web-rendered UI (WKWebView)
- **Aesthetic posture:** Refined reader, not a code editor. Quiet, typographic, comfortable.

## Aesthetic Direction
- **Direction:** Editorial/Refined
- **Decoration level:** Intentional — subtle surfaces, frosted glass titlebar, smooth transitions. Nothing decorative for its own sake.
- **Mood:** A well-lit reading room. Calm, focused, unhurried.

## Typography

### Font Stack
- **Serif (headings + body):** Lora (variable, 400-700 + italic), self-hosted
- **Sans (labels, nav, buttons, UI chrome):** DM Sans (variable, 100-1000), self-hosted
- **Mono (code blocks only):** IBM Plex Mono (400), self-hosted. Never used for UI labels, navigation, or decorative text.

### Type Scale (base 20px, ~1.25 major third)
| Token     | Size   | Usage |
|-----------|--------|-------|
| `xs`      | 14px   | Tags, metadata, sidebar labels |
| `sm`      | 16px   | Secondary text, table body |
| `base`    | 20px   | Body text, article prose |
| `lg`      | 24px   | h3 headings |
| `xl`      | 32px   | h2 headings |
| `2xl`     | 40px   | h1 headings |
| `3xl`     | 48px   | Welcome screen heading |

### Type Rules
- **Body line-height:** 1.7
- **Heading line-height:** 1.1-1.3
- **Heading letter-spacing:** -0.01em to -0.02em (tighter at larger sizes)
- **Sans labels:** Sentence case or title case, normal letter-spacing, font-weight 450-500. No uppercase, no wide tracking.
- **Mono:** Reserved exclusively for `<code>` and code blocks.

## Color

### Approach: Restrained (cool slate accent)
Hierarchy comes from brightness and weight, not color saturation.

### Dark Theme (default)

Design tokens (used directly in our components via `text-{token}`, `bg-{token}`):

| Token | Value | Usage |
|-------|-------|-------|
| `base` | `oklch(10% 0.01 260)` | Page background |
| `surface` | `oklch(14% 0.012 260)` | Cards, sidebar, raised elements |
| `surface-hover` | `oklch(17% 0.015 260)` | Hover state for surfaces |
| `edge` | `oklch(20% 0.015 260)` | Primary borders |
| `edge-subtle` | `oklch(16% 0.01 260)` | Faint separators |
| `subtle` | `oklch(45% 0.008 260)` | Subdued text, descriptions |
| `dim` | `oklch(30% 0.008 260)` | Very quiet, meta info |
| `accent-bright` | `oklch(70% 0.05 260)` | Hover on accent elements |
| `accent-dim` | `oklch(52% 0.03 260)` | Quieter accent |
| `accent-glow` | `oklch(62% 0.04 260 / 0.1)` | Background tint, focus rings |
| `accent-subtle` | `oklch(62% 0.04 260 / 0.05)` | Very faint tint |

shadcn semantic tokens (bg/fg pairs used by shadcn components):

| Token | Value | Usage |
|-------|-------|-------|
| `primary` | `oklch(93% 0.015 80)` | Headings, emphasis, default button bg |
| `primary-foreground` | `oklch(10% 0.01 260)` | Text on primary bg |
| `secondary` | `oklch(65% 0.01 80)` | Body text, secondary button bg |
| `secondary-foreground` | `oklch(93% 0.015 80)` | Text on secondary bg |
| `muted` | `oklch(17% 0.015 260)` | Subtle backgrounds (kbd, toggle) |
| `muted-foreground` | `oklch(45% 0.008 260)` | Text on muted bg |
| `accent` | `oklch(62% 0.04 260)` | Links, active states, accent button bg |
| `accent-foreground` | `oklch(93% 0.015 80)` | Text on accent bg |
| `destructive` | `oklch(62% 0.2 25)` | Error states |
| `destructive-foreground` | `oklch(93% 0.015 80)` | Text on destructive bg |

### Light Theme

Design tokens:

| Token | Value | Usage |
|-------|-------|-------|
| `base` | `oklch(97% 0.005 80)` | Page background |
| `surface` | `oklch(100% 0 0)` | Cards, sidebar |
| `surface-hover` | `oklch(95% 0.005 80)` | Hover state |
| `edge` | `oklch(85% 0.01 80)` | Primary borders |
| `edge-subtle` | `oklch(90% 0.005 80)` | Faint separators |
| `subtle` | `oklch(55% 0.008 260)` | Subdued text |
| `dim` | `oklch(70% 0.005 260)` | Very quiet text |
| `accent-bright` | `oklch(35% 0.05 260)` | Hover (darker on light) |
| `accent-dim` | `oklch(52% 0.03 260)` | Quieter accent |
| `accent-glow` | `oklch(42% 0.04 260 / 0.08)` | Focus rings |
| `accent-subtle` | `oklch(42% 0.04 260 / 0.04)` | Faint tint |

shadcn semantic tokens:

| Token | Value | Usage |
|-------|-------|-------|
| `primary` | `oklch(15% 0.01 260)` | Headings, default button bg |
| `primary-foreground` | `oklch(97% 0.005 80)` | Text on primary bg |
| `secondary` | `oklch(35% 0.01 260)` | Body text, secondary button bg |
| `secondary-foreground` | `oklch(97% 0.005 80)` | Text on secondary bg |
| `muted` | `oklch(95% 0.005 80)` | Subtle backgrounds |
| `muted-foreground` | `oklch(55% 0.008 260)` | Text on muted bg |
| `accent` | `oklch(42% 0.04 260)` | Links, active states |
| `accent-foreground` | `oklch(97% 0.005 80)` | Text on accent bg |
| `destructive` | `oklch(52% 0.2 25)` | Error states |
| `destructive-foreground` | `oklch(97% 0.005 80)` | Text on destructive bg |

### Semantic Colors
| Token | Dark | Light | Usage |
|-------|------|-------|-------|
| `success` | `oklch(62% 0.14 150)` | `oklch(50% 0.14 150)` | Positive states |
| `warning` | `oklch(72% 0.14 85)` | `oklch(60% 0.14 85)` | Warnings |
| `error` | `oklch(62% 0.2 25)` | `oklch(52% 0.2 25)` | Errors |
| `info` | `oklch(62% 0.04 260)` | `oklch(42% 0.04 260)` | Informational |

## Icons
- **Library:** Phosphor Icons (`@phosphor-icons/react`)
- **Import convention:** `NameIcon` (e.g. `SidebarIcon`, not `Sidebar`)
- **Weight:** Regular (not bold, not fill)
- **Never:** hand-code SVGs, use emoji, use SF Symbols

## Spacing
- **Base unit:** 4px
- **Density:** Comfortable
- **Scale:** xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64)

### Component Spacing
- Sidebar width: 260px
- Content padding: 24px (matches card padding)
- Border radius: sm:4px, md:8px, lg:12px, xl:16px, full:9999px

## Layout
- **Approach:** Grid-disciplined
- **Structure:** Optional sidebar (left) + fluid reader content + optional ToC (right)
- **Max content width:** 800px for prose readability
- **Border radius:** sm:4px, md:8px, lg:12px, xl:16px, full:9999px

## Motion
- **Approach:** Intentional — motion adds meaning, not decoration
- **Easing:** enter(`cubic-bezier(0.22, 1, 0.36, 1)`) move(`cubic-bezier(0.45, 0, 0.55, 1)`)
- **Duration:** micro(75ms) short(150ms) medium(300ms) long(500ms)

### Transitions
Every hover, focus, and state change must have a transition. Nothing snaps.
- **Hover states:** 150ms with enter easing
- **Theme switch:** 300ms with move easing — background, color, border-color
- **Panel open/close:** 300ms (sidebar, ToC)
- **Content entrance:** fadeUp animation with staggered delays
- **Buttons:** scale transform on press

### Animations
All animations respect `prefers-reduced-motion: reduce`.
- `fadeUp`: opacity 0→1 + translateY(8px→0)
- `fadeIn`: opacity 0→1
- Content appears with staggered fadeUp delays

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-02 | Copied design system from robinvanbaalen.nl | Same brand, consistent visual language across products |
| 2026-04-02 | Adapted product context for mdreader | Reader app, not portfolio — adjusted mood and component spacing |
