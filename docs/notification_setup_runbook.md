# Notification Setup Runbook (Android + Web + Appwrite)

This runbook is the operator-facing companion to `docs/technical_notification_system.md`.

## Goal

Enable reliable chat notifications in all app states:

- Foreground/in-app badges
- Background local/browser notifications
- Terminated-state push notifications

## A) Appwrite Console Setup

### 1. Configure Messaging provider(s)

In Appwrite Console:

- Go to **Messaging -> Providers**
- Configure:
  - **FCM** for Android (and optionally Apple via FCM)
  - Web push/FCM route as required by your environment

Record provider ID if you want explicit routing from client:

- `APPWRITE_PUSH_PROVIDER_ID`

### 2. Deploy function config

`appwrite.config.json` includes function:

- `notify_new_message`
- events: `databases.*.tables.messages.rows.*.create`
- scopes: `databases.read`, `messaging.write`
- execute: `[]` (event-driven only)

Deploy:

```bash
appwrite push functions
```

### 3. Function environment variables

Set on `notify_new_message`:

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_API_KEY`
- `APPWRITE_DATABASE_ID`

## B) Android Setup

### 1. Firebase project

- Add Android app in Firebase Console for your package ID.
- Download `google-services.json`.

Place it under:

- `android/app/google-services.json`

### 2. Gradle plugins

Already wired:

- `android/settings.gradle.kts`: `com.google.gms.google-services`
- `android/app/build.gradle.kts`: applies `com.google.gms.google-services`

### 3. Permissions

Already wired:

- `android.permission.POST_NOTIFICATIONS`

## C) Web Setup

### 1. Service worker

File:

- `web/firebase-messaging-sw.js`

Replace placeholders with real Firebase Web config values.

### 2. .env values

Set:

- `FIREBASE_WEB_API_KEY`
- `FIREBASE_WEB_APP_ID`
- `FIREBASE_WEB_PROJECT_ID`
- `FIREBASE_WEB_MESSAGING_SENDER_ID`
- `FIREBASE_WEB_AUTH_DOMAIN`
- `FIREBASE_WEB_STORAGE_BUCKET`
- `FIREBASE_WEB_MEASUREMENT_ID`
- `FIREBASE_WEB_VAPID_KEY`

## D) App Runtime Wiring

Runtime services:

- `MessageNotificationLifecycleService`:
  - background/inactive local/browser notifications
- `PushTargetRegistrationService`:
  - fetches/refreshes FCM token
  - registers Appwrite push target per authenticated user

Startup/lifecycle owner:

- `MainScreen` (`WidgetsBindingObserver`)

## E) Data Path Validation

### 1. Login flow

- User logs in.
- Verify push target created for account.

### 2. Send message

- Message inserted in `messages` table.
- `notify_new_message` executes via event.
- Function resolves recipients and sends push via Messaging.

### 3. Device receives push

- Background/terminated receiver gets OS push notification.

## F) QA Checklist

1. Android user A logs in -> target exists.
2. Android user B logs in -> target exists.
3. A sends to general -> B receives push (not A).
4. A sends to building -> only same-building users receive push.
5. Kill receiver app and repeat -> push still received.
6. Rotate FCM token scenario -> target update succeeds.
7. Web user receives push with active service worker.

## G) Common Failure Modes

- No provider configured -> function succeeds but no push delivery.
- Missing targets -> no delivery.
- Wrong Firebase config/web service worker placeholders -> web token/push fail.
- Incorrect function env vars/API key scopes -> function errors.

## H) Rollback Plan

If push introduces issues:

1. Disable `notify_new_message` function in Appwrite Console.
2. Keep in-app mention/lifecycle local notifications active.
3. Re-enable after fixing provider/target configuration.
