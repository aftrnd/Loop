import Foundation
import FirebaseAuth
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
    @Published var isAPNsRegistered: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthState()
        checkAPNsRegistration()
    }
    
    func checkAuthState() {
        authState = .loading
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
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
        
        // Format phone number for Firebase (assuming US format for now)
        let formattedPhoneNumber = formatPhoneNumber(phoneNumber)
        
        print("🔍 DEBUG: Attempting to verify phone number: \(formattedPhoneNumber)")
        print("🔍 DEBUG: Firebase Auth current user: \(Auth.auth().currentUser?.uid ?? "nil")")
        
        // Check APNs status for debugging but don't block
        print("🔍 DEBUG: APNs registered status: \(isAPNsRegistered)")
        if !isAPNsRegistered {
            print("🔍 DEBUG: WARNING - APNs not registered, but attempting phone auth anyway for testing")
        }
        
        // Create a strong reference to avoid retain cycles
        let provider = PhoneAuthProvider.provider()
        
        // Try to use a more robust approach with error handling
        do {
            provider.verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
                print("🔍 DEBUG: Phone verification callback received")
                print("🔍 DEBUG: Verification ID: \(verificationID ?? "nil")")
                print("🔍 DEBUG: Error: \(error?.localizedDescription ?? "nil")")
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("🔍 DEBUG: Firebase error details: \(error)")
                        self?.errorMessage = self?.handleFirebaseError(error) ?? "Failed to send verification code"
                        return
                    }
                    
                    guard let verificationID = verificationID else {
                        print("🔍 DEBUG: Verification ID is nil - this is the source of the crash")
                        self?.errorMessage = "Failed to receive verification ID. Please check your Firebase configuration and try again."
                        return
                    }
                    
                    print("🔍 DEBUG: Successfully received verification ID")
                    self?.verificationID = verificationID
                }
            }
        } catch {
            print("🔍 DEBUG: Exception caught during phone verification: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Phone verification failed. Please check your network connection and try again."
            }
        }
    }
    
    func verifyCode() {
        guard let verificationID = verificationID,
              !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
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
    
    func refreshAPNsStatus() {
        print("🔍 DEBUG: Manually refreshing APNs status")
        checkAPNsRegistration()
    }
    
    func forceAPNsRegistration() {
        print("🔍 DEBUG: Force attempting APNs registration")
        UIApplication.shared.registerForRemoteNotifications()
        
        // Check status after registration attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let status = UIApplication.shared.isRegisteredForRemoteNotifications
            print("🔍 DEBUG: Force registration result: \(status)")
            self.isAPNsRegistered = status
        }
    }
    
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        print("🔍 DEBUG: Original phone number: \(phoneNumber)")
        print("🔍 DEBUG: Extracted digits: \(digits)")
        
        // Validate we have enough digits for a US phone number
        guard digits.count == 10 else {
            print("🔍 DEBUG: Invalid phone number length: \(digits.count)")
            return phoneNumber // Return original if invalid
        }
        
        // Format as +1XXXXXXXXXX for Firebase
        let formattedNumber = "+1" + digits
        print("🔍 DEBUG: Formatted phone number: \(formattedNumber)")
        
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
                return "Internal error. Please try again."
            default:
                return "Authentication error: \(error.localizedDescription)"
            }
        }
        
        return error.localizedDescription
    }
    
    private func checkAPNsRegistration() {
        // Check notification authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                print("🔍 DEBUG: Notification authorization status: \(settings.authorizationStatus.rawValue)")
                print("🔍 DEBUG: Alert setting: \(settings.alertSetting.rawValue)")
                print("🔍 DEBUG: Badge setting: \(settings.badgeSetting.rawValue)")
                print("🔍 DEBUG: Sound setting: \(settings.soundSetting.rawValue)")
                
                // Check if app is registered for remote notifications
                let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
                print("🔍 DEBUG: isRegisteredForRemoteNotifications: \(isRegistered)")
                
                // APNs is registered if we have authorization AND the app is registered
                let apnsReady = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && isRegistered
                
                print("🔍 DEBUG: APNs ready for Firebase: \(apnsReady)")
                self?.isAPNsRegistered = apnsReady
                
                // If we have permission but aren't registered, try to register
                if (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && !isRegistered {
                    print("🔍 DEBUG: Have permission but not registered, attempting to register")
                    print("🔍 DEBUG: Calling registerForRemoteNotifications()")
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Check again after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let newStatus = UIApplication.shared.isRegisteredForRemoteNotifications
                        print("🔍 DEBUG: Registration status after 1 second: \(newStatus)")
                        if !newStatus {
                            print("🔍 DEBUG: Registration failed - this usually means APNs certificates are missing in Firebase Console")
                            print("🔍 DEBUG: Check Firebase Console -> Project Settings -> Cloud Messaging -> APNs certificates")
                        }
                    }
                }
                
                // If no permission, request it
                if settings.authorizationStatus == .notDetermined {
                    print("🔍 DEBUG: Requesting notification permission")
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            print("🔍 DEBUG: Permission request result - granted: \(granted)")
                            if let error = error {
                                print("🔍 DEBUG: Permission request error: \(error)")
                            }
                            if granted {
                                UIApplication.shared.registerForRemoteNotifications()
                                print("🔍 DEBUG: Registered for remote notifications after permission granted")
                            }
                        }
                    }
                }
            }
        }
    }
}
