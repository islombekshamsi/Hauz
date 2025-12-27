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
