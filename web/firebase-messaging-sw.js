// Import and configure the Firebase SDK
importScripts('https://www.gstatic.com/firebasejs/10.3.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.3.1/firebase-messaging-compat.js');

// Initialize Firebase
firebase.initializeApp({
  // Firebase config - use environment variables in production
  apiKey: "your_firebase_api_key_here",
  authDomain: "co1l0uvij8nhdcps5tiyii9b2wp9hp.firebaseapp.com",
  projectId: "co1l0uvij8nhdcps5tiyii9b2wp9hp",
  storageBucket: "co1l0uvij8nhdcps5tiyii9b2wp9hp.firebasestorage.app",
  messagingSenderId: "350088513961",
  appId: "1:350088513961:web:7104e09731a24d24c3dcb8"
});

// Retrieve Firebase Messaging object
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'default',
    requireInteraction: false,
    actions: [
      {
        action: 'open',
        title: 'Open',
        icon: '/icons/Icon-192.png'
      }
    ]
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification clicked', event);
  
  event.notification.close();
  
  // Open the app when notification is clicked
  event.waitUntil(
    clients.openWindow('/')
  );
});
