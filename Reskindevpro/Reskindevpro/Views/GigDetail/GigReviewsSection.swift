import SwiftUI

/// Public reviews under the gig description (website components/GigReviews.js)
struct GigReviewsSection: View {
    let reviews: [GigReview]

    private var average: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reviews").font(.title2.weight(.bold))
                Spacer()
                Image(systemName: "star.fill").foregroundStyle(Color.starYellow)
                Text(String(format: "%.1f", average)).font(.headline)
                Text("(\(reviews.count))").foregroundStyle(.secondary)
            }

            ForEach(reviews) { review in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        UserAvatar(name: review.userName, photoUrl: review.userImage, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.userName).font(.headline)
                            if let date = review.createdAt {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < review.rating ? "star.fill" : "star")
                                    .foregroundStyle(Color.starYellow)
                            }
                        }
                        .font(.caption)
                    }
                    if !review.comment.isEmpty {
                        Text(review.comment).foregroundStyle(.secondary)
                    }
                    if let reply = review.sellerReply {
                        Label {
                            Text(reply).italic()
                        } icon: {
                            Image(systemName: "arrowshape.turn.up.left.fill").foregroundStyle(Color.brandGreen)
                        }
                        .font(.subheadline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brandGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.small))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
