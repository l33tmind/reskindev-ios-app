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

    enum MainTab: Hashable { case explore, messages, profile }
    /// Tab bar of the main window
    var selectedTab: MainTab = .explore
    /// Whether the My Orders / Menu side windows are open
    var showOrders = false
    var showSidebar = false
    /// Home look: on Explore the side panels hug the main window like a cockpit
    var isHome: Bool { selectedTab == .explore }
    /// Sheets currently shown; while any is up, Explore flattens its floating cards so nothing covers the sheet
    var openSheets = 0

    /// Open gig / seller-profile windows, so closing the main window can close them too
    var openGigIDs = Set<String>()
    var openSellerKeys = Set<String>()
    var isDeliveryBoxOpen = false
    var isPagesOpen = false

    /// Side panels attached to the Explore window (hidden while that panel is popped out into its own window)
    var sidebarPanelShown = true
    var ordersPanelShown = true

    /// Section shown in the Profile tab
    var profileTab: ProfileTab = .profile
    /// Bumped by the dock's Search button to focus the search field
    var searchFocusRequest = 0
    /// Order opened from the orders panel or a chat card
    var selectedOrderID: String?
}

/// Fixed window values so each of these windows opens once and is reused
enum WindowID {
    static let main = "Main"
    static let orders = "Orders"
    static let sidebar = "Sidebar"
    static let gigDetail = "GigDetail"
    static let sellerProfile = "SellerProfile"
    static let page = "Page"
    static let deliveryBox = "DeliveryBox"
    static let single = "main"
}
