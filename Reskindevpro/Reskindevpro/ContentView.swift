import SwiftUI
import RealityKit

// MARK: - Models
struct GigModel: Identifiable {
    let id: String
    let title: String
    let price: Double
    let imageUrl: String
    let sellerName: String
    let rating: String
}

// MARK: - Main Application View
struct ContentView: View {
    @State private var gigs: [GigModel] = [
        GigModel(id: "1", title: "I will develop iOS app for you", price: 150, imageUrl: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=600&q=80", sellerName: "Robius Sani", rating: "4.9 (11 Reviews)"),
        GigModel(id: "2", title: "Short video editing | Cinematic", price: 15, imageUrl: "https://images.unsplash.com/photo-1574717024453-354056bfdc0b?w=600&q=80", sellerName: "Cinematic Cuts", rating: "5.0 (24 Reviews)"),
        GigModel(id: "3", title: "Create custom mobile apps", price: 300, imageUrl: "https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=600&q=80", sellerName: "App Pro", rating: "4.8 (8 Reviews)"),
        GigModel(id: "4", title: "UI/UX Design for VisionOS", price: 500, imageUrl: "https://images.unsplash.com/photo-1561070791-2526d30994b5?w=600&q=80", sellerName: "Spatial Designer", rating: "5.0 (2 Reviews)"),
        GigModel(id: "5", title: "Backend API with Firebase", price: 100, imageUrl: "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=600&q=80", sellerName: "Backend Guru", rating: "4.7 (42 Reviews)")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main 3-Panel Ergonomic Layout
            HStack(alignment: .center, spacing: 40) {
                
                // Panel A: Left Sidebar (Angled Inward)
                LeftSidebarView()
                    .frame(width: 320, height: 750)
                    .rotation3DEffect(.degrees(15), axis: (x: 0, y: 1, z: 0))
                    .offset(z: 50)
                
                // Panel B: Center Stage (Floating Filter & 3D Carousel)
                CenterStageView(gigs: $gigs)
                    .frame(width: 900)
                    .padding(.bottom, 80)
                
                // Panel C: Right Workspace (Angled Inward)
                RightOrdersView()
                    .frame(width: 380, height: 700)
                    .rotation3DEffect(.degrees(-15), axis: (x: 0, y: 1, z: 0))
                    .offset(z: 50)
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
            .padding(.bottom, 140)
            
            // Bottom Dock Ornament
            SpatialBottomDock()
                .padding(.bottom, 40)
                .offset(z: 100)
        }
    }
}

// MARK: - Panel B: Center Stage (Carousel & AI)
struct CenterStageView: View {
    @Binding var gigs: [GigModel]
    
    var body: some View {
        VStack(spacing: 50) {
            
            // Top Floating Filter Bar
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search services...", text: .constant(""))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1), in: Capsule())
                .frame(width: 280)
                
                FilterPill(title: "⊞ All", isActive: true)
                FilterPill(title: "🎬 Video", isActive: false)
                FilterPill(title: "📱 Mobile Apps", isActive: false)
                FilterPill(title: "🌐 Web Dev", isActive: false)
                FilterPill(title: "📢 Marketing", isActive: false)
            }
            .padding(8)
            .glassBackgroundEffect(in: Capsule())
            .offset(z: 40)
            
            // Curved 3D Gig Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -30) { // Negative spacing for overlap effect before 3D rotation
                    ForEach(Array(gigs.enumerated()), id: \.element.id) { index, gig in
                        // Calculate curvature math
                        let centerIndex = 2
                        let offset = index - centerIndex
                        let angle = Double(offset) * -12.0
                        let zOffset = abs(CGFloat(offset)) * -60.0
                        let scale = 1.0 - (abs(CGFloat(offset)) * 0.05)
                        
                        GigCardView(gig: gig)
                            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
                            .offset(z: zOffset)
                            .scaleEffect(scale)
                            .zIndex(Double(-abs(offset)))
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 80)
            }
            
            // AI Assistant Orb & Mini Results
            AIAssistantSection()
                .offset(z: 60)
        }
    }
}

// MARK: - Center Stage Subcomponents

struct GigCardView: View {
    let gig: GigModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: gig.imageUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.1)
            }
            .frame(height: 160)
            .clipped()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(Color.gray.opacity(0.5)).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 12)).foregroundColor(.white))
                    Text(gig.sellerName).font(.subheadline).foregroundColor(.secondary)
                }
                
                Text(gig.title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("★ \(gig.rating)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer(minLength: 10)
                
                HStack {
                    Text("FROM $\(String(format: "%.0f", gig.price))")
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("Order") { }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .controlSize(.regular)
                }
            }
            .padding(20)
        }
        .frame(width: 300, height: 380)
        .background(Color.white.opacity(0.05))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 30))
        .hoverEffect(.lift)
    }
}

struct FilterPill: View {
    let title: String
    let isActive: Bool
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isActive ? Color.black.opacity(0.5) : Color.clear)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .hoverEffect(.highlight)
    }
}

struct AIAssistantSection: View {
    @State private var floatingOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 30) {
            
            // Orb and Main Bubble
            VStack(spacing: 20) {
                Text("Found video editing services for $15!\nHere are the best matches...")
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .glassBackgroundEffect(in: Capsule())
                
                ZStack {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 6/255, green: 75/255, blue: 59/255)]), center: .center, startRadius: 5, endRadius: 60))
                        .frame(width: 90, height: 90)
                    
                    // Simple face
                    HStack(spacing: 15) {
                        Circle().fill(.white).frame(width: 8, height: 8)
                        Circle().fill(.white).frame(width: 8, height: 8)
                    }.offset(y: -5)
                }
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.8), radius: 30)
                .offset(y: floatingOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        floatingOffset = -15
                    }
                }
            }
            
            // AI Mini Results
            VStack(spacing: 12) {
                AIMiniResultCard(title: "Short Video Speech... $15", seller: "Cinematic Cuts", rating: "4.9")
                AIMiniResultCard(title: "Short Video Editing | 1080p", seller: "Cinematic Cuts", rating: "4.8")
            }
        }
    }
}

struct AIMiniResultCard: View {
    let title: String
    let seller: String
    let rating: String
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "play.circle.fill").foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                Text(seller).font(.system(size: 12)).foregroundColor(.secondary)
                Text("★ \(rating)").font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 280)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
        .hoverEffect(.highlight)
    }
}

// MARK: - Panel A: Left Sidebar Window
struct LeftSidebarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Header
            VStack(spacing: 16) {
                Circle()
                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .frame(width: 90, height: 90)
                    .overlay(Text("r").font(.largeTitle).foregroundColor(.white))
                
                VStack(spacing: 4) {
                    Text("robiussani robiussani")
                        .font(.title2.bold())
                    Text("Online")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.2), in: Capsule())
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                }
                
                Button("Switch to Seller") { }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .controlSize(.large)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            
            Divider()
            
            // Menu List
            VStack(alignment: .leading, spacing: 28) {
                SidebarNavItem(icon: "person.crop.circle", text: "My Orders", isActive: true)
                SidebarNavItem(icon: "heart", text: "Saved Services")
                SidebarNavItem(icon: "gearshape", text: "Settings")
            }
            .padding(32)
            
            Spacer()
            
            // Destructive Actions
            VStack(alignment: .leading, spacing: 28) {
                SidebarNavItem(icon: "trash", text: "Delete Account", color: .red)
                SidebarNavItem(icon: "rectangle.portrait.and.arrow.right", text: "Log Out")
            }
            .padding(32)
        }
        .background(Color.white.opacity(0.03))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 36))
        .overlay(RoundedRectangle(cornerRadius: 36).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

struct SidebarNavItem: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var color: Color = .primary
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(isActive ? Color(red: 16/255, green: 185/255, blue: 129/255) : color)
                .frame(width: 30)
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            Spacer()
        }
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
    }
}

// MARK: - Panel C: Right Workspace Window
struct RightOrdersView: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Orders Workspace")
                        .font(.system(size: 26, weight: .bold))
                    Spacer()
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.white.opacity(0.1), in: Circle())
                        .hoverEffect(.highlight)
                }
                Text("Manage orders placed for your gigs.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Order Details
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("I will develop iOS app\nfor you")
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(2)
                        Text("Seller: ") + Text("Robius Sani").foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        Text("Package: Basic | Ordered on: 23/09/2026")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Paid").font(.subheadline).foregroundColor(.secondary)
                        Text("$157.50")
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .font(.system(size: 28, weight: .bold))
                    }
                }
                
                // 3D Timeline Stepper
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        let stepWidth = (geo.size.width - 50) / 4
                        HStack(spacing: 0) {
                            StepNode(isActive: true)
                            StepLine(width: stepWidth, isActive: true)
                            StepNode(isActive: true)
                            StepLine(width: stepWidth, isActive: true)
                            StepNode(isActive: true)
                            StepLine(width: stepWidth, isActive: false)
                            StepNode(isActive: false)
                            StepLine(width: stepWidth, isActive: false)
                            StepNode(isActive: false)
                        }
                    }
                    .frame(height: 20)
                    
                    HStack {
                        Text("PAYMENT").font(.system(size: 10, weight: .bold)).foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        Spacer()
                        Text("REQUIREMENTS").font(.system(size: 10, weight: .bold)).foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        Spacer()
                        Text("PROCESSING").font(.system(size: 10, weight: .bold)).foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        Spacer()
                        Text("DELIVERED").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 16)
            }
            
            Spacer()
            
            // Context Actions
            VStack(spacing: 16) {
                Button("Accept & Complete") { }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .controlSize(.extraLarge)
                
                Button("View AR Delivery") {
                    openWindow(id: "DeliveryBox")
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Request Revision") { }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(32)
        .background(Color.white.opacity(0.03))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 36))
        .overlay(RoundedRectangle(cornerRadius: 36).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

struct StepNode: View {
    var isActive: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.white.opacity(0.2))
                .frame(width: 14, height: 14)
            if isActive {
                Circle()
                    .stroke(Color.black.opacity(0.5), lineWidth: 4)
                    .frame(width: 14, height: 14)
                Circle()
                    .stroke(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.5), lineWidth: 4)
                    .frame(width: 22, height: 22)
            }
        }
    }
}

struct StepLine: View {
    var width: CGFloat
    var isActive: Bool
    var body: some View {
        Rectangle()
            .fill(isActive ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.white.opacity(0.2))
            .frame(width: width, height: 4)
    }
}

// MARK: - Bottom Dock
struct SpatialBottomDock: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 45) {
                DockTabItem(icon: "house.fill", text: "Home", isActive: true)
                DockTabItem(icon: "magnifyingglass", text: "Search")
                DockTabItem(icon: "doc.text", text: "Orders")
                DockTabItem(icon: "message", text: "Inbox")
                DockTabItem(icon: "person", text: "Profile", action: { openWindow(id: "ProfileWindow") })
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .glassBackgroundEffect(in: Capsule())
            
            // Drag Indicator line
            Capsule()
                .fill(Color.white.opacity(0.5))
                .frame(width: 60, height: 4)
        }
    }
}

struct DockTabItem: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? .white : .secondary)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isActive ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

// MARK: - Delivery AR View (Window Cnt)
struct Delivery3DView: View {
    @State private var isOpened = false
    @Environment(\.dismissWindow) private var dismissWindow
    var body: some View {
        VStack {
            Text(isOpened ? "🎉 Delivery Accepted!" : "Tap to Unbox")
                .font(.extraLargeTitle).padding().glassBackgroundEffect()
            RealityView { content in
                let mesh = MeshResource.generateBox(size: 0.2, cornerRadius: 0.02)
                let material = SimpleMaterial(color: .systemGreen, isMetallic: true)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.generateCollisionShapes(recursive: false)
                model.components.set(InputTargetComponent())
                content.add(model)
            } update: { content in
                if let model = content.entities.first as? ModelEntity, isOpened {
                    model.model?.materials = [SimpleMaterial(color: .systemBlue, isMetallic: true)]
                    model.transform.scale = [1.2, 1.2, 1.2]
                }
            }
            .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in withAnimation(.spring()) { isOpened.toggle() } })
            if isOpened { Button("Close") { dismissWindow(id: "DeliveryBox") }.buttonStyle(.borderedProminent) }
        }
    }
}

#Preview(windowStyle: .plain) {
    ContentView()
}
