import Foundation

public struct AlHaTorahBookmark: Codable, Identifiable, Equatable {
    public let id: String
    public let type: String
    public let location: AlHaTorahLocation
    public let createdAt: Date?

    public init(id: String, type: String = "mg-full", location: AlHaTorahLocation, createdAt: Date? = nil) {
        self.id = id
        self.type = type
        self.location = location
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type
        case location
        case createdAt
    }

    public var displayTitle: String {
        location.displayTitle
    }

    public var displayTitleEn: String {
        location.displayTitleEn
    }

    public var readerURL: URL? {
        location.readerURL
    }
}

public struct AlHaTorahNote: Codable, Identifiable, Equatable {
    public let id: String
    public let dataType: String
    public var title: String
    public var content: String
    public let paragraph: Int?
    public let begin: Int?
    public let end: Int?
    public let type: String
    public let location: AlHaTorahLocation

    public init(
        id: String,
        dataType: String = "gilayon",
        title: String,
        content: String,
        paragraph: Int? = nil,
        begin: Int? = nil,
        end: Int? = nil,
        type: String = "mg-full",
        location: AlHaTorahLocation
    ) {
        self.id = id
        self.dataType = dataType
        self.title = title
        self.content = content
        self.paragraph = paragraph
        self.begin = begin
        self.end = end
        self.type = type
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case dataType
        case title
        case content
        case paragraph
        case begin
        case end
        case type
        case location
    }

    public var plainContent: String {
        Self.stripHTML(from: content)
    }

    public var displayTitle: String {
        let loc = location.displayTitle
        if title.isEmpty {
            return loc
        }
        return "\(title) (\(loc))"
    }

    public var readerURL: URL? {
        location.readerURL
    }

    public static func stripHTML(from html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<br/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        let entities = [
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&nbsp;", " "),
            ("&#39;", "'"),
            ("&#34;", "\"")
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct AlHaTorahHighlight: Codable, Identifiable, Equatable {
    public let id: String
    public let dataType: String
    public var color: String
    public let paragraph: Int?
    public let begin: Int
    public let end: Int
    public let type: String
    public let location: AlHaTorahLocation

    public init(
        id: String,
        dataType: String = "highlight",
        color: String,
        paragraph: Int? = nil,
        begin: Int,
        end: Int,
        type: String = "mg-full",
        location: AlHaTorahLocation
    ) {
        self.id = id
        self.dataType = dataType
        self.color = color
        self.paragraph = paragraph
        self.begin = begin
        self.end = end
        self.type = type
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case dataType
        case color
        case paragraph
        case begin
        case end
        case type
        case location
    }

    public var displayTitle: String {
        location.displayTitle
    }
}

public struct AlHaTorahHistoryItem: Codable, Identifiable, Equatable {
    public let id: String
    public let base: String
    public let locnum: String?
    public let title: String
    public let urlString: String
    public let commentator: String?
    public let visitedAt: Date
    public let isSynced: Bool

    public init(
        id: String = UUID().uuidString,
        base: String,
        locnum: String? = nil,
        title: String,
        urlString: String,
        commentator: String? = nil,
        visitedAt: Date = Date(),
        isSynced: Bool = true
    ) {
        self.id = id
        self.base = base
        self.locnum = locnum
        self.title = title
        self.urlString = urlString
        self.commentator = commentator
        self.visitedAt = visitedAt
        self.isSynced = isSynced
    }

    public var url: URL? {
        URL(string: urlString)
    }

    public var displayCorpus: String {
        switch base.lowercased() {
        case "tanakh": return "תנ\"ך"
        case "shas": return "ש\"ס"
        case "mishna": return "משנה"
        case "rambam": return "רמב\"ם"
        case "library": return "ספרייה"
        default: return base
        }
    }
}

public struct AlHaTorahPaletteColor: Identifiable, Equatable {
    public let id: String
    public let nameHe: String
    public let nameEn: String
    public let hex: String
    public let rgbString: String

    public static let yellow = AlHaTorahPaletteColor(
        id: "yellow",
        nameHe: "צהוב",
        nameEn: "Yellow",
        hex: "#fffc6a",
        rgbString: "rgb(255, 252, 106)"
    )

    public static let pink = AlHaTorahPaletteColor(
        id: "pink",
        nameHe: "ורוד",
        nameEn: "Pink",
        hex: "#ffaed7",
        rgbString: "rgb(255, 174, 215)"
    )

    public static let orange = AlHaTorahPaletteColor(
        id: "orange",
        nameHe: "כתום",
        nameEn: "Orange",
        hex: "#ffa579",
        rgbString: "rgb(255, 165, 121)"
    )

    public static let green = AlHaTorahPaletteColor(
        id: "green",
        nameHe: "ירוק",
        nameEn: "Green",
        hex: "#88ff88",
        rgbString: "rgb(136, 255, 136)"
    )

    public static let blue = AlHaTorahPaletteColor(
        id: "blue",
        nameHe: "כחול",
        nameEn: "Blue",
        hex: "#81d1ff",
        rgbString: "rgb(129, 209, 255)"
    )

    public static let purple = AlHaTorahPaletteColor(
        id: "purple",
        nameHe: "סגול",
        nameEn: "Purple",
        hex: "#bf80ff",
        rgbString: "rgb(191, 128, 255)"
    )

    public static let all: [AlHaTorahPaletteColor] = [
        yellow, pink, orange, green, blue, purple
    ]
}

public struct AlHaTorahRawAnnotation: Codable {
    public let id: String
    public let dataType: String
    public let type: String?
    public let title: String?
    public let content: String?
    public let color: String?
    public let paragraph: Int?
    public let begin: Int?
    public let end: Int?
    public let location: RawLocation?

    public struct RawLocation: Codable {
        public let base: String?
        public let book: String?
        public let largeUnit: String?
        public let subUnit: Int?
        public let parshan: String?
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case dataType
        case type
        case title
        case content
        case color
        case paragraph
        case begin
        case end
        case location
    }

    public func toBookmark() -> AlHaTorahBookmark? {
        guard dataType == "bookmark", let loc = location, let book = loc.book else { return nil }
        let locationObj = AlHaTorahLocation(
            type: type ?? "mg-full",
            mg: loc.base ?? "Tanakh",
            book: book,
            unit: loc.largeUnit ?? "1",
            subUnit: loc.subUnit ?? 1,
            parshan: loc.parshan ?? "_mainVerse"
        )
        return AlHaTorahBookmark(id: id, type: type ?? "mg-full", location: locationObj)
    }

    public func toNote() -> AlHaTorahNote? {
        guard dataType == "gilayon", let loc = location, let book = loc.book else { return nil }
        let locationObj = AlHaTorahLocation(
            type: type ?? "mg-full",
            mg: loc.base ?? "Tanakh",
            book: book,
            unit: loc.largeUnit ?? "1",
            subUnit: loc.subUnit ?? 1,
            parshan: loc.parshan ?? "_mainVerse"
        )
        return AlHaTorahNote(
            id: id,
            dataType: dataType,
            title: title ?? "",
            content: content ?? "",
            paragraph: paragraph,
            begin: begin,
            end: end,
            type: type ?? "mg-full",
            location: locationObj
        )
    }

    public func toHighlight() -> AlHaTorahHighlight? {
        guard dataType == "highlight", let loc = location, let book = loc.book else { return nil }
        let locationObj = AlHaTorahLocation(
            type: type ?? "mg-full",
            mg: loc.base ?? "Tanakh",
            book: book,
            unit: loc.largeUnit ?? "1",
            subUnit: loc.subUnit ?? 1,
            parshan: loc.parshan ?? "_mainVerse"
        )
        return AlHaTorahHighlight(
            id: id,
            dataType: dataType,
            color: color ?? "rgb(255, 252, 106)",
            paragraph: paragraph,
            begin: begin ?? 0,
            end: end ?? 0,
            type: type ?? "mg-full",
            location: locationObj
        )
    }
}

public struct AlHaTorahExportResponse: Codable {
    public let id: String
    public let name: String?
    public let email: String?
    public let createdAt: String?
    public let data: ExportDataPayload?

    public struct ExportDataPayload: Codable {
        public let bookmark: [AlHaTorahRawAnnotation]?
        public let gilayon: [AlHaTorahRawAnnotation]?
        public let highlight: [AlHaTorahRawAnnotation]?
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case createdAt
        case data
    }
}
