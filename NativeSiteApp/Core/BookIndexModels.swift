import Foundation

struct BookIndexItem: Codable, Equatable {
    let id: String
    let titleHe: String
    let titleEn: String
    let aliases: [String]
    let categoryTitles: [String]
    let sectionNames: [String]
    let searchableText: String
}

struct BookTreeNode: Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    var children: [BookTreeNode]
    let item: BookIndexItem?
    var bookCount: Int
}

struct BookIndexBundle: Codable, Equatable {
    let signature: String
    let createdAt: Date
    let booksIndex: [BookIndexItem]
    let booksTree: BookTreeNode
}

struct RefPHPDocument {
    let text: String
    let signature: String
    let downloadedAt: Date
    let source: RefPHPSource
}

enum RefPHPSource: String {
    case downloaded
    case cached
}

struct SpotlightRefreshSummary {
    let itemCount: Int
    let indexedCount: Int
    let skipped: Bool
    let source: RefPHPSource
    let signature: String
    let message: String
}
