import 'dart:io';

void main() {
  final file = File('lib/models/order_model.dart');
  var content = file.readAsStringSync();

  // Add statusColor for pending_payment
  content = content.replaceAll(
    "case 'requirements':  return const Color(0xFFF59E0B); // Amber",
    "case 'pending_payment': return const Color(0xFFEF4444); // Red\n      case 'requirements':  return const Color(0xFFF59E0B); // Amber"
  );

  // Add statusLabel for pending_payment
  content = content.replaceAll(
    "case 'requirements':  return 'Requirements';",
    "case 'pending_payment': return 'Waiting for Payment';\n      case 'requirements':  return 'Requirements';"
  );

  // Add statusIcon for pending_payment
  content = content.replaceAll(
    "case 'requirements':  return Icons.assignment_outlined;",
    "case 'pending_payment': return Icons.payment_outlined;\n      case 'requirements':  return Icons.assignment_outlined;"
  );

  file.writeAsStringSync(content);
  print('Updated order_model.dart');
}
