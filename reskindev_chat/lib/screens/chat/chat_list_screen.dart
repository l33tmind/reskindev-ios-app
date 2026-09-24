import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (now.difference(date).inDays == 0 && now.day == date.day) {
      return DateFormat('hh:mm a').format(date);
    } else if (now.difference(date).inDays == 1 && now.day != date.day) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {})
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participants', arrayContains: user.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;
              
              final participants = List<String>.from(data['participants'] ?? []);
              final partnerId = participants.firstWhere((id) => id != user.uid, orElse: () => user.uid);
              final participantDetails = data['participantDetails'] as Map<String, dynamic>? ?? {};
              final partnerDetails = participantDetails[partnerId] as Map<String, dynamic>? ?? {};
              
              final partnerName = partnerDetails['name'] ?? 'User';
              final lastMessage = data['lastMessage'] ?? '';
              final time = _formatTime(data['updatedAt'] as Timestamp?);
              
              final unreadCountMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
              final unreadCount = unreadCountMap[user.uid] ?? 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(partnerName[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  partnerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: unreadCount > 0 ? Theme.of(context).primaryColor : Colors.grey,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        chatId: chatId,
                        clientName: partnerName,
                        partnerId: partnerId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
