import Flutter
import UIKit
import GoogleMaps
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appBadgeChannelName = "bark/app_badge"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()
    
    // Initialize Google Maps
    GMSServices.provideAPIKey("AIzaSyAbZGdAyEUXEkN-1CtVvPCWIsxkAY8_4ss")
    
    // Register for push notifications
    UNUserNotificationCenter.current().delegate = self
    
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )
    
    application.registerForRemoteNotifications()
    
    // Set Firebase Messaging delegate
    Messaging.messaging().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register the badge channel here — engineBridge.pluginRegistry is the
    // recommended API (avoids the rootViewController deprecation warning).
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BarkAppBadgePlugin") else {
      print("🔴 [AppDelegate] ⚠️ Could not get registrar for BarkAppBadgePlugin")
      return
    }

    let badgeChannel = FlutterMethodChannel(
      name: appBadgeChannelName,
      binaryMessenger: registrar.messenger()  // messenger() is a function in this Flutter version
    )

    badgeChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadgeCount":
        guard
          let args = call.arguments as? [String: Any],
          let rawCount = args["count"] as? Int
        else {
          result(FlutterError(code: "bad_args", message: "Missing or invalid badge count", details: nil))
          return
        }
        let safeCount = max(0, rawCount)
        print("🔴 [AppDelegate] setBadgeCount → \(safeCount)")
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = safeCount
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // Handle APNs token registration
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase FCM Token: \(fcmToken ?? "nil")")
    // Token is handled by Flutter side via FirebaseMessagingService
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
  // Show notification banner even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📱 Notification received in foreground: \(userInfo)")
    
    // Show banner, sound, and badge even when app is open
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("📱 Notification tapped: \(userInfo)")
    
    // CRITICAL: call super FIRST so the firebase_messaging Flutter plugin
    // intercepts the tap and fires onMessageOpenedApp / getInitialMessage().
    // Calling completionHandler() directly (without super) bypasses the plugin.
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
