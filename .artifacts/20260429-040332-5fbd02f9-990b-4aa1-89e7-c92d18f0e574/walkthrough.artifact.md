# PWA Background & Sync Improvements Walkthrough

I have implemented several improvements to the PWA (Web) version of the app to address synchronization issues when resuming the app and to improve background notification reliability. These changes are strictly guarded to only affect the Web platform, ensuring no performance impact on the Android version.

## Key Changes

### 1. Sync on Resume (Web-Only)
When the PWA is backgrounded, the browser often suspends its WebSocket connections. I added a lifecycle observer to re-fetch the latest messages when the app resumes on Web.

- **[ChatCubit](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/bloc/chat_cubit.dart)**: Added `refreshMessages()` to pull the first page of messages from the server and merge them into the local state.
- **[MentionNotificationCubit](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/bloc/mention_notification_cubit.dart)**: Added `refreshUnreadMentionsForce()` to ensure unread mention counts are updated on resume.
- **[GeneralChat](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/widgets/chatWidget/GeneralChat/GeneralChat.dart)** & **[BuildingChat](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/pages/building_chat_page.dart)**: Added `WidgetsBindingObserver` to trigger the refresh when the app state transitions to `resumed`, guarded by `if (kIsWeb)`.
- **[MainScreen](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/home/presentation/pages/main_screen.dart)**: Triggers a mention refresh on resume for the Web version.

### 2. Improved PWA Notifications
Enhanced the service worker to make notifications more interactive and reliable.

- **[firebase-messaging-sw.js](file:///H:/Repo/WhatsUnity%20-%20Appwrite/web/firebase-messaging-sw.js)**:
    - Added a `notificationclick` listener that focuses the existing app window or opens a new one when a notification is tapped.
    - Added support for data-only payloads and custom icons.
- **[index.html](file:///H:/Repo/WhatsUnity%20-%20Appwrite/web/index.html)**: Added `gcm_sender_id` as a fallback for older browsers to support Web Push notifications.

## Verification Summary

### Static Analysis
- Ran `flutter analyze` and verified that no new errors or regressions were introduced in the chat features.
- Fixed a missing `kIsWeb` import in `GeneralChat`.

### Manual Logic Verification
- Confirmed that all lifecycle-based refresh triggers are wrapped in `kIsWeb` checks.
- Verified that `BuildingChat` correctly uses a lifecycle manager to access the `ChatCubit` provided by its scope.
- Confirmed that the service worker handles both `notification` and `data` fields in FCM payloads for maximum compatibility.

## Critical Rules Followed
- **Web-Only**: All Flutter-side lifecycle changes are platform-guarded.
- **No Android Impact**: The Android app logic remains identical to its previous state.
- **Architecture**: Logic remains in Cubits/Repositories; UI only triggers actions based on platform state.
