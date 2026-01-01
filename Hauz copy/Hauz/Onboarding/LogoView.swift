//
//  LogoView.swift
//  Hauz
//
//  Created by Islom Shamsiev on 2025/12/28.
//

import SwiftUI
import Supabase
import PostgREST

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var showIntro = false  // NEW: Show intro page after logo
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0.0
    @State private var isCheckingSession = true
    @State private var isLoggedIn = false
    @State private var hasProfile = false
    @State private var authStateTask: Task<Void, Never>?
    
    var body: some View {
        if isActive {
            if isLoggedIn && hasProfile {
                ContentView()
                    .onAppear {
                        startAuthStateListener()
                    }
            } else if showIntro {
                // NEW: Show IntroPage after logo splash
                IntroPageWrapper(
                    isLoggedIn: $isLoggedIn,
                    hasProfile: $hasProfile,
                    onGetStarted: {
                        showIntro = false
                        startAuthStateListener()
                    }
                )
            } else {
                GetInView(initialLoginState: isLoggedIn, initialProfileState: hasProfile)
                    .onAppear {
                        startAuthStateListener()
                    }
            }
        } else {
            LogoView(logoScale: $logoScale, logoOpacity: $logoOpacity)
                .task {
                    // Start session check immediately
                    await checkSession()
                    
                    // Animate the logo in
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.8)) {
                            logoScale = 1.0
                            logoOpacity = 1.0
                        }
                    }
                    
                    // Wait for minimum splash duration (so logo is visible)
                    try? await Task.sleep(for: .seconds(1.5))
                    
                    // Transition to intro page or main app
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            if !isLoggedIn {
                                // First time user -> show intro
                                showIntro = true
                            }
                            isActive = true
                        }
                    }
                }
        }
    }
    
    private func startAuthStateListener() {
        // Cancel any existing listener
        authStateTask?.cancel()
        
        // Start listening for auth state changes
        authStateTask = Task {
            for await state in supabase.auth.authStateChanges {
                switch state.event {
                case .signedOut:
                    await MainActor.run {
                        // Reset to login screen when user signs out
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isLoggedIn = false
                            hasProfile = false
                            isActive = false
                        }
                        
                        // Small delay then show login
                        Task {
                            try? await Task.sleep(for: .seconds(0.3))
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isActive = true
                                }
                            }
                        }
                    }
                case .signedIn:
                    // User signed in, check profile
                    if let user = state.session?.user {
                        let profileExists = await checkProfileExists(userId: user.id)
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isLoggedIn = true
                                hasProfile = profileExists
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func checkSession() async {
        do {
            let session = try await supabase.auth.session
            let profileExists = await checkProfileExists(userId: session.user.id)
            
            await MainActor.run {
                isLoggedIn = true
                hasProfile = profileExists
                isCheckingSession = false
            }
            
            if !profileExists {
                try? await supabase.auth.signOut()
                await MainActor.run {
                    isLoggedIn = false
                    hasProfile = false
                }
            }
        } catch {
            debugPrint("No cached session to restore: \(error)")
            await MainActor.run {
                isLoggedIn = false
                hasProfile = false
                isCheckingSession = false
            }
        }
    }
    
    private func checkProfileExists(userId: UUID) async -> Bool {
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            return (profile.gender?.isEmpty == false)
        } catch {
            debugPrint("Profile check error during restore: \(error)")
            return false
        }
    }
}

struct LogoView: View {
    @Binding var logoScale: CGFloat
    @Binding var logoOpacity: Double
    
    var body: some View {
        ZStack{
            Color("HauzBg").ignoresSafeArea(.all)
            
            VStack{
                Text("Hauz")
                    .font(.custom("bernoru-blackultraexpanded", size: 48))
                    .foregroundColor(Color("HauzFocus"))
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
        }
    }
}

// Wrapper for IntroPage that handles the "Get Started" action
struct IntroPageWrapper: View {
    @Binding var isLoggedIn: Bool
    @Binding var hasProfile: Bool
    let onGetStarted: () -> Void
    
    @State private var showGetIn = false
    @State private var introOffset: CGFloat = 0
    @State private var getInOffset: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            // IntroPage - slides to the left
            IntroPageWithAction(onGetStarted: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    introOffset = -UIScreen.main.bounds.width
                    getInOffset = 0
                }
                
                // Update state after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showGetIn = true
                    onGetStarted()
                }
            })
            .offset(x: introOffset)
            
            // GetInView - slides in from the right
            if getInOffset < UIScreen.main.bounds.width || showGetIn {
                GetInView(initialLoginState: isLoggedIn, initialProfileState: hasProfile)
                    .offset(x: getInOffset)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
