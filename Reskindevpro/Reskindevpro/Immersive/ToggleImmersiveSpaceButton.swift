//
//  ToggleImmersiveSpaceButton.swift
//  Reskindevpro
//
//  Created by Robius Sani on 25/9/26.
//

import SwiftUI

struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button {
            Task { @MainActor in
                switch appModel.immersiveSpaceState {
                    case .open:
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()
                        // Don't set immersiveSpaceState to .closed because there
                        // are multiple paths to ImmersiveView.onDisappear().
                        // Only set .closed in ImmersiveView.onDisappear().

                    case .closed:
                        appModel.immersiveSpaceState = .inTransition
                        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                // Don't set immersiveSpaceState to .open because there
                                // may be multiple paths to ImmersiveView.onAppear().
                                // Only set .open in ImmersiveView.onAppear().
                                break

                            case .userCancelled, .error:
                                // On error, we need to mark the immersive space
                                // as closed because it failed to open.
                                fallthrough
                            @unknown default:
                                // On unknown response, assume space did not open.
                                appModel.immersiveSpaceState = .closed
                        }

                    case .inTransition:
                        // This case should not ever happen because button is disabled for this case.
                        break
                }
            }
        } label: {
            // Dock-style item: the Showroom is the app's immersive space
            VStack(spacing: 6) {
                Image(systemName: appModel.immersiveSpaceState == .open ? "cube.fill" : "cube.transparent")
                    .font(.title2)
                    .symbolEffect(.bounce, value: appModel.immersiveSpaceState == .open)
                Text(appModel.immersiveSpaceState == .open ? "Exit 3D" : "Showroom")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(appModel.immersiveSpaceState == .open ? Color.brandGreen : Color.secondary)
            .frame(minWidth: 72, minHeight: 72)
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.small))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .accessibilityLabel(appModel.immersiveSpaceState == .open ? "Exit 3D Showroom" : "Open 3D Showroom")
    }
}
