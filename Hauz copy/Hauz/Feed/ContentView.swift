import SwiftUI

// MARK: - Custom Tab Enum
/// Defines the available tabs in the app with their associated properties
enum CustomTab: String, CaseIterable{
    case feed = "Feed"
    case profile = "Profile"
    
    /// Returns the SF Symbol name for the tab icon
    var symbol: String{
        switch self{
            case .feed: return "hanger"
            case .profile: return "person.crop.circle"
        }
    }
    
    /// Returns the SF Symbol name for the action button on each tab
    /// Feed tab shows a filter icon, Profile tab shows a settings icon
    var actionSymbol: String{
        switch self{
        case .feed: return "slider.horizontal.3"
        case .profile: return "gearshape"
        }
    }
    
    /// Returns the index of the tab in the allCases array
    /// Used for animations and tab transitions
    var index: Int{
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - Main Content View
struct ContentView: View {
    /// Tracks which tab is currently active
    /// Used to switch between Feed and Profile views
    @State private var activeTab: CustomTab = .feed
    
    var body: some View {
        // Main TabView that switches between Feed and Profile
        TabView(selection: $activeTab){
            Tab.init(value: .feed){
                MainView()
                    .toolbarVisibility(.hidden, for: .tabBar) // Hide default tab bar
            }
            Tab.init(value: .profile){
                ProfileView()
                    .toolbarVisibility(.hidden, for: .tabBar) // Hide default tab bar
            }
        }
        // Add custom tab bar at the bottom with padding
        .safeAreaInset(edge: .bottom, spacing: 0){
            CustomTabBarView()
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Custom Tab Bar
    /// Creates the custom glass-effect tab bar at the bottom of the screen
    /// Contains tab buttons on the left and action buttons on the right
    @ViewBuilder
    func CustomTabBarView() -> some View{
        GlassEffectContainer(spacing: 10){
            HStack(spacing: 10){
                // Left side: Tab selection buttons (Feed/Profile)
                GeometryReader{
                    CustomTabBar(size: $0.size, activeTab: $activeTab){ tab in
                        VStack(spacing: 3){
                            // Tab icon
                            Image(systemName: tab.symbol)
                                .font(.title2)
                            
                            // Tab label
                            Text(tab.rawValue)
                                .font(.custom("HooverVariable-Bold_Regular", size: 12))
                                .fontWeight(tab == self.activeTab ? .bold : .regular)
                                
                        }
                        .symbolVariant(.fill) // Use filled variant of SF Symbols
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                
                // Right side: Action buttons (Filter/Settings)
                // This ZStack switches between different action buttons based on active tab
                ZStack {
                    ForEach(CustomTab.allCases, id: \.rawValue){ tab in
                        // Only show the action button for the currently active tab
                        if activeTab == tab {
                            if tab == .feed {
                                // Filter Menu Button for Feed tab
                                // Uses CustomMenuView to show filter options in a popover
                                CustomMenuView(style: .glass) {
                                    Image(systemName: tab.actionSymbol)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(Color("HauzFocus"))
                                        .frame(width: 55, height: 55)
                                } content: {
                                    FilterView() // Show filter menu content
                                }
                            } else if tab == .profile {
                                // Settings Menu Button for Profile tab
                                // Uses CustomMenuView to show settings options in a popover
                                CustomMenuView(style: .glass) {
                                    Image(systemName: tab.actionSymbol)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(Color("HauzFocus"))
                                        .frame(width: 55, height: 55)
                                } content: {
                                    SettingsMenuView() // Show settings menu content
                                }
                            }
                        }
                    }
                }
                // Make the action button circular with glass effect
                .glassEffect(.regular.interactive(), in: .circle)
                // Smooth animation when switching tabs
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: activeTab)
            }
        }
        .frame(height: 55) // Fixed height for tab bar
    }
    
    // MARK: - Settings Menu View
    /// Displays the settings menu with various action options
    /// Appears as a popover when the settings button is tapped
    @ViewBuilder
    func SettingsMenuView() -> some View {
        VStack(spacing: 20) {
            // Menu title
            Text("Settings")
                .font(.custom("HooverVariable-Bold_Medium", size: 25))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Settings options container
            VStack(alignment: .leading, spacing: 12){
                // Each row represents a different settings action
                RowView("paperplane.fill", "Share")
                RowView("message.badge", "Suggestions")
                RowView("chart.bar", "Data")
                RowView("door.left.hand.open", "Log Out")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial) // Glass effect background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1) // Subtle border
            )
            
            // Helper text at bottom
            Text("Choose an option from the menu")
                .font(.custom("HooverVariable-Bold_Thin", size: 11))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(20)
        .frame(width: 280) // Fixed width for consistent appearance
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial) // Glass effect for entire menu
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10) // Subtle shadow for depth
    }
    
    // MARK: - Row View for Menu Items
    /// Creates a menu item row with an icon and title
    /// Used in both settings and filter menus
    /// - Parameters:
    ///   - image: SF Symbol name for the icon
    ///   - title: Display text for the menu item
    @ViewBuilder
    func RowView(_ image: String, _ title: String) -> some View{
        Button {
            // TODO: Add action handling for each menu item
        } label: {
            HStack(spacing: 12){
                // Icon with circular background
                Image(systemName: image)
                    .foregroundStyle(Color("HauzFocus"))
                    .font(.title3)
                    .symbolVariant(.fill) // Use filled variant
                    .frame(width: 45, height: 45)
                    .background(.background, in: .circle)
                
                // Menu item title
                Text(title)
                    .foregroundStyle(Color("HauzFocus"))
                    .font(.custom("HooverVariable-Bold", size: 18))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .contentShape(.rect) // Make entire row tappable
        }
    }
}

// MARK: - View Extensions
extension View{
    /// Creates a blur fade effect for smooth transitions between views
    /// Used for animating the action button icons when switching tabs
    /// - Parameter status: If true, view is visible; if false, view is blurred and hidden
    @ViewBuilder
    func blurFade(_ status: Bool)-> some View{
        self
            .compositingGroup()
            .blur(radius: status ? 0 : 10) // Apply blur when hidden
            .opacity(status ? 1 : 0) // Fade in/out
    }
}

// MARK: - Custom Menu View
/// A reusable button component that displays content in a popover
/// Used for both filter and settings menus
/// - Parameters:
///   - Label: The view to display as the button
///   - Content: The view to display in the popover
struct CustomMenuView<Label: View, Content: View>: View {
    /// The style of the menu button (glass or prominent)
    var style: CustomMenuStyle = .glass
    /// Whether to enable haptic feedback on tap
    var isHapticsEnabled: Bool = true
    
    @ViewBuilder var label: Label // Button appearance
    @ViewBuilder var content: Content // Popover content
    
    /// Triggers haptic feedback when toggled
    @State private var haptics: Bool = false
    /// Controls whether the popover is shown
    @State private var isExpanded: Bool = false
    
    var body: some View{
        Button{
            // Trigger haptic feedback if enabled
            if isHapticsEnabled{
                haptics.toggle()
            }
            // Toggle popover with smooth animation
            withAnimation(.smooth(duration: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            label
        }
        .applyStyle(style) // Apply the specified button style
        .popover(isPresented: $isExpanded){
            content
                .presentationCompactAdaptation(.popover) // Always show as popover
        }
        .sensoryFeedback(.selection, trigger: haptics) // Haptic feedback
    }
}

// MARK: - Custom Menu Style Enum
/// Defines available styles for CustomMenuView buttons
enum CustomMenuStyle: String, CaseIterable {
    case glass = "Glass"
    case glassProminent = "Glass Prominent"
}

// MARK: - Style Application Extension
fileprivate extension View{
    /// Applies the specified CustomMenuStyle to a view
    /// - Parameter style: The style to apply
    @ViewBuilder
    func applyStyle(_ style: CustomMenuStyle) -> some View {
        switch style{
        case .glass:
            self.buttonStyle(.borderless) // Clean borderless style
        case .glassProminent:
            self.buttonStyle(.glassProminent) // Prominent glass effect
        }
    }
}

// MARK: - Filter View
/// The main filter menu view with price range and gender selection
/// Displayed as a popover from the filter button on the Feed tab
struct FilterView: View {
    // MARK: Price Range State
    /// Lower bound of the price range slider
    @State private var lowerLimit: Double = 50
    /// Upper bound of the price range slider
    @State private var upperLimit: Double = 300
    
    // MARK: Gender Selection
    /// Enum defining gender options for filtering
    enum Gender: Int, CaseIterable {
        case male, female, preferNotToSay
        
        /// Display label for each gender option
        var label: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .preferNotToSay: return "Other"
            }
        }
        
        /// Color associated with each gender option
        /// Used for the selection highlight
        var color: Color {
            switch self{
            case .male: return .blue
            case .female: return .pink
            case .preferNotToSay: return Color("HauzFocus")
            }
        }
    }
    /// Currently selected gender filter
    @State private var selectedGender: Gender = .male
    
    /// SF Symbol icons for each gender option
    private let genderIcons: [Gender: String] = [
        .male: "figure.stand",
        .female: "figure.stand.dress",
        .preferNotToSay: "person.fill.questionmark"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: Header
            Text("Filter Preferences")
                .font(.custom("HooverVariable-Bold_Medium", size: 25))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // MARK: Price Range Section
            VStack(spacing: 12) {
                // Section title
                HStack {
                    Text("Price Range")
                        .font(.custom("HooverVariable-Bold_Regular", size: 15))
                    Spacer()
                }
                
                // Display current price range values
                HStack {
                    Text("$\(Int(lowerLimit))")
                        .font(.custom("HooverVariable-Bold_Medium", size: 20))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("$\(Int(upperLimit))")
                        .font(.custom("HooverVariable-Bold_Medium", size: 20))
                        .foregroundStyle(.primary)
                }
                
                // Custom range slider component
                RangeSlider(
                    lowerValue: $lowerLimit,
                    upperValue: $upperLimit,
                    minValue: 0,
                    maxValue: 1000
                )
                .frame(height: 24)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial) // Glass effect
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1) // Subtle border
            )
            
            // MARK: Gender Selection Section
            VStack(spacing: 12) {
                // Section title
                HStack {
                    Text("Gender")
                        .font(.custom("HooverVariable-Bold_Regular", size: 15))
                    Spacer()
                }
                
                // Gender selection buttons
                HStack(spacing: 0) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Button {
                            // Animate gender selection change
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedGender = gender
                            }
                        } label: {
                            VStack(spacing: 8) {
                                // Gender icon
                                Image(systemName: genderIcons[gender]!)
                                    .font(.title2)
                                    .foregroundStyle(selectedGender == gender ? .white : .primary)
                                
                                // Gender label
                                Text(gender.label)
                                    .font(.custom("HooverVariable-Bold_Regular", size: 13))
                                    .fontWeight(selectedGender == gender ? .semibold : .regular)
                                    .foregroundStyle(selectedGender == gender ? .white : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    // Show colored background for selected gender
                                    if selectedGender == gender {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(gender.color)
                                            .shadow(color: gender.color.opacity(0.4), radius: 8, x: 0, y: 4)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            )
                            .contentShape(Rectangle()) // Make entire area tappable
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove default button styling
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial) // Glass effect background
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1) // Subtle border
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial) // Glass effect
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1) // Subtle border
            )
            
            // MARK: Apply Button
            Button {
                // TODO: Implement filter application logic
                // Use lowerLimit, upperLimit, and selectedGender to filter results
            } label: {
                Text("Apply Filters")
                    .font(.custom("HooverVariable-Bold_Medium", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(Color("HauzFocus"))
            .controlSize(.large)
            
            // MARK: Helper Text
            Text("Adjust your preferences and tap Apply to see results")
                .font(.custom("HooverVariable-Bold_Thin", size: 11))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(20)
        .frame(width: 320) // Fixed width for consistent appearance
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial) // Glass effect for entire menu
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10) // Subtle shadow for depth
    }
}

// MARK: - Range Slider Component
/// A custom two-thumb range slider for selecting a value range
/// Used in the filter view for price range selection
struct RangeSlider: View {
    /// Binding to the lower bound of the range
    @Binding var lowerValue: Double
    /// Binding to the upper bound of the range
    @Binding var upperValue: Double
    
    /// Minimum possible value for the slider
    let minValue: Double
    /// Maximum possible value for the slider
    let maxValue: Double
    
    /// Visual properties
    let height: CGFloat = 4 // Track height
    let thumbSize: CGFloat = 18 // Thumb diameter
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // MARK: Background Track
                // Gray track showing full range
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                
                // MARK: Active Range Track
                // Colored track showing selected range
                Capsule()
                    .fill(Color("HauzFocus"))
                    .frame(
                        width: thumbPosition(value: upperValue, width: geo.size.width)
                        - thumbPosition(value: lowerValue, width: geo.size.width),
                        height: height
                    )
                    .offset(x: thumbPosition(value: lowerValue, width: geo.size.width))
                
                // MARK: Lower Thumb
                // Left thumb for minimum value
                thumb
                    .offset(x: thumbPosition(value: lowerValue, width: geo.size.width) - thumbSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newValue = valueFromDrag(gesture.location.x, width: geo.size.width)
                                // Prevent lower thumb from crossing upper thumb
                                lowerValue = min(max(minValue, newValue), upperValue)
                            }
                    )
                
                // MARK: Upper Thumb
                // Right thumb for maximum value
                thumb
                    .offset(x: thumbPosition(value: upperValue, width: geo.size.width) - thumbSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newValue = valueFromDrag(gesture.location.x, width: geo.size.width)
                                // Prevent upper thumb from crossing lower thumb
                                upperValue = max(min(maxValue, newValue), lowerValue)
                            }
                    )
            }
        }
        .frame(height: thumbSize)
    }
    
    // MARK: Thumb View
    /// Visual appearance of the slider thumbs
    private var thumb: some View {
        Circle()
            .fill(Color.white)
            .frame(width: thumbSize, height: thumbSize)
            .overlay(
                Circle()
                    .stroke(Color("HauzFocus"), lineWidth: 2) // Colored border
            )
            .shadow(radius: 1) // Subtle shadow for depth
    }
    
    // MARK: Helper Functions
    
    /// Converts a slider value to its X position on screen
    /// - Parameters:
    ///   - value: The slider value to convert
    ///   - width: The total width of the slider
    /// - Returns: The X position in points
    private func thumbPosition(value: Double, width: CGFloat) -> CGFloat {
        CGFloat((value - minValue) / (maxValue - minValue)) * width
    }
    
    /// Converts a drag X position to a slider value
    /// - Parameters:
    ///   - x: The X position from the drag gesture
    ///   - width: The total width of the slider
    /// - Returns: The corresponding slider value
    private func valueFromDrag(_ x: CGFloat, width: CGFloat) -> Double {
        let percentage = min(max(0, x / width), 1) // Clamp to 0-1
        return minValue + Double(percentage) * (maxValue - minValue)
    }
}

#Preview{
    ContentView()
}
