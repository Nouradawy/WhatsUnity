# PWA & Android Notification Preference Sync

This plan ensures that notification preferences (GeneralChat, BuildingChat, etc.) set in the Profile Page are honored across all platforms and states (Foreground, Background, Killed/Terminated).

## User Review Required

> [!CAUTION]
> **Action Required**: You must run the schema provisioning script to create the new `notification_preferences` collection before deploying these changes:
> ```bash
> dart run tools/provision_appwrite_schema.dart
> ```

## Proposed Changes

### 1. Database Schema

#### [provision_spec.json](file:///H:/Repo/WhatsUnity%20-%20Appwrite/tools/provision_spec.json) & [APPWRITE_SCHEMA.md](file:///H:/Repo/WhatsUnity%20-%20Appwrite/APPWRITE_SCHEMA.md)
- [x] Added `notification_preferences` collection to store user settings on the server.

---

### 2. Flutter App (Sync Preferences to Server)

#### [message_notification_lifecycle_service.dart](file:///H:/Repo/WhatsUnity%20-%20Appwrite/lib/core/services/message_notification_lifecycle_service.dart)
- Add `_syncRemoteNotificationPreferences` to push local settings to Appwrite.
- Update `updateNotificationChannelEnabled` to trigger this sync.
- This ensures the server knows when a user "mutes" a channel.

---

### 3. Appwrite Cloud Function (Honor Preferences)

#### [main.js (notify-new-message)](file:///H:/Repo/WhatsUnity%20-%20Appwrite/functions/notify-new-message/src/main.js)
- Update the function to fetch the `notification_preferences` document for each recipient.
- Filter out users who have disabled notifications for the current channel type.
- This stops FCM/Web Push messages from being sent to "muted" users in killed/terminated states.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no syntax errors.

### Manual Verification
1. **Preference Sync**:
   - Go to Profile Page on Web or Android.
   - Disable "GeneralChat" notifications.
   - Verify (via Appwrite Console) that the `notification_preferences` document for your user ID is updated with `general_chat_enabled: false`.
2. **Killed State Suppression**:
   - Disable a channel in the app.
   - Kill the app (Android) or close the PWA tab.
   - Send a message to that channel from another account.
   - **Expected**: No notification should be received.
3. **Re-enable Verification**:
   - Re-enable the channel in the app.
   - Repeat the background test.
   - **Expected**: Notification should be received normally.
