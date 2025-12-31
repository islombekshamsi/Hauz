import Foundation
import SwiftUI

struct Card: Identifiable, Hashable{
    var id: String = UUID().uuidString
    var image: String
}


let cards: [Card] = [
    .init(image: "preview1"),
    .init(image: "preview2"),
    .init(image: "preview3"),
    .init(image: "preview4"),
]
