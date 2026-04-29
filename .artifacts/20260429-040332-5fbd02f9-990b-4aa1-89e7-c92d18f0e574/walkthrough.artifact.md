# Unified Notification Sync Walkthrough

I have implemented a comprehensive synchronization system for notification preferences. This ensures that when a user disables a channel (e.g., BuildingChat) in the Profile Page, they stop receiving notifications for that channel across all platforms (Android & Web) and all app states (Open, Closed, or Killed).

## Key Components

### 1. Database Schema (`notification_preferences`)
Added a new collection to Appwrite to persist user-specific toggles on the server.
- **Document ID**: Matches the User's ID.
- **Attributes**: `general_chat_enabled`, `building_chat_enabled`, `admin_notifications_enabled`, `maintenance_notifications_enabled`.

### 2. Flutter App Sync
Updated `MessageNotificationLifecycleService` to push local preference changes to the server.
- Whenever a toggle is changed in the **Profile Page**, the app triggers an asynchronous sync to the Appwrite collection.
- This bridges the gap between local `SharedPreferences` and the server's push logic.

### 3. Smart Cloud Function (`notify-new-message`)
Enhanced the `notify_new_message` function to be "preference-aware".
- **Recipient Filtering**: Before sending a push message via FCM/Web Push, the function now fetches the `notification_preferences` for each recipient.
- **Mute Enforcement**: If a user has disabled the corresponding channel type on the server, the function skips sending them a push notification.

## Platform Impact

| State | Web (PWA) | Android |
| :--- | :--- | :--- |
| **Open (Active)** | Handled by Realtime (Suppressed by UI). | Handled by Realtime (Suppressed by UI). |
| **Background (Alive)** | Handled by `MessageNotificationLifecycleService`. Checks local prefs. | Handled by `MessageNotificationLifecycleService`. Checks local prefs. |
| **Closed / Killed** | Handled by FCM + Cloud Function. **Now checks server prefs.** | Handled by FCM + Cloud Function. **Now checks server prefs.** |

## Critical Action Required
To enable this feature, you must deploy the updated schema:
```bash
dart run tools/provision_appwrite_schema.dart
```

## Verification Summary
- **Static Analysis**: Ran `flutter analyze` and verified no regressions in the sync logic.
- **Architecture**: Adhered to "One-Job Rule" by delegating background filtering to the Cloud Function, keeping the client lightweight.
