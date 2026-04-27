# UI/UX Screen Inventory

This inventory covers the agreed scope: core user flows plus admin/manager dashboards.

## Auth

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Sign In / Sign Up | `lib/features/auth/presentation/pages/signup_page.dart` | Default, Loading, Empty Validation, Error | Main auth entry with mode toggle. |
| OTP Verification | `lib/features/auth/presentation/pages/otp_screen.dart` | Default, Loading, Error, Success | Needs clear resend and retry behavior. |
| Join Community | `lib/features/auth/presentation/pages/welcome_page.dart` | Loading, Empty, Error, Content | Replace spinner-only dead-end with retry CTA. |
| Google Continuation | `lib/features/auth/presentation/widgets/signup_sections.dart` | Default, Loading, Error | Separate continuation state after Google identity. |
| Role Selection | `lib/features/auth/presentation/widgets/signup_sections.dart` | Default, Validation Error, Success | Resident vs manager selection with form variants. |

## Home

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Main Shell / Bottom Nav | `lib/features/home/presentation/pages/main_screen.dart` | Default, Switching, Empty Nav Fallback | Role-aware tabs and safe index handling. |
| Resident Home | `lib/features/home/presentation/pages/home_page.dart` | Default, Loading, Empty Widgets, Error | Service cards and community overview. |
| Manager Home | `lib/features/home/presentation/pages/manager_home_page.dart` | Default, Loading, Empty, Error | Remove "coming soon" UX for announcements. |
| Announcement Screen | `lib/features/home/presentation/pages/announcement_screen.dart` | Default, Empty, Error | Announcement list + actionability. |

## Chat

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Building Chat Container | `lib/features/chat/presentation/pages/building_chat_page.dart` | Loading, Empty Conversations, Error, Content | Entry to chat tabs and thread. |
| Chat Thread | `lib/features/chat/presentation/widgets/chatWidget/GeneralChat/GeneralChat.dart` | Default, Loading Older Messages, Empty, Error | Include composer and mention affordances. |
| Message Options Popover | `lib/features/chat/presentation/widgets/chatWidget/GeneralChat/message_row_wrapper.dart` | Default, Action Success, Action Error | Replace TODO actions (`Message`, `View profile`). |
| Member Details | `lib/features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart` | Default, Loading, Error | Actionable member profile flow. |

## Profile

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Profile Overview | `lib/features/profile/presentation/pages/profile_page.dart` | Default, Loading, Error, Readonly | Identity, role, and account status. |
| Edit Profile | `lib/features/profile/presentation/pages/profile_page.dart` | Default, Validation Error, Save Success, Save Error | Separate edit state from display state. |

## Maintenance

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Maintenance Requests | `lib/features/maintenance/presentation/pages/maintenance_page.dart` | Default, Loading, Empty, Error | List + status chips + filters. |
| Request Form | `lib/features/maintenance/presentation/pages/maintenance_page.dart` | Default, Validation Error, Submit Loading, Submit Success | Guided form with attachment cues. |
| Request Detail / Timeline | `lib/features/maintenance/presentation/pages/maintenance_page.dart` | Default, Empty Timeline, Error | Status progression transparency. |

## Social

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Social Feed | `lib/features/social/presentation/pages/Social.dart` + `lib/features/social/presentation/widgets/social_feed_tab.dart` | Default, Loading, Empty, Error | Add retry and onboarding empty state. |
| Post Card Interactions | `lib/features/social/presentation/widgets/social_feed_tab.dart` | Default, Like Success, Share Success, Action Error | Replace placeholder like/share actions. |
| Post Detail / Comments | `lib/features/social/presentation/widgets/comment_popup_dialog.dart` | Default, Empty Comments, Error | Comment creation and moderation copy. |
| Create Post | `lib/features/social/presentation/widgets/create_post_dialog.dart` | Default, Validation Error, Posting, Posted | Media and text composition hints. |

## Admin / Manager Operations

| Screen | Existing File | Prototype Required States | Notes |
|---|---|---|---|
| Admin Dashboard Shell | `lib/features/admin/presentation/pages/AdminDashboard/AdminDashboard.dart` | Default, Loading, Empty, Error | Stable navigation hierarchy. |
| Members Management | `lib/features/admin/presentation/pages/AdminDashboard/MembersManagement.dart` | Default, Loading, Empty, Error | Search/sort and moderation actions. |
| Reports List | `lib/features/admin/presentation/pages/AdminDashboard/Reports.dart` | Default, Loading, Empty, Error | Clarify severity and resolution states. |
| Report Details | `lib/features/admin/presentation/pages/AdminDashboard/Reports.dart` | Default, Action Confirm, Action Error | Remove placeholder tap behavior. |
| Manager Announcements | `lib/features/home/presentation/pages/manager_home_page.dart` | Default, Empty, Error, Published | Replace current placeholder flow. |

## Prototype Completion Definition

A screen is considered prototype-complete when it has:

1. A default content state
2. A loading state
3. An empty state with CTA
4. An error state with retry
5. Navigation/action notes for top interactions
