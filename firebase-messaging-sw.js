/* eslint-disable no-undef */
// Firebase Messaging service worker (Web Push background).
//
// Config is loaded from firebase-web-push-env.js (generated from .env):
//   dart run tool/sync_firebase_web_push_env.dart
// Or: npm run sync:firebase-web-push
//
// That file must match the options passed to Firebase.initializeApp in Dart
// (see PushTargetRegistrationService).

importScripts("./firebase-web-push-env.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp(self.__WHATSUNITY_FIREBASE_WEB_CONFIG__);

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // If the payload contains a 'notification' object, the browser (FCM)
  // handles showing it automatically when the app is in the background.
  // Calling showNotification here would result in duplication.
  if (payload.notification) {
    console.log("FCM notification handled by browser automatically.");
    return;
  }

  const title = payload?.data?.title || "WhatsUnity";
  const body = payload?.data?.body || "You have a new message";

  // Tag helps deduplicate notifications for the same channel.
  const tag = payload?.data?.tag || payload?.data?.channel_id || "default";

  return self.registration.showNotification(title, {
    body,
    tag,
    data: payload?.data || {},
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  // Try to open the app or focus if already open.
  const urlToOpen = new URL(self.location.origin).href;

  const promiseChain = clients.matchAll({
    type: "window",
    includeUncontrolled: true
  }).then((windowClients) => {
    let matchingClient = null;

    for (let i = 0; i < windowClients.length; i++) {
      const windowClient = windowClients[i];
      if (windowClient.url === urlToOpen || windowClient.url.startsWith(urlToOpen)) {
        matchingClient = windowClient;
        break;
      }
    }

    if (matchingClient) {
      return matchingClient.focus();
    } else {
      return clients.openWindow(urlToOpen);
    }
  });

  event.waitUntil(promiseChain);
});
