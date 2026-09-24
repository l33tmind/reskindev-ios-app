import 'dart:io';

void main() {
  // Fix 1: admin_support_tickets_view.dart
  var adminFile = File('lib/screens/admin_support_tickets_view.dart');
  var adminContent = adminFile.readAsStringSync();
  adminContent = adminContent.replaceAll("data['gigTitle']", "data[\"gigTitle\"]");
  adminFile.writeAsStringSync(adminContent);

  // Fix 2: seller_profile_screen.dart
  var profileFile = File('lib/screens/seller_profile_screen.dart');
  var profileContent = profileFile.readAsStringSync();
  profileContent = profileContent.replaceAll("bool get shouldRebuild", "bool shouldRebuild");
  profileFile.writeAsStringSync(profileContent);

  // Fix 3: gig_card.dart (Dollar sign issue)
  var gigCardFile = File('lib/widgets/gig_card.dart');
  var gigCardContent = gigCardFile.readAsStringSync();
  // It literally says: '\$\${startingPrice.toStringAsFixed(0)}',
  // Because in bash `\$\$` becomes `$$`.
  // So the Dart file has `$$` which means `$` and `$` (invalid interpolation).
  gigCardContent = gigCardContent.replaceAll(
    String.fromCharCode(36) + String.fromCharCode(36) + '{startingPrice', 
    '\\\$' + String.fromCharCode(36) + '{startingPrice'
  );
  gigCardFile.writeAsStringSync(gigCardContent);

  print('Fixed all errors 2');
}
