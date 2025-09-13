import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/notification.dart';
import 'package:barkdate/services/in_app_notification_service.dart';
import 'package:barkdate/services/notification_sound_service.dart';

/// Firebase Cloud Messaging service for BarkDate
/// Handles push notifications, background messages, and FCM token management
/// Based on best practices from FluffyChat and Beacon reference implementations
class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static String? _cachedToken;
  
  /// Initialize Firebase messaging service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🔥 Initializing Firebase Messaging...');
      
      // Request permissions for notifications
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Get and store FCM token
      await _getAndStoreFCMToken();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Subscribe to user-specific topics
      await _subscribeToUserTopics();
      
      _isInitialized = true;
      debugPrint('✅ Firebase Messaging initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Error initializing Firebase Messaging: $e');
      // Don't rethrow - app should continue to work without push notifications
    }
  }
  
  /// Request notification permissions
  static Future<NotificationSettings> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
      carPlay: false,
      announcement: false,
    );
    
    debugPrint('📱 Notification permission status: ${settings.authorizationStatus}');
    
    // For iOS, also request local notification permissions
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
    
    return settings;
  }
  
  /// Initialize local notifications for when app is in foreground
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = 
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channels for Android
    if (!kIsWeb) {
      await _createNotificationChannels();
    }
  }
  
  /// Create Android notification channels for different notification types
  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;
    
    // Bark notifications channel
    final AndroidNotificationChannel barkChannel = AndroidNotificationChannel(
      'bark_notifications',
      'Bark Notifications',
      description: 'Notifications when dogs bark at each other',
      importance: Importance.high,
      sound: const RawResourceAndroidNotificationSound('bark_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
    );
    
    // Playdate notifications channel
    final AndroidNotificationChannel playdateChannel = AndroidNotificationChannel(
      'playdate_notifications',
      'Playdate Notifications',
      description: 'Notifications for playdate requests and updates',
      importance: Importance.high,
      sound: const RawResourceAndroidNotificationSound('playdate_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 100, 300, 100, 300]),
    );
    
    // Match notifications channel
    final AndroidNotificationChannel matchChannel = AndroidNotificationChannel(
      'match_notifications',
      'Match Notifications',
      description: 'Notifications for new matches',
      importance: Importance.high,
      sound: const RawResourceAndroidNotificationSound('match_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200, 100, 200]),
    );
    
    // Social notifications channel
    final AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
      'social_notifications',
      'Social Notifications',
      description: 'Notifications for likes, comments, and social interactions',
      importance: Importance.defaultImportance,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250]),
    );
    
    // Create all channels
    await Future.wait([
      androidPlugin.createNotificationChannel(barkChannel),
      androidPlugin.createNotificationChannel(playdateChannel),
      androidPlugin.createNotificationChannel(matchChannel),
      androidPlugin.createNotificationChannel(socialChannel),
    ]);
    
    debugPrint('📱 Created Android notification channels');
  }
  
  /// Get FCM token and store it in database
  static Future<String?> _getAndStoreFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _cachedToken = token;
        debugPrint('🔑 FCM Token: ${token.substring(0, 20)}...');
        
        // Store token in database for current user
        final user = SupabaseConfig.auth.currentUser;
        if (user != null) {
          await SupabaseConfig.client
              .from('users')
              .update({'fcm_token': token})
              .eq('id', user.id);
          
          debugPrint('💾 FCM token stored in database');
        }
        
        return token;
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
    
    return null;
  }
  
  /// Set up message handlers for different app states
  static void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    
    // Handle messages when app is terminated and opened from notification
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
      _cachedToken = newToken;
      
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        await SupabaseConfig.client
            .from('users')
            .update({'fcm_token': newToken})
            .eq('id', user.id);
      }
    });
  }
  
  /// Handle messages when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Foreground message received: ${message.messageId}');
    debugPrint('📱 Title: ${message.notification?.title}');
    debugPrint('📱 Body: ${message.notification?.body}');
    debugPrint('📱 Data: ${message.data}');
    
    // Create BarkDateNotification from FCM message
    final notification = _createNotificationFromMessage(message);
    
    if (notification != null) {
      // Show in-app banner notification
      await InAppNotificationService.showBanner(notification);
      
      // Play notification sound
      await NotificationSoundService.playNotificationSound(notification.type);
      
      // Show local notification if app is not in focus
      await _showLocalNotification(message, notification);
    }
  }
  
  /// Handle messages when app is opened from background
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('🔄 Background message opened: ${message.messageId}');
    
    // Navigate to appropriate screen based on notification type
    await _handleNotificationNavigation(message);
  }
  
  /// Show local notification
  static Future<void> _showLocalNotification(
    RemoteMessage message, 
    BarkDateNotification notification,
  ) async {
    final title = message.notification?.title ?? notification.title;
    final body = message.notification?.body ?? notification.body;
    
    // Determine notification channel and settings based on type
    String channelId;
    String channelName; 
    Importance importance;
    Priority priority;
    String? soundFile;
    
    switch (notification.type) {
      case NotificationType.bark:
        channelId = 'bark_notifications';
        channelName = 'Bark Notifications';
        importance = Importance.high;
        priority = Priority.high;
        soundFile = 'bark_sound';
        break;
      case NotificationType.playdateRequest:
      case NotificationType.playdate:
        channelId = 'playdate_notifications';
        channelName = 'Playdate Notifications';
        importance = Importance.high;
        priority = Priority.high;
        soundFile = 'playdate_sound';
        break;
      case NotificationType.match:
        channelId = 'match_notifications';
        channelName = 'Match Notifications';
        importance = Importance.high;
        priority = Priority.high;
        soundFile = 'match_sound';
        break;
      default:
        channelId = 'social_notifications';
        channelName = 'Social Notifications';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        break;
    }
    
    // Create notification details
    // Android-specific notification details
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      ticker: 'ticker',
      styleInformation: _getNotificationStyle(message, notification),
      icon: '@mipmap/ic_launcher',
      color: notification.iconColor,
      sound: soundFile != null ? RawResourceAndroidNotificationSound(soundFile) : null,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Show local notification
    await _localNotifications.show(
      notification.id.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode({
        'type': notification.type.name,
        'id': notification.id,
        'relatedId': notification.relatedId,
        'metadata': notification.metadata,
      }),
    );
  }
  
  /// Get notification style based on content
  static StyleInformation? _getNotificationStyle(
    RemoteMessage message, 
    BarkDateNotification notification,
  ) {
    // Get image URL from message data
    final imageUrl = message.data['image_url'];
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Big picture style for image notifications
      return BigPictureStyleInformation(
        FilePathAndroidBitmap(imageUrl), // Use file path for now
        contentTitle: notification.title,
        htmlFormatContentTitle: true,
        summaryText: notification.body,
        htmlFormatSummaryText: true,
      );
    }
    
    // Big text style for long notifications
    if (notification.body.length > 50) {
      return BigTextStyleInformation(
        notification.body,
        htmlFormatBigText: true,
        contentTitle: notification.title,
        htmlFormatContentTitle: true,
      );
    }
    
    return null;
  }
  
  /// Handle notification tap
  static Future<void> _onNotificationTapped(NotificationResponse response) async {
    debugPrint('👆 Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final type = NotificationType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => NotificationType.system,
        );
        
        // Navigate based on notification type
        await _navigateToScreen(type, data);
        
      } catch (e) {
        debugPrint('❌ Error handling notification tap: $e');
      }
    }
  }
  
  /// Navigate to appropriate screen based on notification
  static Future<void> _navigateToScreen(NotificationType type, Map<String, dynamic> data) async {
    // This will be implemented to navigate to appropriate screens
    // based on the notification type and data
    switch (type) {
      case NotificationType.bark:
        // Navigate to dog profile
        break;
      case NotificationType.playdateRequest:
        // Navigate to playdate response
        break;
      case NotificationType.playdate:
        // Navigate to playdate details
        break;
      case NotificationType.message:
        // Navigate to chat
        break;
      case NotificationType.match:
        // Navigate to match screen
        break;
      case NotificationType.social:
        // Navigate to social feed
        break;
      default:
        // Navigate to notifications screen
        break;
    }
  }
  
  /// Handle notification navigation from message
  static Future<void> _handleNotificationNavigation(RemoteMessage message) async {
    final notificationType = message.data['type'];
    if (notificationType != null) {
      final type = NotificationType.values.firstWhere(
        (e) => e.name == notificationType,
        orElse: () => NotificationType.system,
      );
      
      await _navigateToScreen(type, message.data);
    }
  }
  
  /// Create BarkDateNotification from FCM message
  static BarkDateNotification? _createNotificationFromMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final notification = message.notification;
      
      if (notification == null) return null;
      
      final type = NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      );
      
      return BarkDateNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: data['user_id'] ?? '',
        title: notification.title ?? '',
        body: notification.body ?? '',
        type: type,
        actionType: data['action_type'],
        relatedId: data['related_id'],
        metadata: data.isNotEmpty ? Map<String, dynamic>.from(data) : null,
        isRead: false,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error creating notification from message: $e');
      return null;
    }
  }
  
  /// Subscribe to user-specific topic
  static Future<void> _subscribeToUserTopics() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user != null) {
      try {
        // Subscribe to user-specific notifications
        await _firebaseMessaging.subscribeToTopic('user_${user.id}');
        
        // Subscribe to general topics
        await _firebaseMessaging.subscribeToTopic('barkdate_general');
        
        debugPrint('📡 Subscribed to notification topics');
      } catch (e) {
        debugPrint('❌ Error subscribing to topics: $e');
      }
    }
  }
  
  /// Unsubscribe from user-specific topics (called on logout)
  static Future<void> unsubscribeFromUserTopics(String userId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('user_$userId');
      debugPrint('📡 Unsubscribed from user topics');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topics: $e');
    }
  }
  
  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    if (_cachedToken != null) return _cachedToken;
    return await _getAndStoreFCMToken();
  }
  
  /// Send push notification to specific user
  static Future<bool> sendPushNotificationToUser({
    required String userToken,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      // This would typically be done via a cloud function or server
      // For now, we'll use Supabase Edge Functions
      final response = await SupabaseConfig.client.functions.invoke(
        'send-push-notification',
        body: {
          'token': userToken,
          'title': title,
          'body': body,
          'type': type.name,
          'data': data ?? {},
          'imageUrl': imageUrl,
        },
      );
      
      return response.status == 200;
    } catch (e) {
      debugPrint('❌ Error sending push notification: $e');
      return false;
    }
  }
  
  /// Send notification to topic
  static Future<bool> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-topic-notification',
        body: {
          'topic': topic,
          'title': title,
          'body': body,
          'type': type.name,
          'data': data ?? {},
        },
      );
      
      return response.status == 200;
    } catch (e) {
      debugPrint('❌ Error sending topic notification: $e');
      return false;
    }
  }
  
  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }
  
  /// Clear notification by ID
  static Future<void> clearNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // Don't call other services here as the app is not running
  
  debugPrint('🔄 Background message received: ${message.messageId}');
  debugPrint('🔄 Title: ${message.notification?.title}');
  debugPrint('🔄 Body: ${message.notification?.body}');
  debugPrint('🔄 Data: ${message.data}');
  
  // The system will handle showing the notification
  // We can update badge counts or do minimal processing here
}
