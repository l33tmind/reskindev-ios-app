import 'dart:io';

void main() {
  final file = File('lib/models/order_model.dart');
  var content = file.readAsStringSync();
  
  // Add new fields to the class
  if (!content.contains('final DateTime? completedAt;')) {
    content = content.replaceFirst(
      '  final DateTime createdAt;\n\n  OrderModel({',
      '  final DateTime createdAt;\n  final DateTime? completedAt;\n  final String deliveryNote;\n\n  OrderModel({'
    );
    
    // Add to constructor
    content = content.replaceFirst(
      '    this.status = \'requirements\',\n    DateTime? createdAt,',
      '    this.status = \'requirements\',\n    DateTime? createdAt,\n    this.completedAt,\n    this.deliveryNote = \'\','
    );
    
    // Add to fromFirestore
    content = content.replaceFirst(
      '      createdAt: (d[\'createdAt\'] as Timestamp?)?.toDate() ?? DateTime.now(),\n    );',
      '      createdAt: (d[\'createdAt\'] as Timestamp?)?.toDate() ?? DateTime.now(),\n      completedAt: (d[\'completedAt\'] as Timestamp?)?.toDate(),\n      deliveryNote: d[\'deliveryNote\'] ?? \'\',\n    );'
    );
    
    // Add to toMap
    content = content.replaceFirst(
      '      \'createdAt\': FieldValue.serverTimestamp(),\n    };',
      '      \'createdAt\': FieldValue.serverTimestamp(),\n      \'deliveryNote\': deliveryNote,\n      if (completedAt != null) \'completedAt\': Timestamp.fromDate(completedAt!),\n    };'
    );
    
    file.writeAsStringSync(content);
    print('Updated OrderModel');
  } else {
    print('OrderModel already updated');
  }
}
