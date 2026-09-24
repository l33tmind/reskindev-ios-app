import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String clientName;
  final String partnerId;

  const ChatDetailScreen({
    super.key, 
    required this.chatId,
    required this.clientName,
    required this.partnerId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage(String text, {String type = 'text', Map<String, dynamic>? extraFields}) async {
    if (text.trim().isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _messageController.clear();

    final Map<String, dynamic> messageData = {
      'text': text.trim(),
      'senderId': user.uid,
      'senderName': user.displayName ?? 'User',
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
    };

    if (extraFields != null) {
      messageData.addAll(extraFields);
    }

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    await FirebaseFirestore.instance.collection('conversations').doc(widget.chatId).update({
      'lastMessage': type == 'offer' ? 'Sent a custom offer' : text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount.${widget.partnerId}': FieldValue.increment(1),
    });
  }

  void _showCustomOfferSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return _CustomOfferSheet(onSend: (price, days, desc) {
          _sendMessage('Sent a custom offer', type: 'offer', extraFields: {
            'offerPrice': price,
            'offerDays': days,
            'offerDescription': desc,
            'offerStatus': 'pending',
          });
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(widget.clientName[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Active Now', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black87), onPressed: () {}),
        ],
      ),
      body: user == null ? const Center(child: Text('Not logged in')) : Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msg = docs[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == user.uid;
                      final type = msg['type'] ?? 'text';
                      
                      if (type == 'offer') {
                        return _buildCustomOfferBubble(msg, isMe);
                      }
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),
          ),
          
          // Message Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Theme.of(context).primaryColor),
                    onPressed: _showCustomOfferSheet,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? '';
    final timestamp = msg['createdAt'] as Timestamp?;
    final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Text(widget.clientName[0].toUpperCase(), style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                  bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: [
                  if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))
                ]
              ),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[500], fontSize: 10),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.done_all, size: 12, color: Colors.white.withOpacity(0.7)),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOfferBubble(Map<String, dynamic> msg, bool isMe) {
    final price = msg['offerPrice']?.toString() ?? '0';
    final desc = msg['offerDescription'] ?? '';
    final timestamp = msg['createdAt'] as Timestamp?;
    final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, color: Theme.of(context).primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Custom Offer', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$$price', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(desc, style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('View Offer', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomOfferSheet extends StatefulWidget {
  final Function(String price, String days, String description) onSend;

  const _CustomOfferSheet({required this.onSend});

  @override
  State<_CustomOfferSheet> createState() => _CustomOfferSheetState();
}

class _CustomOfferSheetState extends State<_CustomOfferSheet> {
  final _priceCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Create Custom Offer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInput('Price (\$)', _priceCtrl, TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput('Delivery (Days)', _daysCtrl, TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput('Description of work', _descCtrl, TextInputType.text, maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onSend(_priceCtrl.text, _daysCtrl.text, _descCtrl.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Send Offer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, TextInputType type, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
