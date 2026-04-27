# Prototype Usage

The prototype catalog is implemented as an in-app route:

- Route: `/uiux-prototypes`
- Page: `lib/features/ui_ux_prototypes/presentation/pages/uiux_prototype_catalog_page.dart`

## What it contains

- Mid-fidelity prototypes for every in-scope screen group:
  - Auth
  - Home
  - Chat
  - Profile
  - Maintenance
  - Social
  - Admin/Manager
- State toggle for each screen card:
  - Default
  - Loading
  - Empty
  - Error

## How to open

From any existing screen in debug/dev flows, navigate with:

```dart
Navigator.of(context).pushNamed('/uiux-prototypes');
```

## Implementation intent

This catalog is a production-readiness prototype reference. It is intentionally
isolated from business logic and backend data, so teams can validate interaction
states and UI consistency before implementing final feature behavior.
