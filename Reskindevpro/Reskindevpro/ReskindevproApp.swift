import SwiftUI

@main
struct ReskindevproApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.plain)
        
        // Profile Window (Floating Window)
        WindowGroup(id: "ProfileWindow") {
            ProfileView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 400, height: 600)
        
        // 3D Delivery Box Window (Volumetric)
        WindowGroup(id: "DeliveryBox") {
            Delivery3DView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)
    }
}

// A simple Profile Screen
struct ProfileView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: {
                    dismissWindow(id: "ProfileWindow")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            Circle()
                .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                .frame(width: 100, height: 100)
                .overlay(Text("r").font(.system(size: 40, weight: .bold)).foregroundColor(.white))
            
            Text("Robius Sani")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Top Rated Seller • 4.9 ★")
                .foregroundColor(.secondary)
            
            Divider().padding(.vertical)
            
            VStack(alignment: .leading, spacing: 15) {
                Label("robiussani@example.com", systemImage: "envelope")
                Label("Dhaka, Bangladesh", systemImage: "mappin.and.ellipse")
                Label("Joined August 2023", systemImage: "calendar")
            }
            .font(.title3)
            
            Spacer()
            
            Button("Edit Profile") { }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 16/255, green: 185/255, blue: 129/255))
                .frame(maxWidth: .infinity)
        }
        .padding(30)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
        .glassBackgroundEffect()
    }
}
