/* eslint-disable no-undef */
// Firebase Messaging service worker for Web push background handling.
//
// IMPORTANT:
// 1) Replace config placeholders with real Firebase Web config values.
// 2) Keep this file at `/web/firebase-messaging-sw.js`.
// 3) Ensure Appwrite Messaging provider is configured for FCM/Web Push.

importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "REPLACE_FIREBASE_WEB_API_KEY",
  authDomain: "REPLACE_FIREBASE_WEB_AUTH_DOMAIN",
  projectId: "REPLACE_FIREBASE_WEB_PROJECT_ID",
  storageBucket: "REPLACE_FIREBASE_WEB_STORAGE_BUCKET",
  messagingSenderId: "REPLACE_FIREBASE_WEB_MESSAGING_SENDER_ID",
  appId: "REPLACE_FIREBASE_WEB_APP_ID",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload?.notification?.title || "WhatsUnity";
  const body = payload?.notification?.body || "You have a new message";
  self.registration.showNotification(title, {
    body,
    data: payload?.data || {},
  });
});
