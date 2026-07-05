### action-bar
A right-aligned form footer: a primary submit button and an optional secondary/cancel button. Ideal inside modals and forms.

Reference: `{{#actionBar}}{{> action-bar}}{{/actionBar}}`

#### Data contract
```ts
{
  primaryLabel: string
  secondaryLabel?: string  // renders a secondary button when present
  cancelUrl?: string       // href for the secondary button (e.g. "#" to close a modal)
}
```

#### Rules
- The primary button is a `type="submit"` styled `bg-primary text-white` — place it inside a `<form>`.
- Omit `secondaryLabel` for a single-button footer.
