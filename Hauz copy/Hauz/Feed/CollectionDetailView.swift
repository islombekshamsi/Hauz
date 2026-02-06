import SwiftUI

struct CollectionDetailView: View {
    let collection: Collection
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var sneakers: [SneakerInCollection] = []
    @State private var isLoading = false
    @State private var viewMode: ViewMode = .card // Card or Grid view
    @State private var isSelectMode = false // Multi-select mode
    @State private var selectedSneakers: Set<UUID> = []
    @State private var activeSwipeID: UUID? = nil // Track which card is currently swiped open
    
    private let collectionsService = CollectionsService()
    
    enum ViewMode {
        case card, grid
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("HauzBg").ignoresSafeArea()
                
                if isLoading && sneakers.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                } else if sneakers.isEmpty {
                    emptyState
                } else {
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
                    
                    // Floating action button (shown in select mode)
                    if isSelectMode {
                        VStack {
                            Spacer()
                            actionButtons
                        }
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(collection.name)
                        .font(.custom("Outfit-SemiBold", size: 24))
                        .foregroundColor(Color("HauzFocus"))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("HauzFocus"))
                    .font(.custom("Outfit-SemiBold", size: 16))
                }
            }
        }
        .task {
            await loadSneakers()
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
                        selectedSneakers.removeAll()
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
                
                ForEach(sneakers) { sneaker in
                    selectableCardView(sneaker: sneaker)
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
                ForEach(sneakers) { sneaker in
                    gridCardView(sneaker: sneaker)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Grid Card View
    private func gridCardView(sneaker: SneakerInCollection) -> some View {
        ZStack(alignment: .topLeading) {
            CollectionFlippableCard(sneaker: sneaker, onRemove: {
                removeSneaker(sneaker)
            })
            .scaleEffect(0.48) // Scale down to fit 2 per row
            .frame(width: 173, height: 154) // Scaled dimensions
            .opacity(isSelectMode ? 0.95 : 1.0)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectMode {
                    toggleSelection(sneaker.id)
                }
            }
            .contextMenu {
                if !isSelectMode {
                    Button(role: .destructive) {
                        removeSneaker(sneaker)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    
                    if let link = sneaker.stockxLink, let url = URL(string: link) {
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
                    toggleSelection(sneaker.id)
                }) {
                    Image(systemName: selectedSneakers.contains(sneaker.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(selectedSneakers.contains(sneaker.id) ? Color("HauzFocus") : .white)
                        .background(
                            Circle()
                                .fill(selectedSneakers.contains(sneaker.id) ? .white : Color.black.opacity(0.3))
                                .frame(width: 20, height: 20)
                        )
                        .padding(8)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Selectable Card View
    private func selectableCardView(sneaker: SneakerInCollection) -> some View {
        ZStack(alignment: .topLeading) {
            if isSelectMode {
                // In select mode, no swipe actions
                CollectionFlippableCard(sneaker: sneaker, onRemove: {
                    removeSneaker(sneaker)
                })
                .opacity(0.95)
                .onTapGesture {
                    toggleSelection(sneaker.id)
                }
            } else {
                // In normal mode, use swipe actions
                SwipeableCollectionCard(
                    sneaker: sneaker,
                    isActive: activeSwipeID == sneaker.id,
                    activeSwipeID: $activeSwipeID,
                    onRemove: {
                        removeSneaker(sneaker)
                    }
                )
            }
            
            // Selection checkmark (top-left)
            if isSelectMode {
                Button(action: {
                    toggleSelection(sneaker.id)
                }) {
                    Image(systemName: selectedSneakers.contains(sneaker.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 32))
                        .foregroundColor(selectedSneakers.contains(sneaker.id) ? Color("HauzFocus") : .white)
                        .background(
                            Circle()
                                .fill(selectedSneakers.contains(sneaker.id) ? .white : Color.black.opacity(0.3))
                                .frame(width: 28, height: 28)
                        )
                        .padding(16)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }
    
    // MARK: - Action Button (Floating)
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Delete Button
            Button(action: {
                bulkRemoveSneakers()
            }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(selectedSneakers.isEmpty ? Color.gray.opacity(0.3) : Color("HauzFocus"))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(selectedSneakers.isEmpty)
            .opacity(selectedSneakers.isEmpty ? 0.5 : 1.0)
            
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
            if selectedSneakers.contains(id) {
                selectedSneakers.remove(id)
            } else {
                selectedSneakers.insert(id)
            }
        }
    }
    
    // Bulk remove selected sneakers with staggered animation
    private func bulkRemoveSneakers() {
        let sneakersToRemove = sneakers.filter { selectedSneakers.contains($0.id) }
        
        Task {
            // Remove sneakers one by one with staggered animation
            for (index, sneaker) in sneakersToRemove.enumerated() {
                // Small delay for staggered effect
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
                
                // Animate removal
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        sneakers.removeAll { $0.id == sneaker.id }
                    }
                }
                
                // Delete from database (async, doesn't block UI)
                Task {
                    do {
                        try await collectionsService.removeSneakerFromCollection(sneakerId: sneaker.id, collectionId: collection.id)
                    } catch {
                        debugPrint("❌ Failed to remove sneaker \(sneaker.name): \(error)")
                    }
                }
            }
            
            // Small delay before clearing selection
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Clear selection and exit select mode
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    selectedSneakers.removeAll()
                    isSelectMode = false
                }
            }
            
            onUpdate()
            print("✅ Bulk removed \(sneakersToRemove.count) sneakers from collection")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            /*Image(systemName: "shoeprints.fill")
                .font(.system(size: 60))
                .foregroundColor(Color("HauzFocus").opacity(0.5))*/
            
            Text("No Sneakers Yet")
                .font(.custom("Outfit-Black", size: 20))
                .foregroundColor(Color("HauzFocus"))
            
            Text("Add sneakers to this collection from your liked sneakers")
                .font(.custom("Outfit-Black", size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Data Functions
    
    private func loadSneakers() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let fetchedSneakers = try await collectionsService.fetchSneakersInCollection(collectionId: collection.id)
            await MainActor.run {
                sneakers = fetchedSneakers
            }
        } catch {
            debugPrint("Failed to load sneakers in collection: \(error)")
        }
    }
    
    private func removeSneaker(_ sneaker: SneakerInCollection) {
        // Remove from local UI with smooth animation first (optimistic update)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            sneakers.removeAll { $0.id == sneaker.id }
        }
        
        // Delete from database (async)
        Task {
            do {
                try await collectionsService.removeSneakerFromCollection(sneakerId: sneaker.id, collectionId: collection.id)
                onUpdate()
                print("✅ Removed \(sneaker.name) from collection")
            } catch {
                debugPrint("❌ Failed to remove sneaker: \(error)")
                // If delete fails, reload
                await loadSneakers()
            }
        }
    }
}

// MARK: - Collection Flippable Card
struct CollectionFlippableCard: View {
    let sneaker: SneakerInCollection
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            // Pure white background
            Color.white
            
            // Main content
            VStack(spacing: 0) {
                // MASSIVE shoe section with price floating on top
                ZStack(alignment: .topTrailing) {
                    Color.white
                    
                    // Giant shoe image
                    if let url = sneaker.imageUrl {
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
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 320, height: 200)
                            .foregroundColor(.gray.opacity(0.3))
                            .padding(.vertical, 30)
                            .padding(.horizontal, 20)
                    }
                    
                    // Floating price badge - top right
                    Text(sneaker.price.map { "$\(Int($0))" } ?? "$—")
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
                        Text(sneaker.name)
                            .font(.custom("Outfit-SemiBold", size: 15))
                            .foregroundColor(Color("HauzBg"))
                            .lineLimit(1)
                        
                        Text(sneaker.brand)
                            .font(.custom("Outfit-SemiBold", size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // View button
                    Button(action: {
                        if let link = sneaker.stockxLink, let url = URL(string: link) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color("HauzBg"))
                    }
                    .disabled(sneaker.stockxLink == nil)
                    .opacity(sneaker.stockxLink == nil ? 0.5 : 1.0)
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
    }
}

// MARK: - Swipeable Collection Card
struct SwipeableCollectionCard: View {
    let sneaker: SneakerInCollection
    let isActive: Bool
    @Binding var activeSwipeID: UUID?
    let onRemove: () -> Void
    
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
            
            // Delete button
            deleteButton
                .frame(width: buttonWidth)
                .padding(.trailing, 10)
            
            // Main content with fixed width
            CollectionFlippableCard(sneaker: sneaker, onRemove: onRemove)
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
        if translation < 0 && activeSwipeID != sneaker.id && activeSwipeID != nil {
            activeSwipeID = nil
        }
        
        if translation < 0 {
            let rawOffset = translation
            offset = max(rawOffset, -autoDeleteThreshold - 50)
            
            let swipeDistance = abs(offset)
            let maxWidth = screenWidth
            let expandedWidth = minButtonWidth + (swipeDistance * 0.7)
            let brightnessProgress = min(abs(offset) / autoDeleteThreshold, 1.0)
            
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 1.0
                buttonOpacity = 1.0
                buttonWidth = min(expandedWidth, maxWidth)
                buttonBrightness = brightnessProgress * 0.15
            }
            
            if abs(offset) >= autoDeleteThreshold {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
        } else if offset < 0 {
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
        
        if abs(offset) >= autoDeleteThreshold {
            performDelete()
            return
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if abs(offset) > swipeThreshold || velocity < -300 {
                offset = -initialSwipeDistance
                buttonScale = 1.0
                buttonOpacity = 1.0
                buttonWidth = minButtonWidth + (initialSwipeDistance * 0.7)
                buttonBrightness = (initialSwipeDistance / autoDeleteThreshold) * 0.15
                
                activeSwipeID = sneaker.id
                
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } else {
                closeSwipe()
            }
        }
    }
    
    private func closeSwipe() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            offset = 0
            buttonScale = 1.0
            buttonOpacity = 0
            buttonWidth = minButtonWidth
            buttonBrightness = 0
        }
        
        if activeSwipeID == sneaker.id {
            activeSwipeID = nil
        }
    }
    
    private func performDeleteWithAutoSwipe() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            offset = -autoDeleteThreshold
            buttonWidth = minButtonWidth + (autoDeleteThreshold * 0.7)
            buttonBrightness = 0.15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            performDelete()
        }
    }
    
    private func performDelete() {
        isDeleting = true
        activeSwipeID = nil
        
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.95)) {
            itemHeight = 0
            verticalPadding = -6
            offset = -400
            buttonOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onRemove()
        }
    }
}

#Preview {
    CollectionDetailView(
        collection: Collection(
            id: UUID(),
            userId: UUID(),
            name: "Favorites",
            createdAt: Date(),
            updatedAt: Date(),
            coverImageUrl: nil,
            itemCount: 0
        ),
        onUpdate: {}
    )
}
