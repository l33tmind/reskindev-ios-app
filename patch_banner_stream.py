import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    c = f.read()

old_banner = """          if (_currentOrderId != null && _currentOrderId!.isNotEmpty)
            GestureDetector(
              onTap: _showWorkspaceDetails,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Order Workspace',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                      child: Text('View', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),"""

new_banner = """          if (_chatId.isNotEmpty && _chatId != 'new')
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('conversations').doc(_chatId).snapshots(),
              builder: (context, snapshot) {
                final chatData = snapshot.data?.data() as Map<String, dynamic>?;
                final orderId = chatData?['orderId'] as String?;
                if (orderId == null || orderId.isEmpty) return const SizedBox.shrink();
                
                return GestureDetector(
                  onTap: () {
                    _currentOrderId = orderId;
                    _showWorkspaceDetails();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Order Workspace',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                          child: Text('View', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),"""

c = c.replace(old_banner, new_banner)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c)
