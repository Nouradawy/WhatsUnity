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
  const title = payload?.notification?.title || "WhatsUnity";
  const body = payload?.notification?.body || "You have a new message";
  self.registration.showNotification(title, {
    body,
    data: payload?.data || {},
  });
});
