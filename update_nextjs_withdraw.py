import re

with open('next-frontend/src/app/profile/earnings/page.js', 'r') as f:
    c = f.read()

# Add charge and netAmount to Firestore payload
old_add_doc = """      await addDoc(collection(db, "withdrawals"), {
        freelancerId: user.uid,
        freelancerName: user.displayName,
        email: payoneerEmail,
        amount: amount,
        status: "pending",
        createdAt: serverTimestamp()
      });"""

new_add_doc = """      await addDoc(collection(db, "withdrawals"), {
        freelancerId: user.uid,
        freelancerName: user.displayName,
        email: payoneerEmail,
        amount: amount,
        charge: 3,
        netAmount: amount - 3,
        status: "pending",
        createdAt: serverTimestamp()
      });"""

c = c.replace(old_add_doc, new_add_doc)

with open('next-frontend/src/app/profile/earnings/page.js', 'w') as f:
    f.write(c)

