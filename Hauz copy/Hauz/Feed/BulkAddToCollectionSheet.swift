import SwiftUI

struct BulkAddToCollectionSheet: View {
    let sneakerIds: [UUID]
    let sneakerCount: Int
    let onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var collections: [Collection] = []
    @State private var selectedCollections: Set<UUID> = []
    @State private var isLoading = false
    @State private var isAdding = false
    @State private var showCreateNew = false
    
    private let collectionsService = CollectionsService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("HauzBg").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header info
                    VStack(spacing: 8) {
                       /* Image(systemName: "shoeprints.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color("HauzFocus"))*/
                        
                        Text("Add \(sneakerCount) \(sneakerCount == 1 ? "Sneaker" : "Sneakers")")
                            .font(.custom("Outfit-SemiBold", size: 28))
                            .foregroundColor(Color("HauzFocus"))
                        
                        Text("Select collections")
                            .font(.custom("Outfit-SemiBold", size: 20))
                            .foregroundColor(Color("HauzLight").opacity(0.7))
                    }
                    .padding(.vertical, 20)
                    
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
                        
                        // Add button
                        Button(action: addAndDismiss) {
                            if isAdding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                HStack(spacing: 8) {
                                   // Image(systemName: "checkmark.circle.fill")
                                    Text("Add")
                                }
                                .font(.custom("Outfit-SemiBold", size: 20))
                                .foregroundColor(Color("HauzLight"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedCollections.isEmpty ? Color.gray : Color("HauzFocus"))
                        )
                        .disabled(selectedCollections.isEmpty || isAdding)
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
                    .font(.custom("Outfit-SemiBold", size: 14))
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
            
            Text("Create your first collection to save these sneakers")
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
    
    private func addAndDismiss() {
        guard !isAdding, !selectedCollections.isEmpty else { return }
        isAdding = true
        
        Task {
            do {
                // Add each sneaker to each selected collection
                for collectionId in selectedCollections {
                    for sneakerId in sneakerIds {
                        // Try to add, ignore duplicates
                        try? await collectionsService.addSneakerToCollection(
                            sneakerId: sneakerId,
                            collectionId: collectionId
                        )
                    }
                }
                
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
                
                print("✅ Added \(sneakerIds.count) sneakers to \(selectedCollections.count) collections")
            } catch {
                debugPrint("Failed to add sneakers to collections: \(error)")
                await MainActor.run {
                    isAdding = false
                }
            }
        }
    }
}

#Preview {
    BulkAddToCollectionSheet(
        sneakerIds: [UUID(), UUID(), UUID()],
        sneakerCount: 3,
        onComplete: {}
    )
}
