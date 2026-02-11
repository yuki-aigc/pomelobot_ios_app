import SwiftUI

@main
struct PomeloBotApp: App {
    @StateObject private var settings = SettingsStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(resolvedColorScheme)
        }
    }
    
    private var resolvedColorScheme: ColorScheme? {
        switch settings.colorSchemeOverride {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
