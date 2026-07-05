### sidebar family
The left navigation shell. **Usually automatic** — the layout builds it from `AppConfig.pages`, or from an explicit `AppConfig.sidebar`. You rarely reference these partials directly.

Partials: `sidebar`, `sidebar-brand`, `sidebar-workspace`, `sidebar-section`, `sidebar-item`, `sidebar-subitem`, `sidebar-user`, `sidebar-theme`.

#### SidebarConfig (pass via `createApp({ sidebar })` to override the auto-generated nav)
```ts
sidebar: {
  brand: { name: string; href: string; icon?: string; iconHtml?: string; logoHtml?: string; initials?: string }
  sections: Array<{
    title?: string
    items: Array<{
      label: string
      href?: string
      icon?: string
      badge?: string
      active?: boolean
      expanded?: boolean
      children?: SidebarItem[]   // nested subitems
    }>
  }>
  workspace?: { name: string; href: string; slug?: string; logoHtml?: string }
  user?: { name: string; email?: string; avatar?: string; initials?: string; href?: string }
  theme?: 'light' | 'dark'
}
```

#### Rules
- Prefer letting the sidebar auto-generate from `pages`. Only pass `sidebar` when you need custom sections, nesting, a workspace switcher, or a user footer.
- `sidebar-theme` renders the theme picker (see [../tokens/SKILL.md](../tokens/SKILL.md)).
