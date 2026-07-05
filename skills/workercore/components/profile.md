### profile-header / profile-sidebar / profile-activity
Pieces for building a user/entity profile page.

#### profile-header
A cover banner + avatar + name/subtitle + status badge + optional edit action and tabs.

Reference: `{{#profileHeader}}{{> profile-header}}{{/profileHeader}}`

```ts
profileHeader: {
  avatar: string           // initials or raw markup shown in the avatar circle
  name: string
  subtitle: string
  isActive?: boolean       // toggles an "Active" vs "Offline" status badge
  editUrl?: string         // shows an "Edit" button when present
  tabs?: { items: Array<{ label: string; url: string; active?: boolean; iconHtml?: string }> }
}
```

#### profile-sidebar / profile-activity
Side panel and activity feed partials used on profile pages. Reference with `{{> profile-sidebar}}` / `{{> profile-activity}}` inside their data sections.

#### Rules
- The status badge (`isActive`) and cover gradient are intentionally fixed-tone; everything else uses semantic tokens.
- Set `active: true` on the current tab.
