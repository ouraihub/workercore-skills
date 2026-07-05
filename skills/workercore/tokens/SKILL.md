---
name: workercore-tokens
description: MANDATORY color and theming rules for @ouraihub/workercore. Semantic tokens and the no-dark: rule.
---

# workercore semantic color tokens

Like daisyUI, workercore colors are **semantic tokens driven by CSS variables**, so they adapt to the active theme automatically.

## Rules

1. **Only use semantic token utilities for color.** Never raw Tailwind palette colors (`slate-*`, `red-*`, `bg-white`, `text-black`) for themeable surfaces/text/borders.
2. **Never use `dark:` for color.** Tokens already flip between light/dark and across all themes. Adding `dark:bg-...` is wrong and causes double-theming bugs.
3. `*-foreground` tokens are the readable content color to place *on* the matching background.
4. Raw palette colors are allowed **only** for intentionally theme-independent content: brand logos, data-viz series colors, illustration/preview swatches, code-file glyph colors. Everything structural uses tokens.
5. Use `surface`/`fg`/`border` tokens for the majority of the UI. Use `primary` sparingly, for the most important action.

## Token reference (utility class → meaning)

Surfaces / backgrounds:
- `bg-surface` — card / panel background (the "white" surface)
- `bg-surface-muted` — subtle raised/hover background
- `bg-surface-strong` — stronger elevated background

Text / foreground:
- `text-fg` — primary text
- `text-fg-muted` — secondary text
- `text-fg-subtle` — tertiary / labels / captions

Borders:
- `border-border` — default border
- `border-border-strong` — emphasized border
- `border-card` — card border (custom utility)
- `divide-table` — table row dividers (custom utility)

Brand / primary:
- `bg-primary`, `text-primary`, `border-primary`
- `bg-primary-hover` (hover state), `bg-primary-light`, `bg-primary-dark`
- `text-primary-foreground` — content on primary

Destructive / danger:
- `bg-danger`, `text-danger`, `border-danger-border`
- `bg-danger-subtle` (soft bg), `bg-danger-solid` / `bg-danger-solid-hover` (solid button), `bg-danger-hover`
- `text-danger-foreground` — content on danger

Other: `bg-tooltip` / `text-tooltip-foreground`.

## Themes

`THEMES` lists the runtime-switchable themes (light, dark, cupcake, corporate, synthwave, dracula, night, … 30+). The layout ships a theme picker. Switching sets `[data-theme]` / `.dark`; token values change, your markup does not.

Tokens are defined in `src/templates/tailwind.css` — `@theme` registers the `--color-*` utility namespace, and `:root` / `.dark` / `[data-theme]` blocks hold the actual values. Tailwind is built at package-build time (no runtime CDN).
