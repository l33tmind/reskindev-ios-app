import re

path = "./lib/screens/seller_dashboard_screen.dart"
with open(path, "r") as f:
    content = f.read()

# Fix the try-catch block for withdrawal
new_logic = """
                        setState(() => submitting = true);
                        
                        try {
                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'freelancerId': uid,
                            'freelancerName': displayName,
                            'email': payoneerEmail,
                            'amount': amount,
                            'charge': 3.0,
                            'netAmount': amount - 3.0,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          }).timeout(const Duration(seconds: 10));
                          
                          // Use set with merge instead of update, in case user doc is missing
                          await FirebaseFirestore.instance.collection('users').doc(uid).set({
                            'payoneerEmail': payoneerEmail
                          }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted successfully!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting request. Please try again.'), backgroundColor: Colors.red));
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => submitting = false);
                          }
                        }
"""

content = re.sub(
    r'setState\(\(\) => submitting = true\);\s*try \{[\s\S]*?setState\(\(\) => submitting = false\);\s*\}\s*\}',
    new_logic.strip(),
    content
)

# Also fix the amount validation logic which was checking < 20 but saying $50
content = content.replace('if (amount < 20) {', 'if (amount < 50) {')

with open(path, "w") as f:
    f.write(content)
