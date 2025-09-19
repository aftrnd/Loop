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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Request notification permissions for phone auth
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔍 DEBUG: Notification permission granted: \(granted)")
            if let error = error {
                print("🔍 DEBUG: Notification permission error: \(error)")
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                    print("🔍 DEBUG: Registered for remote notifications")
                }
            } else {
                print("🔍 DEBUG: Notification permission denied - phone auth will not work")
            }
        }
        
        return true
    }
    
    // Handle APNs device token for Firebase phone auth
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🔍 DEBUG: APNs device token received: \(deviceToken)")
        // Pass device token to auth for phone authentication
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        print("🔍 DEBUG: APNs token set in Firebase Auth")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔍 DEBUG: Failed to register for remote notifications: \(error)")
    }
    
    // Handle push notifications for Firebase phone auth
    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        // This notification is not auth related; handle separately if needed
        completionHandler(.noData)
    }
    
    // Handle custom scheme redirects for reCAPTCHA verification
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        // URL not auth related; handle separately if needed
        return false
    }
}

@main
struct LoopApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            AuthenticationView()
        }
    }
}
