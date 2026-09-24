with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

import re

old_sort = """        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = dataA['createdAt'] as Timestamp?;
          final timeB = dataB['createdAt'] as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); // Descending
        });"""

new_sort = """        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          
          DateTime? parseD(dynamic val) {
            if (val == null) return null;
            if (val is Timestamp) return val.toDate();
            if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
            if (val is String) return DateTime.tryParse(val);
            return null;
          }
          
          final timeA = parseD(dataA['createdAt']);
          final timeB = parseD(dataB['createdAt']);
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); // Descending
        });"""
c = c.replace(old_sort, new_sort)
with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)
