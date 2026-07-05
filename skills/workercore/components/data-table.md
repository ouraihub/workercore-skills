### data-table
A responsive table with a header row, body rows, and optional pagination / offcanvas.

Reference: `{{#table}}{{> data-table}}{{/table}}`

#### Data contract
```ts
table: {
  columns?: Array<{ label: string }>  // simple header cells (label may contain HTML)
  columnsHtml?: string                // OR raw <th> markup for full control (overrides columns)
  rowsHtml: string                    // raw <tr>...</tr> markup for all body rows (required)
  pagination?: {                      // renders the pagination partial below the table
    totalResults: string | number
    currentPage: string | number
    totalPages: string | number
    prevUrl?: string
    nextUrl?: string
  }
  offcanvasHtml?: string              // raw HTML appended after the table (e.g. a row-detail panel)
}
```

#### Rules
- `rowsHtml` is raw `<tr>` markup you build in the handler — one `<tr class="...">` per row, cells `<td class="px-5 py-3 text-sm text-fg">`. Use semantic tokens.
- Provide either `columns` (simple) or `columnsHtml` (custom `<th>`s), not both — `columnsHtml` wins.
- See [pagination](./pagination.md) for the pagination sub-contract.
