with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_block = """    } else if (url.contains('shorts/')) {
      final id = url.split('shorts/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    }
    } else if (url.contains('/vi/')) {
      final id = url.split('/vi/')[1];
      final slash = id.indexOf('/');
      return slash != -1 ? id.substring(0, slash) : id;
    return null;
  }"""

new_block = """    } else if (url.contains('shorts/')) {
      final id = url.split('shorts/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('/vi/')) {
      final id = url.split('/vi/')[1];
      final slash = id.indexOf('/');
      return slash != -1 ? id.substring(0, slash) : id;
    }
    return null;
  }"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed syntax error")
else:
    print("Could not find old_block")
