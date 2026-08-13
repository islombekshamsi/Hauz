import Foundation

struct Features: Codable, Identifiable, Hashable{
    var id: Int?
    var createdAt: Date
    var text: String
    var isComplete: Bool
    var userID: UUID
    
    enum CodingKeys: String, CodingKey {
        case id, text
        case createdAt = "created_at"
        case isComplete = "is_complete"
        case userID = "user_id"
    }
    
}

struct Sneaker: Codable, Identifiable {
    let id: UUID
    let name: String
    let brand: String
    let image_url: String?
    let link: String?
    let retail_price: Double?
    let release_date: String?
}

struct Profile: Decodable {
    let id: UUID?
    let username: String?
    let fullName: String?
    let gender: String?
    let avatarURL: String?
    let brands: [String]?
    let phoneNumber: String?
    let priceMin: Double?
    let priceMax: Double?
    let swipedRightIds: [UUID]?
    let swipedLeftIds: [UUID]?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case gender
        case avatarURL = "avatar_url"
        case brands
        case phoneNumber = "phone_number"
        case priceMin = "price_min"
        case priceMax = "price_max"
        case swipedRightIds = "swiped_right_ids"
        case swipedLeftIds = "swiped_left_ids"
        case updatedAt = "updated_at"
    }
}

struct UpdateProfileParams: Encodable {
    let username: String?
    let fullName: String?
    let gender: String?
    let avatarURL: String?
    let brands: [String]?
    let phoneNumber: String?
    let priceMin: Double?
    let priceMax: Double?
    let swipedRightIds: [UUID]?
    let swipedLeftIds: [UUID]?
    
    enum CodingKeys: String, CodingKey {
        case username
        case fullName = "full_name"
        case gender
        case avatarURL = "avatar_url"
        case brands
        case phoneNumber = "phone_number"
        case priceMin = "price_min"
        case priceMax = "price_max"
        case swipedRightIds = "swiped_right_ids"
        case swipedLeftIds = "swiped_left_ids"
    }
}

// MARK: - Collections Models
struct Collection: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let coverImageUrl: String?
    let itemCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case coverImageUrl = "cover_image_url"
        case itemCount = "item_count"
    }
}

struct CollectionItem: Codable, Identifiable {
    let id: UUID
    let collectionId: UUID
    let sneakerId: UUID
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case collectionId = "collection_id"
        case sneakerId = "sneaker_id"
        case addedAt = "added_at"
    }
}

struct CreateCollectionParams: Encodable {
    let userId: UUID
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
    }
}
