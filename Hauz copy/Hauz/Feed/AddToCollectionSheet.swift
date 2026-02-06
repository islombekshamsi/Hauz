import SwiftUI

struct AddToCollectionSheet: View {
    let sneakerId: UUID
    let sneakerName: String
    
    @Environment(\.dismiss) var dismiss
    @State private var collections: [Collection] = []
    @State private var selectedCollections: Set<UUID> = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showCreateNew = false
    
    private let collectionsService = CollectionsService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("HauzBg").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Sneaker name
                    Text(sneakerName)
                        .font(.custom("bernoru-blackultraexpanded", size: 18))
                        .foregroundColor(Color("HauzFocus"))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    Text("Select collections")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                        Spacer()
                    } else if collections.isEmpty {
                        emptyState
                    } else {
                        // Collections list
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(collections) { collection in
                                    CollectionCheckRow(
                                        collection: collection,
                                        isSelected: selectedCollections.contains(collection.id)
                                    ) {
                                        toggleCollection(collection.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        
                        // Save button
                        Button(action: saveAndDismiss) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Save")
                                    .font(.custom("bernoru-blackultraexpanded", size: 18))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("HauzFocus"))
                        )
                        .disabled(isSaving)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("HauzFocus"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateNew = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("HauzFocus"))
                            .font(.system(size: 22))
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateNew) {
            CreateCollectionSheet { newName, _ in
                await createAndSelectCollection(name: newName)
            }
        }
        .task {
            await loadCollections()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color("HauzFocus").opacity(0.5))
            
            Text("No Collections Yet")
                .font(.custom("bernoru-blackultraexpanded", size: 22))
                .foregroundColor(Color("HauzFocus"))
            
            Text("Create your first collection to save this sneaker")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showCreateNew = true
            }) {
                Text("Create Collection")
                    .font(.custom("bernoru-blackultraexpanded", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
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
            
            // Load which collections already have this sneaker
            let existingCollections = try await collectionsService.getCollectionsForSneaker(sneakerId: sneakerId)
            await MainActor.run {
                selectedCollections = Set(existingCollections)
            }
        } catch {
            debugPrint("Failed to load collections: \(error)")
        }
    }
    
    private func toggleCollection(_ collectionId: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedCollections.contains(collectionId) {
                selectedCollections.remove(collectionId)
            } else {
                selectedCollections.insert(collectionId)
            }
        }
    }
    
    private func createAndSelectCollection(name: String) async {
        do {
            let newCollection = try await collectionsService.createCollection(name: name)
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    collections.insert(newCollection, at: 0)
                    selectedCollections.insert(newCollection.id)
                }
            }
        } catch {
            debugPrint("Failed to create collection: \(error)")
        }
    }
    
    private func saveAndDismiss() {
        guard !isSaving else { return }
        isSaving = true
        
        Task {
            do {
                // Get existing collections for this sneaker
                let existingCollections = try await collectionsService.getCollectionsForSneaker(sneakerId: sneakerId)
                let existingSet = Set(existingCollections)
                
                // Find collections to add to (newly selected)
                let toAdd = selectedCollections.subtracting(existingSet)
                
                // Find collections to remove from (newly deselected)
                let toRemove = existingSet.subtracting(selectedCollections)
                
                // Add to new collections
                for collectionId in toAdd {
                    try await collectionsService.addSneakerToCollection(sneakerId: sneakerId, collectionId: collectionId)
                }
                
                // Remove from deselected collections
                for collectionId in toRemove {
                    try await collectionsService.removeSneakerFromCollection(sneakerId: sneakerId, collectionId: collectionId)
                }
                
                await MainActor.run {
                    dismiss()
                }
                
                print("✅ Updated sneaker collections")
            } catch {
                debugPrint("Failed to save collections: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Collection Check Row
struct CollectionCheckRow: View {
    let collection: Collection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Cover image thumbnail
                if let coverUrl = collection.coverImageUrl,
                   let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color("HauzLight")
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        Color("HauzLight")
                        Image(systemName: "photo.stack")
                            .font(.system(size: 20))
                            .foregroundColor(Color("HauzFocus").opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Collection info
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.custom("Outfit-SemiBold", size: 18))
                        .foregroundColor(Color("HauzBg"))
                        .lineLimit(1)
                    
                    Text("\(collection.itemCount) \(collection.itemCount == 1 ? "item" : "items")")
                        .font(.custom("Outfit-SemiBold", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color("HauzFocus") : .gray.opacity(0.3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color("HauzFocus") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AddToCollectionSheet(sneakerId: UUID(), sneakerName: "Air Jordan 1 Retro High OG")
}
