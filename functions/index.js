const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Trigger: Whenever a review is created, updated, or deleted.
 * Action: Recalculates the average rating and reviewCount for the parent service/gig.
 */
exports.updateGigRating = onDocumentWritten("services/{gigId}/reviews/{reviewId}", async (event) => {
    const gigId = event.params.gigId;
    const db = admin.firestore();
    
    // Fetch all reviews for this specific gig
    const reviewsSnapshot = await db.collection(`services/${gigId}/reviews`).get();
    
    let totalRating = 0;
    let reviewCount = 0;

    reviewsSnapshot.forEach((doc) => {
        const data = doc.data();
        // Assume rating is stored as a number, if string try to parse it
        const rating = Number(data.rating);
        if (!isNaN(rating)) {
            totalRating += rating;
            reviewCount++;
        }
    });

    const averageRating = reviewCount > 0 ? (totalRating / reviewCount) : 0;
    
    // Update the parent gig document with the new aggregated data
    await db.collection("services").doc(gigId).update({
        rating: Number(averageRating.toFixed(1)),
        averageRating: Number(averageRating.toFixed(1)),
        reviewCount: reviewCount
    });

    console.log(`Successfully updated gig ${gigId}: new rating ${averageRating.toFixed(1)} based on ${reviewCount} reviews.`);
    return null;
});