### stats-card
A single KPI / metric card — icon, label, big value, optional change indicator.

Reference (iterate an array): `{{#stats}}{{> stats-card}}{{/stats}}`

#### Data contract (one object per card in the `stats` array)
```ts
stats: Array<{
  label: string
  value: string
  icon?: string   // raw SVG markup (rendered with {{{ }}}); falls back to a dot
  change?: string // small caption next to the value, e.g. "+12%"
}>
```

#### Rules
- Put cards in a responsive grid: `<div class="grid grid-cols-2 gap-3 xl:grid-cols-4">{{#stats}}{{> stats-card}}{{/stats}}</div>`.
- `icon` is raw SVG string. Use `icon('name')` from the package to get a built-in glyph.
