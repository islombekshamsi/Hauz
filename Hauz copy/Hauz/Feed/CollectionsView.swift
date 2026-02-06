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
                                
                                // Brand chips
                                BrandChipsView(
                                    brands: availableBrands,
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

// MARK: - Brand Chips View
struct BrandChipsView: View {
    let brands: [String]
    @Binding var selectedBrands: [String]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(brands, id: \.self) { brand in
                BrandChip(
                    brand: brand,
                    isSelected: selectedBrands.contains(brand),
                    onTap: {
                        toggleBrand(brand)
                    }
                )
            }
        }
    }
    
    private func toggleBrand(_ brand: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedBrands.contains(brand) {
                selectedBrands.removeAll { $0 == brand }
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } else {
                selectedBrands.append(brand)
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }
}

// MARK: - Brand Chip
struct BrandChip: View {
    let brand: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(brand)
                .font(.custom("Outfit-SemiBold", size: 14))
                .foregroundColor(isSelected ? .white : Color("HauzFocus"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color("HauzFocus") : Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    Capsule()
                        .stroke(Color("HauzFocus"), lineWidth: isSelected ? 0 : 1.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    CollectionsView()
}
