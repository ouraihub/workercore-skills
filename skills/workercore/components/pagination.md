### pagination
Prev/next page navigation with a result count. Usually nested inside [data-table](./data-table.md), but can stand alone.

Reference: `{{#pagination}}{{> pagination}}{{/pagination}}`

#### Data contract
```ts
pagination: {
  totalResults: string | number
  currentPage: string | number
  totalPages: string | number
  prevUrl?: string   // omit to render a disabled Previous button
  nextUrl?: string   // omit to render a disabled Next button
}
```

#### Rules
- Omit `prevUrl` on the first page and `nextUrl` on the last — the partial renders a disabled arrow automatically.
- URLs are your own query strings, e.g. `/users?page=2`.
