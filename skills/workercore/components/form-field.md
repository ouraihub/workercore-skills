### form-field
A labelled form control row — label on the left, control on the right, with optional hint and error.

Reference: `{{#field}}{{> form-field}}{{/field}}` (or iterate an array of fields)

#### Data contract
```ts
{
  label: string
  controlHtml: string   // raw HTML for the input/select/textarea (rendered with {{{ }}})
  hint?: string         // small helper text below the control
  error?: string        // error text below the control (rendered in text-danger)
  multiline?: boolean   // top-aligns the label for textarea-style controls
}
```

#### Rules
- `controlHtml` is the raw input markup. Style inputs with tokens: `rounded-lg border border-border bg-surface px-3 py-1.5 text-sm text-fg focus:border-primary focus:ring-primary`.
- `error` renders in `text-danger` automatically — don't hardcode a red color.
