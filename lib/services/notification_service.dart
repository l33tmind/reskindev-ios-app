import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  

  // Cache the config in memory so we don't read from Firestore every time a message is sent.
  static Map<String, dynamic>? _cachedServiceAccount;

  static Future<Map<String, dynamic>> _getServiceAccountConfig() async {
    if (_cachedServiceAccount != null) return _cachedServiceAccount!;

    final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('fcm_config').get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data.containsKey('jsonString')) {
         // User pasted the whole JSON file into one string field
         _cachedServiceAccount = jsonDecode(data['jsonString'] as String);
      } else {
         // User created individual fields
         _cachedServiceAccount = data;
      }
      // Fix private key formatting if it got messed up (escaped newlines)
      if (_cachedServiceAccount!['private_key'] != null) {
        _cachedServiceAccount!['private_key'] = _cachedServiceAccount!['private_key'].replaceAll('\\n', '\n');
      }
      return _cachedServiceAccount!;
    }
    
    throw Exception("FCM Service Account Config not found in Firestore (admin_settings/fcm_config)");
  }

  static Future<String> _getAccessToken(Map<String, dynamic> serviceAccountJson) async {
    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final authClient = await clientViaServiceAccount(accountCredentials, _scopes);
    final accessToken = authClient.credentials.accessToken.data;
    authClient.close();
    return accessToken;
  }

  static Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
  }) async {
    try {
      final config = await _getServiceAccountConfig();
      final String token = await _getAccessToken(config);
      final String endpoint = 'https://fcm.googleapis.com/v1/projects/${config["project_id"]}/messages:send';
      
      final Map<String, dynamic> messagePayload = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'notification': {
              'sound': 'default',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
              }
            }
          }
        }
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(messagePayload),
      );

      if (response.statusCode == 200) {
        debugPrint('Notification sent successfully!');
      } else {
        debugPrint('Failed to send notification. Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }
  static Future<void> sendAndSaveNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      // 1. Save to in-app notifications
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch FCM token and send push
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final fcmToken = doc.data()?['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await sendPushNotification(fcmToken: fcmToken, title: title, body: body);
        }
      }
    } catch (e) {
      debugPrint('Error saving/sending notification: $e');
    }
  }
}