### breadcrumb
A breadcrumb trail. Usually driven by the top-level `breadcrumbs` key returned from a handler.

Reference: `{{#breadcrumbs}}{{> breadcrumb}}{{/breadcrumbs}}` (or rendered automatically by the layout).

#### Data contract
```ts
breadcrumbs: Array<{
  label: string
  href?: string   // linked crumb; omit href for the current (last) page
  last?: boolean  // set true on the final crumb to suppress the trailing separator
}>
```

#### Rules
- The last crumb should omit `href` (renders as bold current-page text) and set `last: true`.
- Links use `hover:text-primary` automatically — do not hardcode colors.
