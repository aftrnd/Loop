import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Debug Manager
class DebugManager: ObservableObject {
    static let shared = DebugManager()
    
    @Published var isDebugMenuVisible = false
    @Published var debugSettings = DebugSettings()
    
    private init() {}
    
    // MARK: - Debug Actions
    
    /// Sign out current user and reset to welcome screen
    func resetAuthentication() {
        do {
            try Auth.auth().signOut()
            print("🔧 DEBUG: User signed out successfully")
        } catch {
            print("🔧 DEBUG: Sign out error: \(error)")
        }
    }
    
    /// Clear all user defaults (app settings)
    func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("🔧 DEBUG: UserDefaults cleared")
    }
    
    /// Reset app to fresh install state
    func resetAppState() {
        resetAuthentication()
        clearUserDefaults()
        print("🔧 DEBUG: App state reset to fresh install")
    }
    
    /// Toggle between mock and real Firebase auth
    func toggleMockAuth() {
        debugSettings.useMockAuth.toggle()
        print("🔧 DEBUG: Mock auth \(debugSettings.useMockAuth ? "enabled" : "disabled")")
    }
    
    /// Show debug menu
    func showDebugMenu() {
        isDebugMenuVisible = true
    }
    
    /// Hide debug menu
    func hideDebugMenu() {
        isDebugMenuVisible = false
    }
}

// MARK: - Debug Settings
struct DebugSettings {
    var useMockAuth: Bool = false
    var showDebugLogs: Bool = true
    var simulateNetworkDelay: Bool = false
    var networkDelaySeconds: Double = 2.0
}

// MARK: - Debug Menu View
struct DebugMenuView: View {
    @ObservedObject var debugManager = DebugManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("🔧 Authentication Debug") {
                    Button("🔄 Reset Authentication") {
                        debugManager.resetAuthentication()
                    }
                    .foregroundColor(.orange)
                    
                    Button("🗑️ Clear User Data") {
                        debugManager.clearUserDefaults()
                    }
                    .foregroundColor(.red)
                    
                    Button("🆕 Reset to Fresh Install") {
                        debugManager.resetAppState()
                    }
                    .foregroundColor(.red)
                }
                
                Section("🧪 Testing Options") {
                    Toggle("Use Mock Authentication", isOn: $debugManager.debugSettings.useMockAuth)
                    
                    Toggle("Show Debug Logs", isOn: $debugManager.debugSettings.showDebugLogs)
                    
                    Toggle("Simulate Network Delay", isOn: $debugManager.debugSettings.simulateNetworkDelay)
                    
                    if debugManager.debugSettings.simulateNetworkDelay {
                        HStack {
                            Text("Delay: \(debugManager.debugSettings.networkDelaySeconds, specifier: "%.1f")s")
                            Slider(value: $debugManager.debugSettings.networkDelaySeconds, in: 0.5...10.0, step: 0.5)
                        }
                    }
                }
                
                Section("📱 App Info") {
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text(Bundle.main.bundleIdentifier ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Firebase User")
                        Spacer()
                        Text(Auth.auth().currentUser?.uid ?? "None")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("⚠️ Danger Zone") {
                    Button("💥 Force Crash (Test Crashlytics)") {
                        fatalError("Debug crash test")
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("🔧 Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Debug Gesture Modifier
struct DebugGestureModifier: ViewModifier {
    @ObservedObject var debugManager = DebugManager.shared
    
    func body(content: Content) -> some View {
        content
            .onShake {
                // Shake gesture to show debug menu
                #if DEBUG
                debugManager.showDebugMenu()
                #endif
            }
            .onLongPressGesture(minimumDuration: 3.0) {
                // Long press (3 seconds) to show debug menu
                #if DEBUG
                debugManager.showDebugMenu()
                #endif
            }
            .sheet(isPresented: $debugManager.isDebugMenuVisible) {
                DebugMenuView()
            }
    }
}

// MARK: - View Extension for Debug
extension View {
    func debugMenu() -> some View {
        self.modifier(DebugGestureModifier())
    }
}

// MARK: - Shake Gesture Detection
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

struct ShakeViewModifier: ViewModifier {
    let onShake: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                onShake()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeViewModifier(onShake: action))
    }
}

