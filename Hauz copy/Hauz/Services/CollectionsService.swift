import Foundation
import Supabase

class CollectionsService {
    // MARK: - Fetch Collections
    
    /// Fetch all collections for the current user
    func fetchCollections() async throws -> [Collection] {
        let response = try await supabase
            .from("collections")
            .select()
            .order("updated_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let collections = try decoder.decode([Collection].self, from: response.data)
        return collections
    }
    
    /// Fetch sneakers in a specific collection
    func fetchSneakersInCollection(collectionId: UUID) async throws -> [SneakerInCollection] {
        let response = try await supabase
            .from("collection_items")
            .select("""
                id,
                added_at,
                sneakers_only:sneaker_id (
                    id,
                    name,
                    brand,
                    image_url,
                    retail_price,
                    link
                )
            """)
            .eq("collection_id", value: collectionId.uuidString)
            .order("added_at", ascending: false)
            .execute()
        
        let json = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
        
        var sneakers: [SneakerInCollection] = []
        let dateFormatter = ISO8601DateFormatter()
        
        for item in json {
            guard let sneakerData = item["sneakers_only"] as? [String: Any],
                  let idString = sneakerData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = sneakerData["name"] as? String,
                  let brand = sneakerData["brand"] as? String else {
                continue
            }
            
            let imageUrlString = sneakerData["image_url"] as? String
            let imageUrl = imageUrlString.flatMap { URL(string: $0) }
            let price = sneakerData["retail_price"] as? Double
            let link = sneakerData["link"] as? String
            
            let addedAtString = item["added_at"] as? String ?? ""
            let addedAt = dateFormatter.date(from: addedAtString) ?? Date()
            
            let sneaker = SneakerInCollection(
                id: id,
                name: name,
                brand: brand,
                imageUrl: imageUrl,
                price: price,
                stockxLink: link,
                addedAt: addedAt
            )
            sneakers.append(sneaker)
        }
        
        return sneakers
    }
    
    // MARK: - Create Collection
    
    func createCollection(name: String) async throws -> Collection {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        struct NewCollection: Encodable {
            let user_id: UUID
            let name: String
        }
        
        let newCollection = NewCollection(user_id: userId, name: name)
        
        let response = try await supabase
            .from("collections")
            .insert(newCollection)
            .select()
            .single()
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let collection = try decoder.decode(Collection.self, from: response.data)
        return collection
    }
    
    // MARK: - Add Sneaker to Collection
    
    func addSneakerToCollection(sneakerId: UUID, collectionId: UUID) async throws {
        struct NewItem: Encodable {
            let collection_id: UUID
            let sneaker_id: UUID
        }
        
        let newItem = NewItem(collection_id: collectionId, sneaker_id: sneakerId)
        
        _ = try await supabase
            .from("collection_items")
            .insert(newItem)
            .execute()
        
        print("Added sneaker to collection")
    }
    
    // MARK: - Remove Sneaker from Collection
    
    func removeSneakerFromCollection(sneakerId: UUID, collectionId: UUID) async throws {
        _ = try await supabase
            .from("collection_items")
            .delete()
            .eq("collection_id", value: collectionId.uuidString)
            .eq("sneaker_id", value: sneakerId.uuidString)
            .execute()
        
        print("Removed sneaker from collection")
    }
    
    // MARK: - Check if Sneaker is in Collection
    
    func isSneakerInCollection(sneakerId: UUID, collectionId: UUID) async throws -> Bool {
        let response = try await supabase
            .from("collection_items")
            .select("id")
            .eq("collection_id", value: collectionId.uuidString)
            .eq("sneaker_id", value: sneakerId.uuidString)
            .execute()
        
        let json = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
        return !json.isEmpty
    }
    
    // MARK: - Get Collections for a Sneaker
    
    func getCollectionsForSneaker(sneakerId: UUID) async throws -> [UUID] {
        let response = try await supabase
            .from("collection_items")
            .select("collection_id")
            .eq("sneaker_id", value: sneakerId.uuidString)
            .execute()
        
        let json = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
        return json.compactMap { item in
            guard let idString = item["collection_id"] as? String else { return nil }
            return UUID(uuidString: idString)
        }
    }
    
    // MARK: - Delete Collection
    
    func deleteCollection(collectionId: UUID) async throws {
        _ = try await supabase
            .from("collections")
            .delete()
            .eq("id", value: collectionId.uuidString)
            .execute()
        
        print("Deleted collection")
    }
    
    // MARK: - Rename Collection
    
    func renameCollection(collectionId: UUID, newName: String) async throws {
        struct UpdateName: Encodable {
            let name: String
        }
        
        let update = UpdateName(name: newName)
        
        _ = try await supabase
            .from("collections")
            .update(update)
            .eq("id", value: collectionId.uuidString)
            .execute()
        
        print("Renamed collection to: \(newName)")
    }
}

// MARK: - Supporting Models

struct SneakerInCollection: Identifiable {
    let id: UUID
    let name: String
    let brand: String
    let imageUrl: URL?
    let price: Double?
    let stockxLink: String?
    let addedAt: Date
}
