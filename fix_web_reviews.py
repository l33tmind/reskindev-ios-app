import re

with open('next-frontend/src/app/profile/orders/page.js', 'r') as f:
    content = f.read()

# We need to find the addDoc block
old_block = """      await addDoc(collection(db, "services", reviewOrder.gigId, "reviews"), {
        orderId: reviewOrder.id,
        userId: user.uid,
        userName: user.displayName || "Client",
        userImage: user.photoURL || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.displayName || "Client")}`,
        rating: Number(rating),
        comment,
        createdAt: serverTimestamp()
      });

      // Mark order as completed and reviewed
      await updateDoc(doc(db, "orders", reviewOrder.id), {
        status: "completed",
        hasReview: true,
        completedAt: serverTimestamp()
      });"""

new_block = """      await addDoc(collection(db, "services", reviewOrder.gigId, "reviews"), {
        orderId: reviewOrder.id,
        userId: user.uid,
        userName: user.displayName || "Client",
        userImage: user.photoURL || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.displayName || "Client")}`,
        rating: Number(rating),
        comment,
        createdAt: serverTimestamp()
      });
      
      // Update the gig's average rating
      import { getDoc, doc } from "firebase/firestore";
      const gigRef = doc(db, "services", reviewOrder.gigId);
      const gigDoc = await getDoc(gigRef);
      if (gigDoc.exists()) {
        const gigData = gigDoc.data();
        const currentCount = gigData.reviewCount || 0;
        const currentAvg = gigData.averageRating || gigData.rating || 0;
        const newCount = currentCount + 1;
        const newAvg = ((currentAvg * currentCount) + Number(rating)) / newCount;
        await updateDoc(gigRef, {
          reviewCount: newCount,
          averageRating: newAvg,
          rating: newAvg
        });
      }

      // Mark order as completed and reviewed, and save overallRating for Flutter app
      await updateDoc(doc(db, "orders", reviewOrder.id), {
        status: "completed",
        hasReview: true,
        completedAt: serverTimestamp(),
        overallRating: Number(rating),
        publicReview: comment
      });"""

if old_block in content:
    content = content.replace(old_block, new_block)
    # Add getDoc to imports if not there
    if 'getDoc' not in content:
        content = content.replace('import { collection, query, where, getDocs, updateDoc, doc, addDoc, serverTimestamp, orderBy } from "firebase/firestore";', 'import { collection, query, where, getDocs, updateDoc, doc, addDoc, serverTimestamp, orderBy, getDoc } from "firebase/firestore";')
    with open('next-frontend/src/app/profile/orders/page.js', 'w') as f:
        f.write(content)
    print("Fixed web review logic")
else:
    print("Could not find web review logic")
