import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_func = """  String? _extractVideoId(String url) {
    if (url.contains('v=')) {
      final id = url.split('v=')[1];
      final amp = id.indexOf('&');
      return amp != -1 ? id.substring(0, amp) : id;
    } else if (url.contains('youtu.be/')) {
      final id = url.split('youtu.be/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('embed/')) {
      final id = url.split('embed/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    }
    return null;
  }"""

new_func = """  String? _extractVideoId(String url) {
    if (url.contains('v=')) {
      final id = url.split('v=')[1];
      final amp = id.indexOf('&');
      return amp != -1 ? id.substring(0, amp) : id;
    } else if (url.contains('youtu.be/')) {
      final id = url.split('youtu.be/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('embed/')) {
      final id = url.split('embed/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('/vi/')) {
      final id = url.split('/vi/')[1];
      final slash = id.indexOf('/');
      return slash != -1 ? id.substring(0, slash) : id;
    }
    return null;
  }"""

if old_func in content:
    content = content.replace(old_func, new_func)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed _extractVideoId")
else:
    print("Could not find _extractVideoId")
