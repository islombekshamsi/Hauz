import SwiftUI

struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var selectedCollection: Collection?
    
    private let collectionsService = CollectionsService()
    
    // Grid layout (2 columns) - comfortable spacing
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            Color("HauzBg").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with + button
                header
                
                if isLoading && collections.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                    Spacer()
                } else if collections.isEmpty {
                    // Empty state
                    emptyState
                } else {
                    // Collections grid with comfortable spacing
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(collections) { collection in
                                CollectionGridItem(collection: collection)
                                    .onTapGesture {
                                        selectedCollection = collection
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteCollection(collection)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCollectionSheet { newName, selectedBrands in
                await createCollection(name: newName, brands: selectedBrands)
            }
        }
        .sheet(item: $selectedCollection) { collection in
            CollectionDetailView(collection: collection, onUpdate: {
                Task { await loadCollections() }
            })
        }
        .task {
            await loadCollections()
        }
        .onAppear {
            // Refresh when view appears (e.g., switching tabs)
            Task { await loadCollections() }
        }
        .refreshable {
            await loadCollections()
        }
    }
    
    private var header: some View {
        HStack {
            Text("Collections")
                .font(.custom("Outfit-Black", size: 32))
                .foregroundColor(Color("HauzFocus"))
            
            Spacer()
            
            // Plus button to create new collection
            Button(action: {
                showCreateSheet = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color("HauzFocus"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color("HauzBg"))
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 60))
                .foregroundColor(Color("HauzFocus").opacity(0.5))
            
            Text("No Collections Yet")
                .font(.custom("Outfit-Black", size: 22))
                .foregroundColor(Color("HauzFocus"))
            
            Text("Create your first collection to organize your favorite sneakers")
                .font(.custom("Outfit-Medium", size: 15))
                .foregroundColor(Color("HauzLight"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showCreateSheet = true
            }) {
                Text("Create Collection")
                    .font(.custom("Outfit-Black", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 45)
                    .padding(.vertical, 15)
                    .background(Color("HauzFocus"))
                    .clipShape(Capsule())
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // MARK: - Data Functions
    
    private func loadCollections() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let fetchedCollections = try await collectionsService.fetchCollections()
            await MainActor.run {
                collections = fetchedCollections
            }
        } catch {
            debugPrint("Failed to load collections: \(error)")
        }
    }
    
    private func createCollection(name: String, brands: [String]) async {
        do {
            let newCollection = try await collectionsService.createCollection(name: name)
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    collections.insert(newCollection, at: 0)
                }
            }
            print("✅ Created collection: \(name)")
            
            // Auto-fill collection with sneakers from selected brands
            if !brands.isEmpty {
                await autoFillCollection(collectionId: newCollection.id, brands: brands)
            }
        } catch {
            debugPrint("Failed to create collection: \(error)")
        }
    }
    
    private func autoFillCollection(collectionId: UUID, brands: [String]) async {
        do {
            let feedService = FeedService()
            let likedShoes = try await feedService.fetchLikedForProfile()
            
            // Filter shoes by selected brands
            let matchingShoes = likedShoes.filter { shoe in
                brands.contains(shoe.brand)
            }
            
            // Add matching shoes to collection
            for shoe in matchingShoes {
                try? await collectionsService.addSneakerToCollection(sneakerId: shoe.id, collectionId: collectionId)
            }
            
            print("✅ Auto-filled collection with \(matchingShoes.count) sneakers from \(brands.count) brand(s)")
            
            // Reload collections to update counts
            await loadCollections()
        } catch {
            debugPrint("Failed to auto-fill collection: \(error)")
        }
    }
    
    private func deleteCollection(_ collection: Collection) {
        Task {
            do {
                try await collectionsService.deleteCollection(collectionId: collection.id)
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        collections.removeAll { $0.id == collection.id }
                    }
                }
                print("✅ Deleted collection: \(collection.name)")
            } catch {
                debugPrint("Failed to delete collection: \(error)")
            }
        }
    }
}

// MARK: - Collection Grid Item
struct CollectionGridItem: View {
    let collection: Collection
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main container with border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color("HauzFocus").opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                    )
                
                // Cover image or empty state
                VStack(spacing: 0) {
                    if let coverUrl = collection.coverImageUrl,
                       let url = URL(string: coverUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.width)
                                .clipped()
                        } placeholder: {
                            Color("HauzLight")
                                .frame(height: geometry.size.width * 0.6)
                                .overlay {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                                }
                        }
                    } else {
                        // Empty state
                        Color("HauzLight")
                            .frame(height: geometry.size.width * 0.6)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.stack")
                                        .font(.system(size: 35))
                                        .foregroundColor(Color("HauzFocus").opacity(0.3))
                                    
                                    Text("0")
                                        .font(.custom("bernoru-blackultraexpanded", size: 16))
                                        .foregroundColor(Color("HauzFocus").opacity(0.4))
                                }
                            }
                    }
                    
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Bottom bar with name and count
                VStack(alignment: .leading, spacing: 3) {
                    Text(collection.name)
                        .font(.custom("bernoru-blackultraexpanded", size: 13))
                        .foregroundColor(Color("HauzFocus"))
                        .lineLimit(1)
                    
                    Text("\(collection.itemCount) \(collection.itemCount == 1 ? "item" : "items")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(collection.itemCount == 0 ? Color("HauzFocus").opacity(0.4) : Color("HauzBg").opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
                )
                .offset(y: -1)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Create Collection Sheet
struct CreateCollectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var collectionName = ""
    @State private var isCreating = false
    @State private var availableBrands: [String] = []
    @State private var selectedBrands: [String] = []
    @State private var isLoadingBrands = true
    
    let onCreate: (String, [String]) async -> Void
    
    private let feedService = FeedService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("HauzBg").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 40)
                        
                        // Icon
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(Color("HauzFocus"))
                        
                        Text("New Collection")
                            .font(.custom("Outfit-Black", size: 28))
                            .foregroundColor(Color("HauzFocus"))
                        
                        // Text field
                        TextField("Collection name", text: $collectionName)
                            .font(.custom("Outfit-Black", size: 18))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                            .submitLabel(.done)
                            .onSubmit {
                                if !collectionName.isEmpty {
                                    createAndDismiss()
                                }
                            }
                        
                        Text("Max 50 characters")
                            .font(.custom("Outfit-Black", size: 13))
                            .foregroundColor(Color("HauzLight"))
                        
                        // Brand selection section
                        if !availableBrands.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Quick Fill by Brand")
                                        .font(.custom("Outfit-SemiBold", size: 18))
                                        .foregroundColor(Color("HauzFocus"))
                                    
                                    Spacer()
                                    
                                    if !selectedBrands.isEmpty {
                                        Text("\(selectedBrands.count) selected")
                                            .font(.custom("Outfit-Medium", size: 14))
                                            .foregroundColor(Color("HauzLight"))
                                    }
                                }
                                .padding(.horizontal, 30)
                                .padding(.top, 10)
                                
                                Text("Select brands to auto-add your liked sneakers")
                                    .font(.custom("Outfit-Medium", size: 13))
                                    .foregroundColor(Color("HauzLight"))
                                    .padding(.horizontal, 30)
                                
                                // Brand chips - using the same layout as UserInfo
                                CollectionBrandChipsView(
                                    spacing: 12,
                                    brands: availableBrands,
                                    content: { brand, isSelected in
                                        CollectionBrandChip(
                                            brand: brand,
                                            isSelected: isSelected
                                        )
                                    },
                                    didChangeSelection: { selection in
                                        selectedBrands = selection
                                    },
                                    selectedBrands: $selectedBrands
                                )
                                .padding(.horizontal, 30)
                                .padding(.top, 8)
                            }
                        } else if isLoadingBrands {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                                .padding(.top, 20)
                        }
                        
                        Spacer().frame(height: 20)
                        
                        // Create button
                        Button(action: createAndDismiss) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Create")
                                    .font(.custom("Outfit-Black", size: 18))
                                    .foregroundColor(Color("HauzLight"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(collectionName.isEmpty ? Color.gray : Color("HauzFocus"))
                        )
                        .disabled(collectionName.isEmpty || isCreating)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("Outfit-Black", size: 18))
                    .foregroundColor(Color("HauzFocus"))
                }
            }
        }
        .task {
            await loadBrands()
        }
    }
    
    private func loadBrands() async {
        do {
            let likedShoes = try await feedService.fetchLikedForProfile()
            
            // Extract unique brands, sorted alphabetically
            let brands = Set(likedShoes.map { $0.brand })
                .sorted()
            
            await MainActor.run {
                availableBrands = brands
                isLoadingBrands = false
            }
        } catch {
            debugPrint("Failed to load brands: \(error)")
            await MainActor.run {
                isLoadingBrands = false
            }
        }
    }
    
    private func createAndDismiss() {
        guard !collectionName.isEmpty, !isCreating else { return }
        isCreating = true
        
        Task {
            await onCreate(collectionName, selectedBrands)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Collection Brand Chips View (matching UserInfo.swift style)
struct CollectionBrandChipsView<Content: View>: View {
    var spacing: CGFloat = 12
    var brands: [String]
    var animation: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    @ViewBuilder var content: (String, Bool) -> Content
    var didChangeSelection: ([String]) -> ()
    @Binding var selectedBrands: [String]
    
    var body: some View {
        CollectionCustomChipLayout(spacing: spacing) {
            ForEach(brands, id: \.self) { brand in
                content(brand, selectedBrands.contains(brand))
                    .contentShape(.rect)
                    .onTapGesture {
                        handleTap(on: brand)
                    }
            }
        }
    }
    
    private func handleTap(on brand: String) {
        withAnimation(animation) {
            if selectedBrands.contains(brand) {
                selectedBrands.removeAll(where: { $0 == brand })
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                selectedBrands.append(brand)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
        didChangeSelection(selectedBrands)
    }
}

// MARK: - Collection Custom Chip Layout (matching UserInfo.swift)
fileprivate struct CollectionCustomChipLayout: Layout {
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

// MARK: - Collection Brand Chip (matching UserInfo.swift style)
struct CollectionBrandChip: View {
    let brand: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(brand)
                .font(.custom("Outfit-Medium", size: 16))
                .foregroundStyle(isSelected ? .white : Color.primary)
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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

#Preview {
    CollectionsView()
}
