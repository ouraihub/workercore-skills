### empty-state
A centered "no data" placeholder with an icon, title, message, and optional action.

Reference: `{{#emptyState}}{{> empty-state}}{{/emptyState}}`

#### Data contract
```ts
{
  emptyTitle: string
  emptyMessage?: string
  iconHtml?: string    // raw SVG (rendered with {{{ }}}); falls back to a dot
  actionHtml?: string  // raw HTML for a CTA button below the message
}
```

#### Rules
- Use inside a table/list container when the data array is empty.
- `iconHtml` / `actionHtml` are raw HTML — use semantic tokens; the placeholder border is `border-dashed border-border`.
