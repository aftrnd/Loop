import SwiftUI
import FirebaseFirestore
import CoreMotion

struct PhoneNumberInputView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var isPhoneFieldFocused: Bool
    @State private var isFormattingInProgress = false
    @State private var accountExists: Bool? = nil // nil = unchecked, true = exists, false = new
    @State private var lastCheckedNumber: String = "" // Track last checked number to prevent redundant checks
    
    // Motion tracking for accelerometer-based lighting
    @State private var tiltX: Double = 0.0
    @State private var tiltY: Double = 0.0
    private let motionManager = CMMotionManager()
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            iconSection
            
            Spacer()
            
            welcomeTextSection
            
            inputSection
            
            actionSection
        }
        .padding(.horizontal, AppConstants.UI.padding)
        .background(Color(.systemBackground))
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isPhoneFieldFocused = false
        }
        .keyboardAdaptive() // Custom keyboard handling
        .onAppear {
            startMotionTracking()
        }
        .onDisappear {
            stopMotionTracking()
        }
    }
    
    private var iconSection: some View {
        // App icon/logo area with orbiting particles
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            // Calculate breathing scale synchronized with wave at center (r=75)
            let waveSpeed: CGFloat = 1.57
            let waveFrequency: CGFloat = 0.018
            let innerR: CGFloat = 75
            
            // Calculate wave phase at the inner radius (center of pattern)
            let wavePhase = sin(innerR * waveFrequency - CGFloat(time) * waveSpeed)
            let normalizedPhase = (wavePhase + 1.0) / 2.0  // 0 to 1
            
            // Apply same easing as dots for perfect sync
            let easedPhase = pow(normalizedPhase, 2.5)
            
            // Natural breathing: oscillates between 0.95 (contracted) and 1.05 (expanded)
            // Circle and icon offset for organic feel
            let timeOffset: CGFloat = 0.4
            let circleWavePhase = sin(innerR * waveFrequency - CGFloat(time) * waveSpeed)
            let iconWavePhase = sin(innerR * waveFrequency - CGFloat(time + timeOffset) * waveSpeed)
            
            let circleScale = 1.0 + (circleWavePhase * 0.05)
            let iconScale = 1.0 + (iconWavePhase * 0.1)
            
            ZStack {
                // Orbiting particle animation (background layer) - purple base color for holographic effect
                OrbitingParticlesView(baseColor: Color(red: 0.5, green: 0.3, blue: 0.8), tiltX: tiltX, tiltY: tiltY)
                    .frame(width: 600, height: 600)
                    .allowsHitTesting(false)

                // Glass circle around the icon with breathing effect (offset from icon)
                Circle()
                    .frame(width: 120, height: 120)
                    .glassEffect(.clear)
                    .scaleEffect(circleScale)

                // Icon (on top of everything) with synchronized breathing animation
                // Primary color = white in dark mode, black in light mode
                Image(systemName: "message.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.primary)
                    .scaleEffect(iconScale)
            }
            .frame(width: 120, height: 120) // Constrains the ZStack to icon size for layout (dots overflow)
        }
    }
    
    private var welcomeTextSection: some View {
        VStack(spacing: 8) {
            Text("Welcome to Loop")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Enter your phone number to continue")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isButtonDisabled: Bool {
        // Extract digits and check count
        let digits = String(viewModel.phoneNumber.compactMap { $0.isNumber ? $0 : nil })
        return viewModel.isLoading || digits.count != 10
    }
    
    private var buttonText: String {
        if viewModel.isLoading {
            return "Sending..."
        }
        
        guard let exists = accountExists else {
            return "Continue"
        }
        
        return exists ? "Sign In" : "Sign Up"
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    // Country code prefix
                    HStack(spacing: 4) {
                        Image(systemName: "flag")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("+1")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Phone number input
                    TextField("(555) 123-4567", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isPhoneFieldFocused)
                        .onChange(of: viewModel.phoneNumber) { _, newValue in
                            // Extract digits only
                            let digits = String(newValue.compactMap { $0.isNumber ? $0 : nil })
                            
                            // Hard limit: prevent entering more than 10 digits
                            if digits.count > 10 {
                                // Revert to previous value by truncating to 10 digits
                                let truncatedDigits = String(digits.prefix(10))
                                viewModel.phoneNumber = formatPhoneNumber(truncatedDigits)
                                return
                            }
                            
                            // Immediate formatting without debouncing to prevent flashing
                            formatPhoneNumberOptimized(newValue)
                            
                            // Check if account exists when full number is entered
                            if digits.count == 10 {
                                // Only check if this is a different number than last checked
                                if digits != lastCheckedNumber {
                                    lastCheckedNumber = digits
                                    checkIfAccountExists(phoneNumber: digits)
                                }
                            } else {
                                // Reset if number is incomplete and was previously checked
                                if !lastCheckedNumber.isEmpty {
                                    lastCheckedNumber = ""
                                    accountExists = nil
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                // Only send verification if we have exactly 10 digits
                let digits = String(viewModel.phoneNumber.compactMap { $0.isNumber ? $0 : nil })
                if digits.count == 10 {
                    viewModel.sendVerificationCode()
                }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(Color(.systemBackground))
                    }
                    
                    Text(buttonText)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(.systemBackground))
                .opacity(isButtonDisabled ? 0.4 : 1.0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Color.primary
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                )
            }
            .disabled(isButtonDisabled)
            
            // Terms and privacy notice
            VStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Handle terms action
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        // Handle privacy action
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.clear
                .lightGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Optimized phone number formatting without debouncing
    private func formatPhoneNumberOptimized(_ newValue: String) {
        // Prevent recursive updates
        guard !isFormattingInProgress else { return }
        isFormattingInProgress = true
        
        // Extract digits only (optimized character filtering)
        let digits = String(newValue.compactMap { $0.isNumber ? $0 : nil })
        
        // Format the digits (limit already enforced in onChange)
        let formatted = formatPhoneNumber(digits)
        
        // Only update if different to prevent infinite loops
        if formatted != viewModel.phoneNumber {
            DispatchQueue.main.async {
                self.viewModel.phoneNumber = formatted
                self.isFormattingInProgress = false
            }
        } else {
            isFormattingInProgress = false
        }
    }
    
    private func formatPhoneNumber(_ digits: String) -> String {
        switch digits.count {
        case 0...3:
            return digits
        case 4...6:
            let areaCode = String(digits.prefix(3))
            let remaining = String(digits.dropFirst(3))
            return "(\(areaCode)) \(remaining)"
        case 7...10:
            let areaCode = String(digits.prefix(3))
            let firstPart = String(digits.dropFirst(3).prefix(3))
            let lastPart = String(digits.dropFirst(6))
            return "(\(areaCode)) \(firstPart)-\(lastPart)"
        default:
            return digits
        }
    }
    
    // MARK: - Account Check
    
    private func checkIfAccountExists(phoneNumber: String) {
        Task {
            do {
                // Format phone number with country code for Firebase
                let formattedNumber = "+1\(phoneNumber)"
                
                // Check Firestore for existing user with this phone number
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .whereField("phoneNumber", isEqualTo: formattedNumber)
                    .limit(to: 1)
                    .getDocuments()
                
                let exists = !snapshot.documents.isEmpty
                
                await MainActor.run {
                    accountExists = exists
                }
            } catch {
                print("❌ Error checking account existence: \(error.localizedDescription)")
                await MainActor.run {
                    // Default to continue if check fails
                    accountExists = nil
                }
            }
        }
    }
    
    // MARK: - Motion Tracking
    
    private func startMotionTracking() {
        print("🚀 Starting motion tracking...")
        
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available")
            return
        }
        
        print("✅ Device motion is available, starting updates...")
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [self] motion, error in
            guard let motion = motion else {
                if let error = error {
                    print("❌ Motion update error: \(error.localizedDescription)")
                }
                return
            }
            
            // Use gravity vector for more responsive tilt detection
            let gravityX = motion.gravity.x  // -1 to 1
            let gravityY = motion.gravity.y  // -1 to 1
            
            // When device tilts right, gravity.x is positive
            // When device tilts forward (top down), gravity.y is negative
            // Amplify for dramatic effect
            let newTiltX = max(-1, min(1, Double(gravityX * 2.0)))
            let newTiltY = max(-1, min(1, Double(gravityY * 2.0)))
            
            // Update state
            tiltX = newTiltX
            tiltY = newTiltY
            
            // More frequent debug output
            if Int(Date().timeIntervalSince1970 * 20) % 10 == 0 {
                print("📱 Tilt - X: \(String(format: "%.2f", tiltX)), Y: \(String(format: "%.2f", tiltY)) | Gravity - X: \(String(format: "%.2f", gravityX)), Y: \(String(format: "%.2f", gravityY))")
            }
        }
        
        // Verify it started
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("📊 Motion manager running: \(self.motionManager.isDeviceMotionActive)")
        }
    }
    
    private func stopMotionTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
    
}

// MARK: - Keyboard Adaptive Modifier
struct KeyboardAdaptiveModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    let keyboardRectangle = keyboardFrame.cgRectValue
                    let keyboardHeight = keyboardRectangle.height
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.keyboardHeight = keyboardHeight * 0.1 // Minimal adjustment
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.keyboardHeight = 0
                }
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptiveModifier())
    }
}

#Preview {
    PhoneNumberInputView(viewModel: AuthenticationViewModel())
}
