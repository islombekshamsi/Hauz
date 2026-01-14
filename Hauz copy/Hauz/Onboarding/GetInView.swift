import SwiftUI
import Auth
import Supabase
import PostgREST


struct GetInView: View {
    @State private var isLogged = false
    @State private var hasProfile = false
    
    // Accept initial states from SplashScreen to prevent flash
    init(initialLoginState: Bool = false, initialProfileState: Bool = false) {
        _isLogged = State(initialValue: initialLoginState)
        _hasProfile = State(initialValue: initialProfileState)
    }
    
    var body: some View {
        ZStack{
            if isLogged{
                if hasProfile {
                    ContentView()
                } else {
                    // Use the onboarding container so UserInfo receives its required environment object
                    OnboardingContainer()
                }
            } else {
                LoginView(onComplete: {
                    isLogged = true
                }, hasProfile: $hasProfile)
            }
        }
    }
}



struct LoginView: View{
    var onComplete: () -> ()
    @Binding var hasProfile: Bool
    
    @State private var mobileNumber: String = ""
    @State var showVerificationView: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    

    
    var body: some View{
        Color("HauzLight").ignoresSafeArea(edges: .all)
        
        
        VStack(alignment: .leading, spacing: 12){
            VStack(alignment: .leading, spacing: 8){
                Text("Hello there!")
                    .font(.custom("Outfit-Black", size: 35))

                    .foregroundStyle(Color("HauzFocus"))
                Text("Please enter your phone number to proceed")
                    .font(.custom("Outfit-Black", size: 20))

                    .foregroundStyle(Color("HauzFocus"))
            }
            .fontWeight(.medium)
            .padding(.top, 5)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack(spacing: 8){
                HStack(spacing: 5){
                    Text("🇺🇸 +1")
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundStyle(.gray)
        
                    
                    TextField("Mobile Number", text: $mobileNumber)
                        .font(.custom("Outfit-SemiBold", size: 18))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .padding(10)
                        .focused($isTextFieldFocused)
                        .onChange(of: mobileNumber) {
                            mobileNumber = formatUSNumber(input: mobileNumber)
                            errorMessage = nil
                        }
                }
                    .padding(.horizontal, 12)
                    
            }
            .frame(height: 50)
            .background(Color("HauzLight"))
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(isTextFieldFocused ? Color("HauzBg") : Color.clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.3), value: isTextFieldFocused)
            .clipShape(.capsule)
            .padding(.top, 10)
            
            Button{
                Task {
                    await sendOTP()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Get Verification Code")
                        .font(.custom("Outfit-Black", size: 16))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color("HauzFocus"))
            // for better ui
            .disabled(mobileNumber.isEmpty || isLoading)
            
            Spacer(minLength: 0)
            // links and more
            HStack(spacing: 4){
                Link("Terms of Service", destination: URL(string: "https://apple.com")!)
                    .underline()
                    .font(.custom("Outfit-Black", size: 14))

                
                Text("&")
                    .font(.custom("Outfit-Black", size: 12))

                
                Link("Privacy Policy", destination: URL(string: "https://apple.com")!)
                    .underline()
                    .font(.custom("Outfit-Black", size: 14))

            }
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(Color("HauzFocus"))
            .frame(maxWidth: .infinity)
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showVerificationView){
            OTPVerificationView(fullNumber: fullMobileNumber, onComplete: onComplete, hasProfile: $hasProfile)
        }
    }
    
    // function below might be an issue when sending a verification code
    var fullMobileNumber: String {
        // Remove dashes and format for Supabase (E.164 format: +1XXXXXXXXXX)
        let digits = mobileNumber.filter { $0.isNumber }
        
        // Ensure we have exactly 10 digits for US phone number
        guard digits.count == 10 else {
            return "+1\(digits)" // Return anyway, but validation will catch it
        }
        
        return "+1\(digits)"
    }
    
    func sendOTP() async {
        isLoading = true
        errorMessage = nil
        
        // Validate phone number format
        let digits = mobileNumber.filter { $0.isNumber }
        guard digits.count == 10 else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Please enter a valid 10-digit phone number"
            }
            return
        }
        
        do {
            let phoneNumber = fullMobileNumber
            print("📱 Attempting to send OTP to: \(phoneNumber)")
            debugPrint("Phone number formatted: \(phoneNumber)")
            
            // Try to send OTP
            try await supabase.auth.signInWithOTP(phone: phoneNumber)
            
            print("✅ OTP request sent successfully")
            await MainActor.run {
                isLoading = false
                showVerificationView = true
            }
        } catch {
            // Log the full error for debugging
            print("❌ Error sending OTP:")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("Domain: \(nsError.domain)")
                print("Code: \(nsError.code)")
                print("UserInfo: \(nsError.userInfo)")
            }
            
            await MainActor.run {
                isLoading = false
                
                // Parse error message more carefully
                let errorMsg = error.localizedDescription
                let errorString = String(describing: error)
                
                // Check for specific error types
                if errorString.contains("otp_disabled") || errorString.contains("disabled") {
                    errorMessage = "Phone authentication is disabled in Supabase. Please enable it in your project settings."
                } else if errorString.contains("SMS") || errorString.contains("provider") || errorString.contains("configure") || errorString.contains("twilio") {
                    errorMessage = "SMS provider (Twilio) not configured. Please configure it in Supabase Dashboard → Authentication → Providers → Phone."
                } else if errorString.contains("rate limit") || errorString.contains("too many") {
                    errorMessage = "Too many requests. Please wait a moment and try again."
                } else if errorString.contains("invalid") && errorString.contains("phone") {
                    errorMessage = "Invalid phone number format. Please check your number."
                } else {
                    // Show the actual error message
                    errorMessage = "Failed to send code: \(errorMsg.isEmpty ? errorString : errorMsg)"
                }
            }
            debugPrint("Full error details: \(error)")
        }
    }
  
    
    func formatUSNumber(input: String) -> String {
        // Remove non-digit characters
        let digits = input.filter { $0.isNumber }

        var result = ""
        let count = digits.count

        if count > 0 {
            let start = digits.prefix(3)
            result += start
            if count > 3 { result += "-" }
        }
        if count > 3 {
            let middleStart = digits.index(digits.startIndex, offsetBy: 3)
            let middleEnd = count > 6 ? digits.index(middleStart, offsetBy: 3) : digits.endIndex
            let middle = digits[middleStart..<middleEnd]
            result += middle
            if count > 6 { result += "-" }
        }
        if count > 6 {
            let lastStart = digits.index(digits.startIndex, offsetBy: 6)
            let last = digits[lastStart...].prefix(4)
            result += last
        }

        return result
    }
}

struct OTPVerificationView: View{
    var fullNumber: String
    var onComplete: () -> ()
    @Binding var hasProfile: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var isOTPSent: Bool = false
    @State private var showVerificationField: Bool = false
    @State private var otpCode: String = ""
    @FocusState private var isFocused: Bool
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    var body: some View{
        ZStack{
            if showVerificationField{
                VStack(alignment: .leading, spacing: 12){
                    VStack(alignment: .leading, spacing: 8){
                        Text("Verification")
                            .font(.custom("Outfit-Medium", size: 30))
                            .foregroundStyle(Color("HauzFocus"))
                        
                        HStack(spacing: 4){
                            Text("Enter the 6-digit code.")
                                .font(.custom("Outfit-Medium", size: 18))
                                .foregroundStyle(Color("HauzFocus"))
                            
                            // resent button could be added below
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .trailing, content:{
                        Button("", systemImage: "xmark.circle.fill"){
                            dismiss()
                        }
                        .font(.title)
                        .tint(Color("HauzFocus"))
                        .offset(x: 10, y: -15)
                    })
                    .padding(.top, 10)
                    
                    VerificationField(type: .six, value: $otpCode){code in
                        Task { @MainActor in
                            if code.count == 6 {
                                await verifyOTP(code: code)
                            }
                        }
                        if code.count < 6 {
                            return .typing
                        }
                        return isVerifying ? .typing : .valid
                    }
                    .allowsHitTesting(false)
                    .padding(.top, 12)
                    .disabled(isVerifying)
                }
                .padding(20)
                .geometryGroup()
                .transition(.blurReplace)
                
            }
            
            // Animation view - always present, but fades out when verification field appears
            if !showVerificationField {
                VStack(spacing: 12){
                    // simple looping animation till ver.code is sent
                    let symbols = ["iphone", "ellipsis.message.fill", "paperplane.fill"]
                    PhaseAnimator(symbols){ symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 100))
                            .foregroundStyle(Color("HauzFocus"))
                            .contentTransition(.symbolEffect)
                            .frame(width: 150, height: 150)
                    } animation: {_ in
                            .linear(duration: 3)
                    }
                    .frame(height: 150)
                    
                    Text(isOTPSent ? "Verification Code Sent!" : "Sending Verification Code...")
                        .font(.custom("Outfit-Medium", size: 20))
                        .foregroundStyle(Color("HauzFocus"))
                }
                .geometryGroup()
                .transition(.blurReplace)
                .opacity(showVerificationField ? 0 : 1)
            }
        }
        .presentationDetents([.height(190)])
        .presentationBackground(.background)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled()
        .task{
            guard !isOTPSent else { return }
            // Mark that OTP was sent, but delay showing the verification field
            // so the animation can complete smoothly
            isOTPSent = true
            
            // Let the animation play for a bit longer (2-3 seconds) before showing verification field
            try? await Task.sleep(for: .seconds(2.5))
            
            // Now show the verification field with smooth transition
            withAnimation(.easeInOut(duration: 0.5)) {
                showVerificationField = true
                isFocused = true
            }
        }
        .animation(.snappy(duration: 0.25, extraBounce: 0), value: isOTPSent)
        .focused($isFocused)
    }
    
    
    
    func verifyOTP(code: String) async {
        guard code.count == 6 else { return }
        
        isVerifying = true
        errorMessage = nil
        
        do {
            // Verify the OTP code - use exact same phone number format as when sending
            debugPrint("Verifying OTP for: \(fullNumber) with code: \(code)")
            let session = try await supabase.auth.verifyOTP(phone: fullNumber, token: code, type: .sms)
            
            // Check if user has a profile
            let profileExists = await checkProfileExists(userId: session.user.id)
            
            await MainActor.run {
                hasProfile = profileExists
                isVerifying = false
                onComplete()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isVerifying = false
                let errorMsg = error.localizedDescription
                if errorMsg.contains("expired") || errorMsg.contains("invalid") {
                    errorMessage = "Invalid or expired verification code. Please try again."
                } else {
                    errorMessage = "Verification failed: \(errorMsg)"
                }
                otpCode = ""
                isFocused = true
            }
            debugPrint("Error verifying OTP for \(fullNumber): \(error)")
        }
    }
    
    func checkProfileExists(userId: UUID) async -> Bool {
        do {
            let profile: Profile = try await supabase
                .from("profiles") // Supabase table names are lowercase
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            // Consider profile complete if gender is set (username/fullName are optional today)
            return (profile.gender?.isEmpty == false)
        } catch {
            // Profile doesn't exist or has missing fields
            debugPrint("Profile check error: \(error)")
            return false
        }
    }
}

#Preview {
    GetInView()
}


/*
 Hoover Variable
 -- HooverVariable-Bold_Regular
 -- HooverVariable-Bold_Thin
 -- HooverVariable-Bold_Light
 -- HooverVariable-Bold_Medium
 -- HooverVariable-Bold

 
 */

/*
 // Test each one until one works
 .font(.custom("bernoru-blackultraexpanded", size: 16))
 .font(.custom("Bernoru-BlackUltraExpanded", size: 16))
 .font(.custom("Bernoru Black UltraExpanded", size: 16))
 
 */
