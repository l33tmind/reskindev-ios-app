//
//  AppModel.swift
//  Reskindevpro
//
//  Created by Robius Sani on 25/9/26.
//

import SwiftUI

/// Maintains app-wide state: immersive space + which panels/tabs are showing
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    enum ProfileTab: String, CaseIterable, Identifiable {
        case profile = "Profile"
        case saved = "Saved Services"
        case settings = "Settings"
        case myGigs = "My Gigs"
        case earnings = "Earnings"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .profile: "person"
            case .saved: "heart"
            case .settings: "gearshape"
            case .myGigs: "square.stack.3d.up"
            case .earnings: "dollarsign.circle"
            }
        }
        var sellerOnly: Bool { self == .myGigs || self == .earnings }
    }

    /// Side panels start docked in the main window next to the carousel. People can drag them anywhere
    /// inside it (incl. closer/further), pop them out into their own window, or hide them.
    var sidebarDocked = true
    var ordersDocked = true
    var sidebarOffset = PanelOffset()
    var ordersOffset = PanelOffset()
    /// Whether the popped-out window of each panel is open
    var showSidebar = false
    var showOrders = false

    var sidebarVisible: Bool { sidebarDocked || showSidebar }
    var ordersVisible: Bool { ordersDocked || showOrders }

    struct PanelOffset: Equatable {
        var x: Double = 0
        var y: Double = 0
        /// Toward the viewer (+) — kept ≥ 0 so the panel never slips behind the window plane and gets clipped
        var z: Double = 0
        var isMoved: Bool { self != PanelOffset() }
    }
    /// Tab shown in the Profile window
    var profileTab: ProfileTab = .profile
    /// Bumped by the dock's Search button to focus the search field
    var searchFocusRequest = 0
    /// Order opened from the orders panel or a chat card
    var selectedOrderID: String?
}

/// Fixed window values so each of these windows opens once and is reused
enum WindowID {
    static let main = "Main"
    static let sidebar = "Sidebar"
    static let orders = "Orders"
    static let gigDetail = "GigDetail"
    static let inbox = "Inbox"
    static let profile = "Profile"
    static let sellerProfile = "SellerProfile"
    static let page = "Page"
    static let deliveryBox = "DeliveryBox"
    static let single = "main"
}
