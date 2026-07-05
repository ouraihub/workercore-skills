---
name: workercore-templates
description: MANDATORY guide for @ouraihub/workercore templates — Mustache syntax, partial usage, and the no-inline-JS client interactivity convention.
---

# workercore templates & client interactivity

## Mustache templates

Templates are `.html` files rendered with Mustache. Reference a partial with `{{> partial-name}}`. Use section blocks to render a partial only when its data is present:

```html
<div class="space-y-5">
  {{#pageHeader}}{{> page-header}}{{/pageHeader}}

  <div class="grid grid-cols-2 gap-3 xl:grid-cols-4">
    {{#stats}}{{> stats-card}}{{/stats}}
  </div>

  {{#table}}{{> data-table}}{{/table}}
</div>
```

Mustache reminders:
- `{{value}}` HTML-escapes. `{{{value}}}` is raw — use for pre-built HTML fragments like `rowsHtml`, `controlHtml`, `actionsHtml`.
- `{{#key}}...{{/key}}` renders when `key` is truthy / iterates arrays. `{{^key}}...{{/key}}` renders when falsy/empty.
- Inside an array section, `{{field}}` refers to the current item.

All colors in templates use semantic tokens — see [../tokens/SKILL.md](../tokens/SKILL.md). For component data contracts, see [../components/](../components/).

## Client interactivity (no inline JS)

Rule 2 of the [core conventions](../conventions/SKILL.md): HTML never contains JS. Interactivity is pre-built in `src/client/modules/` and bundled at build time. Templates opt in **declaratively**:

- **Modals / overlays:** trigger with `<a href="#modal-id">`; the overlay uses CSS `:target` to show (works without JS). The JS module also supports `data-modal-open` / `data-modal-close` / `data-modal-panel` / `data-modal-backdrop`.
- **Dropdowns:** `data-dropdown-trigger` + `data-dropdown-menu`.
- **Repeaters (add/remove rows):** `data-repeater`, `data-repeater-item`, `data-repeater-template`, `data-repeater-add`, `data-repeater-remove`.
- **Offcanvas, mobile sidebar, theme picker, charts, kanban drag:** handled by their modules via markup hooks.

Never write a new `<script>` in a template. If new behavior is needed, add a module under `src/client/modules/` and rebuild the client bundle (`pnpm build:client`) — do not edit the generated `client-bundle.js` directly.
