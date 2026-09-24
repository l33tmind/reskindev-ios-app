import 'dart:io';

void main() {
  final file = File('lib/models/order_model.dart');
  var content = file.readAsStringSync();
  
  // 1. Add fields to class
  content = content.replaceFirst(
    'final DateTime createdAt;\n  final DateTime? completedAt;\n  final String deliveryNote;',
    'final DateTime createdAt;\n  final DateTime? completedAt;\n  final DateTime? startedAt;\n  final String deliveryNote;\n  final String deliveryLink;\n  final String revisionNote;'
  );

  // 2. Add fields to constructor
  content = content.replaceFirst(
    'this.completedAt,\n    this.deliveryNote = \'\',',
    'this.completedAt,\n    this.startedAt,\n    this.deliveryNote = \'\',\n    this.deliveryLink = \'\',\n    this.revisionNote = \'\','
  );

  // 3. Add fields to fromFirestore
  content = content.replaceFirst(
    'completedAt: (d[\'completedAt\'] as Timestamp?)?.toDate(),\n      deliveryNote: d[\'deliveryNote\'] ?? \'\',',
    'completedAt: (d[\'completedAt\'] as Timestamp?)?.toDate(),\n      startedAt: (d[\'startedAt\'] as Timestamp?)?.toDate(),\n      deliveryNote: d[\'deliveryNote\'] ?? \'\',\n      deliveryLink: d[\'deliveryLink\'] ?? \'\',\n      revisionNote: d[\'revisionNote\'] ?? \'\','
  );

  // 4. Add fields to toMap
  content = content.replaceFirst(
    '\'createdAt\': FieldValue.serverTimestamp(),\n      \'deliveryNote\': deliveryNote,',
    '\'createdAt\': FieldValue.serverTimestamp(),\n      \'deliveryNote\': deliveryNote,\n      \'deliveryLink\': deliveryLink,\n      \'revisionNote\': revisionNote,'
  );
  content = content.replaceFirst(
    'if (completedAt != null) \'completedAt\': Timestamp.fromDate(completedAt!),',
    'if (completedAt != null) \'completedAt\': Timestamp.fromDate(completedAt!),\n      if (startedAt != null) \'startedAt\': Timestamp.fromDate(startedAt!),'
  );

  file.writeAsStringSync(content);
  print('Updated order_model.dart');
}
