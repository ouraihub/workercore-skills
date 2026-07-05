### filter-bar
A toolbar above a table: filter tabs, a search box, and an optional custom control.

Reference: `{{#filterBar}}{{> filter-bar}}{{/filterBar}}`

#### Data contract
```ts
filterBar: {
  tabs: {
    items: Array<{ label: string; active?: boolean; url?: string }>
  }
  searchPlaceholder: string
  controlHtml?: string   // raw HTML for an extra control on the right (rendered with {{{ }}})
}
```

#### Rules
- One tab should have `active: true`.
- `controlHtml` is raw HTML — e.g. a sort dropdown or a "columns" toggle. Use semantic tokens.
