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
  let username: String?
  let fullName: String?
  let gender: String?

  enum CodingKeys: String, CodingKey {
    case username
    case fullName = "full_name"
    case gender
  }
}

struct UpdateProfileParams: Encodable {
  let username: String
  let fullName: String
  let gender: String

  enum CodingKeys: String, CodingKey {
    case username
    case fullName = "full_name"
    case gender
  }
}
