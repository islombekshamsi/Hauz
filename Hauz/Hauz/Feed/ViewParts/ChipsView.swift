/*import SwiftUI

// MARK: - Sample Data with Popularity
// CUSTOMIZE: Add or remove brands, mark popular ones
struct BrandTag: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let isPopular: Bool
    
    // For easier creation
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

// MARK: - Main Chips View (Enhanced)
// Professional, VC-ready chips component with advanced features
struct ChipsView<Content: View, Tag: Equatable>: View where Tag: Hashable {
    var spacing: CGFloat = 12
    var tags: [Tag]
    var animation: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    @ViewBuilder var content: (Tag, Bool) -> Content
    var didChangeSelection: ([Tag]) -> ()
    
    // CUSTOMIZE: Binding to allow parent to control selection
    @Binding var selectedTags: [Tag]
    
    var body: some View {
        CustomChipLayout(spacing: spacing) {
            ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                content(tag, selectedTags.contains(tag))
                    .contentShape(.rect)
                    .onTapGesture {
                        handleTap(on: tag)
                    }
                    // CUSTOMIZE: Staggered entrance animation for polish
                    .opacity(1.0)
                    .scaleEffect(1.0)
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

// MARK: - VC-Ready Brand Selection View
// Polished, professional implementation with all the bells and whistles
struct VCReadyBrandSelection: View {
    @State private var selectedBrands: [BrandTag] = []
    @State private var searchText: String = ""
    @State private var showContent = false
    
    // CUSTOMIZE: Filter brands based on search
    var filteredBrands: [BrandTag] {
        if searchText.isEmpty {
            return brandTags
        }
        return brandTags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // CUSTOMIZE: Background
                Color("HauzLight")
                    .ignoresSafeArea(edges: .all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // CUSTOMIZE: Header with instructions
                        VStack(spacing: 8) {
                            Text("Select Your Favorite Brands")
                                .font(.custom("HooverVariable-Bold_Regular", size: 26))
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)
                            
                            Text("Choose 3-5 brands you love")
                                .font(.custom("HooverVariable-Bold_Light", size: 16))
                                .foregroundColor(.secondary)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -20)
                        }
                        .padding(.top, 20)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: showContent)
                        
                        // CUSTOMIZE: Search bar for discoverability
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search brands...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.custom("HooverVariable-Bold_Regular", size: 16))
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                        
                        // CUSTOMIZE: Popular section header
                        if searchText.isEmpty {
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
                        }
                        
                        // CUSTOMIZE: Chips container
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
                                selectedBrands = selection
                                print("✅ Selected: \(selection.map { $0.name })")
                            },
                            selectedTags: $selectedBrands
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
                        
                        // CUSTOMIZE: Selection indicator
                        if !selectedBrands.isEmpty {
                            HStack(spacing: 12) {
                                // Progress indicator
                                HStack(spacing: 6) {
                                    Image(systemName: selectedBrands.count >= 3 ? "checkmark.circle.fill" : "circle.dashed")
                                        .foregroundColor(selectedBrands.count >= 3 ? Color("HauzFocus") : .gray)
                                    
                                    Text("\(selectedBrands.count) of 5 selected")
                                        .font(.custom("HooverVariable-Bold_Regular", size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Clear all button
                                Button(action: {
                                    // CUSTOMIZE: Clear all with smooth animation
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        selectedBrands.removeAll()
                                    }
                                    
                                    // Haptic feedback for clearing
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
                        
                        // CUSTOMIZE: Continue button
                        if selectedBrands.count >= 3 {
                            Button(action: {
                                // Action: Continue to next step
                                print("🚀 Continuing with: \(selectedBrands.map { $0.name })")
                            }) {
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
                                            LinearGradient(
                                                colors: [
                                                    Color("HauzFocus"),
                                                    Color("HauzFocus").opacity(0.85)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(color: Color("HauzFocus").opacity(0.4), radius: 15, x: 0, y: 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // CUSTOMIZE: Help text
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }
}

// MARK: - Enhanced Chip View (VC-Ready)
// Professional chip with popular badge and smooth animations
struct EnhancedChipView: View {
    let brand: BrandTag
    let isSelected: Bool
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 8) {
            // CUSTOMIZE: Add brand logo here if you have assets
            // Image(brand.name.lowercased())
            //     .resizable()
            //     .frame(width: 18, height: 18)
            
            // Brand name
            Text(brand.name)
                .font(.custom("HooverVariable-Bold_Regular", size: 15))
                .foregroundStyle(isSelected ? .white : Color.primary)
            
            // Popular badge
            if brand.isPopular && !isSelected {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color("HauzFocus").opacity(0.8))
            }
            
            // Checkmark when selected
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
                // Unselected state
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
                
                // Selected state
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
        // CUSTOMIZE: Bounce animation on tap
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    VCReadyBrandSelection()
}
*/
