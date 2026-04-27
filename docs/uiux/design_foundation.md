# Mid-Fidelity UI/UX Design Foundation

This document defines consistent mid-fidelity design rules for all prototype screens.

## 1) Tokens

### Typography

- `titleLarge`: primary screen heading
- `titleMedium`: section heading
- `bodyMedium`: main copy and list rows
- `labelLarge`: buttons and chips
- `bodySmall`: helper text and metadata

### Color Roles

- `primary`: main call-to-action and active elements
- `surface`: card and panel backgrounds
- `surfaceContainerHighest`: grouped placeholders and skeleton blocks
- `error`: destructive and retry/failure emphasis
- `outline`: low-emphasis borders/dividers

### Spacing + Shape

- Base spacing scale: `4, 8, 12, 16, 20, 24`
- Card radius: `16`
- Input radius: `12`
- Button height target: `44` minimum

## 2) Reusable Component Contracts

### App Shell

- Top app bar with title and one primary action (if needed)
- Bottom nav with role-aware tabs
- Body always padded horizontally by `16`

### Form Patterns

- Label above input when form complexity is medium/high
- Inline helper text only for actionable guidance
- Validation appears below field and at submit-level summary

### Card Patterns

- Title + short metadata + action row
- One primary CTA max per card
- Use secondary text for status, never color alone

### Feedback Patterns

- Non-blocking success via snackbar
- Blocking errors via inline card + retry button
- Loading via skeleton rows for list screens and spinner only for short waits

## 3) Interaction Conventions

- Single primary action per view (`Continue`, `Submit`, `Save`, `Retry`)
- Secondary actions are text buttons when low-risk
- Overflow menus for message/report post actions
- Destructive actions require confirmation modal

## 4) Required UX State Template

Every data screen prototype must include:

1. **Default**
2. **Loading**
3. **Empty** (with explanatory copy and clear CTA)
4. **Error** (with retry CTA)

Optional states when relevant:

- `Offline`
- `PermissionRequired`
- `PartialData`

## 5) Accessibility and Localization Rules

- Do not hardcode user-facing copy in final implementation; all copy must map to localization keys.
- Keep minimum tap target at `44x44`.
- Do not force LTR at component level.
- Respect text scaling up to at least `1.2` in implementation.
- Pair icons with labels for state chips and actions.

## 6) Prototype Annotation Rules

Each prototype screen includes:

- Screen goal (what user should accomplish)
- Primary action
- Entry and exit navigation points
- State transitions (`Default -> Loading -> Success/Error`)

## 7) Delivery Mapping

- Core flow prototypes: Auth, Home, Chat, Profile
- Ops flow prototypes: Maintenance, Social, Admin/Manager
- Each prototype is published with the same shared state frame for consistency.
