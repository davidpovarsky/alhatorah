import Foundation

public struct AlHaTorahLocation: Codable, Equatable, Hashable {
    public var type: String
    public var mg: String
    public var book: String
    public var unit: String
    public var subUnit: Int
    public var parshan: String
    public var paragraph: Int?
    public var begin: Int?
    public var end: Int?

    public init(
        type: String = "mg-full",
        mg: String = "Tanakh",
        book: String,
        unit: String,
        subUnit: Int = 1,
        parshan: String = "_mainVerse",
        paragraph: Int? = nil,
        begin: Int? = nil,
        end: Int? = nil
    ) {
        self.type = type
        self.mg = mg
        self.book = book
        self.unit = unit
        self.subUnit = subUnit
        self.parshan = parshan
        self.paragraph = paragraph
        self.begin = begin
        self.end = end
    }

    enum CodingKeys: String, CodingKey {
        case type
        case mg
        case book
        case unit
        case subUnit
        case parshan
        case paragraph
        case begin
        case end
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "mg-full"
        self.mg = try container.decodeIfPresent(String.self, forKey: .mg) ?? "Tanakh"
        self.book = try container.decodeIfPresent(String.self, forKey: .book) ?? ""
        
        if let unitString = try? container.decode(String.self, forKey: .unit) {
            self.unit = unitString
        } else if let unitInt = try? container.decode(Int.self, forKey: .unit) {
            self.unit = String(unitInt)
        } else {
            self.unit = "1"
        }

        if let subUnitInt = try? container.decode(Int.self, forKey: .subUnit) {
            self.subUnit = subUnitInt
        } else if let subUnitStr = try? container.decode(String.self, forKey: .subUnit), let intVal = Int(subUnitStr) {
            self.subUnit = intVal
        } else {
            self.subUnit = 1
        }

        self.parshan = try container.decodeIfPresent(String.self, forKey: .parshan) ?? "_mainVerse"
        self.paragraph = try container.decodeIfPresent(Int.self, forKey: .paragraph)
        self.begin = try container.decodeIfPresent(Int.self, forKey: .begin)
        self.end = try container.decodeIfPresent(Int.self, forKey: .end)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(mg, forKey: .mg)
        try container.encode(book, forKey: .book)
        try container.encode(unit, forKey: .unit)
        try container.encode(subUnit, forKey: .subUnit)
        try container.encode(parshan, forKey: .parshan)
        
        // Normalize paragraph 0 to nil for server encoding compatibility
        if let paragraph = paragraph, paragraph > 0 {
            try container.encode(paragraph, forKey: .paragraph)
        } else {
            try container.encodeNil(forKey: .paragraph)
        }
        try container.encodeIfPresent(begin, forKey: .begin)
        try container.encodeIfPresent(end, forKey: .end)
    }

    public var isCommentary: Bool {
        parshan != "_mainVerse" && parshan != "_mainVerseEn" && parshan != "_mainTur"
    }

    public var isTranslation: Bool {
        parshan == "_mainVerseEn"
    }

    public var normalizedParagraph: Int {
        paragraph ?? 0
    }

    public var readerURL: URL? {
        let cleanBook = book.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBook.isEmpty else { return nil }

        let mgLower = mg.lowercased()
        if mgLower.contains("shas") {
            let encodedBook = cleanBook.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanBook
            let encodedUnit = unit.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? unit
            return URL(string: "https://shas.alhatorah.org/Full/Shas/\(encodedBook)/\(encodedUnit)")
        }

        if type == "mg-dual" && isCommentary {
            let encodedParshan = parshan.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parshan
            let encodedBook = cleanBook.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanBook
            let unitPart = subUnit > 0 ? "\(unit).\(subUnit)" : unit
            return URL(string: "https://mg.alhatorah.org/Dual/\(encodedParshan)/\(encodedBook)/\(unitPart)")
        }

        let corpus = mg.isEmpty ? "Tanakh" : mg
        let encodedCorpus = corpus.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? corpus
        let encodedBook = cleanBook.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanBook
        let unitPart = subUnit > 0 ? "\(unit).\(subUnit)" : unit
        return URL(string: "https://mg.alhatorah.org/Full/\(encodedCorpus)/\(encodedBook)/\(unitPart)")
    }

    public static func from(url: URL) -> AlHaTorahLocation? {
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard pathComponents.count >= 3 else { return nil }

        let host = url.host?.lowercased() ?? ""
        let isShas = host.contains("shas") || (pathComponents.count >= 2 && pathComponents[1].lowercased() == "shas")
        let mode = pathComponents[0].lowercased() // "full" or "dual"

        if isShas {
            // e.g. /Full/Shas/Berakhot/2a
            let book = pathComponents.count > 2 ? pathComponents[2] : ""
            let unit = pathComponents.count > 3 ? pathComponents[3] : "2a"
            return AlHaTorahLocation(
                type: "mg-full",
                mg: "Shas",
                book: book,
                unit: unit,
                subUnit: 0,
                parshan: "_mainVerse"
            )
        }

        if mode == "dual" {
            // e.g. /Dual/Rashi/Shemot/6.1
            let parshan = pathComponents.count > 1 ? pathComponents[1] : "_mainVerse"
            let book = pathComponents.count > 2 ? pathComponents[2] : ""
            let unitPart = pathComponents.count > 3 ? pathComponents[3] : "1"
            let (unit, subUnit) = parseUnitPart(unitPart)
            return AlHaTorahLocation(
                type: "mg-dual",
                mg: "Tanakh",
                book: book,
                unit: unit,
                subUnit: subUnit,
                parshan: parshan
            )
        }

        if mode == "full" {
            // e.g. /Full/Tanakh/Shemot/6.1
            let corpus = pathComponents.count > 1 ? pathComponents[1] : "Tanakh"
            let book = pathComponents.count > 2 ? pathComponents[2] : ""
            let unitPart = pathComponents.count > 3 ? pathComponents[3] : "1"
            let (unit, subUnit) = parseUnitPart(unitPart)
            return AlHaTorahLocation(
                type: "mg-full",
                mg: corpus,
                book: book,
                unit: unit,
                subUnit: subUnit,
                parshan: "_mainVerse"
            )
        }

        return nil
    }

    private static func parseUnitPart(_ part: String) -> (String, Int) {
        if part.contains(".") {
            let pieces = part.split(separator: ".", maxSplits: 1)
            let unit = String(pieces[0])
            let sub = pieces.count > 1 ? (Int(pieces[1]) ?? 1) : 1
            return (unit, sub)
        }
        return (part, 1)
    }

    public var displayTitle: String {
        let bookName = HebrewNames.hebrewBook(for: book)
        let chapterNumeral = HebrewNames.hebrewNumeral(for: unit)
        let verseNumeral = subUnit > 0 ? HebrewNames.hebrewNumeral(for: String(subUnit)) : ""

        var title = bookName
        if !chapterNumeral.isEmpty {
            title += " " + chapterNumeral
        }
        if !verseNumeral.isEmpty {
            title += ", " + verseNumeral
        }

        if isCommentary {
            title += " • " + parshan
        }
        return title
    }

    public var displayTitleEn: String {
        var title = book
        if !unit.isEmpty {
            title += " \(unit)"
        }
        if subUnit > 0 {
            title += ":\(subUnit)"
        }
        if isCommentary {
            title += " (\(parshan))"
        }
        return title
    }

    public func formUrlEncodedString(includeOffsets: Bool = true) -> String {
        var items: [(String, String)] = [
            ("type", type),
            ("mg", mg),
            ("book", book),
            ("unit", unit),
            ("subUnit", String(subUnit)),
            ("parshan", parshan)
        ]

        if let paragraph = paragraph, paragraph > 0 {
            items.append(("paragraph", String(paragraph)))
        }

        if includeOffsets {
            if let begin = begin {
                items.append(("begin", String(begin)))
            }
            if let end = end {
                items.append(("end", String(end)))
            }
        }

        return items.map { key, val in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedVal = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? val
            return "\(escapedKey)=\(escapedVal)"
        }.joined(separator: "&")
    }
}

public enum HebrewNames {
    private static let bookMap: [String: String] = [
        "Bereshit": "בראשית", "Genesis": "בראשית",
        "Shemot": "שמות", "Exodus": "שמות",
        "Vayikra": "ויקרא", "Leviticus": "ויקרא",
        "Bemidbar": "במדבר", "Numbers": "במדבר",
        "Devarim": "דברים", "Deuteronomy": "דברים",
        "Yehoshua": "יהושע", "Joshua": "יהושע",
        "Shoftim": "שופטים", "Judges": "שופטים",
        "Shemuel I": "שמואל א", "I Samuel": "שמואל א",
        "Shemuel II": "שמואל ב", "II Samuel": "שמואל ב",
        "Melakhim I": "מלכים א", "I Kings": "מלכים א",
        "Melakhim II": "מלכים ב", "II Kings": "מלכים ב",
        "Yeshayahu": "ישעיהו", "Isaiah": "ישעיהו",
        "Yirmeyahu": "ירמיהו", "Jeremiah": "ירמיהו",
        "Yechezkel": "יחזקאל", "Ezekiel": "יחזקאל",
        "Hoshea": "הושע", "Hosea": "הושע",
        "Yoel": "יואל", "Joel": "יואל",
        "Amos": "עמוס",
        "Ovadyah": "עובדיה", "Obadiah": "עובדיה",
        "Yonah": "יונה", "Jonah": "יונה",
        "Mikhah": "מיכה", "Micah": "מיכה",
        "Nachum": "נחום", "Nahum": "נחום",
        "Chavakuk": "חבקוק", "Habakkuk": "חבקוק",
        "Tzefanyah": "צפניה", "Zephaniah": "צפניה",
        "Chaggai": "חגי", "Haggai": "חגי",
        "Zekharyah": "זכריה", "Zechariah": "זכריה",
        "Malakhi": "מלאכי", "Malachi": "מלאכי",
        "Tehillim": "תהלים", "Psalms": "תהלים",
        "Mishlei": "משלי", "Proverbs": "משלי",
        "Iyov": "איוב", "Job": "איוב",
        "Shir HaShirim": "שיר השירים", "Song of Songs": "שיר השירים",
        "Rut": "רות", "Ruth": "רות",
        "Eikhah": "איכה", "Lamentations": "איכה",
        "Kohelet": "קהלת", "Ecclesiastes": "קהלת",
        "Esther": "אסתר",
        "Daniel": "דניאל",
        "Ezra": "עזרא",
        "Nechemyah": "נחמיה", "Nehemiah": "נחמיה",
        "Divrei HaYamim I": "דברי הימים א", "I Chronicles": "דברי הימים א",
        "Divrei HaYamim II": "דברי הימים ב", "II Chronicles": "דברי הימים ב",
        "Berakhot": "ברכות", "Shabbat": "שבת", "Eruvin": "עירובין",
        "Pesachim": "פסחים", "Yoma": "יומא", "Sukkah": "סוכה",
        "Beitzah": "ביצה", "Rosh Hashanah": "ראש השנה",
        "Taanit": "תענית", "Megillah": "מגילה", "Moed Katan": "מועד קטן",
        "Chagigah": "חגיגה", "Yevamot": "יבמות", "Ketubot": "כתובות",
        "Nedarim": "נדרים", "Nazir": "נזיר", "Sotah": "סוטה",
        "Gittin": "גיטין", "Kiddushin": "קידושין", "Bava Kamma": "בבא קמא",
        "Bava Metzia": "בבא מציעא", "Bava Batra": "בבא בתרא",
        "Sanhedrin": "סנהדרין", "Makkot": "מכות", "Shevuot": "שבועות",
        "Avodah Zarah": "עבודה זרה", "Horayot": "הוריות",
        "Zevachim": "זבחים", "Menachot": "מנחות", "Chullin": "חולין",
        "Bekhorot": "בכורות", "Arakhin": "ערכין", "Temurah": "תמורה",
        "Keritot": "כריתות", "Meilah": "מעילה", "Tamid": "תמיד", "Niddah": "נדה"
    ]

    public static func hebrewBook(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return bookMap[trimmed] ?? trimmed
    }

    public static func hebrewNumeral(for value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let num = Int(clean) {
            return toHebrewNumeral(num)
        }
        // If Daf like "141b" -> קמא, ע"ב
        let isAmudB = clean.hasSuffix("b") || clean.hasSuffix("2") || clean.hasSuffix("ב")
        let digits = clean.filter { $0.isNumber }
        if let dafNum = Int(digits) {
            let hebDaf = toHebrewNumeral(dafNum)
            return isAmudB ? "\(hebDaf), ע\"ב" : "\(hebDaf), ע\"א"
        }
        return value
    }

    public static func toHebrewNumeral(_ number: Int) -> String {
        guard number > 0 && number < 1000 else { return "\(number)" }
        var n = number
        var result = ""

        let hundreds = [
            (400, "ת"), (300, "ש"), (200, "ר"), (100, "ק")
        ]
        for (val, letter) in hundreds {
            while n >= val {
                result += letter
                n -= val
            }
        }

        if n == 15 {
            return result + "טו"
        }
        if n == 16 {
            return result + "טז"
        }

        let tens = [
            (90, "צ"), (80, "פ"), (70, "ע"), (60, "ס"), (50, "נ"),
            (40, "מ"), (30, "ל"), (20, "כ"), (10, "י")
        ]
        for (val, letter) in tens {
            if n >= val {
                result += letter
                n -= val
            }
        }

        let ones = [
            (9, "ט"), (8, "ח"), (7, "ז"), (6, "ו"), (5, "ה"),
            (4, "ד"), (3, "ג"), (2, "ב"), (1, "א")
        ]
        for (val, letter) in ones {
            if n >= val {
                result += letter
                n -= val
            }
        }

        return result
    }
}
