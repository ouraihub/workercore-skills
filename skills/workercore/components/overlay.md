### overlay
A modal dialog shell, shown/hidden purely via CSS `:target` (no JS required).

Reference: register as a partial and include it, or use one of the [prebuilt modals](./modals.md).

#### Data contract
```ts
{
  id: string      // unique id; the modal opens when the URL hash matches (#id)
  title: string
  body: string    // raw HTML for the modal body (rendered with {{{ }}})
  size?: string   // Tailwind max-width class, e.g. "max-w-lg"; defaults to "max-w-md"
}
```

#### Rules
- **Open it** with a link: `<a href="#your-modal-id">Open</a>`. **Close** with `<a href="#">` or the built-in close button.
- The overlay uses `target:visible target:opacity-100` — it works without JavaScript. The modal JS module adds enhancements via `data-modal-*` but is not required.
- `body` is raw HTML — build it with semantic tokens and, for forms, the [action-bar](./action-bar.md) partial for the footer buttons.
