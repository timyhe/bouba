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
                // Buttons and icons default to black; orange is opted into where it marks an action or selection.
                .tint(Color.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let _ = AlloFont.setContentSize(dynamicTypeSize)
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
        .fullScreenCover(isPresented: Bindable(store).showingMeet) {
            NavigationStack {
                MeetThePetView(onFinish: { store.showingMeet = false })
            }
        }
        .font(.allo(17))
        // Allo is built at a fixed size per text-size setting, so rebuild the tree when it changes.
        .id(dynamicTypeSize)
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: 0) {
                ActivityView().tint(Color.primary)
            } label: { tabIcon("Activity", "list.bullet.clipboard", 0) }
            Tab(value: 1) {
                PetProfileView().tint(Color.primary)
            } label: { tabIcon(store.pet.name, petSymbol, 1) }
            Tab(value: 2) {
                MeView().tint(Color.primary)
            } label: { tabIcon("Me", "person.crop.circle", 2) }
        }
        .tabBarMinimizeBehavior(.never)
        .tint(Color.primary)
    }

    /// The pet's species symbol without its fill, e.g. "dog".
    private var petSymbol: String {
        store.pet.species.symbol.replacingOccurrences(of: ".fill", with: "")
    }

    /// Icon-only tab: the filled symbol in black when selected, the outline dimmed when not.
    /// The glass tab bar forces the fill variant and its own tint onto symbol images, so each
    /// icon is drawn into a plain bitmap first; the tab bar then shows it exactly as drawn.
    private func tabIcon(_ title: String, _ symbol: String, _ tag: Int) -> some View {
        let selected = selection == tag
        let image = Self.bitmap(symbol: selected ? symbol + ".fill" : symbol,
                                color: selected ? .label : UIColor.label.withAlphaComponent(0.35))
        return Label { Text(title) } icon: { Image(uiImage: image) }
            .labelStyle(.iconOnly)
    }

    private static func bitmap(symbol: String, color: UIColor) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: 21, weight: .medium)
        guard let symbolImage = UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return UIImage() }
        let rendered = UIGraphicsImageRenderer(size: symbolImage.size).image { _ in
            symbolImage.draw(at: .zero)
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}
