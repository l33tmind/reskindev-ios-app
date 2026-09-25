import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of conversations for the current user
  Stream<List<ConversationModel>> getInbox(String currentUserId, {bool showArchived = false}) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
             final list = snapshot.docs.map((doc) => ConversationModel.fromMap(doc.id, doc.data())).toList();
             return list.where((chat) => showArchived ? chat.archivedBy.contains(currentUserId) : !chat.archivedBy.contains(currentUserId)).toList();
          }
        );
  }
  
  Future<void> toggleArchive(String chatId, String userId, bool archive) async {
    final ref = _db.collection('conversations').doc(chatId);
    if (archive) {
      await ref.update({'archivedBy': FieldValue.arrayUnion([userId])});
    } else {
      await ref.update({'archivedBy': FieldValue.arrayRemove([userId])});
    }
  }

  // Stream of messages for a specific conversation
  Stream<List<MessageModel>> getMessages(String chatId, {int limit = 30}) {
    return _db
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Get a single conversation
  Future<ConversationModel?> getConversation(String chatId) async {
    final doc = await _db.collection('conversations').doc(chatId).get();
    if (doc.exists && doc.data() != null) {
      return ConversationModel.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  // Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String text,
    String type = 'text',
    num? offerPrice,
    int? offerDays,
    String? offerDescription,
    String? imageUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final batch = _db.batch();

    final chatRef = _db.collection('conversations').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    // Create the message
    final msgData = {
      'text': text,
      'senderId': currentUserId,
      'senderName': currentUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
      if (offerPrice != null) 'offerPrice': offerPrice,
      if (offerDays != null) 'offerDays': offerDays,
      if (offerDescription != null) 'offerDescription': offerDescription,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
    };
    batch.set(msgRef, msgData);

    // Get the conversation to increment unread counts for OTHER participants
    final chatDoc = await chatRef.get();
    Map<String, int> unreadCount = {};
    if (chatDoc.exists) {
      final data = chatDoc.data()!;
      unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
      final participants = List<String>.from(data['participants'] ?? []);
      for (String p in participants) {
        if (p != currentUserId) {
          unreadCount[p] = (unreadCount[p] ?? 0) + 1;
        }
      }
    }

    // Update parent conversation
    batch.update(chatRef, {
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'archivedBy': [],
      'unreadCount': unreadCount,
    });

    await batch.commit();

    // Send push notification to other participants
    if (chatDoc.exists) {
      final participants = List<String>.from(
        chatDoc.data()!['participants'] ?? [],
      );
      String? myDeviceToken;
      try {
        myDeviceToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      for (String p in participants) {
        if (p != currentUserId) {
          try {
            final userDoc = await _db.collection('users').doc(p).get();
            if (userDoc.exists) {
              final token = userDoc.data()?['fcmToken'] as String?;
              if (token != null && token.isNotEmpty && token != myDeviceToken) {
                await NotificationService.sendPushNotification(
                  fcmToken: token,
                  title: currentUserName,
                  body: text,
                );
              }
            }
          } catch (e) {
            debugPrint('Failed to send chat notification: $e');
          }
        }
      }
    }
  }

  // Mark messages as read for current user
  Future<void> markAsRead(String chatId, String currentUserId) async {
    final chatRef = _db.collection('conversations').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    final data = chatDoc.data()!;
    final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});

    if (unreadCount[currentUserId] != null && unreadCount[currentUserId]! > 0) {
      unreadCount[currentUserId] = 0;
      await chatRef.update({
        'unreadCount': unreadCount,
        'lastReadTime.$currentUserId': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> getOrCreateOrderConversation({
    required String currentUserId,
    required String targetUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required String targetUserName,
    required String targetUserAvatar,
    required String orderId,
  }) async {
    final query = await _db
        .collection('conversations')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    final chatRef = _db.collection('conversations').doc();
    final newChat = ConversationModel(
      id: chatRef.id,
      participants: [currentUserId, targetUserId],
      participantDetails: {
        currentUserId: {'name': currentUserName, 'avatar': currentUserAvatar},
        targetUserId: {'name': targetUserName, 'avatar': targetUserAvatar},
      },
      lastMessage: '',
      updatedAt: null,
      unreadCount: {currentUserId: 0, targetUserId: 0},
      typing: {currentUserId: false, targetUserId: false},
      freelancerId: targetUserId,
      clientId: currentUserId,
      orderId: orderId,
    );

    await chatRef.set(newChat.toMap());
    return chatRef.id;
  }

  // Create a new conversation if it doesn't exist, or return existing
  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String targetUserId,
    required String currentUserName,
    required String currentUserAvatar,
    required String targetUserName,
    required String targetUserAvatar,
  }) async {
    // Check if conversation already exists (this can be optimized based on how you index)
    // A simple query to check if there is a conversation with exactly these two participants.
    final query = await _db
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in query.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(targetUserId) &&
          participants.length == 2 &&
          doc.data()['orderId'] == null) {
        return doc.id;
      }
    }

    // Create new
    final chatRef = _db.collection('conversations').doc();
    final newChat = ConversationModel(
      id: chatRef.id,
      participants: [currentUserId, targetUserId],
      participantDetails: {
        currentUserId: {'name': currentUserName, 'avatar': currentUserAvatar},
        targetUserId: {'name': targetUserName, 'avatar': targetUserAvatar},
      },
      lastMessage: '',
      updatedAt: null, // Will be set by serverTimestamp on first message
      unreadCount: {currentUserId: 0, targetUserId: 0},
      typing: {currentUserId: false, targetUserId: false},
      freelancerId: targetUserId,
      clientId: currentUserId,
    );

    await chatRef.set(newChat.toMap());
    return chatRef.id;
  }

  // Set typing status
  Future<void> setTyping(String chatId, String userId, bool isTyping) async {
    final chatRef = _db.collection('conversations').doc(chatId);
    await chatRef.update({'typing.$userId': isTyping});
  }

  Future<void> sendSystemMessage({
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String orderId,
    required String gigTitle,
    required String actionType,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Check if a conversation already exists for this specific order
      final QuerySnapshot chatQuery = await _db
          .collection('conversations')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      String? existingChatId;
      if (chatQuery.docs.isNotEmpty) {
        existingChatId = chatQuery.docs.first.id;
      }

      // 2. Create chat if it doesn't exist
      if (existingChatId == null) {
        DocumentReference newChat = await _db.collection('conversations').add({
          'participants': [buyerId, sellerId],
          'orderId': orderId,
          'participantDetails': {
            buyerId: {'name': buyerName},
            sellerId: {'name': sellerName},
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
      'archivedBy': [],
          'lastMessage': text,
        });
        existingChatId = newChat.id;
      } else {
        // Update last message
        await _db.collection('conversations').doc(existingChatId).update({
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
      'archivedBy': [],
        });
      }

      // 3. Insert the system message
      await _db
          .collection('conversations')
          .doc(existingChatId)
          .collection('messages')
          .add({
            'type': 'system_notification',
            'actionType': actionType,
            'text': text,
            'orderId': orderId,
            'gigTitle': gigTitle,
            'senderId': 'system',
            'createdAt': FieldValue.serverTimestamp(),
            if (metadata != null) 'metadata': metadata,
          });
    } catch (e) {
      print("Failed to send system message: $e");
    }
  }
}
