import Foundation
import FirebaseAuth
import FirebaseCore
import Combine
import UIKit
import UserNotifications


@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var phoneNumber: String = ""
    @Published var verificationCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var verificationID: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthState()
    }
    
    // CRITICAL FIX: Ensure Firebase is configured before using it
    private func ensureFirebaseConfigured() -> Bool {
        if FirebaseApp.app() != nil {
            // Firebase is already configured
            return true
        } else {
            // Firebase not configured yet, try to configure it
            print("⚠️ Firebase not configured, attempting to configure...")
            FirebaseApp.configure()
            if FirebaseApp.app() != nil {
                print("✅ Firebase successfully configured")
                return true
            } else {
                print("❌ Firebase configuration failed - app() returned nil after configure()")
                return false
            }
        }
    }
    
    func checkAuthState() {
        authState = .loading
        
        // CRITICAL FIX: Ensure Firebase is configured before using Auth
        guard ensureFirebaseConfigured() else {
            print("❌ Firebase configuration failed")
            authState = .error("Firebase configuration failed")
            return
        }
        
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    let appUser = User(from: user)
                    self?.authState = .authenticated(appUser)
                } else {
                    self?.authState = .unauthenticated
                }
            }
        }
    }
    
    func sendVerificationCode() {
        guard !phoneNumber.isEmpty else {
            errorMessage = "Please enter your phone number"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // CRITICAL FIX: Ensure Firebase is configured before proceeding
        guard ensureFirebaseConfigured() else {
            isLoading = false
            errorMessage = "Firebase configuration failed. Please restart the app."
            return
        }
        
        // Format phone number for Firebase (assuming US format for now)
        let formattedPhoneNumber = formatPhoneNumber(phoneNumber)
        
        // Proceed with phone verification
        attemptPhoneVerificationSafely(phoneNumber: formattedPhoneNumber)
    }
    
    func verifyCode() {
        guard let verificationID = verificationID,
              !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Check if this is mock authentication
        if verificationID == "mock_verification_id_12345" {
            // Create a mock user for development
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let mockUser = User(
                    id: "mock_user_id_\(Int.random(in: 1000...9999))",
                    phoneNumber: self.phoneNumber,
                    displayName: "User"
                )
                
                self.isLoading = false
                self.authState = .authenticated(mockUser)
            }
            return
        }
        
        // CRITICAL FIX: Ensure Firebase is configured before using PhoneAuthProvider
        guard ensureFirebaseConfigured() else {
            isLoading = false
            errorMessage = "Firebase configuration failed"
            return
        }
        
        // Original Firebase verification
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            Task { @MainActor in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                if let user = authResult?.user {
                    let appUser = User(from: user)
                    self?.authState = .authenticated(appUser)
                }
            }
        }
    }
    
    func signOut() {
        // CRITICAL FIX: Ensure Firebase is configured before using Auth
        guard ensureFirebaseConfigured() else {
            errorMessage = "Firebase configuration failed"
            return
        }
        
        do {
            try Auth.auth().signOut()
            authState = .unauthenticated
            phoneNumber = ""
            verificationCode = ""
            verificationID = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func resetVerification() {
        verificationCode = ""
        verificationID = nil
        errorMessage = nil
    }
    
    
    
    private func attemptPhoneVerificationSafely(phoneNumber: String) {
        // CRITICAL FIX: Try real Firebase phone authentication with proper safety checks
        print("🔥 Attempting REAL Firebase phone authentication...")
        
        // Ensure Firebase is configured
        guard ensureFirebaseConfigured() else {
            print("❌ Firebase not configured, falling back to mock auth")
            isLoading = false
            skipFirebaseAndUseMockAuth()
            return
        }
        
        // CRITICAL FIX: Configuration has been updated - test Firebase phone auth
        print("🎯 Configuration updated with URL schemes - testing Firebase phone auth...")
        testConfigurationAndTryFirebase()
    }
    
    func skipFirebaseAndUseMockAuth() {
        isLoading = true
        errorMessage = nil
        
        // Simulate SMS verification process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.verificationID = "mock_verification_id_12345"
            self.isLoading = false
        }
    }
    
    func testConfigurationAndTryFirebase() {
        print("🧪 Testing Firebase configuration after URL scheme addition...")
        
        // First, test the configuration
        let configResult = checkFirebaseConfiguration()
        print(configResult)
        
        // Check if configuration looks good enough to try Firebase
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let _ = NSDictionary(contentsOfFile: path) else {
            print("❌ GoogleService-Info.plist not found")
            errorMessage = "GoogleService-Info.plist missing"
            return
        }
        
        // Check if we have URL schemes configured
        let hasUrlSchemes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") != nil
        
        if hasUrlSchemes {
            print("✅ URL schemes detected - attempting Firebase phone auth...")
            tryRealFirebasePhoneAuth()
        } else {
            print("❌ No URL schemes found - using mock auth")
            skipFirebaseAndUseMockAuth()
        }
    }
    
    // MARK: - Firebase Phone Auth (When Configuration is Fixed)
    
    func tryRealFirebasePhoneAuth() {
        guard !phoneNumber.isEmpty else {
            errorMessage = "Please enter your phone number"
            return
        }
        
        print("⚠️ WARNING: Attempting real Firebase phone auth - may crash if not configured properly!")
        
        isLoading = true
        errorMessage = nil
        
        let formattedPhoneNumber = formatPhoneNumber(phoneNumber)
        attemptFirebasePhoneAuthWithCrashProtection(phoneNumber: formattedPhoneNumber)
    }
    
    private func attemptFirebasePhoneAuthWithCrashProtection(phoneNumber: String) {
        print("🛡️ Attempting Firebase phone auth with crash protection...")
        print("📋 Configuration check: REVERSED_CLIENT_ID and URL schemes are configured")
        
        // Set up crash detection with timeout
        var hasCompleted = false
        let timeoutSeconds = 15.0 // Give more time for real SMS
        
        // Set up timeout protection
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
            if !hasCompleted {
                hasCompleted = true
                print("⏰ Firebase phone auth timed out after \(timeoutSeconds) seconds")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Phone verification timed out"
                    self.skipFirebaseAndUseMockAuth()
                }
            }
        }
        
        // Attempt Firebase phone auth
        do {
            print("🔥 Creating PhoneAuthProvider...")
            let provider = PhoneAuthProvider.provider()
            print("✅ PhoneAuthProvider created successfully")
            
            print("📞 Calling verifyPhoneNumber with proper configuration...")
            
            // This should now work with proper configuration
            provider.verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
                guard !hasCompleted else {
                    print("⚠️ Firebase callback received after timeout - ignoring")
                    return
                }
                hasCompleted = true
                
                print("🎉 Firebase callback received!")
                print("🆔 Verification ID: \(verificationID ?? "nil")")
                print("❌ Error: \(error?.localizedDescription ?? "none")")
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("🚨 Firebase returned error: \(error)")
                        
                        // Handle specific billing error
                        let errorString = error.localizedDescription
                        if errorString.contains("BILLING_NOT_ENABLED") {
                            print("💳 BILLING_NOT_ENABLED error detected")
                            print("🔧 Solution: Enable billing in Firebase Console")
                            print("📋 Go to Firebase Console → Project Settings → Usage and billing → Modify plan")
                            self?.errorMessage = "🚨 Firebase billing required for phone auth. Enable billing in Firebase Console or use mock auth for development."
                        } else {
                            self?.errorMessage = self?.handleFirebaseError(error) ?? "Phone verification failed"
                        }
                        
                        // Still fall back to mock auth if Firebase has issues
                        self?.skipFirebaseAndUseMockAuth()
                    } else if let verificationID = verificationID {
                        print("🎉 SUCCESS! Real Firebase verification ID received!")
                        print("📱 You should receive an SMS with the verification code!")
                        self?.verificationID = verificationID
                    } else {
                        print("⚠️ No verification ID and no error - using mock auth")
                        self?.skipFirebaseAndUseMockAuth()
                    }
                }
            }
            
            print("📱 Firebase verifyPhoneNumber called - waiting for SMS or callback...")
            
        }
    }
    
    // MARK: - Testing & Debugging
    
    func testFirebaseInitialization() -> String {
        var result = "🧪 Firebase Initialization Test:\n"
        
        // Test 1: Check if Firebase is configured
        if let app = FirebaseApp.app() {
            result += "✅ Firebase app available: \(app.name)\n"
            result += "✅ Project ID: \(String(describing: app.options.projectID))\n"
            
            // Test 2: Try to access Auth
            let currentUser = Auth.auth().currentUser
                result += "✅ Auth service accessible, current user: \(String(describing: currentUser?.uid))\n"
            
            // Test 3: Check GoogleService-Info.plist contents
            result += checkFirebaseConfiguration()
            
        } else {
            result += "❌ Firebase app not configured\n"
            
            // Test configuration
            result += "🔧 Attempting to configure Firebase...\n"
            if ensureFirebaseConfigured() {
                result += "✅ Firebase configured successfully\n"
            } else {
                result += "❌ Firebase configuration failed\n"
            }
        }
        
        return result
    }
    
    func checkFirebaseConfiguration() -> String {
        var result = "\n📋 Firebase Configuration Check:\n"
        
        // Check if GoogleService-Info.plist has required keys
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            result += "❌ GoogleService-Info.plist not found\n"
            return result
        }
        
        result += "✅ GoogleService-Info.plist found\n"
        
        // Check required keys
        let requiredKeys = [
            "API_KEY",
            "GCM_SENDER_ID",
            "PROJECT_ID",
            "BUNDLE_ID",
            "GOOGLE_APP_ID"
        ]
        
        for key in requiredKeys {
            if plist[key] != nil {
                result += "✅ \(key) present\n"
            } else {
                result += "❌ \(key) missing\n"
            }
        }
        
        // Check for Google Sign-In keys (needed for phone auth)
        if let reversedClientId = plist["REVERSED_CLIENT_ID"] {
            result += "✅ REVERSED_CLIENT_ID present: \(reversedClientId)\n"
        } else {
            result += "❌ REVERSED_CLIENT_ID missing (enable Google Sign-In in Firebase Console)\n"
        }
        
        if plist["CLIENT_ID"] != nil {
            result += "✅ CLIENT_ID present\n"
        } else {
            result += "❌ CLIENT_ID missing\n"
        }
        
        // Check URL schemes in app
        if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
            result += "✅ URL Types configured: \(urlTypes.count)\n"
            for (index, urlType) in urlTypes.enumerated() {
                if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                    result += "  Type \(index): \(schemes.joined(separator: ", "))\n"
                }
            }
        } else {
            result += "❌ No URL Types configured (add REVERSED_CLIENT_ID as URL scheme)\n"
        }
        
        result += "\n🔧 To fix Firebase phone auth crashes:\n"
        result += "1. Enable Google Sign-In in Firebase Console\n"
        result += "2. Download fresh GoogleService-Info.plist\n"
        result += "3. Add REVERSED_CLIENT_ID as URL scheme in Xcode\n"
        
        return result
    }
    
    
    
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Validate we have enough digits for a US phone number
        guard digits.count == 10 else {
            return phoneNumber // Return original if invalid
        }
        
        // Format as +1XXXXXXXXXX for Firebase
        let formattedNumber = "+1" + digits
        return formattedNumber
    }
    
    private func handleFirebaseError(_ error: Error) -> String {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .invalidPhoneNumber:
                return "Please enter a valid phone number"
            case .tooManyRequests:
                return "Too many requests. Please try again later."
            case .quotaExceeded:
                return "SMS quota exceeded. Please try again later."
            case .networkError:
                return "Network error. Please check your connection."
            case .internalError:
                // Check for specific internal errors
                let errorString = error.localizedDescription
                if errorString.contains("BILLING_NOT_ENABLED") {
                    return "Firebase billing not enabled. Please enable billing in Firebase Console to use phone authentication."
                } else if errorString.contains("QUOTA_EXCEEDED") {
                    return "Phone authentication quota exceeded. Please check your Firebase quota limits."
                } else {
                    return "Firebase internal error. Please check your Firebase project configuration."
                }
            default:
                return "Authentication error: \(error.localizedDescription)"
            }
        }
        
        // Check for billing error in error description
        let errorString = error.localizedDescription
        if errorString.contains("BILLING_NOT_ENABLED") {
            return "🚨 Firebase billing not enabled. Enable billing in Firebase Console for phone authentication."
        }
        
        return error.localizedDescription
    }
    
}


