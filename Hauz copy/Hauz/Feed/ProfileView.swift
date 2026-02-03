import SwiftUI

struct ProfileView: View {
    @State private var filters: [String] = ["Sneakers","Collections"]
    @AppStorage("hauz_profile_filter") private var selectedFilter = "Sneakers"
    
    @State private var likedShoes: [LikedShoeData] = []
    @State private var isLoading = false
    @State private var viewMode: ViewMode = .card // Card or Grid view
    @State private var isSelectMode = false // Multi-select mode
    @State private var selectedShoes: Set<UUID> = []
    @State private var showAddToCollectionSheet = false
    @State private var activeSwipeID: UUID? = nil // Track which card is currently swiped open
    
    private let feedService = FeedService()
    
    enum ViewMode {
        case card, grid
    }
    
    // Computed properties for pinned and unpinned shoes
    private var pinnedShoes: [LikedShoeData] {
        likedShoes.filter { $0.isPinned }
    }
    
    private var unpinnedShoes: [LikedShoeData] {
        likedShoes.filter { !$0.isPinned }
    }
    
    var body: some View {
        ZStack{
            Color("HauzBg").ignoresSafeArea(edges: .all)
            VStack(spacing: 0){
                header
                
                HauzFilterView(options: filters, selection: $selectedFilter)
                    .background(
                        Divider(), alignment: .bottom
                    )
                
                Spacer().frame(height: 20)
                
                // Conditionally show Sneakers or Collections
                if selectedFilter == "Sneakers" {
                    sneakersView
                } else {
                    CollectionsView()
                }
            }
        }
        .task {
            await loadLikedShoes()
        }
    }
    
    private var sneakersView: some View {
        ZStack {
            VStack(spacing: 0) {
                // Toolbar with view toggle and select button
                sneakersToolbar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("HauzBg"))
                
                // Content based on view mode
                if viewMode == .card {
                    cardListView
                } else {
                    gridView
                }
            }
            
            // Floating action buttons (shown in select mode)
            if isSelectMode {
                VStack {
                    Spacer()
                    actionButtons
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            
            // Commented out filter button for now
            // GlassFilterButton(
            //     onAlphabeticalSort: applyAlphabeticalSort,
            //     onPriceLowToHigh: applyPriceLowToHighSort,
            //     onPriceHighToLow: applyPriceHighToLowSort
            // )
            // .padding(.top, 16)
            // .padding(.trailing, 10)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
            }
        }
        .fullScreenCover(isPresented: $showAddToCollectionSheet) {
            BulkAddToCollectionSheet(
                sneakerIds: Array(selectedShoes),
                sneakerCount: selectedShoes.count,
                onComplete: {
                    isSelectMode = false
                    selectedShoes.removeAll()
                }
            )
        }
    }
    
    // MARK: - Toolbar
    private var sneakersToolbar: some View {
        HStack(spacing: 12) {
            // View toggle (Card/Grid)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewMode = viewMode == .card ? .grid : .card
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewMode == .card ? "square.grid.2x2" : "rectangle.stack")
                        .font(.system(size: 18))
                    Text(viewMode == .card ? "Grid" : "Cards")
                        .font(.custom("Outfit-SemiBold", size: 14))
                }
                .foregroundColor(Color("HauzFocus"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
            }
            
            Spacer()
            
            // Select button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSelectMode.toggle()
                    if !isSelectMode {
                        selectedShoes.removeAll()
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 18))
                    Text(isSelectMode ? "Done" : "Select")
                        .font(.custom("Outfit-SemiBold", size: 14))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelectMode ? Color.green : Color("HauzFocus"))
                )
            }
        }
    }
    
    // MARK: - Card List View
    private var cardListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)
                
                // Show pinned shoes first
                ForEach(pinnedShoes) { shoe in
                    selectableCardView(shoe: shoe, isPinned: true)
                }
                
                // Then show unpinned shoes
                ForEach(unpinnedShoes) { shoe in
                    selectableCardView(shoe: shoe, isPinned: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Grid View (2 cards per row)
    private var gridView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 16) {
                // Show pinned shoes first
                ForEach(pinnedShoes) { shoe in
                    gridCardView(shoe: shoe)
                }
                
                // Then show unpinned shoes
                ForEach(unpinnedShoes) { shoe in
                    gridCardView(shoe: shoe)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Grid Card View (Scaled FlippableShoeCard)
    private func gridCardView(shoe: LikedShoeData) -> some View {
        ZStack(alignment: .topLeading) {
            FlippableShoeCard(card: shoe, onTogglePin: {
                togglePin(for: shoe)
            })
            .scaleEffect(0.48) // Scale down to fit 2 per row
            .frame(width: 173, height: 154) // Scaled dimensions
            .opacity(isSelectMode ? 0.95 : 1.0)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectMode {
                    toggleSelection(shoe.id)
                }
            }
            .contextMenu {
                if !isSelectMode {
                    Button {
                        togglePin(for: shoe)
                    } label: {
                        Label(shoe.isPinned ? "Unpin" : "Pin", systemImage: shoe.isPinned ? "star.slash" : "star")
                    }
                    
                    Button(role: .destructive) {
                        Task { await removeShoe(shoe) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    if let link = shoe.stockxLink, let url = URL(string: link) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("View on StockX", systemImage: "arrow.up.forward.app")
                        }
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            
            // Selection checkmark (top-left)
            if isSelectMode {
                Button(action: {
                    toggleSelection(shoe.id)
                }) {
                    Image(systemName: selectedShoes.contains(shoe.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(selectedShoes.contains(shoe.id) ? Color("HauzFocus") : .white)
                        .background(
                            Circle()
                                .fill(selectedShoes.contains(shoe.id) ? .white : Color.black.opacity(0.3))
                                .frame(width: 20, height: 20)
                        )
                        .padding(8)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Selectable Card View
    private func selectableCardView(shoe: LikedShoeData, isPinned: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            if isSelectMode {
                // In select mode, no swipe actions
                FlippableShoeCard(card: shoe, onTogglePin: {
                    togglePin(for: shoe)
                })
                .opacity(0.95)
                .onTapGesture {
                    toggleSelection(shoe.id)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            } else {
                // In normal mode, use swipe actions
                SwipeableCardWrapper(
                    shoe: shoe,
                    isActive: activeSwipeID == shoe.id,
                    activeSwipeID: $activeSwipeID,
                    onTogglePin: {
                        togglePin(for: shoe)
                    },
                    onDelete: {
                        Task {
                            await removeShoe(shoe)
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            // Selection checkmark (top-left)
            if isSelectMode {
                Button(action: {
                    toggleSelection(shoe.id)
                }) {
                    Image(systemName: selectedShoes.contains(shoe.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 32))
                        .foregroundColor(selectedShoes.contains(shoe.id) ? Color("HauzFocus") : .white)
                        .background(
                            Circle()
                                .fill(selectedShoes.contains(shoe.id) ? .white : Color.black.opacity(0.3))
                                .frame(width: 28, height: 28)
                        )
                        .padding(16)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Action Buttons (Floating)
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Delete Button
            Button(action: {
                Task {
                    await bulkDeleteShoes()
                }
            }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(selectedShoes.isEmpty ? Color.gray.opacity(0.3) : Color("HauzFocus"))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(selectedShoes.isEmpty)
            .opacity(selectedShoes.isEmpty ? 0.5 : 1.0)
            
            // Add to Collection Button
            Button(action: {
                showAddToCollectionSheet = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(selectedShoes.isEmpty ? Color.gray.opacity(0.3) : Color("HauzBg"))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(selectedShoes.isEmpty)
            .opacity(selectedShoes.isEmpty ? 0.5 : 1.0)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 60)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Helper Functions
    private func toggleSelection(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedShoes.contains(id) {
                selectedShoes.remove(id)
            } else {
                selectedShoes.insert(id)
            }
        }
    }
    
    // Bulk delete selected shoes with staggered animation
    private func bulkDeleteShoes() async {
        let shoesToDelete = likedShoes.filter { selectedShoes.contains($0.id) }
        
        // Delete shoes one by one with staggered animation
        for (index, shoe) in shoesToDelete.enumerated() {
            // Small delay for staggered effect
            if index > 0 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
            
            // Animate removal
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    likedShoes.removeAll { $0.id == shoe.id }
                }
            }
            
            // Delete from database (async, doesn't block UI)
            Task {
                do {
                    try await feedService.unlikeShoe(sneakerID: shoe.id)
                } catch {
                    debugPrint("❌ Failed to delete shoe \(shoe.shoeName): \(error)")
                }
            }
        }
        
        // Small delay before clearing selection
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Clear selection and exit select mode
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                selectedShoes.removeAll()
                isSelectMode = false
            }
        }
        
        print("✅ Bulk deleted \(shoesToDelete.count) shoes")
    }
    
    private var header: some View{
        HStack(spacing: 0){
            Text("Liked")
                .font(.custom("bernoru-blackultraexpanded", size: 40))
                .bold()
                .foregroundStyle(Color("HauzFocus"))
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color("HauzBg"))
        }
        .font(.title2)
        .fontWeight(.medium)
        .foregroundStyle(Color.black)
    }
    
    // Toggle pin status
    private func togglePin(for card: LikedShoeData) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if let index = likedShoes.firstIndex(where: { $0.id == card.id }) {
                likedShoes[index].isPinned.toggle()
                let newPinState = likedShoes[index].isPinned
                
                // Persist to database
                Task {
                    do {
                        try await feedService.updatePinStatus(sneakerID: card.id, isPinned: newPinState)
                        print("✅ Updated pin status for \(card.shoeName): \(newPinState)")
                    } catch {
                        debugPrint("❌ Failed to update pin status: \(error)")
                        // Revert on error
                        await MainActor.run {
                            if let idx = likedShoes.firstIndex(where: { $0.id == card.id }) {
                                likedShoes[idx].isPinned.toggle()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Remove shoe from liked collection with smooth animation
    private func removeShoe(_ shoe: LikedShoeData) async {
        // Remove from local UI with smooth animation first (optimistic update)
        await MainActor.run {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                likedShoes.removeAll { $0.id == shoe.id }
            }
        }
        
        // Delete from database (async)
        do {
            try await feedService.unlikeShoe(sneakerID: shoe.id)
            print("✅ Removed \(shoe.shoeName) from liked collection")
        } catch {
            debugPrint("❌ Failed to remove shoe: \(error)")
            // If delete fails, add it back
            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    likedShoes.append(shoe)
                }
            }
        }
    }
    
    // MARK: - Filter Functions (only apply to unpinned shoes)
    
    private func applyAlphabeticalSort() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            let pinned = likedShoes.filter { $0.isPinned }
            let unpinned = likedShoes.filter { !$0.isPinned }.sorted { $0.shoeName < $1.shoeName }
            likedShoes = pinned + unpinned
        }
        print("Alphabetical sort applied")
    }
    
    private func applyPriceLowToHighSort() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            let pinned = likedShoes.filter { $0.isPinned }
            let unpinned = likedShoes.filter { !$0.isPinned }.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
            likedShoes = pinned + unpinned
        }
        print("Price Low to High sort applied")
    }
    
    private func applyPriceHighToLowSort() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            let pinned = likedShoes.filter { $0.isPinned }
            let unpinned = likedShoes.filter { !$0.isPinned }.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
            likedShoes = pinned + unpinned
        }
        print("Price High to Low sort applied")
    }
}

private extension ProfileView {
    func loadLikedShoes() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        do {
            // Reuse feed service helper to fetch liked details
            let likedCards = try await feedService.fetchLikedForProfile()
            await MainActor.run {
                likedShoes = likedCards.map { card in
                    LikedShoeData(
                        id: card.id,
                        shoeName: card.name,
                        brandName: card.brand,
                        price: card.price,
                        imageURL: card.imageURL,
                        priceTrendIsUp: true,
                        priceChangePercentage: 1.0,
                        isPinned: card.isPinned,
                        stockxLink: card.stockxLink
                    )
                }
            }
        } catch {
            debugPrint("Failed to load liked shoes: \(error)")
        }
    }
}

// MARK: - Liked Shoe Data Model (mutable version for ProfileView)
struct LikedShoeData: Identifiable {
    let id: UUID
    let shoeName: String
    let brandName: String
    let price: Double?
    let imageURL: URL?
    var priceTrendIsUp: Bool
    var priceChangePercentage: Double
    var isPinned: Bool
    let stockxLink: String?
}

// MARK: - Flippable Shoe Card
struct FlippableShoeCard: View {
    let card: LikedShoeData
    let onTogglePin: () -> Void
    
    @State private var showAddToCollection = false
    
    var body: some View {
        ZStack {
            // Pure white background
            Color.white
            
            // Main content
            VStack(spacing: 0) {
                // MASSIVE shoe section with price floating on top
                ZStack(alignment: .topTrailing) {
                    Color.white
                    
                    // Giant shoe image - the absolute star
                    if let url = card.imageURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 320, height: 200)
                                .padding(.vertical, 30)
                                .padding(.horizontal, 20)
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image("asics_forpreview")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 320, height: 200)
                            .padding(.vertical, 30)
                            .padding(.horizontal, 20)
                    }
                    
                    // Pin button - top left
                    Button(action: onTogglePin) {
                        Image(systemName: card.isPinned ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundColor(card.isPinned ? Color("HauzBg") : Color("HauzBg"))
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 20)
                    .padding(.leading, 10)
                    
                    // Floating price badge - top right, clean and bold
                    Text(card.price.map { "$\(Int($0))" } ?? "$—")
                        .font(.custom("Outfit-Black", size: 27))
                        .foregroundColor(Color("HauzLight"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color("HauzBg"))
                                .shadow(
                                    color: Color.black.opacity(0.15),
                                    radius: 12,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                }
                .frame(height: 260)
                
                // Sleek info bar
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.shoeName)
                            .font(.custom("Outfit-SemiBold", size: 15))
                            .foregroundColor(Color("HauzBg"))
                            .lineLimit(1)
                        
                        Text(card.brandName)
                            .font(.custom("Outfit-SemiBold", size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Add to Collection button
                    Button(action: {
                        showAddToCollection = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(Color("HauzFocus"))
                    }
                    .padding(.trailing, 8)
                    
                    // View button
                    Button(action: {
                        if let link = card.stockxLink, let url = URL(string: link) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color("HauzBg"))
                    }
                    .disabled(card.stockxLink == nil)
                    .opacity(card.stockxLink == nil ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
            }
        }
        .frame(width: 360, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color("HauzFocus"), lineWidth: 3)
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 20,
            x: 0,
            y: 10
        )
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(sneakerId: card.id, sneakerName: card.shoeName)
        }
    }
}

// MARK: - Glass Filter Button
struct GlassFilterButton: View {
    @State private var isExpanded = false
    
    var onAlphabeticalSort: () -> Void
    var onPriceLowToHigh: () -> Void
    var onPriceHighToLow: () -> Void
    
    var body: some View {
        ExpandableFilterMenu(
            isExpanded: $isExpanded,
            onAlphabeticalSort: onAlphabeticalSort,
            onPriceLowToHigh: onPriceLowToHigh,
            onPriceHighToLow: onPriceHighToLow
        )
    }
}

struct ExpandableFilterMenu: View {
    @Binding var isExpanded: Bool
    @State private var selectedFilter: FilterType?
    
    var onAlphabeticalSort: () -> Void
    var onPriceLowToHigh: () -> Void
    var onPriceHighToLow: () -> Void
    
    enum FilterType {
        case alphabetical, priceLowToHigh, priceHighToLow
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isExpanded {
                HStack(spacing: 12) {
                    FilterCircle(
                        icon: "characters.uppercase",
                        isSelected: selectedFilter == .alphabetical
                    ) {
                        selectedFilter = .alphabetical
                        onAlphabeticalSort()
                    }
                    
                    FilterCircle(
                        icon: "chart.bar.xaxis.ascending",
                        isSelected: selectedFilter == .priceLowToHigh
                    ) {
                        selectedFilter = .priceLowToHigh
                        onPriceLowToHigh()
                    }
                    
                    FilterCircle(
                        icon: "chart.bar.xaxis.descending",
                        isSelected: selectedFilter == .priceHighToLow
                    ) {
                        selectedFilter = .priceHighToLow
                        onPriceHighToLow()
                    }
                }
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            Button(action: {
                withAnimation(.bouncy(duration: 0.75, extraBounce: 0.02)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    if isExpanded {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundStyle(Color("HauzFocus"))
                            .rotationEffect(.degrees(90))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Color("HauzFocus"))
                            .transition(.scale.combined(with: .opacity))
                        
                        Text("Filter")
                            .font(.custom("bernoru-blackultraexpanded", size: 15))
                            .foregroundStyle(Color("HauzFocus"))
                            .transition(.opacity)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 25)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
    }
}

struct FilterCircle: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(isSelected ? 0.8 : 0.6),
                                        Color.white.opacity(isSelected ? 0.4 : 0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1.5
                            )
                        
                        if isSelected {
                            Circle()
                                .fill(Color("HauzFocus"))
                        }
                    }
                if isSelected{
                    Image(systemName: icon)
                        .foregroundStyle(Color.white)
                        .font(.system(size: 16, weight: .semibold))
                } else{
                    Image(systemName: icon)
                        .foregroundStyle(Color("HauzFocus"))
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(width: 55, height: 55)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
    }
}

// MARK: - Swipeable Card Wrapper
struct SwipeableCardWrapper: View {
    let shoe: LikedShoeData
    let isActive: Bool
    @Binding var activeSwipeID: UUID?
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting: Bool = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var buttonOpacity: Double = 0
    @State private var buttonWidth: CGFloat = 100
    @State private var buttonBrightness: Double = 0
    @State private var itemHeight: CGFloat = 320
    @State private var verticalPadding: CGFloat = 0
    
    private let itemWidth: CGFloat = 360
    private let initialSwipeDistance: CGFloat = 140
    private let autoDeleteThreshold: CGFloat = 280
    private let swipeThreshold: CGFloat = 70
    private let minButtonWidth: CGFloat = 25
    private let buttonHeight: CGFloat = 80
    private let screenWidth: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background container
            Color.clear
            
            // Delete button - scaled for bigger items
            deleteButton
                .frame(width: buttonWidth)
                .padding(.trailing, 10)
            
            // Main content with fixed width
            FlippableShoeCard(card: shoe, onTogglePin: onTogglePin)
                .frame(width: itemWidth, height: itemHeight)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { gesture in
                            handleDragChanged(gesture)
                        }
                        .onEnded { gesture in
                            handleDragEnded(gesture)
                        }
                )
                .onChange(of: isActive) { newValue in
                    if !newValue && offset != 0 {
                        closeSwipe()
                    }
                }
        }
        .frame(width: itemWidth, height: itemHeight)
        .padding(.vertical, verticalPadding)
        .clipped()
    }
    
    // MARK: - Delete Button
    private var deleteButton: some View {
        Button(action: {
            performDeleteWithAutoSwipe()
        }) {
            // Centered icon with perfect alignment
            HStack {
                Spacer()
                
                Image(systemName: "trash.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .frame(height: buttonHeight)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .brightness(buttonBrightness)
            )
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChanged(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        
        // Close any other open item when starting to swipe this one
        if translation < 0 && activeSwipeID != shoe.id && activeSwipeID != nil {
            activeSwipeID = nil
        }
        
        if translation < 0 {
            // Left swipe - reveal delete button
            let rawOffset = translation
            offset = max(rawOffset, -autoDeleteThreshold - 50)
            
            // Calculate horizontal expansion
            let swipeDistance = abs(offset)
            let maxWidth = screenWidth
            let expandedWidth = minButtonWidth + (swipeDistance * 0.7)
            
            // Calculate brightness increase
            let brightnessProgress = min(abs(offset) / autoDeleteThreshold, 1.0)
            
            // Smooth animations - fully visible icon that expands
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 1.0
                buttonOpacity = 1.0
                
                // Horizontal expansion - icon stays centered
                buttonWidth = min(expandedWidth, maxWidth)
                
                // Progressive brightness glow
                buttonBrightness = brightnessProgress * 0.15
            }
            
            // Haptic feedback at auto-delete threshold
            if abs(offset) >= autoDeleteThreshold {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
        } else if offset < 0 {
            // Right swipe when already open
            let newOffset = offset + translation
            offset = min(newOffset, 0)
            
            let swipeDistance = abs(offset)
            let expandedWidth = minButtonWidth + (swipeDistance * 0.7)
            let brightnessProgress = min(abs(offset) / autoDeleteThreshold, 1.0)
            
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 1.0
                buttonOpacity = 1.0
                buttonWidth = min(expandedWidth, screenWidth)
                buttonBrightness = brightnessProgress * 0.15
            }
        }
    }
    
    private func handleDragEnded(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        let velocity = gesture.predictedEndTranslation.width - translation
        
        // Auto-delete if swiped beyond threshold
        if abs(offset) >= autoDeleteThreshold {
            performDelete()
            return
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if abs(offset) > swipeThreshold || velocity < -300 {
                // Snap to open position with more space
                offset = -initialSwipeDistance
                buttonScale = 1.0
                buttonOpacity = 1.0
                buttonWidth = minButtonWidth + (initialSwipeDistance * 0.7)
                buttonBrightness = (initialSwipeDistance / autoDeleteThreshold) * 0.15
                
                // Mark this card as active
                activeSwipeID = shoe.id
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } else {
                // Snap back to closed
                closeSwipe()
            }
        }
    }
    
    // MARK: - Close Swipe
    private func closeSwipe() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            offset = 0
            buttonScale = 1.0
            buttonOpacity = 0
            buttonWidth = minButtonWidth
            buttonBrightness = 0
        }
        
        // Clear active state if this was the active card
        if activeSwipeID == shoe.id {
            activeSwipeID = nil
        }
    }
    
    // MARK: - Auto-Swipe Delete Animation
    private func performDeleteWithAutoSwipe() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Animate to full swipe position first
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            offset = -autoDeleteThreshold
            buttonWidth = minButtonWidth + (autoDeleteThreshold * 0.7)
            buttonBrightness = 0.15
        }
        
        // Then perform the delete after a brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            performDelete()
        }
    }
    
    // MARK: - Delete Action with Smooth Disappearance
    private func performDelete() {
        isDeleting = true
        
        // Clear active state
        activeSwipeID = nil
        
        // Strong haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Smooth disappearance animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.95)) {
            itemHeight = 0
            verticalPadding = -6
            offset = -400
            buttonOpacity = 0
        }
        
        // Delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDelete()
        }
    }
}

#Preview {
    ProfileView()
}

extension View {
    func disableWithOpacity(_ condition: Bool) -> some View {
        self.disabled(condition).opacity(condition ? 0.5 : 1)
    }
    func hAlign(_ alignment: Alignment) -> some View {
        self.frame(maxWidth: .infinity, alignment: alignment)
    }
    func vAlign(_ alignment: Alignment) -> some View {
        self.frame(maxHeight: .infinity, alignment: alignment)
    }
    func border(_ width: CGFloat, _ color: Color) -> some View {
        self
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(color, lineWidth: width)
            }
    }
    func fillView(_ color: Color) -> some View {
        self
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
            }
    }
}
