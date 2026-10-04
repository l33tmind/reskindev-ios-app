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

    /// The home (main) window is on screen
    var isMainOpen = false

    /// Open gig / seller-profile windows, so closing the main window can close them too
    var openGigIDs = Set<String>()
    /// "View in Your Room" volumes and Delivery Theater screens that are open
    var openModelURLs = Set<String>()
    var openTheaters = Set<TheaterItem>()
    var isEarnings3DOpen = false
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
    /// Ticks to throw confetti (order placed, delivered, completed, reviews in)
    var celebration = 0

    @MainActor func celebrate() {
        celebration += 1
        SoundFX.success.play()
    }
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
    static let model3D = "Model3D"
    static let theater = "Theater"
    static let earnings3D = "Earnings3D"
    static let single = "main"
}
