with open('lib/widgets/earnings_chart.dart', 'r') as f:
    c = f.read()

import re

old_date_parse = "final completedAt = (data['completedAt'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp).toDate();"

new_date_parse = """        DateTime? parseD(dynamic val) {
          if (val == null) return null;
          if (val is Timestamp) return val.toDate();
          if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
          if (val is String) return DateTime.tryParse(val);
          return null;
        }
        final completedAt = parseD(data['completedAt']) ?? parseD(data['createdAt']) ?? DateTime.now();"""

c = c.replace(old_date_parse, new_date_parse)
with open('lib/widgets/earnings_chart.dart', 'w') as f:
    f.write(c)
