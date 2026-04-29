# PWA Background & Sync Improvement Plan

This plan addresses two main issues with the PWA version of the app:
1. **Sync on Resume**: Messages sent while the app was in the background or closed do not appear immediately when the app is reopened.
2. **Background Notifications**: PWA notifications are unreliable when the app is backgrounded or killed.

## User Review Required

> [!IMPORTANT]
> - **VAPID Key**: Ensure `FIREBASE_WEB_VAPID_KEY` is provided in your `.env` or build command. Without it, Web Push notifications will fail on most browsers.
> - **PWA Installation**: For the best notification experience on Android/iOS, users should "Add to Home Screen" the PWA.

## Proposed Changes

### 1. Sync & Lifecycle (Web-Only Triggers)

#### [chat_cubit.dart](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/bloc/chat_cubit.dart)
- Add `refreshMessages()` to re-fetch the first page of messages and merge with the current state.
- This ensures that any messages missed while the WebSocket was disconnected (background state) are pulled from the server.

#### [mention_notification_cubit.dart](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/bloc/mention_notification_cubit.dart)
- Expose `refreshUnreadMentionsForce()` or ensure the existing refresh logic is easily triggerable on app resume.

#### [GeneralChat.dart](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/widgets/chatWidget/GeneralChat/GeneralChat.dart)
- Add `WidgetsBindingObserver` to the `_GeneralChatState`.
- On `AppLifecycleState.resumed`, trigger `chatCubit.refreshMessages()` **only if `kIsWeb` is true**.

#### [main_screen.dart](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/home/presentation/pages/main_screen.dart)
- In `didChangeAppLifecycleState`, trigger `mentionCubit.refreshUnreadMentions(authState)` when the app resumes **only if `kIsWeb` is true**.

#### [building_chat_page.dart](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/features/chat/presentation/pages/building_chat_page.dart)
- Convert `BuildingChat` to a `StatefulWidget` and add `WidgetsBindingObserver`.
- On `AppLifecycleState.resumed`, trigger `chatCubit.refreshMessages()` **only if `kIsWeb` is true**.
- This ensures the building-specific chat also refreshes its state on PWA resume.

---

### 2. PWA Background Notifications

#### [firebase-messaging-sw.js](file:///H:/Repo/WhatsUnity%20-%20Appwrite/web/firebase-messaging-sw.js)
- Add a `notificationclick` event listener to open or focus the app window when a notification is tapped.
- Improve the `onBackgroundMessage` handler to provide better defaults if the payload is missing notification fields.

#### [index.html](file:///H:/Repo/WhatsUnity%20-%20Appwrite/web/index.html)
- Ensure the service worker registration is robust and correctly handles the base path.
- Add `gcm_sender_id` to the manifest metadata (fallback for older browsers).

---

## Verification Plan

### Automated Tests
- I will verify the code changes by running `flutter analyze` to ensure no regressions.
- (Manual) Since I cannot run a PWA in this environment, I will verify the logic by ensuring the `resumed` state correctly triggers the expected cubit methods.

### Manual Verification
1. **Sync Test**:
   - Open the PWA, then switch to another tab.
   - Send a message to the user from another account.
   - Switch back to the PWA tab.
   - **Expected**: The new message should appear within a few seconds (re-fetch on resume).
2. **Notification Test**:
   - Close the PWA tab or kill the browser (if supported by OS).
   - Send a message to the user.
   - **Expected**: A browser notification should appear. Clicking it should open the PWA.
3. **Background Tab Test**:
   - Keep the PWA in a background tab.
   - Send a message.
   - **Expected**: A notification should appear (handled by `MessageNotificationLifecycleService` or Service Worker).
