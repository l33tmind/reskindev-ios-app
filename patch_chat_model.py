import re

with open('lib/models/chat_models.dart', 'r') as f:
    c = f.read()

c = c.replace(
    "final String? orderId; // Null for inbox, holds ID for order workstream",
    "final String? orderId; // Null for inbox, holds ID for order workstream\n  final List<String> archivedBy;"
)

c = c.replace(
    "this.orderId,\n  });",
    "this.orderId,\n    this.archivedBy = const [],\n  });"
)

c = c.replace(
    "orderId: data['orderId'],\n    );",
    "orderId: data['orderId'],\n      archivedBy: List<String>.from(data['archivedBy'] ?? []),\n    );"
)

c = c.replace(
    "'clientId': clientId,\n    };",
    "'clientId': clientId,\n      'archivedBy': archivedBy,\n    };"
)

with open('lib/models/chat_models.dart', 'w') as f:
    f.write(c)
