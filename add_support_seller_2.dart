import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();

  final oldRow = '''
          Row(
            children: [
              Expanded(
                child: _buildSellerAction(context, order),
              ),
            ],
          )
        ],
      ),
    );
  }
''';
  final newRow = '''
          Row(
            children: [
              Expanded(
                child: _buildSellerAction(context, order),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _showSupportModal(context, order, order.authorId),
              style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: const Text('Report Issue', style: TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
''';
  if (content.contains(oldRow)) {
    content = content.replaceFirst(oldRow, newRow);
    print("Added Support to seller dashboard");
  } else {
    print("Could not find oldRow");
  }

  file.writeAsStringSync(content);
}
