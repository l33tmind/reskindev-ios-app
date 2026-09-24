import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    c = f.read()

banner_ui = """      body: Column(
        children: [
          if (_currentOrderId != null && _currentOrderId!.isNotEmpty)
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
            ),
          Expanded("""

c = c.replace("      body: Column(\n        children: [\n          Expanded(", banner_ui)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c)
