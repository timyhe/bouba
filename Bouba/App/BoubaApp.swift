import SwiftUI

@main
struct BoubaApp: App {
    @State private var store = AppStore()

    init() {
        AlloFont.register()
        AlloFont.applyAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .font(.allo(17))
                // Buttons and icons default to black; orange is opted into where it marks an action or selection.
                .tint(Color.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            if store.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.hasOnboarded)
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        TabView {
            Tab("Activity", systemImage: "pawprint.fill") {
                ActivityView().tint(Color.primary)
            }
            Tab("History", systemImage: "calendar") {
                HistoryView().tint(Color.primary)
            }
            Tab(store.pet.name, systemImage: store.pet.species.symbol) {
                PetProfileView().tint(Color.primary)
            }
            Tab("Me", systemImage: "person.crop.circle") {
                MeView().tint(Color.primary)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Orange marks the selected tab; each tab's content resets to black above.
        .tint(Color.boubaOrange)
    }
}
