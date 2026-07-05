### navbar
The top bar (search, notifications, mobile menu toggle). **Usually automatic** — rendered by the layout. You rarely reference it directly.

Reference: `{{> navbar}}` (the layout includes it for you).

#### Rules
- Provided by the layout shell; no per-page data contract needed for standard use.
- The mobile menu toggle and search are wired to client modules via `data-*` hooks — do not add inline JS.
