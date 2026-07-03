# Design

Visual system for the Maven Fuzzy Factory data-story. **Not invented here** — derived from the personal-brand-design system (`D:\Dev\Projects\personal-brand-design`, v2.0), which is the source of truth. This file scopes that system to this one page and locks the exact tokens the Fase 6 build consumes. Where a value differs from the brand front-matter, the brand front-matter wins.

Build note (per CLAUDE.md): copy `outputs/css/tokens.css` + `tokens.dark.css` from the brand repo into `docs/assets/` so GitHub Pages is self-contained. Do not link outside the repo.

## Theme

Identity: **Architectural Restraint meets Editorial Authority.** Dark carries authority; light carries information; the single amber accent appears only where attention must be directed.

Default **light** (warm canvas) — the brand rule for public HTML/documents — with a persisted **dark** (ink) toggle in the top bar. Both themes are first-class and fully derived from tokens; the toggle also demonstrates the dual-theme system (portfolio value). Respect `prefers-color-scheme` on first load, then honor the user's explicit toggle.

Scene sentence: *a recruiter opens this link in a bright office on a laptop or phone between meetings, and an analyst opens it later at night to read the method — the page must hold up warm-and-legible by day and authoritative-and-focused by dark.*

## Color

Anchors: `ink #111827` · `canvas #E7E5E0`. Ink and canvas each have a full ramp (`ink-950…ink-300`, `canvas-50…canvas-700`) — use ramp steps for surfaces, borders, and muted text, never arbitrary grays.

| Role | Light | Dark |
|---|---|---|
| Page background | `canvas-200 #E7E5E0` | `ink-900 #111827` |
| Elevated surface / card | `canvas-50 #F5F4F1` | `ink-800 #1C2636` |
| Border / divider | `canvas-300 #D2CFC8` | `ink-600 #374459` |
| Body text | `ink-900 #111827` | `canvas-200 #E7E5E0` |
| Secondary / caption | `canvas-700 #4A4741` | `canvas-500 #96928A` |
| Accent (focal only) | `accent #C27C35` | `accent-on-dark #E09A50` |

**Accent scarcity rule (governs UI *and* charts):** amber = the one focal point per view. Never decorative, never a categorical rotation color.

Semantic (deltas, significance, refund alerts): `success #28A45A / #3DBF70`, `error #C03B3B / #D95555`, `warning #C48520 / #E09A3A`, `info #3573B8 / #5590D4`. Never color-only — pair with sign, label, or marker.

### Data-visualization palette

- **Emphasis (reserved, out of rotation):** `data-emphasis #C27C35` (= accent). The single focal series/datum per chart.
- **Categorical sequence (apply in order, never skip):** `data-1 #4A7FA5` slate · `data-2 #3D9E8C` teal · `data-3 #B55577` rose · `data-4 #7157A8` violet · `data-5 #6B7A8D` steel · `data-6 #8FAE5A` sage · `data-7 #9C6B4E` clay. Amber deliberately absent.
- **Signature move — mute-all-but-one:** when a chart makes a single point, render every series in a neutral (`ink-500`/`canvas-400`) and the focal series in `data-emphasis` at full saturation. Use the full categorical sequence only when all series carry equal weight.
- **Sequential (single-metric heatmap):** `#E7E5E0 → #C9C4BA → #A08C72 → #6E5A3A → #3A2E1C → #111827`.
- **Diverging (neg ↔ 0 ↔ pos):** `#C03B3B → #E0A0A0 → #E7E5E0 → #A0CCB8 → #28A45A`.
- Max 4 categorical colors per chart without justification; beyond that, mute-all-but-one or small multiples.

## Typography

Google Fonts (self-host or `<link>` per brand doc): **Cormorant Garamond** (display serif), **Barlow** (UI + numeric, weights 100–600), **JetBrains Mono** (SQL/technical).

- `--font-display: 'Cormorant Garamond', Georgia, serif` — headlines/hero only, ≥28px. Never in body/labels.
- `--font-ui: 'Barlow', system-ui, sans-serif` — headings, body, labels, buttons.
- `--font-mono: 'JetBrains Mono', monospace` — SQL blocks, technical IDs.

Scale (from brand tokens): display `72/56/40/32`, heading `28/22/18/15`, body `16/14/13`, labels `14/12/11` (label-sm uppercase, tracked). **Metrics use Barlow Thin** — `metric-xl 64/100`, `metric-lg 48/100`, `metric-md 36/200`, `metric-sm 28/200` — always `font-variant-numeric: tabular-nums; font-feature-settings: "tnum"`. Thin large numerals are the brand's numeric signature; do not set data values in a heavy sans.

Rules: body line length 65–75ch; `text-wrap: balance` on h1–h3; display letter-spacing ≥ −0.02em; use Cormorant *italic 600* on a single word of the hero for brand voice.

Number formatting (en-US, public audience): `1,188,124` · `8.44%` · `$1.94M` · `$60`.

## Layout

- HTML-page grid: 12 col, 24px gutter, **max-width 1280px**, centered container. Reading column for prose ≤ 720px.
- Density `comfortable` (documents/public); drop touch targets to ≥44px below `tablet`.
- Breakpoints: mobile 0 · tablet 768 · desktop 1024 · wide 1440.
- Vertical rhythm between acts: `space-24 (96px)` desktop, compress on mobile. Vary spacing — generous between acts, tight within a group.
- Radius: `radius-lg (8px)` for the document context (cards/panels). Elevation on light = `shadow-1/2`; on dark = border-weight + surface step, **no shadows**.
- Charts are borderless within the reading flow where possible; when boxed, `chart-container`: surface `canvas-50 | ink-800`, `1px` border, `radius-md`, title `heading-3`.
- **Cards are not the default.** Use flow + rules + whitespace for the narrative; reserve bordered panels for genuinely modular content (e.g. the A/B results table, KPI stat row). No nested cards.

## Charts (encoding, per brand chart-selection guide)

- **Grid/axes:** gridline `1px, 0.5 opacity` (`ink-600 | canvas-300`); hide ticks (labels carry it); zero-line full opacity. Axis labels `label-sm` tabular-nums.
- **Tooltip:** always dark (`ink-900` bg, `canvas-200` text) even in light mode; value `metric-xs`, label `label-sm` uppercase.
- **Legend:** `body-sm`, top-right ≤4 series, bottom-center ≥5.
- Bans: no dual axes, no 3D, no pie >3 slices, no chart-junk. Never encode by color alone.
- Library: ECharts via CDN (no build), per project stack.

## Motion

Principle: motion communicates narrative/state, not personality. Exit-fast, enter-slow; ease-out (quart/quint/expo), no bounce.

- Tokens: `fast 80ms` · `base 150ms` · `medium 250ms` · `slow 350ms cubic-bezier(.4,0,.2,1)` · `page 450ms cubic-bezier(.16,1,.3,1)`.
- Scroll-driven reveals **enhance an already-rendered chart** (progressive highlight, step-draw, series stagger 40ms) — they never gate content visibility.
- Chart series entry: opacity 0→1 + translateY 8→0, 350ms, 40ms stagger.
- `prefers-reduced-motion: reduce`: every reveal collapses to final state instantly (crossfade or none); scrollytelling degrades to a plain long-scroll with all charts in their end state.

## Iconography

Lucide, outline only, 1.5px stroke (2px ≤16px). Sizes 16/18/20/24. Inherit text color; accent only for the single focal/active icon. One icon set — never mix libraries. Functional only; if an icon doesn't aid scanning, remove it.
