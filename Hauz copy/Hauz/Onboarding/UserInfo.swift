import SwiftUI
import Combine
import Supabase

// MARK: - Brand Data Models
// CUSTOMIZE: Add or remove brands, mark popular ones
struct BrandTag: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let isPopular: Bool
    
    init(_ name: String, popular: Bool = false) {
        self.name = name
        self.isPopular = popular
    }
}

let brandTags: [BrandTag] = [
    BrandTag("Nike", popular: true),
    BrandTag("Air Jordans", popular: true),
    BrandTag("Adidas", popular: true),
    BrandTag("New Balance", popular: true),
    BrandTag("ASICS"),
    BrandTag("Converse"),
    BrandTag("Puma"),
    BrandTag("Reebok"),
    BrandTag("Vans"),
    BrandTag("Hoka"),
    BrandTag("On Running"),
    BrandTag("Salomon"),
    BrandTag("UGG"),
    BrandTag("Balenciaga"),
    BrandTag("Rick Owens")
]

// MARK: - Main Onboarding Container
// This view manages the shared state across all onboarding screens
// CUSTOMIZE: Add more steps by increasing totalSteps
struct OnboardingContainer: View {
    @StateObject private var onboardingState = OnboardingState()
    
    var body: some View {
        NavigationStack {
            UserInfo()
                .environmentObject(onboardingState)
        }
    }
}

// MARK: - Onboarding State Manager
// ObservableObject that stores progress and user selections across all screens
// CUSTOMIZE: Add more properties here for additional user data
class OnboardingState: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 2  // CUSTOMIZE: 2 steps (Gender → Brands)
    @Published var selectedGender: String = ""
    @Published var selectedBrands: [BrandTag] = []
    
    // Computed property for smooth progress calculation
    var progress: Double {
        return Double(currentStep) / Double(totalSteps)
    }
    
    // CUSTOMIZE: Add methods to update user data
    func selectGender(_ gender: String) {
        selectedGender = gender
        print("✅ Selected gender: \(gender)")
    }
    
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep += 1
        }
    }
    
    func previousStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }
}

// MARK: - First Onboarding Screen (Gender Selection)
struct UserInfo: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            Color("HauzBg")
                .ignoresSafeArea(edges: .all)
            
            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressBar(progress: onboardingState.progress)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header section
                        VStack(spacing: 12) {
                            Text("Welcome to Hauz! Let's get to know you.")
                                .font(.custom("HooverVariable-Bold_Regular", size: 20))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)
                            
                            Text("Which section would you like to shop in?.")
                                .font(.custom("HooverVariable-Bold_Thin", size: 28))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Gender selection cards
                        VStack(spacing: 16) {
                            GenderSelectionCard(
                                icon: "figure.stand",
                                label: "Male",
                                color: .blue,
                                isSelected: onboardingState.selectedGender == "Male"
                            ) {
                                onboardingState.selectGender("Male")
                            }
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                            .animation(.easeOut(duration: 0.5).delay(0.1), value: showContent)
                            
                            GenderSelectionCard(
                                icon: "figure.stand.dress",
                                label: "Female",
                                color: .pink,
                                isSelected: onboardingState.selectedGender == "Female"
                            ) {
                                onboardingState.selectGender("Female")
                            }
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)
                            
                            
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        // Continue button - always visible, disabled when no selection
                        NavigationLink(destination: UserInfo2().environmentObject(onboardingState)) {
                            HStack {
                                Text("Continue")
                                    .font(.custom("HooverVariable-Bold_Regular", size: 18))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        onboardingState.selectedGender.isEmpty
                                            ? Color.gray.opacity(0.3)
                                            : Color("HauzFocus")
                                    )
                            )
                            .shadow(
                                color: onboardingState.selectedGender.isEmpty
                                    ? Color.clear
                                    : Color("HauzFocus").opacity(0.3),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                        }
                        .disabled(onboardingState.selectedGender.isEmpty)
                        .opacity(onboardingState.selectedGender.isEmpty ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: onboardingState.selectedGender.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Text("Don't worry, you can change the filters later on!")
                            .font(.custom("HooverVariable-Bold_Regular", size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.top, 10)
                            .opacity(showContent ? 1 : 0)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            onboardingState.currentStep = 0
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }
}

// MARK: - Gender Selection Card Component
struct GenderSelectionCard: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(isSelected ? color : color.opacity(0.6))
                
                Text(label)
                    .font(.custom("HooverVariable-Bold_Regular", size: 18))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? color : Color.white.opacity(0.3),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 15 : 8,
                x: 0,
                y: isSelected ? 8 : 4
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Second Onboarding Screen (Brand Selection)
struct UserInfo2: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @Environment(\.dismiss) var dismiss
    @State private var showContent = false
    
    // Filter brands based on search
    var filteredBrands: [BrandTag] {
        brandTags
    }
    
    var body: some View {
        ZStack {
            Color("HauzLight")
                .ignoresSafeArea(edges: .all)
            
            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressBar(progress: onboardingState.progress)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header section
                        VStack(spacing: 12) {
                            Text("Great! Now select your favorite brands.")
                                .font(.custom("HooverVariable-Bold_Regular", size: 20))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)
                            
                            Text("It will help us personalize your experience. You can change this at any time.")
                                .font(.custom("HooverVariable-Bold_Light", size: 15))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: showContent)
                        
                         // Popular section header
                         HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("HauzFocus"))
                                Text("Popular Brands")
                                    .font(.custom("HooverVariable-Bold_Medium", size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                        
                        // Brand chips
                        ChipsView(
                            spacing: 12,
                            tags: filteredBrands,
                            content: { tag, isSelected in
                                EnhancedChipView(
                                    brand: tag,
                                    isSelected: isSelected
                                )
                            },
                            didChangeSelection: { selection in
                                onboardingState.selectedBrands = selection
                                print("✅ Selected brands: \(selection.map { $0.name })")
                            },
                            selectedTags: $onboardingState.selectedBrands
                        )
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 20)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
                        
                        // Selection counter
                        if !onboardingState.selectedBrands.isEmpty {
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: onboardingState.selectedBrands.count >= 3 ? "checkmark.circle.fill" : "circle.dashed")
                                        .foregroundColor(onboardingState.selectedBrands.count >= 3 ? Color("HauzFocus") : .gray)
                                    
                                    Text("\(onboardingState.selectedBrands.count) of 5 selected")
                                        .font(.custom("HooverVariable-Bold_Regular", size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        onboardingState.selectedBrands.removeAll()
                                    }
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }) {
                                    Text("Clear all")
                                        .font(.custom("HooverVariable-Bold_Medium", size: 14))
                                        .foregroundColor(Color("HauzFocus"))
                                }
                            }
                            .padding(.horizontal, 20)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Continue button
                        NavigationLink(destination: OnboardingSucceeded().environmentObject(onboardingState)) {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.custom("HooverVariable-Bold_Medium", size: 18))
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        onboardingState.selectedBrands.count < 3
                                            ? LinearGradient(
                                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            : LinearGradient(
                                                colors: [
                                                    Color("HauzFocus"),
                                                    Color("HauzFocus").opacity(0.85)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                    )
                            )
                            .shadow(color: onboardingState.selectedBrands.count < 3 ? Color.clear : Color("HauzFocus").opacity(0.4), radius: 15, x: 0, y: 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .disabled(onboardingState.selectedBrands.count < 3)
                        .simultaneousGesture(TapGesture().onEnded {
                            if onboardingState.selectedBrands.count >= 3 {
                                onboardingState.nextStep()
                            }
                        })
                        
                        Text("Don't see your brand? You can add more later!")
                            .font(.custom("HooverVariable-Bold_Light", size: 13))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .opacity(showContent ? 1 : 0)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    onboardingState.previousStep()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.custom("HooverVariable-Bold_Regular", size: 16))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            onboardingState.currentStep = 1
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }
}

// MARK: - Chips View Component
struct ChipsView<Content: View, Tag: Equatable>: View where Tag: Hashable {
    var spacing: CGFloat = 12
    var tags: [Tag]
    var animation: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    @ViewBuilder var content: (Tag, Bool) -> Content
    var didChangeSelection: ([Tag]) -> ()
    @Binding var selectedTags: [Tag]
    
    var body: some View {
        CustomChipLayout(spacing: spacing) {
            ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                content(tag, selectedTags.contains(tag))
                    .contentShape(.rect)
                    .onTapGesture {
                        handleTap(on: tag)
                    }
            }
        }
    }
    
    private func handleTap(on tag: Tag) {
        withAnimation(animation) {
            if selectedTags.contains(tag) {
                selectedTags.removeAll(where: { $0 == tag })
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                selectedTags.append(tag)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
        didChangeSelection(selectedTags)
    }
}

// MARK: - Custom Chip Layout
fileprivate struct CustomChipLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        return .init(width: width, height: maxHeight(proposal: proposal, subviews: subviews))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        
        for subview in subviews {
            let fitSize = subview.sizeThatFits(proposal)
            
            if (origin.x + fitSize.width) > bounds.maxX {
                origin.x = bounds.minX
                origin.y += fitSize.height + spacing
                subview.place(at: origin, proposal: proposal)
                origin.x += fitSize.width + spacing
            } else {
                subview.place(at: origin, proposal: proposal)
                origin.x += fitSize.width + spacing
            }
        }
    }
    
    private func maxHeight(proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        var origin: CGPoint = .zero
        
        for subview in subviews {
            let fitSize = subview.sizeThatFits(proposal)
            
            if (origin.x + fitSize.width) > (proposal.width ?? 0) {
                origin.x = 0
                origin.y += fitSize.height + spacing
                origin.x += fitSize.width + spacing
            } else {
                origin.x += fitSize.width + spacing
            }
            
            if subview == subviews.last {
                origin.y += fitSize.height
            }
        }
        return origin.y
    }
}

// MARK: - Enhanced Chip View
struct EnhancedChipView: View {
    let brand: BrandTag
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(brand.name)
                .font(.custom("HooverVariable-Bold_Regular", size: 15))
                .foregroundStyle(isSelected ? .white : Color.primary)
            
            if brand.isPopular && !isSelected {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color("HauzFocus").opacity(0.8))
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                brand.isPopular && !isSelected
                                    ? Color("HauzFocus").opacity(0.3)
                                    : Color.gray.opacity(0.2),
                                lineWidth: brand.isPopular && !isSelected ? 1.5 : 1
                            )
                    )
                    .opacity(!isSelected ? 1 : 0)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("HauzFocus"),
                                Color("HauzFocus").opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .shadow(
            color: isSelected
                ? Color("HauzFocus").opacity(0.35)
                : Color.black.opacity(0.04),
            radius: isSelected ? 10 : 4,
            x: 0,
            y: isSelected ? 6 : 2
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Progress Bar Component
struct OnboardingProgressBar: View {
    var progress: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 8)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("HauzFocus"),
                                Color("HauzFocus").opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * progress,
                        height: 8
                    )
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                if progress > 0 && progress < 1 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60, height: 8)
                        .offset(x: -30)
                        .mask(
                            Capsule()
                                .frame(width: geo.size.width * progress, height: 8)
                        )
                }
            }
        }
        .frame(height: 8)
    }
}

struct OnboardingSucceeded: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var localProgress: Double = 0.0
    @State private var isLoading = true
    @State private var showSuccess = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var navigateToContentView = false
    @State private var saveError: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color("HauzLight").ignoresSafeArea(edges: .all)
            
            VStack(spacing: 0) {
                OnboardingProgressBar(progress: localProgress)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                if isLoading {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        LoadingView()
                        
                        Text("We are personalizing your feed. Please give us a moment.")
                            .font(.custom("HooverVariable-Bold_Regular", size: 16))
                            .foregroundColor(Color("HauzFocus"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        if let saveError {
                            Text(saveError)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .transition(.opacity)
                    
                    Spacer()
                } else if showSuccess {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color("HauzFocus").opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(Color("HauzFocus"))
                                .scaleEffect(checkmarkScale)
                        }
                        
                        Text("Enjoy the experience!")
                            .font(.custom("HooverVariable-Bold_Regular", size: 24))
                            .foregroundColor(Color("HauzFocus"))
                    }
                    .transition(.scale.combined(with: .opacity))
                    
                    Spacer()
                }
                
                if showSuccess {
                    Button {
                        // Mark onboarding as complete
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        // Trigger navigation to ContentView
                        navigateToContentView = true
                    } label: {
                        Text("Get Started")
                            .font(.custom("HooverVariable-Bold_Regular", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("HauzFocus"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Hidden NavigationLink triggered by state
            // Navigate to the main app when onboarding completes
            .navigationDestination(isPresented: $navigateToContentView) {
                ContentView()
                    .navigationBarBackButtonHidden(true)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                localProgress = onboardingState.progress
            }
            
            // Start the personalization process
            Task {
                await personalizeFeed()
            }
        }
    }
    
    // MARK: - Backend Integration Placeholder
    private func personalizeFeed() async {
        do {
            try await upsertProfile()
            
            // Once data is saved, show success animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isLoading = false
                showSuccess = true
            }
            
            // Animate checkmark with a slight delay
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
            }
        } catch {
            // Surface error to the user and keep loading view
            await MainActor.run {
                saveError = error.localizedDescription
            }
            debugPrint("Failed to upsert profile: \(error)")
        }
    }

    private func upsertProfile() async throws {
        // Ensure we have an authenticated user
        let session = try await supabase.auth.session
        let userId = session.user.id
        let phone = session.user.phone

        let payload = ProfileUpsert(
            id: userId,
            gender: onboardingState.selectedGender,
            brands: onboardingState.selectedBrands.map { $0.name },
            phone_number: phone,
            price_min: nil,
            price_max: nil
        )

        _ = try await supabase
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .select()
            .single()
            .execute()
    }
}

// MARK: - Supabase DTOs
private struct ProfileUpsert: Encodable {
    let id: UUID
    let gender: String
    let brands: [String]
    let phone_number: String?
    let price_min: Double?
    let price_max: Double?
}

private enum ProfileSaveError: LocalizedError {
    case noSession
    
    var errorDescription: String? {
        switch self {
        case .noSession:
            return "You're signed out. Please log in again."
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingContainer()
}
