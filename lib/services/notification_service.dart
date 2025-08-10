import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notification service
  Future<void> initialize() async {
    // Request permission for iOS
    await _requestPermission();
    
    // Get and save FCM token
    await _saveToken();
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
    
    // Configure message handlers
    _configureMessageHandlers();
  }

  // Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    print('Notification permission status: ${settings.authorizationStatus}');
  }

  // Get FCM token and save to Firestore
  Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('FCM Token saved for user: ${user.uid}');
    }
  }

  // Configure message handlers
  void _configureMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.messageId}');
      _handleMessage(message);
    });

    // Handle background message clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Background message clicked: ${message.messageId}');
      _handleMessageClick(message);
    });
  }

  // Handle incoming message
  void _handleMessage(RemoteMessage message) {
    // Show local notification or in-app notification
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      // TODO: Show local notification using flutter_local_notifications
      print('Notification Title: ${notification.title}');
      print('Notification Body: ${notification.body}');
    }
    
    // Handle data payload
    if (data.isNotEmpty) {
      _processMessageData(data);
    }
  }

  // Handle message click
  void _handleMessageClick(RemoteMessage message) {
    final data = message.data;
    
    // Navigate based on message type
    if (data['type'] == 'match_update') {
      final matchId = data['matchId'];
      // TODO: Navigate to match details screen
      print('Navigate to match: $matchId');
    } else if (data['type'] == 'match_reminder') {
      final matchId = data['matchId'];
      // TODO: Navigate to match details screen
      print('Navigate to match: $matchId');
    } else if (data['type'] == 'new_message') {
      final chatId = data['chatId'];
      // TODO: Navigate to chat screen
      print('Navigate to chat: $chatId');
    }
  }

  // Process message data
  void _processMessageData(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'match_cancelled':
        // Update local match data
        print('Match cancelled: ${data['matchId']}');
        break;
      case 'match_updated':
        // Refresh match data
        print('Match updated: ${data['matchId']}');
        break;
      case 'player_joined':
        // Update participant list
        print('Player joined match: ${data['matchId']}');
        break;
      case 'player_left':
        // Update participant list
        print('Player left match: ${data['matchId']}');
        break;
      case 'substitute_needed':
        // Show substitute alert
        print('Substitute needed for match: ${data['matchId']}');
        break;
      default:
        print('Unknown message type: $type');
    }
  }

  // Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      
      if (fcmToken != null) {
        // Store notification in Firestore (to be sent by Cloud Function)
        await _firestore.collection('notifications').add({
          'token': fcmToken,
          'title': title,
          'body': body,
          'data': data ?? {},
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification to multiple users
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    for (final userId in userIds) {
      await sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  // Subscribe to topic (for group notifications)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  // Clear FCM token on logout
  Future<void> clearToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
    }
  }
}