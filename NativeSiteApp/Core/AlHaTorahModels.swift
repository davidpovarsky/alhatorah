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

        enum CodingKeys: String, CodingKey {
            case base
            case book
            case largeUnit
            case unit
            case subUnit
            case parshan
        }

        public init(
            base: String? = nil,
            book: String? = nil,
            largeUnit: String? = nil,
            subUnit: Int? = nil,
            parshan: String? = nil
        ) {
            self.base = base
            self.book = book
            self.largeUnit = largeUnit
            self.subUnit = subUnit
            self.parshan = parshan
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.base = try? container.decodeIfPresent(String.self, forKey: .base)
            self.book = try? container.decodeIfPresent(String.self, forKey: .book)
            self.parshan = try? container.decodeIfPresent(String.self, forKey: .parshan)

            if let str = try? container.decodeIfPresent(String.self, forKey: .largeUnit) {
                self.largeUnit = str
            } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .largeUnit) {
                self.largeUnit = String(intVal)
            } else if let str = try? container.decodeIfPresent(String.self, forKey: .unit) {
                self.largeUnit = str
            } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .unit) {
                self.largeUnit = String(intVal)
            } else {
                self.largeUnit = nil
            }

            if let intVal = try? container.decodeIfPresent(Int.self, forKey: .subUnit) {
                self.subUnit = intVal
            } else if let str = try? container.decodeIfPresent(String.self, forKey: .subUnit), let intVal = Int(str) {
                self.subUnit = intVal
            } else {
                self.subUnit = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(base, forKey: .base)
            try container.encodeIfPresent(book, forKey: .book)
            try container.encodeIfPresent(largeUnit, forKey: .largeUnit)
            try container.encodeIfPresent(subUnit, forKey: .subUnit)
            try container.encodeIfPresent(parshan, forKey: .parshan)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case altId = "id"
        case data
        case dataType
        case type
        case title
        case content
        case color
        case paragraph
        case begin
        case end
        case location
        case loc
    }

    private enum DataCodingKeys: String, CodingKey {
        case dataType
        case type
        case title
        case content
        case color
        case paragraph
        case begin
        case end
        case location
        case loc
    }

    public init(
        id: String,
        dataType: String,
        type: String? = nil,
        title: String? = nil,
        content: String? = nil,
        color: String? = nil,
        paragraph: Int? = nil,
        begin: Int? = nil,
        end: Int? = nil,
        location: RawLocation? = nil
    ) {
        self.id = id
        self.dataType = dataType
        self.type = type
        self.title = title
        self.content = content
        self.color = color
        self.paragraph = paragraph
        self.begin = begin
        self.end = end
        self.location = location
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .altId))
            ?? UUID().uuidString

        let dataContainer = try? container.nestedContainer(keyedBy: DataCodingKeys.self, forKey: .data)

        self.dataType = (try? container.decodeIfPresent(String.self, forKey: .dataType))
            ?? (try? dataContainer?.decodeIfPresent(String.self, forKey: .dataType))
            ?? "unknown"

        self.type = (try? container.decodeIfPresent(String.self, forKey: .type))
            ?? (try? dataContainer?.decodeIfPresent(String.self, forKey: .type))

        self.title = (try? container.decodeIfPresent(String.self, forKey: .title))
            ?? (try? dataContainer?.decodeIfPresent(String.self, forKey: .title))

        self.content = (try? container.decodeIfPresent(String.self, forKey: .content))
            ?? (try? dataContainer?.decodeIfPresent(String.self, forKey: .content))

        self.color = (try? container.decodeIfPresent(String.self, forKey: .color))
            ?? (try? dataContainer?.decodeIfPresent(String.self, forKey: .color))

        if let p = try? container.decodeIfPresent(Int.self, forKey: .paragraph) {
            self.paragraph = p
        } else if let p = try? dataContainer?.decodeIfPresent(Int.self, forKey: .paragraph) {
            self.paragraph = p
        } else if let pStr = try? container.decodeIfPresent(String.self, forKey: .paragraph), let p = Int(pStr) {
            self.paragraph = p
        } else if let pStr = try? dataContainer?.decodeIfPresent(String.self, forKey: .paragraph), let p = Int(pStr) {
            self.paragraph = p
        } else {
            self.paragraph = nil
        }

        if let b = try? container.decodeIfPresent(Int.self, forKey: .begin) {
            self.begin = b
        } else if let b = try? dataContainer?.decodeIfPresent(Int.self, forKey: .begin) {
            self.begin = b
        } else if let bStr = try? container.decodeIfPresent(String.self, forKey: .begin), let b = Int(bStr) {
            self.begin = b
        } else if let bStr = try? dataContainer?.decodeIfPresent(String.self, forKey: .begin), let b = Int(bStr) {
            self.begin = b
        } else {
            self.begin = nil
        }

        if let e = try? container.decodeIfPresent(Int.self, forKey: .end) {
            self.end = e
        } else if let e = try? dataContainer?.decodeIfPresent(Int.self, forKey: .end) {
            self.end = e
        } else if let eStr = try? container.decodeIfPresent(String.self, forKey: .end), let e = Int(eStr) {
            self.end = e
        } else if let eStr = try? dataContainer?.decodeIfPresent(String.self, forKey: .end), let e = Int(eStr) {
            self.end = e
        } else {
            self.end = nil
        }

        self.location = (try? container.decodeIfPresent(RawLocation.self, forKey: .location))
            ?? (try? dataContainer?.decodeIfPresent(RawLocation.self, forKey: .location))
            ?? (try? container.decodeIfPresent(RawLocation.self, forKey: .loc))
            ?? (try? dataContainer?.decodeIfPresent(RawLocation.self, forKey: .loc))

        if self.location == nil && self.title == nil && self.content == nil && self.color == nil && (self.dataType == "unknown" || self.dataType.isEmpty) {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Object contains no recognized annotation data"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dataType, forKey: .dataType)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(paragraph, forKey: .paragraph)
        try container.encodeIfPresent(begin, forKey: .begin)
        try container.encodeIfPresent(end, forKey: .end)
        try container.encodeIfPresent(location, forKey: .location)
    }

    public func toBookmark(fallbackDataType: String = "bookmark") -> AlHaTorahBookmark? {
        let effType = (dataType == "unknown" || dataType.isEmpty) ? fallbackDataType : dataType
        guard effType == "bookmark", let loc = location, let book = loc.book else { return nil }
        let canonical = HebrewNames.canonicalMg(from: loc.base)
        let locationObj = AlHaTorahLocation(
            type: type ?? "mg-full",
            mg: canonical,
            book: book,
            unit: loc.largeUnit ?? "1",
            subUnit: loc.subUnit ?? 0,
            parshan: loc.parshan ?? "_mainVerse"
        )
        return AlHaTorahBookmark(id: id, type: type ?? "mg-full", location: locationObj)
    }

    public func toNote(fallbackDataType: String = "gilayon") -> AlHaTorahNote? {
        let effType = (dataType == "unknown" || dataType.isEmpty) ? fallbackDataType : dataType
        guard effType == "gilayon", let loc = location, let book = loc.book else { return nil }
        let canonical = HebrewNames.canonicalMg(from: loc.base)
        let locationObj = AlHaTorahLocation(
            type: type ?? "mg-full",
            mg: canonical,
            book: book,
            unit: loc.largeUnit ?? "1",
            subUnit: loc.subUnit ?? 0,
            parshan: loc.parshan ?? "_mainVerse"
        )
        return AlHaTorahNote(
            id: id,
            dataType: effType,
            title: title ?? "",
            content: content ?? "",
            paragraph: paragraph,
            begin: begin,
            end: end,
            type: type ?? "mg-full",
            location: locationObj
        )
    }

    public func toHighlight(fallbackDataType: String = "highlight") -> AlHaTorahHighlight? {
        let effType = (dataType == "unknown" || dataType.isEmpty) ? fallbackDataType : dataType
        guard effType == "highlight", let loc = location, let book = loc.book else { return nil }
        let canonical = HebrewNames.canonicalMg(from: loc.base)
        let locationObj = AlHaTorahLocation(
            type: type ?? "mg-full",
            mg: canonical,
            book: book,
            unit: loc.largeUnit ?? "1",
            subUnit: loc.subUnit ?? 0,
            parshan: loc.parshan ?? "_mainVerse"
        )
        return AlHaTorahHighlight(
            id: id,
            dataType: effType,
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

        enum CodingKeys: String, CodingKey {
            case bookmark
            case gilayon
            case highlight
        }

        public init(
            bookmark: [AlHaTorahRawAnnotation]? = nil,
            gilayon: [AlHaTorahRawAnnotation]? = nil,
            highlight: [AlHaTorahRawAnnotation]? = nil
        ) {
            self.bookmark = bookmark
            self.gilayon = gilayon
            self.highlight = highlight
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.bookmark = Self.decodeTolerantArray(forKey: .bookmark, from: container)
            self.gilayon = Self.decodeTolerantArray(forKey: .gilayon, from: container)
            self.highlight = Self.decodeTolerantArray(forKey: .highlight, from: container)
        }

        private static func decodeTolerantArray(
            forKey key: CodingKeys,
            from container: KeyedDecodingContainer<CodingKeys>
        ) -> [AlHaTorahRawAnnotation]? {
            guard container.contains(key) else { return nil }
            guard var unkeyed = try? container.nestedUnkeyedContainer(forKey: key) else { return nil }
            var result: [AlHaTorahRawAnnotation] = []
            while !unkeyed.isAtEnd {
                if let item = try? unkeyed.decode(AlHaTorahRawAnnotation.self) {
                    result.append(item)
                } else {
                    _ = try? unkeyed.decode(DiscardableElement.self)
                }
            }
            return result
        }

        private struct DiscardableElement: Decodable {
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if container.decodeNil() { return }
                if (try? container.decode(Bool.self)) != nil { return }
                if (try? container.decode(Double.self)) != nil { return }
                if (try? container.decode(String.self)) != nil { return }
                if (try? container.decode([String: DiscardableElement].self)) != nil { return }
                if (try? container.decode([DiscardableElement].self)) != nil { return }
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case createdAt
        case data
    }
}
