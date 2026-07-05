### page-header
The title bar at the top of a page, with an optional description and right-aligned action buttons.

Reference: `{{#pageHeader}}{{> page-header}}{{/pageHeader}}`

#### Data contract
```ts
pageHeader: {
  title: string
  description?: string   // optional subtitle under the title
  actionsHtml?: string   // raw HTML for right-aligned buttons (rendered with {{{ }}})
}
```

#### Rules
- `actionsHtml` is raw HTML — build buttons with semantic tokens (e.g. `bg-primary text-white hover:bg-primary-hover` for the primary action).
- Wrap the partial in a `{{#pageHeader}}...{{/pageHeader}}` section so it only renders when present.
