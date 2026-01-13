import SwiftUI

struct CollectionDetailView: View {
    let collection: Collection
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var sneakers: [SneakerInCollection] = []
    @State private var isLoading = false
    
    private let collectionsService = CollectionsService()
    
    // Grid layout (2 columns)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
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
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(sneakers) { sneaker in
                                SneakerGridCell(sneaker: sneaker)
                                    .contextMenu {
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
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
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "shoeprints.fill")
                .font(.system(size: 60))
                .foregroundColor(Color("HauzFocus").opacity(0.5))
            
            Text("No Sneakers Yet")
                .font(.custom("bernoru-blackultraexpanded", size: 22))
                .foregroundColor(Color("HauzFocus"))
            
            Text("Add sneakers to this collection from your liked sneakers")
                .font(.system(size: 15))
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
        Task {
            do {
                try await collectionsService.removeSneakerFromCollection(sneakerId: sneaker.id, collectionId: collection.id)
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        sneakers.removeAll { $0.id == sneaker.id }
                    }
                }
                onUpdate()
                print("✅ Removed sneaker from collection")
            } catch {
                debugPrint("Failed to remove sneaker: \(error)")
            }
        }
    }
}

// MARK: - Sneaker Grid Cell
struct SneakerGridCell: View {
    let sneaker: SneakerInCollection
    
    var body: some View {
        VStack(spacing: 0) {
            // Sneaker image
            ZStack {
                if let url = sneaker.imageUrl {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    } placeholder: {
                        Color.white
                            .overlay {
                                ProgressView()
                            }
                    }
                } else {
                    Color.white
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                }
            }
            .frame(height: 140)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("HauzFocus").opacity(0.2), lineWidth: 1)
            )
            
            // Sneaker info
            VStack(alignment: .leading, spacing: 4) {
                Text(sneaker.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("HauzBg"))
                    .lineLimit(2)
                    .frame(height: 34, alignment: .top)
                
                if let price = sneaker.price {
                    Text("$\(Int(price))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("HauzFocus"))
                } else {
                    Text("Price N/A")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
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
