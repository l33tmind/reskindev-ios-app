import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  final methodStr = '  Widget _buildReviewsSection(BuildContext context, GigModel gig) {';
  final methodStart = content.indexOf(methodStr);
  
  if (methodStart == -1) {
    print('Could not find _buildReviewsSection');
    return;
  }
  
  // Find where this method ends
  // It's the last thing in the file if it was injected at the end, but wait...
  // Let's just find `}\n}` or similar.
  // Actually, I can just substring from methodStart to the end, then delete the extra `}` at the end.
  // No, let's use a bracket counter.
  int brackets = 0;
  int methodEnd = -1;
  for (int i = methodStart + methodStr.length; i < content.length; i++) {
    if (content[i] == '{') brackets++;
    if (content[i] == '}') {
      if (brackets == 0) {
        methodEnd = i;
        break;
      }
      brackets--;
    }
  }
  
  if (methodEnd == -1) {
    print('Could not find end of method');
    return;
  }
  
  final methodBody = content.substring(methodStart, methodEnd + 1);
  content = content.substring(0, methodStart) + content.substring(methodEnd + 1);
  
  // Now inject it before the end of _GigDetailScreenState
  // We know _GigDetailScreenState ends around line 952.
  // Let's find `class _YoutubeVideoPlayer extends StatefulWidget {`
  final nextClassStr = 'class _YoutubeVideoPlayer extends StatefulWidget {';
  final nextClassIdx = content.indexOf(nextClassStr);
  
  if (nextClassIdx != -1) {
    // The brace before this is the end of _GigDetailScreenState
    final stateEndIdx = content.lastIndexOf('}', nextClassIdx);
    if (stateEndIdx != -1) {
       content = content.substring(0, stateEndIdx) + '\n' + methodBody + '\n' + content.substring(stateEndIdx);
       file.writeAsStringSync(content);
       print('Moved _buildReviewsSection');
    } else {
       print('Could not find end of _GigDetailScreenState');
    }
  } else {
    print('Could not find next class');
  }
}
