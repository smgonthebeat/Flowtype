import Foundation

struct Hotword: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isEnabled = isEnabled
    }
}
