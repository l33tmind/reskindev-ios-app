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

    /// Sidebar and orders panels are their own windows so people can pull them closer or close them.
    /// These mirror whether each window is currently open.
    var showOrders = false
    var showSidebar = false
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
