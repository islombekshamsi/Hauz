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
            CreateCollectionSheet { newName in
                await createCollection(name: newName)
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
    
    private func createCollection(name: String) async {
        do {
            let newCollection = try await collectionsService.createCollection(name: name)
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    collections.insert(newCollection, at: 0)
                }
            }
            print("✅ Created collection: \(name)")
        } catch {
            debugPrint("Failed to create collection: \(error)")
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
    
    let onCreate: (String) async -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("HauzBg").ignoresSafeArea()
                
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
                    
                    Spacer()
                    
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
    }
    
    private func createAndDismiss() {
        guard !collectionName.isEmpty, !isCreating else { return }
        isCreating = true
        
        Task {
            await onCreate(collectionName)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    CollectionsView()
}
