import SwiftUI

struct OrderTimeline: View {
    /// Index of the current step (0...4)
    let currentStep: Int
    private let steps = ["Payment", "Requirements", "Processing", "Delivered", "Completed"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                VStack(spacing: 8) {
                    ZStack {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(i == 0 ? Color.clear : (i <= currentStep ? Color.brandGreen : Color.white.opacity(0.2)))
                                .frame(height: 3)
                            Rectangle()
                                .fill(i == steps.count - 1 ? Color.clear : (i < currentStep ? Color.brandGreen : Color.white.opacity(0.2)))
                                .frame(height: 3)
                        }
                        if i == steps.count - 1 && currentStep == i {
                            // Finished order: check mark on the last node
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.brandGreen)
                                .shadow(color: Color.brandGreen.opacity(0.8), radius: 8)
                        } else {
                            StepNode(isActive: i <= currentStep)
                        }
                    }
                    .frame(height: 24)

                    Text(steps[i])
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(i == currentStep ? Color.brandGreen : (i < currentStep ? Color.white : Color.secondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Order status: \(steps[min(currentStep, steps.count - 1)].lowercased())")
    }
}

struct StepNode: View {
    var isActive: Bool
    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(Color.brandGreen.opacity(0.35))
                    .frame(width: 24, height: 24)
                Circle()
                    .stroke(Color.brandGreen, lineWidth: 2)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
        }
        .shadow(color: isActive ? Color.brandGreen.opacity(0.8) : .clear, radius: 8)
    }
}
