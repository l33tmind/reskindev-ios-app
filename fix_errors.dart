import 'dart:io';

void main() {
  // Fix 1: admin_support_tickets_view.dart
  var adminFile = File('lib/screens/admin_support_tickets_view.dart');
  var adminContent = adminFile.readAsStringSync();
  adminContent = adminContent.replaceAll("Text('Order: \${data['gigTitle']}'", "Text('Order: \${data[\"gigTitle\"]}'");
  adminFile.writeAsStringSync(adminContent);

  // Fix 2: seller_profile_screen.dart
  var profileFile = File('lib/screens/seller_profile_screen.dart');
  var profileContent = profileFile.readAsStringSync();
  profileContent = profileContent.replaceAll("bool get shouldRebuild(_SliverAppBarDelegate oldDelegate)", "bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate)");
  profileFile.writeAsStringSync(profileContent);

  // Fix 3: gig_card.dart (Dollar sign issue)
  var gigCardFile = File('lib/widgets/gig_card.dart');
  var gigCardContent = gigCardFile.readAsStringSync();
  // Change `\$\$` to `\$\${`
  gigCardContent = gigCardContent.replaceAll("Text(\n                          '\$\${startingPrice.toStringAsFixed(0)}',", "Text(\n                          '\\$\${startingPrice.toStringAsFixed(0)}',");
  gigCardFile.writeAsStringSync(gigCardContent);

  print('Fixed all errors');
}
