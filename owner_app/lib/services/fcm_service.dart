import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // To access navigatorKey
import '../screens/alerts_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  debugPrint("Handling a background message: ${message.messageId}");
}

class FCMService {
  FCMService._privateConstructor();
  static final FCMService instance = FCMService._privateConstructor();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> init() async {
    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Request permissions for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
        
        // 2. Get the device token
        String? token = await _messaging.getToken();
        if (token != null) {
          debugPrint("FCM Token: $token");
          await _registerTokenWithSupabase(token);
        }

        // 3. Listen for token refreshes
        _messaging.onTokenRefresh.listen(_registerTokenWithSupabase);

        // Handle initial message (app opened from terminated state)
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationNavigation(initialMessage);
        }

        // Handle background state (app opened from background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

        // 4. Setup foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          
          if (message.notification != null) {
            final context = navigatorKey.currentContext;
            if (context != null) {
              final lat = message.data['lat'];
              final lng = message.data['lng'];
              final hasLocation = lat != null && lng != null;

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(message.notification!.title ?? 'Alert'),
                    ],
                  ),
                  content: Text(message.notification!.body ?? 'You have a new notification.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Dismiss'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
                      },
                      child: const Text('View Alerts'),
                    ),
                    if (hasLocation)
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          } else {
                            debugPrint('Could not launch maps');
                          }
                        },
                        child: const Text('View on Map'),
                      ),
                  ],
                )
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint("FCM Init Error: $e");
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    debugPrint("Navigating from notification: ${message.messageId}");
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
    }
  }

  Future<void> _registerTokenWithSupabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_devices').upsert({
        'owner_id': user.id,
        'fcm_token': token,
      }, onConflict: 'fcm_token');
    } catch (e) {
      debugPrint("Failed to register token: $e");
    }
  }
}
