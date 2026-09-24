import 'dart:io';

void main() {
  final file = File('lib/screens/home_screen.dart');
  var content = file.readAsStringSync();

  final startIdx = content.indexOf('// ─────────────────────────────────────────────────────────────────────────────\n// Gig Card (Android card design)');
  if (startIdx == -1) {
    print("Could not find start of _GigCard");
    return;
  }

  // The rest of the file is just _GigCard.
  final gigCardCode = content.substring(startIdx);
  
  // Make it public
  final publicGigCardCode = gigCardCode
    .replaceAll('class _GigCard', 'class GigCard')
    .replaceAll('State<_GigCard>', 'State<GigCard>')
    .replaceAll('_GigCardState', 'GigCardState')
    .replaceAll('final VoidCallback onTap;', 'final VoidCallback? onTap;')
    .replaceAll('required this.onTap', 'this.onTap')
    .replaceAll('onTap: widget.onTap,', 'onTap: widget.onTap ?? () {},');

  // Create the new file
  final newFileStr = '''
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/gig_model.dart';
import '../theme.dart';
import 'package:go_router/go_router.dart';

''';
  
  File('lib/widgets/gig_card.dart').writeAsStringSync(newFileStr + publicGigCardCode);
  print('Fixed gig_card.dart');
}
