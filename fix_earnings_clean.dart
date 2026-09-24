import 'dart:io';

void main() {
  final file = File('lib/screens/earnings_screen.dart');
  var content = file.readAsStringSync();
  
  final oldBody = '''
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: auth.user!.uid).where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, orderSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('withdrawals').where('freelancerId', isEqualTo: auth.user!.uid).snapshots(),
            builder: (context, withdrawSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          double pendingClearance = 0;
          double availableBalance = 0;
          double totalEarned = 0;

          final now = DateTime.now();

          for (var doc in snapshot.data!.docs) {
            final order = OrderModel.fromFirestore(doc);
            final double price = order.price;
            totalEarned += price;

            if (order.completedAt != null) {
              final daysSinceCompletion = now.difference(order.completedAt!).inDays;
              if (daysSinceCompletion < 15) {
                pendingClearance += price;
              } else {
                availableBalance += price;
              }
            } else {
                  // Fallback if completedAt is missing but status is completed
                  pendingClearance += price;
                }
              }
              
              if (withdrawSnap.hasData) {
                for (var doc in withdrawSnap.data!.docs) {
                  final amount = (doc.data() as Map)['amount'] as num?;
                  if (amount != null) totalWithdrawn += amount.toDouble();
                }
              }
              
              availableBalance -= totalWithdrawn;
              if (availableBalance < 0) availableBalance = 0;

              return SingleChildScrollView(
''';

  final newBody = '''
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: auth.user!.uid).where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, orderSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('withdrawals').where('freelancerId', isEqualTo: auth.user!.uid).snapshots(),
            builder: (context, withdrawSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting || withdrawSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              if (orderSnap.hasError) {
                return Center(child: Text('Error: \${orderSnap.error}'));
              }

              double pendingClearance = 0;
              double availableBalance = 0;
              double totalEarned = 0;
              double totalWithdrawn = 0;

              final now = DateTime.now();

              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final order = OrderModel.fromFirestore(doc);
                  final double price = order.price;
                  totalEarned += price;

                  if (order.completedAt != null) {
                    final daysSinceCompletion = now.difference(order.completedAt!).inDays;
                    if (daysSinceCompletion < 15) {
                      pendingClearance += price;
                    } else {
                      availableBalance += price;
                    }
                  } else {
                    // Fallback if completedAt is missing but status is completed
                    pendingClearance += price;
                  }
                }
              }
              
              if (withdrawSnap.hasData) {
                for (var doc in withdrawSnap.data!.docs) {
                  final amount = (doc.data() as Map)['amount'] as num?;
                  if (amount != null) totalWithdrawn += amount.toDouble();
                }
              }
              
              availableBalance -= totalWithdrawn;
              if (availableBalance < 0) availableBalance = 0;

              return SingleChildScrollView(
''';
  if (content.contains(oldBody)) {
    content = content.replaceFirst(oldBody, newBody);
  } else {
    print("Could not find oldBody!");
  }
  file.writeAsStringSync(content);
}
