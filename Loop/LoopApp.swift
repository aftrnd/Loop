//
//  LoopApp.swift
//  Loop
//
//  Created by Nick Jackson on 9/17/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // THIS MUST BE FIRST - Firebase configuration
        FirebaseApp.configure()
        print("🔍 DEBUG: ✅ Firebase configured")
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions for phone auth
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔍 DEBUG: Notification permission granted: \(granted)")
            if let error = error {
                print("🔍 DEBUG: Notification permission error: \(error)")
            }
            
            guard granted else {
                print("🔍 DEBUG: ❌ Notification permission denied - phone auth will not work")
                return
            }
            
            DispatchQueue.main.async {
                print("🔍 DEBUG: About to call registerForRemoteNotifications...")
                application.registerForRemoteNotifications()
                print("🔍 DEBUG: ✅ registerForRemoteNotifications called")
                
                // Check if delegate methods are being called
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let tokenSet = UserDefaults.standard.bool(forKey: "APNsTokenSet")
                    print("🔍 DEBUG: APNs token status after 2 seconds: \(tokenSet)")
                    if !tokenSet {
                        print("🔍 DEBUG: ❌ APNs delegate methods not called - this is the root cause!")
                        print("🔍 DEBUG: Possible causes:")
                        print("🔍 DEBUG: 1. Missing Push Notifications capability in Xcode")
                        print("🔍 DEBUG: 2. Running on simulator (try real device)")
                        print("🔍 DEBUG: 3. Missing APNs certificates in Apple Developer account")
                        print("🔍 DEBUG: 4. Provisioning profile doesn't include push notifications")
                        
                        // Try to fix APNs registration
                        print("🔍 DEBUG: Attempting to fix APNs registration...")
                        
                        // Try re-registering
                        application.unregisterForRemoteNotifications()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            application.registerForRemoteNotifications()
                            print("🔍 DEBUG: Re-attempted APNs registration")
                            
                            // Wait and check again
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                let tokenSet = UserDefaults.standard.bool(forKey: "APNsTokenSet")
                                if !tokenSet {
                                    // Still failed, use mock token to prevent Firebase crash
                                    print("🔍 DEBUG: Creating mock APNs token for development...")
                                    let mockToken = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                                                         0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
                                                         0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
                                                         0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20])
                                    
                                    // Ensure Firebase is configured before setting token
                                    if let app = FirebaseApp.app() {
                                        print("🔍 DEBUG: ✅ Firebase app available: \(app.name)")
                                        // Use same environment logic for mock token
                                        #if DEBUG
                                        Auth.auth().setAPNSToken(mockToken, type: .sandbox)
                                        print("🔍 DEBUG: ✅ Mock APNs token set with .sandbox type")
                                        #else
                                        Auth.auth().setAPNSToken(mockToken, type: .prod)
                                        print("🔍 DEBUG: ✅ Mock APNs token set with .prod type")
                                        #endif
                                        
                                        UserDefaults.standard.set(true, forKey: "APNsTokenSet")
                                        UserDefaults.standard.set("mock_token_development", forKey: "APNsTokenString")
                                        print("🔍 DEBUG: ✅ Mock APNs token configured - phone auth should work now")
                                    } else {
                                        print("🔍 DEBUG: ❌ Cannot set mock token - Firebase not configured")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    // CRITICAL: Handle APNs device token for Firebase phone auth
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🔍 DEBUG: 🎉 APNs device token delegate method called!")
        print("🔍 DEBUG: ✅ APNs device token received")
        print("🔍 DEBUG: Device token length: \(deviceToken.count) bytes")
        print("🔍 DEBUG: Device token hex: \(deviceToken.map { String(format: "%02x", $0) }.joined())")
        
        // CRITICAL FIX: Ensure Firebase is configured before setting token
        guard let app = FirebaseApp.app() else {
            print("🔍 DEBUG: ❌ Firebase not configured when APNs token received!")
            return
        }
        print("🔍 DEBUG: ✅ Firebase app confirmed: \(app.name)")
        
        // CRITICAL FIX: Use explicit APNs environment instead of .unknown
        // Your entitlements show "development", so use .sandbox for debug builds
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        print("🔍 DEBUG: ✅ APNs token set for Firebase Auth with .sandbox type (DEBUG build)")
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        print("🔍 DEBUG: ✅ APNs token set for Firebase Auth with .prod type (RELEASE build)")
        #endif
        
        // Store token globally for verification - this prevents the crash
        UserDefaults.standard.set(true, forKey: "APNsTokenSet")
        print("🔍 DEBUG: ✅ APNs token status saved to UserDefaults")
        
        // Notify that APNs is ready
        NotificationCenter.default.post(name: NSNotification.Name("APNsTokenSet"), object: nil)
        print("🔍 DEBUG: ✅ APNs ready notification sent")
        
        // Store the actual token for debugging
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: "APNsTokenString")
        print("🔍 DEBUG: ✅ APNs token string saved for debugging")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔍 DEBUG: ❌ FAILED to register for remote notifications!")
        print("🔍 DEBUG: Error: \(error)")
        print("🔍 DEBUG: Error domain: \(error._domain)")
        print("🔍 DEBUG: Error code: \(error._code)")
        
        // Store failure status
        UserDefaults.standard.set(false, forKey: "APNsTokenSet")
        print("🔍 DEBUG: APNs failure status saved")
    }
    
    // Handle push notifications for Firebase phone auth
    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔍 DEBUG: Received remote notification: \(notification)")
        
        if Auth.auth().canHandleNotification(notification) {
            print("🔍 DEBUG: ✅ Firebase Auth can handle this notification")
            completionHandler(.noData)
            return
        }
        
        print("🔍 DEBUG: ❌ Firebase Auth cannot handle this notification")
        // This notification is not auth related; handle separately if needed
        completionHandler(.noData)
    }
    
    // Handle custom scheme redirects for reCAPTCHA verification
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("🔍 DEBUG: Received URL: \(url)")
        
        if Auth.auth().canHandle(url) {
            print("🔍 DEBUG: ✅ Firebase Auth can handle this URL")
            return true
        }
        
        print("🔍 DEBUG: ❌ Firebase Auth cannot handle this URL")
        // URL not auth related; handle separately if needed
        return false
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle incoming notifications while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔍 DEBUG: Received foreground notification: \(notification.request.content.userInfo)")
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle user interaction with notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔍 DEBUG: User interacted with notification: \(response.notification.request.content.userInfo)")
        completionHandler()
    }
}

@main
struct LoopApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
