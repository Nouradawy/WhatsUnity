# UI/UX Must-Fix Implementation Tickets

Source: `docs/uiux/readiness_review.md`

## Chat

### TICKET-CHAT-001: Replace placeholder member actions
- **Problem:** Member popup actions in chat are TODO placeholders.
- **Files:** `lib/features/chat/presentation/widgets/chatWidget/GeneralChat/message_row_wrapper.dart`
- **Acceptance Criteria:**
  - `Message` action performs a concrete behavior (at minimum, user feedback + close modal).
  - `View profile` action performs a concrete behavior (at minimum, user feedback + close modal).
  - No TODO placeholder remains for these actions.

## Social

### TICKET-SOCIAL-001: Replace placeholder like/share actions
- **Problem:** Like/share are no-op callbacks in feed cards.
- **Files:** `lib/features/social/presentation/widgets/social_feed_tab.dart`
- **Acceptance Criteria:**
  - Like action updates UI feedback and user receives confirmation.
  - Share action performs meaningful action (copy/share intent fallback) with user feedback.
  - No empty callbacks remain for primary actions.

### TICKET-SOCIAL-002: Complete feed states
- **Problem:** Missing robust empty/error/retry UX.
- **Files:** `lib/features/social/presentation/widgets/social_feed_tab.dart`
- **Acceptance Criteria:**
  - Loading state for initial fetch.
  - Empty state with CTA (refresh/create).
  - Error state with retry button.

## Admin

### TICKET-ADMIN-001: Add report drill-down action sheet
- **Problem:** Report list tap currently placeholder.
- **Files:** `lib/features/admin/presentation/pages/AdminDashboard/Reports.dart`
- **Acceptance Criteria:**
  - Tapping report opens action sheet/dialog with concrete actions.
  - Must include at least copy details + close action.
  - Placeholder comment removed.

## Home/Manager

### TICKET-MANAGER-001: Replace announcements coming soon state
- **Problem:** Manager announcement area shows non-functional placeholder.
- **Files:** `lib/features/home/presentation/pages/manager_home_page.dart`
- **Acceptance Criteria:**
  - Screen shows proper empty-state structure with actionable CTA.
  - “Coming Soon” placeholder copy removed.

## Cross-Cutting State Completeness

### TICKET-STATE-001: Mandatory `Loading/Empty/Error` patterns
- **Problem:** Inconsistent state behavior across scoped screens.
- **Files:** Chat/Social/Admin/Manager scoped UI files
- **Acceptance Criteria:**
  - Explicit loading states
  - Explicit empty states with CTA
  - Explicit error states with retry affordance

## Cross-Cutting i18n + Accessibility

### TICKET-I18N-001: Remove global forced LTR
- **Problem:** App-level `Directionality(TextDirection.ltr)` forces layout direction.
- **Files:** `lib/main.dart`
- **Acceptance Criteria:**
  - No forced global LTR wrapper in `MaterialApp.builder`.
  - Locale direction follows Flutter localization defaults.

### TICKET-A11Y-001: Relax global text scale clamp
- **Problem:** Max text scale currently clamped too low.
- **Files:** `lib/main.dart`
- **Acceptance Criteria:**
  - Max scale increased to accessibility-friendly bound (>= 1.2).
  - App remains layout-safe in core flows.
