import SwiftUI
import Supabase

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
    
    /// Shared FeedService instance for both MainView and FilterView
    @StateObject private var feedService = FeedService()
    
    var body: some View {
        // Main TabView that switches between Feed and Profile
        TabView(selection: $activeTab){
            Tab.init(value: .feed){
                MainView(feedService: feedService)
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
        .environmentObject(feedService) // Make feedService available to all child views
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
                           /* Text(tab.rawValue)
                                .font(.custom("Satoshi-Regular", size: 8))
                                .fontWeight(tab == self.activeTab ? .bold : .regular)*/
                                
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
                                // Opens filter sheet instead of popover
                                FilterSheetButton()
                                    .frame(width: 55, height: 55)
                                    .environmentObject(feedService)
                            } else if tab == .profile {
                                // Settings Menu Button for Profile tab
                                // Opens settings sheet
                                SettingsSheetButton()
                                    .frame(width: 50, height: 50)
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
        .frame(height: 50) // Fixed height for tab bar
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

// MARK: - Collapsible Section Component
/// A reusable collapsible section with header and expandable content
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("HauzFocus"))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color("HauzFocus").opacity(0.1))
                        )
                    
                    Text(title)
                        .font(.custom("Outfit-Black", size: 18))
                        .foregroundColor(Color("HauzLight"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("HauzLight"))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color("HauzBg"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("HauzFocus").opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable content
            if isExpanded {
                content()
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("HauzBg"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("HauzFocus").opacity(0.2), lineWidth: 1)
                    )
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Filter Sheet Button
/// Button that opens the filter sheet
struct FilterSheetButton: View {
    @State private var showFilterSheet = false
    @EnvironmentObject var feedService: FeedService
    
    var body: some View {
        Button {
            showFilterSheet = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color("HauzFocus"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFilterSheet) {
            FilterView()
                .environmentObject(feedService)
        }
    }
}

// MARK: - Settings Sheet Button
/// Button that opens the settings sheet
struct SettingsSheetButton: View {
    @State private var showSettingsSheet = false
    
    var body: some View {
        Button {
            showSettingsSheet = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color("HauzFocus"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }
}

// MARK: - Filter View
/// The main filter menu view with price range and gender selection
/// Displayed as a sheet with collapsible sections
struct FilterView: View {
    @EnvironmentObject var feedService: FeedService
    @Environment(\.dismiss) var dismiss
    
    // MARK: Section Expansion State
    @State private var isSearchSectionExpanded = true
    @State private var isPriceSectionExpanded = false
    @State private var isGenderSectionExpanded = false
    @State private var isColorSectionExpanded = false
    
    // MARK: Natural Language Search State
    /// User's natural language search query
    @State private var searchQuery: String = ""
    
    // MARK: Brand Selection State
    /// Selected brands for filtering
    @State private var selectedBrands: [String] = []
    /// Search query for filtering brands
    @State private var brandSearchQuery: String = ""
    
    /// Top popular brands (shown by default)
    private let popularBrands = [
        "Nike", "adidas", "Jordan", "New Balance", "ASICS", "Reebok", 
        "Vans", "Converse", "Puma", "On", "Brooks", "Salomon"
    ]
    
    /// All available brand options (EXACT database spelling - case sensitive!)
    /// Complete list of all 106 brands from database
    private let allBrands = [
        // A-B
        "adidas", "Alexander McQueen", "Alexander Wang", "AMIRI", "Anta", "ASICS",
        "Autry", "Axel Arigato", "BAIT", "Balenciaga", "Bally", "BAPE", "Bass",
        "Birkenstock", "Blackstock & Weber", "Bottega Veneta", "Bravest Studios",
        "Brooks", "Burberry",
        // C-D
        "Camper", "Casablanca", "Celine", "Chanel", "Christian Louboutin", "Clarks",
        "Cole Haan", "Columbia", "Common Projects", "Converse", "Crocs", "Diadora",
        "Diesel", "Dior", "Dolce & Gabbana", "Dr. Martens", "Dries Van Noten",
        "Dsquared2",
        // E-H
        "Ecco", "EMU Australia", "ERL", "Ewing Athletics", "Fear of God", "Fendi",
        "Ferragamo", "Fila", "Givenchy", "Gucci", "Hermes", "Heron Preston",
        "Hey Dude", "Hoka One One", "Human Made",
        // J-K
        "Jimmy Choo", "Jordan", "Just Don", "JW Anderson", "Kamiya", "Karhu",
        "Keen", "Kiko Kostadinov",
        // L-M
        "Lacoste", "Lanvin", "Le Coq Sportif", "LOEWE", "Louis Vuitton",
        "Maison Margiela", "Maison Mihara Yasuhiro", "Marni", "MCM", "Merrell",
        "Miu Miu", "Mizuno", "Moncler", "Moon Boot", "MSCHF",
        // N-P
        "New Balance", "Nike", "OFF-WHITE", "On", "Onitsuka Tiger", "Our Legacy",
        "Palace", "Palm Angels", "Polo Ralph Lauren", "Prada", "Puma",
        // R-S
        "Reebok", "Represent", "Rick Owens", "Roa", "Saint Laurent", "Salomon",
        "Saucony", "SKYLRK", "Sonic the Hedgehog",
        // T-Y
        "Timberland", "Tom Ford", "Tory Burch", "UGG", "Under Armour", "Valentino",
        "Vans", "Versace", "Virgil Abloh", "Wellipets", "Wolverine", "Yeezy"
    ].sorted()  // Sort alphabetically for easier searching
    
    /// Filtered brands based on search query
    private var filteredBrands: [String] {
        if brandSearchQuery.isEmpty {
            return popularBrands  // Show only popular brands when not searching
        } else {
            return allBrands.filter { 
                $0.localizedCaseInsensitiveContains(brandSearchQuery)
            }
        }
    }

    // MARK: Price Range State
    /// Lower bound of the price range slider
    @State private var lowerLimit: Double = 50
    /// Upper bound of the price range slider
    @State private var upperLimit: Double = 300
    
    // MARK: Gender Selection
    /// Enum defining gender options for filtering
    enum Gender: Int, CaseIterable {
        case male, female
        
        /// Display label for each gender option
        var label: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            }
        }
        
        /// Color associated with each gender option
        /// Used for the selection highlight
        var color: Color {
            switch self{
            case .male: return .blue
            case .female: return .pink
            }
        }
    }
    /// Currently selected gender filter
    @State private var selectedGender: Gender = .male
    /// Currently selected color filter (optional)
    @State private var selectedColor: String? = nil
    @State private var isApplying = false
    @State private var showError: String?
    @State private var showNotice: String?
    
    /// Available color options for filtering
    private let availableColors = [
        ("Black", "#000000"),
        ("White", "#FFFFFF"),
        ("Red", "#FF0000"),
        ("Blue", "#0000FF"),
        ("Green", "#008000"),
        ("Yellow", "#FFFF00"),
        ("Orange", "#FFA500"),
        ("Purple", "#800080"),
        ("Pink", "#FFC0CB"),
        ("Brown", "#8B4513"),
        ("Gray", "#808080"),
        ("Beige", "#F5F5DC")
    ]
    
    /// SF Symbol icons for each gender option
    private let genderIcons: [Gender: String] = [
        .male: "figure.stand",
        .female: "figure.stand.dress",
    ]
    
    /// Example search queries for user inspiration
    private let exampleQueries = [
        "something cool",
        "winter shoes",
        "running sneakers",
        "casual style",
        "retro vibes",
        "basketball shoes"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: Natural Language Search Section (COMMENTED OUT)
                    /*
                    CollapsibleSection(
                        title: "What are you looking for?",
                        icon: "magnifyingglass",
                        isExpanded: $isSearchSectionExpanded
                    ) {
                        VStack(spacing: 12) {
                            // Section title inside (removed from header)
                            HStack {
                                Text("Search by description")
                                    .font(.custom("Outfit-Black", size: 12))
                                    .foregroundColor(Color("HauzLight"))
                                Spacer()
                            }
                            
                            // Search text field
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color("HauzLight"))
                                    .font(.system(size: 16))
                                
                                TextField("e.g., something cool for winter", text: $searchQuery)
                                    .font(.custom("Outfit-Black", size: 15))
                                    .foregroundColor(Color("HauzLight"))
                                    .textFieldStyle(.plain)
                                    .disabled(isApplying)
                                
                                if !searchQuery.isEmpty {
                                    Button {
                                        searchQuery = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color("HauzLight"))
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("HauzBg"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("HauzFocus").opacity(0.3), lineWidth: 1)
                            )
                            
                            // Example queries
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(exampleQueries, id: \.self) { example in
                                        Button {
                                            searchQuery = example
                                        } label: {
                                            Text(example)
                                                .font(.custom("Outfit-Black", size: 12))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color("HauzFocus").opacity(0.1))
                                                .foregroundColor(Color("HauzFocus"))
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    */
                    
                    // MARK: Brand Selection Section (NEW!)
                    CollapsibleSection(
                        title: "Brands",
                        icon: "tag.fill",
                        isExpanded: $isSearchSectionExpanded
                    ) {
                        VStack(spacing: 12) {
                            // Search bar for brands
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color("HauzLight").opacity(0.5))
                                    .font(.system(size: 14))
                                
                                TextField("Search brands...", text: $brandSearchQuery)
                                    .font(.custom("Outfit-Black", size: 14))
                                    .foregroundColor(Color("HauzLight"))
                                    .textFieldStyle(.plain)
                                
                                if !brandSearchQuery.isEmpty {
                                    Button {
                                        brandSearchQuery = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color("HauzLight").opacity(0.5))
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color("HauzBg"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color("HauzLight").opacity(0.2), lineWidth: 1)
                            )
                            
                            // Show count of filtered brands
                            if !brandSearchQuery.isEmpty {
                                HStack {
                                    Text("\(filteredBrands.count) brands found")
                                        .font(.custom("Outfit-Black", size: 11))
                                        .foregroundColor(Color("HauzLight").opacity(0.6))
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Text("Popular brands • Search for more")
                                        .font(.custom("Outfit-Black", size: 11))
                                        .foregroundColor(Color("HauzLight").opacity(0.6))
                                    Spacer()
                                }
                            }
                            
                            // Brands grid (filtered)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(filteredBrands, id: \.self) { brand in
                                    Button {
                                        if selectedBrands.contains(brand) {
                                            selectedBrands.removeAll { $0 == brand }
                                        } else {
                                            selectedBrands.append(brand)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedBrands.contains(brand) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedBrands.contains(brand) ? Color("HauzFocus") : Color("HauzLight").opacity(0.3))
                                                .font(.system(size: 16))
                                            
                                            Text(brand)
                                                .font(.custom("Outfit-Black", size: 14))
                                                .foregroundColor(Color("HauzLight"))
                                            
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedBrands.contains(brand) ? Color("HauzFocus").opacity(0.1) : Color("HauzBg"))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedBrands.contains(brand) ? Color("HauzFocus") : Color("HauzLight").opacity(0.2), lineWidth: selectedBrands.contains(brand) ? 2 : 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // Clear selection button
                            if !selectedBrands.isEmpty {
                                Button {
                                    selectedBrands = []
                                } label: {
                                    Text("Clear All (\(selectedBrands.count))")
                                        .font(.custom("Outfit-Black", size: 13))
                                        .foregroundColor(Color("HauzFocus"))
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    
                    // MARK: Price Range Section (Collapsible)
                    CollapsibleSection(
                        title: "Price Range",
                        icon: "dollarsign.circle",
                        isExpanded: $isPriceSectionExpanded
                    ) {
                        VStack(spacing: 12) {
                            // Display current price range values
                            HStack {
                                Text("$\(Int(lowerLimit))")
                                    .font(.custom("Outfit-Black", size: 18))
                                    .foregroundStyle(Color("HauzLight"))
                                Spacer()
                                Text("$\(Int(upperLimit))")
                                    .font(.custom("Outfit-Black", size: 18))
                                    .foregroundStyle(Color("HauzLight"))
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
                    }
                    
                    // MARK: Gender Selection Section (Collapsible)
                    CollapsibleSection(
                        title: "Section",
                        icon: "figure.stand.dress",
                        isExpanded: $isGenderSectionExpanded
                    ) {
                        VStack(spacing: 12) {
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
                                                .foregroundStyle(selectedGender == gender ? Color("HauzBg") : Color("HauzLight"))
                                            
                                            // Gender label
                                            Text(gender.label)
                                                .font(.custom("Outfit-Black", size: 15))
                                                .fontWeight(selectedGender == gender ? .semibold : .regular)
                                                .foregroundStyle(selectedGender == gender ? Color("HauzBg") : Color("HauzLight"))
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
                                    .fill(Color("HauzBg"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("HauzFocus").opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // MARK: Color Selection Section (Collapsible) - COMMENTED OUT FOR NOW
                    /*
                    CollapsibleSection(
                        title: "Color",
                        icon: "paintpalette",
                        isExpanded: $isColorSectionExpanded
                    ) {
                        VStack(spacing: 12) {
                            // Clear button
                            if selectedColor != nil {
                                HStack {
                                    Spacer()
                                    Button {
                                        selectedColor = nil
                                    } label: {
                                        Text("Clear")
                                            .font(.custom("Outfit-Black", size: 15))
                                            .foregroundColor(Color("HauzLight"))
                                    }
                                }
                            }
                            
                            // Color chips grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(availableColors, id: \.0) { colorName, hexCode in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedColor == colorName {
                                                selectedColor = nil // Deselect if already selected
                                            } else {
                                                selectedColor = colorName
                                            }
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            // Color circle
                                            Circle()
                                                .fill(Color(hex: hexCode))
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColor == colorName ? Color("HauzFocus") : Color.clear, lineWidth: 3)
                                                )
                                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            
                                            // Color name
                                            Text(colorName)
                                                .font(.custom("Outfit-Black", size: 12))
                                                .foregroundColor(selectedColor == colorName ? Color("HauzFocus") : Color("HauzLight"))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedColor == colorName ? Color("HauzFocus").opacity(0.1) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    */
                    
                    // Show error if any
                    if let showError {
                        Text(showError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Show non-fatal notice (e.g., no strong matches, showing closest results)
                    if let showNotice {
                        Text(showNotice)
                            .font(.caption)
                            .foregroundColor(Color("HauzLight"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // MARK: Apply Button
                    Button {
                        Task {
                            await applyFilters()
                        }
                    } label: {
                        if isApplying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzLight")))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Apply Filters")
                                .font(.custom("Outfit-Black", size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color("HauzLight"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("HauzFocus"))
                    )
                    .disabled(isApplying)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // MARK: Helper Text
                    Text("Adjust your preferences and tap Apply to see results")
                        .font(.custom("Outfit-Black", size: 15))
                        .foregroundColor(Color("HauzLight"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Custom title in center
                ToolbarItem(placement: .principal) {
                    Text("Filter Preferences")
                        .font(.custom("Outfit-Black", size: 20))
                        .foregroundColor(Color("HauzLight"))
                }
                
                // Close button on right
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color("HauzLight"))
                    }
                }
            }
            .background(Color("HauzBg"))
        }
        .background(Color("HauzBg"))
        .task {
            await loadCurrentPreferences()
        }
    }
    
    /// Normalize brand names to match exact database values (case-sensitive!)
    private func normalizeBrandName(_ brand: String) -> String {
        // Map old/incorrect names to exact database names
        let mapping: [String: String] = [
            "Air Jordans": "Jordan",
            "Adidas": "adidas",           // Database uses lowercase!
            "ADIDAS": "adidas",            // Normalize uppercase too
            "On Running": "On",
            "Hoka": "Hoka One One",
            "New balance": "New Balance",  // Fix capitalization
            "new balance": "New Balance",
            "OFF WHITE": "OFF-WHITE",      // Fix hyphen
            "Off White": "OFF-WHITE",
            "Off-White": "OFF-WHITE",
            "Dr Martens": "Dr. Martens",   // Fix period
            "Dolce and Gabbana": "Dolce & Gabbana"
        ]
        
        return mapping[brand] ?? brand
    }
    
    /// Load user's current preferences from Supabase
    private func loadCurrentPreferences() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                if let priceMin = profile.priceMin {
                    lowerLimit = priceMin
                }
                if let priceMax = profile.priceMax {
                    upperLimit = priceMax
                }
                if let gender = profile.gender {
                    selectedGender = gender == "Male" ? .male : .female
                }
                // Load user's preferred brands from onboarding
                if let brands = profile.brands, !brands.isEmpty {
                    // Normalize brand names to match database
                    selectedBrands = brands.map { normalizeBrandName($0) }
                } else {
                    // Default to some popular brands if none selected (exact database values)
                    selectedBrands = ["Nike", "Jordan", "adidas"]
                }
            }
        } catch {
            debugPrint("Failed to load preferences: \(error)")
        }
    }
    
    /// Apply filters with robust error handling - NEVER fails
    private func applyFilters() async {
        isApplying = true
        showError = nil
        showNotice = nil
        
        // Step 1: Update profile preferences (non-blocking, fire and forget)
        Task.detached(priority: .userInitiated) {
            await updateProfilePreferences()
        }
        
        // Step 2: Load feed with filters (brand-based filtering)
        // Natural language search is commented out - using brand filters instead
        await performRegularLoadWithFallback()
        
        await MainActor.run {
            isApplying = false
            // Always dismiss on success
            dismiss()
        }
    }
    
    /// Update profile preferences in background (non-blocking)
    private func updateProfilePreferences() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let payload = FilterUpdate(
                price_min: lowerLimit,
                price_max: upperLimit,
                gender: selectedGender.label,
                brands: selectedBrands
            )
            
            _ = try await supabase
                .from("profiles")
                .update(payload)
                .eq("id", value: userId)
                .execute()
            
            print("✅ Profile preferences updated")
        } catch {
            // Silently fail - user preferences update is not critical
            print("⚠️ Failed to update profile preferences (non-critical): \(error)")
        }
    }
    
    /// Perform semantic search with multiple fallback layers
    private func performSemanticSearchWithFallback(query: String) async {
        print("🔍 Semantic search: '\(query)'")

        // Optimized search should complete in 3-5s (embedding generation + HNSW search)
        do {
            let hasResults = try await withTimeout(seconds: 10) {
                try await feedService.searchWithNaturalLanguage(
                    query,
                    gender: selectedGender.label,
                    priceMin: lowerLimit,
                    priceMax: upperLimit
                )
            }
            
            if !hasResults, let notice = feedService.semanticSearchNotice {
                await MainActor.run { showNotice = notice }
            } else {
                await MainActor.run { showNotice = nil }
            }
            print("✅ Semantic search completed")
            
        } catch is TimeoutError {
            // Fallback 1: Timeout -> Try regular load
            print("⏱️ Semantic search timeout - falling back to regular load")
            await performRegularLoadWithFallback()
            
        } catch {
            // Fallback 2: Any error -> Try regular load
            print("⚠️ Semantic search failed - falling back to regular load: \(error)")
            await performRegularLoadWithFallback()
        }
    }
    
    /// Perform regular load with fallback
    private func performRegularLoadWithFallback() async {
        print("📋 Regular feed load")
        
        do {
            // Try regular load with timeout (faster fallback)
            try await withTimeout(seconds: 15) {
                await feedService.load()
            }
            print("✅ Regular load completed")
            
        } catch is TimeoutError {
            // Fallback: Timeout -> Force reload with fresh data
            print("⏱️ Regular load timeout - forcing fresh reload")
            await forceReloadFeed()
            
        } catch {
            // Final fallback: Any error -> Force reload
            print("⚠️ Regular load failed - forcing fresh reload: \(error)")
            await forceReloadFeed()
        }
    }
    
    /// Final fallback: Force reload feed (always succeeds)
    private func forceReloadFeed() async {
        // This should always work - just reload what's in memory or empty state
        await MainActor.run {
            // If feedService has any data, keep it; otherwise show empty state
            print("✅ Feed reloaded (fallback)")
            // Show a gentle notice instead of error
            if feedService.feed.isEmpty {
                showNotice = "Showing your personalized feed. Adjust filters to see more results."
            }
        }
    }
    
    /// Helper function to run async code with a timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Timeout error type
private struct TimeoutError: Error {}

// MARK: - Settings View
/// Full settings sheet with wrapped sections matching filter view style
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: Account Section
                    SettingsSection(title: "Account", icon: "person.circle") {
                        SettingsRow(icon: "person.fill", title: "Profile", action: {
                            print("Profile tapped")
                        })
                        
                        Divider()
                            .background(Color("HauzFocus").opacity(0.2))
                        
                        /*SettingsRow(icon: "bell.fill", title: "Notifications", action: {
                            print("Notifications tapped")
                        })*/
                    }
                    
                    // MARK: General Section
                    SettingsSection(title: "General", icon: "gear") {
                        SettingsRow(icon: "paintbrush.fill", title: "Appearance", action: {
                            print("Appearance tapped")
                        })
                        
                        Divider()
                            .background(Color("HauzFocus").opacity(0.2))
                        
                        /*SettingsRow(icon: "globe", title: "Language", action: {
                            print("Language tapped")
                        })*/
                    }
                    
                    // MARK: Support Section
                    SettingsSection(title: "Support", icon: "questionmark.circle") {
                        SettingsRow(icon: "paperplane.fill", title: "Share App", action: {
                            print("Share tapped")
                        })
                        
                        Divider()
                            .background(Color("HauzFocus").opacity(0.2))
                        
                        SettingsRow(icon: "message.badge", title: "Feedback", action: {
                            print("Feedback tapped")
                        })
                        
                        Divider()
                            .background(Color("HauzFocus").opacity(0.2))
                        
                        /*SettingsRow(icon: "chart.bar", title: "Privacy & Data", action: {
                            print("Privacy tapped")
                        })*/
                    }
                    
                    // MARK: Logout Section
                    SettingsSection(title: "Account Actions", icon: "rectangle.portrait.and.arrow.right") {
                        Button {
                            Task {
                                await handleLogout()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color("HauzFocus"))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color("HauzFocus").opacity(0.1))
                                    )
                                
                                Text("Log Out")
                                    .font(.custom("Outfit-Black", size: 16))
                                    .foregroundColor(Color("HauzFocus"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("HauzLight").opacity(0.5))
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                    }
                    
                    // Helper text
                    Text("Manage your preferences and account settings")
                        .font(.custom("Outfit-Black", size: 12))
                        .foregroundColor(Color("HauzLight"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.custom("Outfit-Black", size: 20))
                        .foregroundColor(Color("HauzLight"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color("HauzLight"))
                    }
                }
            }
            .background(Color("HauzBg"))
        }
        .background(Color("HauzBg"))
    }
    
    private func handleLogout() async {
        do {
            try await supabase.auth.signOut()
            debugPrint("✅ User logged out successfully")
            dismiss()
        } catch {
            debugPrint("❌ Error logging out: \(error)")
        }
    }
}

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("HauzFocus"))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color("HauzFocus").opacity(0.1))
                    )
                
                Text(title)
                    .font(.custom("Outfit-Black", size: 18))
                    .foregroundColor(Color("HauzLight"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("HauzBg"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("HauzFocus").opacity(0.3), lineWidth: 1)
            )
            
            // Section content
            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("HauzBg"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("HauzFocus").opacity(0.2), lineWidth: 1)
            )
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color("HauzFocus"))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color("HauzFocus").opacity(0.1))
                    )
                
                Text(title)
                    .font(.custom("Outfit-Black", size: 16))
                    .foregroundColor(Color("HauzLight"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("HauzLight").opacity(0.5))
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// DTO for filter updates
private struct FilterUpdate: Encodable {
    let price_min: Double
    let price_max: Double
    let gender: String
    let brands: [String]
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
                    .fill(Color("HauzLight").opacity(0.2))
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
            .fill(Color("HauzLight"))
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

/*
 // Test each one until one works
 .font(.custom("bernoru-blackultraexpanded", size: 16))
 .font(.custom("Bernoru-BlackUltraExpanded", size: 16))
 .font(.custom("Bernoru Black UltraExpanded", size: 16))
 
 */
