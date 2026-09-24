import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains("import 'package:firebase_auth/firebase_auth.dart';")) {
    content = content.replaceFirst("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';");
  }

  // Find all dropdowns and conditionally add 'active'
  final oldActiveItem = '''
                              DropdownMenuItem(
                                value: 'active',
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text('ACTIVE', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                                  ],
                                ),
                              ),
''';

  final newActiveItem = '''
                              if (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com')
                              DropdownMenuItem(
                                value: 'active',
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text('ACTIVE (Admin Only)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                                  ],
                                ),
                              ),
''';

  content = content.replaceAll(oldActiveItem, newActiveItem);
  
  final oldOnChanged = "onChanged: (val) => setState(() => _status = val ?? 'active'),";
  final newOnChanged = "onChanged: (val) => setState(() => _status = val ?? 'pending'),";
  content = content.replaceAll(oldOnChanged, newOnChanged);

  file.writeAsStringSync(content);
}
