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
        subUnit: Int = 0,
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
            self.subUnit = 0
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

    public static func canonicalSubdomain(for corpus: String, book: String) -> String {
        let c = corpus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = book.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Direct corpus check
        if c.contains("shas") || c.contains("bavli") || c.contains("talmud") {
            return "shas"
        }
        if c.contains("tur") || c.contains("shulchan arukh") || c.contains("shulchanarukh") || c.contains("shulchan_arukh") {
            return "tur"
        }
        if c.contains("rambam") || c.contains("mishneh torah") || c.contains("mishnehtorah") {
            return "rambam"
        }
        if c.contains("mishna") || c.contains("mishnah") {
            return "mishna"
        }
        if c.contains("tosefta") {
            return "tosefta"
        }
        if c.contains("yerushalmi") {
            return "yerushalmi"
        }
        if c.contains("rif") {
            return "rif"
        }
        if c.contains("moreh") {
            return "moreh"
        }
        if c.contains("chasidut") {
            return "chasidut"
        }
        if c.contains("haggadah") {
            return "haggadah"
        }
        if c.contains("siddur") {
            return "siddur"
        }

        // 2. Infer from book when corpus is ambiguous or defaulted to Tanakh
        if isTurBook(b) {
            return "tur"
        }
        if isRambamBook(b) {
            return "rambam"
        }
        if isShasTractate(b) {
            return "shas"
        }
        if isMishnaTractate(b) && (c.contains("mishna") || !isTanakhBook(b)) {
            return "mishna"
        }

        if c.contains("tanakh") || c.contains("mikraotgedolot") || c.contains("torah") || c.contains("bible") || isTanakhBook(b) {
            return "mg"
        }

        return c == "library" ? "library" : "mg"
    }

    private static let turBooksSet: Set<String> = [
        "choshen mishpat", "orach chayim", "orach chayyim", "yoreh deah", "even haezer",
        "חושן משפט", "אורח חיים", "יורה דעה", "אבן העזר", "tur", "shulchan arukh"
    ]

    private static func isTurBook(_ book: String) -> Bool {
        let clean = book.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return turBooksSet.contains(clean)
    }

    private static let rambamBooksSet: Set<String> = [
        "deiot", "yesodei hatorah", "tefillah", "teshuvah", "kriyat shema", "mishneh torah", "rambam",
        "talmud torah", "avodah zarah", "tefillin", "mezuzah", "sefer torah", "tzitzit", "berakhot",
        "milah", "shevitat asor", "shevitat yom tov", "chametz umatzah", "shofar velulav vechagigah",
        "kiddush hachodesh", "taaniyot", "megillah vechanukah", "ishut", "gerushin", "yibum",
        "naarah betulah", "sotah", "issurei biah", "maakhalot assurot", "shechitah", "shevuot",
        "nedarim", "nezirut", "erakhin", "kilayim", "matanot aniyim", "terumot", "maaser",
        "maaser sheni", "bikkurim", "shemittah", "beit habechirah", "klei hamikdash",
        "bi'at hamikdash", "issurei mizbeach", "maaseh hakorbanot", "temidin umusafin",
        "pesulei hamukdashim", "avodat yom hakippurim", "meilah", "tum'at met", "parah adumah",
        "tum'at tzara'at", "metam'ei mishkav umoshav", "she'ar avot hatum'ah", "tum'at okhalin",
        "kelim", "mikvaot", "nezikei mamon", "geneivah", "gezeilah vaaveidah", "chovel umazik",
        "rotzeach ushemirat nefesh", "makhirah", "zekhiyah umatanah", "shekhenim",
        "sheluchin veshutafin", "avadim", "sekhirut", "she'eilah upikkadon", "malveh veloveh",
        "to'en venit'an", "nachalot", "sanhedrin", "eidut", "mamrim", "evel", "melakhim",
        "דעות", "יסודי התורה", "תשובה", "תפילה", "קריאת שמע", "משנה תורה", "רמב\"ם"
    ]

    private static func isRambamBook(_ book: String) -> Bool {
        let clean = book.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rambamBooksSet.contains(clean)
    }

    private static let shasTractatesSet: Set<String> = [
        "berakhot", "shabbat", "eruvin", "pesachim", "yoma", "sukkah", "beitzah", "rosh hashanah",
        "taanit", "megillah", "moed katan", "chagigah", "yevamot", "ketubot", "nedarim", "nazir",
        "sotah", "gittin", "kiddushin", "bava kamma", "bava metzia", "bava batra", "sanhedrin",
        "makkot", "shevuot", "avodah zarah", "horayot", "zevachim", "menachot", "chullin",
        "bekhorot", "arakhin", "temurah", "keritot", "meilah", "tamid", "niddah",
        "ברכות", "שבת", "עירובין", "פסחים", "יומא", "סוכה", "ביצה", "ראש השנה", "תענית",
        "מגילה", "מועד קטן", "חגיגה", "יבמות", "כתובות", "נדרים", "נזיר", "סוטה", "גיטין",
        "קידושין", "בבא קמא", "בבא מציעא", "בבא בתרא", "סנהדרין", "מכות", "שבועות",
        "עבודה זרה", "הוריות", "זבחים", "מנחות", "חולין", "בכורות", "ערכין", "תמורה",
        "כריתות", "מעילה", "תמיד", "נדה"
    ]

    private static func isShasTractate(_ book: String) -> Bool {
        let clean = book.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return shasTractatesSet.contains(clean)
    }

    private static let mishnaTractatesSet: Set<String> = [
        "peah", "demai", "kilayim", "sheviit", "terumot", "maasrot", "maaser sheni", "challah",
        "orlah", "bikkurim", "shekalim", "ediyot", "avot", "pirkei avot", "zevachim", "menachot",
        "kelim", "ohalot", "negaim", "parah", "taharot", "mikvaot", "yadayim", "uktzin", "machshirin",
        "פאה", "דמאי", "כלאים", "שביעית", "תרומות", "מעשרות", "מעשר שני", "חלה", "ערלה",
        "ביכורים", "שקלים", "עדיות", "אבות", "פרקי אבות", "כלים", "אהלות", "נגעים", "פרה",
        "טהרות", "מקואות", "ידים", "עוקצין", "מכשירין"
    ]

    private static func isMishnaTractate(_ book: String) -> Bool {
        let clean = book.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return mishnaTractatesSet.contains(clean)
    }

    private static let tanakhBooksSet: Set<String> = [
        "bereshit", "genesis", "shemot", "exodus", "vayikra", "leviticus", "bemidbar", "numbers",
        "devarim", "deuteronomy", "yehoshua", "joshua", "shoftim", "judges", "shemuel i", "shemuel ii",
        "i samuel", "ii samuel", "melakhim i", "melakhim ii", "i kings", "ii kings",
        "yeshayahu", "isaiah", "yirmeyahu", "jeremiah", "yechezkel", "ezekiel", "hoshea", "hosea",
        "yoel", "joel", "amos", "ovadyah", "obadiah", "yonah", "jonah", "mikhah", "micah",
        "nachum", "nahum", "chavakuk", "habakkuk", "tzefanyah", "zephaniah", "chaggai", "haggai",
        "zekharyah", "zechariah", "malakhi", "malachi", "tehillim", "psalms", "mishlei", "proverbs",
        "iyov", "job", "shir hashirim", "song of songs", "rut", "ruth", "eikhah", "lamentations",
        "kohelet", "ecclesiastes", "esther", "daniel", "ezra", "nechemyah", "nehemiah",
        "divrei hayamim i", "divrei hayamim ii", "i chronicles", "ii chronicles",
        "בראשית", "שמות", "ויקרא", "במדבר", "דברים", "יהושע", "שופטים", "שמואל א", "שמואל ב",
        "מלכים א", "מלכים ב", "ישעיהו", "ירמיהו", "יחזקאל", "הושע", "יואל", "עמוס", "עובדיה",
        "יונה", "מיכה", "נחום", "חבקוק", "צפניה", "חגי", "זכריה", "מלאכי", "תהלים", "משלי",
        "איוב", "שיר השירים", "רות", "איכה", "קהלת", "אסתר", "דניאל", "עזרא", "נחמיה",
        "דברי הימים א", "דברי הימים ב"
    ]

    private static func isTanakhBook(_ book: String) -> Bool {
        let clean = book.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tanakhBooksSet.contains(clean)
    }

    public var readerURL: URL? {
        let cleanBook = book.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBook.isEmpty else { return nil }

        let subdomain = Self.canonicalSubdomain(for: mg, book: cleanBook)
        let encodedBook = cleanBook.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanBook
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedUnit = cleanUnit.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanUnit

        if type == "mg-dual" && isCommentary {
            let encodedParshan = parshan.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parshan
            let unitPart = subUnit > 0 ? "\(encodedUnit).\(subUnit)" : encodedUnit
            return URL(string: "https://\(subdomain).alhatorah.org/Dual/\(encodedParshan)/\(encodedBook)/\(unitPart)")
        }

        if subdomain == "shas" {
            let unitPart = subUnit > 1 ? "\(encodedUnit).\(subUnit)" : encodedUnit
            return URL(string: "https://shas.alhatorah.org/Full/Shas/\(encodedBook)/\(unitPart)")
        }

        let unitPart = subUnit > 0 ? "\(encodedUnit).\(subUnit)" : encodedUnit
        return URL(string: "https://\(subdomain).alhatorah.org/Full/\(encodedBook)/\(unitPart)")
    }

    public static func from(url: URL) -> AlHaTorahLocation? {
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard pathComponents.count >= 2 else { return nil }

        let host = url.host?.lowercased() ?? ""
        var defaultCorpus = "Tanakh"
        if host.contains("shas") { defaultCorpus = "Shas" }
        else if host.contains("tur") { defaultCorpus = "Tur" }
        else if host.contains("rambam") { defaultCorpus = "Rambam" }
        else if host.contains("mishna") { defaultCorpus = "Mishna" }
        else if host.contains("tosefta") { defaultCorpus = "Tosefta" }
        else if host.contains("yerushalmi") { defaultCorpus = "Yerushalmi" }
        else if host.contains("rif") { defaultCorpus = "Rif" }
        else if host.contains("mg") { defaultCorpus = "Tanakh" }

        let mode = pathComponents[0].lowercased() // "full" or "dual"

        let knownCorpora: Set<String> = [
            "tanakh", "shas", "mishna", "mishnah", "rambam", "tur",
            "shulchan arukh", "shulchanarukh", "tosefta", "yerushalmi", "library"
        ]

        if mode == "dual" {
            // E.g. /Dual/Rashi/Shemot/6.1 or /Dual/Tanakh/Rashi/Shemot/6.1 or /Dual/Beit_Yosef/Choshen_Mishpat/280
            var corpus = defaultCorpus
            var parshan = "_mainVerse"
            var book = ""
            var unitPart = "1"

            if pathComponents.count >= 4 && knownCorpora.contains(pathComponents[1].lowercased().replacingOccurrences(of: "_", with: " ")) {
                corpus = HebrewNames.canonicalMg(from: pathComponents[1])
                parshan = pathComponents[2].replacingOccurrences(of: "_", with: " ")
                book = pathComponents[3].replacingOccurrences(of: "_", with: " ")
                if pathComponents.count > 4 {
                    unitPart = pathComponents[4]
                }
            } else {
                parshan = pathComponents.count > 1 ? pathComponents[1].replacingOccurrences(of: "_", with: " ") : "_mainVerse"
                book = pathComponents.count > 2 ? pathComponents[2].replacingOccurrences(of: "_", with: " ") : ""
                if pathComponents.count > 3 {
                    unitPart = pathComponents[3]
                }
            }

            let (unit, subUnit) = parseUnitPart(unitPart)
            return AlHaTorahLocation(
                type: "mg-dual",
                mg: corpus,
                book: book,
                unit: unit,
                subUnit: subUnit,
                parshan: parshan
            )
        }

        if mode == "full" {
            // E.g. /Full/Devarim/32.1 or /Full/Tanakh/Devarim/32.1 or /Full/Choshen_Mishpat/280 or /Full/Berakhot/2a
            var corpus = defaultCorpus
            var book = ""
            var unitPart = defaultCorpus == "Shas" ? "2a" : "1"

            if pathComponents.count >= 3 && knownCorpora.contains(pathComponents[1].lowercased().replacingOccurrences(of: "_", with: " ")) {
                corpus = HebrewNames.canonicalMg(from: pathComponents[1])
                book = pathComponents[2].replacingOccurrences(of: "_", with: " ")
                if pathComponents.count > 3 {
                    unitPart = pathComponents[3]
                }
            } else {
                book = pathComponents.count > 1 ? pathComponents[1].replacingOccurrences(of: "_", with: " ") : ""
                if pathComponents.count > 2 {
                    unitPart = pathComponents[2]
                }
            }

            let isShas = corpus.lowercased() == "shas" || host.contains("shas")
            let (unit, subUnit) = isShas ? (unitPart, 0) : parseUnitPart(unitPart)

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
            let sub = pieces.count > 1 ? (Int(pieces[1]) ?? 0) : 0
            return (unit, sub)
        }
        return (part, 0)
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
            let parshanName = HebrewNames.hebrewBook(for: parshan)
            title += " • " + parshanName
        }
        return title
    }

    public var displayTitleEn: String {
        let bookNameEn = HebrewNames.englishBook(for: book)
        var title = bookNameEn.isEmpty ? book : bookNameEn
        if !unit.isEmpty {
            title += " \(unit)"
        }
        if subUnit > 0 {
            title += ":\(subUnit)"
        }
        if isCommentary {
            let parshanEn = HebrewNames.englishBook(for: parshan)
            title += " (\(parshanEn.isEmpty ? parshan : parshanEn))"
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

        return FormURLEncoder.encode(items)
    }
}

public enum FormURLEncoder {
    public static func encode(_ parameters: [(String, String)]) -> String {
        parameters.map { key, value in
            "\(percentEncode(key))=\(percentEncode(value))"
        }.joined(separator: "&")
    }

    public static func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet()
        allowed.insert(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

public enum AlHaTorahCanonicalTitles {
    public static let data: String = """
Bereshit	בראשית
Shemot	שמות
Vayikra	ויקרא
Bemidbar	במדבר
Devarim	דברים
Neviim	נביאים
Terei Asar	תרי עשר
Ketuvim	כתובים
Zeraim	זרעים
Moed	מועד
Nashim	נשים
Nezikin	נזיקין
Kodashim	קדשים
Taharot	טהרות
Orach Chayyim	אורח חיים
OC	אורח חיים
Orach Chayim	אורח חיים
Orah Hayyim	אורח חיים
Yoreh Deah	יורה דעה
YD	יורה דעה
Even HaEzer	אבן העזר
EH	אבן העזר
Choshen Mishpat	חושן משפט
CM	חושן משפט
Preface	מבוא
Positive Commandments	מצוות עשה
Negative Commandments	מצוות לא תעשה
Rabbinic Commandments	מצוות מדרבנן
Division of the Mitzvot	חלוקת המצוות
Knowledge	המדע
Yesodei HaTorah	יסודי התורה
Deiot	דעות
Talmud Torah	תלמוד תורה
Avodah Zarah	עבודה זרה וחוקות הגוים
Teshuvah	תשובה
Love	אהבה
Keriat Shema	קריית שמע
Tefillah uBirkat Kohanim	תפילה וברכת כהנים
Tefillin uMezuzah veSefer Torah	תפילין ומזוזה וספר תורה
Tzitzit	ציצית
Berakhot	ברכות
Milah	מילה
Seder Tefilot	סדר תפילות
Times	זמנים
Shabbat	שבת
Eiruvin	עירובין
Shevitat Asor	שביתת עשור
Shevitat Yom Tov	שביתת יום טוב
Chametz uMatzah	חמץ ומצה
Shofar veSukkah veLulav	שופר וסוכה ולולב
Shekalim	שקלים
Kiddush HaChodesh	קידוש החודש
Taaniyot	תעניות
Megillah vaChanukkah	מגילה וחנוכה
Women	נשים
Ishut	אישות
Geirushin	גירושין
Yibbum vaChalitzah	יבום וחליצה
Naarah Betulah	נערה בתולה
Sotah	שוטה
Holiness	קדושה
Issurei Biah	איסורי ביאה
Maakhalot Asurot	מאכלות אסורות
Shechitah	שחיטה
Separation	הפלאה
Shevuot	שבועות
Nedarim	נדרים
Nezirut	נזירות
Arakhim VaCharamim	ערכים וחרמים
Seeds	זרעים
Kilayim	כלאים
Matenot Aniyyim	מתנות עניים
Terumot	תרומות
Ma'aser	מעשר
Ma'aser Sheini	מעשר שני ונטע רבעי
Bikurim	ביכורים עם שאר מתנות כהונה שבגבולין
Shemittah veYovel	שמיטה ויובל
Divine Service	עבודה
Beit HaBechirah	בית הבחירה
Kelei HaMikdash	כלי המקדש והעובדים בו
Biat HaMikdash	ביאת המקדש
Isurei Mizbeach	איסורי מזבח
Ma'aseh HaKorbanot	מעשה הקרבנות
Temidin uMusafin	תמידין ומוספין
Pesulei HaMukdashin	פסולי המוקדשין
Avodat Yom HaKippurim	עבודת יום הכיפורים
Meilah	מעילה
Offerings	קרבנות
Korban Pesach	קרבן פסח
Chagigah	חגיגה
Bekhorot	בכורות
Shegagot	שגגות
Mechuserei Kapparah	מחוסרי כפרה
Temurah	תמורה
Cleanness	טהרה
Tume'at Meit	טומאת מת
Parah Adumah	פרה אדומה
Tume'at Tzara'at	טומאת צרעת
Metame'ei Mishkav uMoshav	מטמאי משכב ומושב
She'ar Avot haTume'ot	שאר אבות הטמאות
Tume'at Okhelin	טומאת אכלין
Keilim	כלים
Mikvot	מקוות
Injuries	נזקים
Nizkei Mamon	נזקי ממון
Geneivah	גניבה
Gezeilah vaAveidah	גזילה ואבידה
Chovel uMazik	חובל ומזיק
Rotzeach uShemirat haNefesh	רוצח ושמירת נפש
Acquisition	קנין
Mekhirah	מכירה
Zekhiyah uMatanah	זכייה ומתנה
Shekheinim	שכנים
Sheluchin veShutafin	שלוחין ושותפין
Avadim	עבדים
Rights	משפטים
Sekhirut	שכירות
She'eilah uPikkadon	שאלה ופקדון
Malveh veLoveh	מלוה ולווה
To'ein veNit'an	טוען ונטען
Nachalot	נחלות
Judges	שופטים
Sanhedrin	סנהדרין והעונשין המסורין להם
Eidut	עדות
Mamrim	ממרים
Eivel	אבל
Melakhim	מלכים ומלחמות
Enoch	ספר חנוך
Demetrius the Chronographer	דמטריוס הכרונוגראף
Qumran Scroll	מגילת קומראן
Qumran	מגילת קומראן
Qumran Scrolls	מגילת קומראן
Dead Sea Scroll	מגילת קומראן
Dead Sea Scrolls	מגילת קומראן
DSS	מגילת קומראן
Qumran Biblical Texts	מגילות מקראיות מקומראן
Qumran by Cave	קומראן לפי מערות
1Q	1Q
Qumran by Cave 1Q	1Q
2Q	2Q
Qumran by Cave 2Q	2Q
3Q	3Q
Qumran by Cave 3Q	3Q
4Q	4Q
Qumran by Cave 4Q	4Q
5Q	5Q
Qumran by Cave 5Q	5Q
6Q	6Q
Qumran by Cave 6Q	6Q
8Q	8Q
Qumran by Cave 8Q	8Q
9Q	9Q
Qumran by Cave 9Q	9Q
10Q	10Q
Qumran by Cave 10Q	10Q
11Q	11Q
Qumran by Cave 11Q	11Q
X	X
Qumran by Cave X	X
MMT	מקצת מעשי התורה
Qumran by Cave MMT	מקצת מעשי התורה
Additional Scrolls	מגילות נוספות
Damascus Document	מגילת ברית דמשק
Additional Scrolls Damascus Document	מגילת ברית דמשק
Damascus Scroll	מגילת ברית דמשק
Ben Sira Fragments	בן סירא קטעים
Additional Scrolls Ben Sira Fragments	בן סירא קטעים
Masada	מצדה
Additional Scrolls Masada	מצדה
Nahal Hever	נחל חבר
Additional Scrolls Nahal Hever	נחל חבר
PAM	PAM
Additional Scrolls PAM	PAM
Wadi Murabba'at	מערות מורבעת
Additional Scrolls Wadi Murabba'at	מערות מורבעת
Samaritan Pentateuch	הנוסח השומרוני
Samaritan	הנוסח השומרוני
SP	הנוסח השומרוני
Megillat HaMikdash	מגילת המקדש
Megilat HaMikdash	מגילת המקדש
Temple Scroll	מגילת המקדש
Letter of Jeremiah	אגרת ירמיהו
Iggeret Yirmeyahu	אגרת ירמיהו
Tobit	ספר טוביה
Book of Tobit	ספר טוביה
Letter of Aristeas	אגרת אריסטיאס
Ben Sira	בן סירא
Ecclusiasticus	בן סירא
Sirach	בן סירא
Ecclus	בן סירא
Jubilees	יובלים
Book of Jubilees	יובלים
Baruch	ספר ברוך
Book of Baruch	ספר ברוך
Vision of Baruch	ספר ברוך
Judith	ספר יהודית
Book of Judith	ספר יהודית
Prayer of Menasseh	תפילת מנשה
Tefilat Menashe	תפילת מנשה
Susanna	ספר שושנה
Book of Susanna	ספר שושנה
Maccabees I	ספר המקבים א
I Maccabees	ספר המקבים א
Maccabees II	ספר המקבים ב
II Maccabees	ספר המקבים ב
Wisdom of Solomon	ספר חכמת שלמה
Wisdom	ספר חכמת שלמה
Esdras	עזרא החיצוני
Book of Esdras	עזרא החיצוני
Eupolemus	אופולמוס
Artapanus	ארטפנוס
Ezekiel the Tragedian	יחזקאל הטרגיקן
Testaments of the Patriarchs	צוואות השבטים
Testaments of the Twelve Patriarchs	צוואות השבטים
Testament of	צוואות השבטים
Philo	פילון
Josephus	יוספוס
Josephus Flavius	יוספוס
Antiquities of the Jews	קדמוניות היהודים
Josephus Antiquities of the Jews	קדמוניות היהודים
Antiquities	קדמוניות היהודים
Wars of the Jews	מלחמות היהודים
Josephus Wars of the Jews	מלחמות היהודים
Against Apion	נגד אפיון
Josephus Against Apion	נגד אפיון
Life of Flavius Josephus	חיי יוסף
Megillat Taanit	מגילת תענית
Megilat Taanit	מגילת תענית
Megillas Taanis	מגילת תענית
Megilas Taanis	מגילת תענית
Pseudo-Philo	פסבדו-פילון
Biblical Antiquities	פסבדו-פילון
Pseudo Philo	פסבדו-פילון
R. Eliezer	ר' אליעזר
Mishna	משנה
Mishna Masekhet	משנה
Mishnah	משנה
Mishnayot	משנה
Mishnayos	משנה
Mishna Printed Editions	משנה
Mishna MS Kaufmann	משנה כתב יד קאופמן
Mishna Formatted	משנה מעוצבת
Mishna MS Kaufmann A50	משנה כ\"י קאופמן A50
Mishna MS R113	משנה כ\"י R113
Mishna MS T-S NS J523	משנה כ\"י T-S NS J523
Mishna MS Antonin 262G	משנה כ\"י אנטונין 262G
Mishna MS Yemenite Tiklal	משנה כ\"י תכלאל תימן
Mishna MS Yemenite Tiklal (חבארה)	משנה כ\"י תכלאל תימן (חבארה)
Mishna Printing Warsaw	משנה דפוס ורשא
Mishna Printing Mekitzei Nirdamim	משנה דפוס מקיצי נרדמים
Tosefta	תוספתא
Mishna Parallels	מקבילות במשנה
Tosefta Printings	תוספתא דפוסים
Tosefta Printed	תוספתא דפוסים
Tosefta Formatted	תוספתא מעוצבת
Tosefta Parallels	מקבילות בתוספתא
Mekhilta DeRabbi Yishmael Shemot	מכילתא דרבי ישמעאל שמות
Mekhilta DeRabbi Yishmael	מכילתא דרבי ישמעאל שמות
Mekhilta	מכילתא דרבי ישמעאל שמות
Mekhilta Shemot	מכילתא דרבי ישמעאל שמות
Mechilta DeRabbi Yishmael Shemot	מכילתא דרבי ישמעאל שמות
Mechilta DeRabbi Yishmael	מכילתא דרבי ישמעאל שמות
Mechilta	מכילתא דרבי ישמעאל שמות
Mechilta Shemot	מכילתא דרבי ישמעאל שמות
Mekhilta DeRashbi Shemot	מכילתא דרשב\"י שמות
Mechilta DeRashbi Shemot	מכילתא דרשב\"י שמות
Mekhilta DeRashbi	מכילתא דרשב\"י שמות
Mechilta DeRashbi	מכילתא דרשב\"י שמות
Mekhilta DeRabbi Shimon b. Yochai Shemot	מכילתא דרשב\"י שמות
Mekhilta DeRabbi Shimon b. Yochai	מכילתא דרשב\"י שמות
Mechilta DeRabbi Shimon b. Yochai Shemot	מכילתא דרשב\"י שמות
Mechilta DeRabbi Shimon b. Yochai	מכילתא דרשב\"י שמות
Sifra Vayikra	ספרא ויקרא
Sifra	ספרא ויקרא
Sifre Bemidbar	ספרי במדבר
Sifrei Bemidbar	ספרי במדבר
Sifre Devarim	ספרי דברים
Sifrei Devarim	ספרי דברים
Sifre Zuta	ספרי זוטא
Sifrei Zuta	ספרי זוטא
Midrash Tannaim	מדרש תנאים
Baraita DeMelekhet HaMishkan	ברייתא דמלאכת המשכן
Baraita DiMelekhet HaMishkan	ברייתא דמלאכת המשכן
Beraita DeMelekhet HaMishkan	ברייתא דמלאכת המשכן
Baraita DeMelechet HaMishkan	ברייתא דמלאכת המשכן
Beraita DiMelekhet HaMishkan	ברייתא דמלאכת המשכן
Baraita DiMelechet HaMishkan	ברייתא דמלאכת המשכן
Beraita DeMelechet HaMishkan	ברייתא דמלאכת המשכן
Baraisa DeMelekhes HaMishkan	ברייתא דמלאכת המשכן
Beraisa DeMelekhes HaMishkan	ברייתא דמלאכת המשכן
Baraisa DeMeleches HaMishkan	ברייתא דמלאכת המשכן
Beraisa DeMeleches HaMishkan	ברייתא דמלאכת המשכן
Seder Olam Rabbah	סדר עולם רבה
Seder Olam Rabba	סדר עולם רבה
Seder Olam	סדר עולם רבה
Yerushalmi	ירושלמי
Talmud Yerushalmi	ירושלמי
Talmud Yerushalmi Masekhet	ירושלמי
Jerusalem Talmud	ירושלמי
Yerushalmi MS Leiden	ירושלמי כתב יד ליידן
Bavli	בבלי
Talmud Bavli	בבלי
Talmud Bavli Masekhet	בבלי
Gemara	בבלי
Babylonian Talmud	בבלי
Bavli MS Melk: Fragm. V	בבלי כתב יד Melk: Fragm. V
Bavli MS Melk Fragm V	בבלי כתב יד Melk: Fragm. V
Bavli MS Munich BS Cod hebr 436XIV	בבלי כתב יד Munich, BS: Cod. hebr. 436.XIV
Bavli MS אסקוריאל	בבלי כתב יד אסקוריאל
Bavli MS Stuttgart, WL: –	בבלי כתב יד Stuttgart, WL: –
Bavli MS Stuttgart WL	בבלי כתב יד Stuttgart, WL: –
Bavli MS Munich BS Cod hebr 151IV	בבלי כתב יד Munich, BS: Cod. hebr. 151.IV
Bavli MS Trento: –	בבלי כתב יד Trento: –
Bavli MS Trento	בבלי כתב יד Trento: –
Bavli MS AIU III A61	בבלי כתב יד AIU: III A.61
Bavli MS CUL T S H15139	בבלי כתב יד CUL: T-S H15.139
Bavli MS AIU III A64	בבלי כתב יד AIU: III A.64
Bavli MS קרמונה	בבלי כתב יד קרמונה
Bavli MS BL Or 1011822C	בבלי כתב יד BL: Or. 10118.22C
Bavli MS AIU III C10	בבלי כתב יד AIU: III C.10
Bavli MS Erfurt 11XXI1a1b	בבלי כתב יד Erfurt: 1–1/XXI/1a–1b
Bavli MS Munich BS Cod hebr 436IX	בבלי כתב יד Munich, BS: Cod. hebr. 436.IX
Bavli MS Alessandria, SV: –	בבלי כתב יד Alessandria, SV: –
Bavli MS Alessandria SV	בבלי כתב יד Alessandria, SV: –
Bavli MS AIU III A3839	בבלי כתב יד AIU: III A.38–39
Bavli MS Basel B VII14	בבלי כתב יד Basel: B VII.14
Bavli MS Lewis Gibson Bibl 631ab	בבלי כתב יד Lewis-Gibson: Bibl. 6.31.a–b
Bavli MS CUL T S NS 29167d	בבלי כתב יד CUL: T-S NS 291.67d +
Bavli MS AIU III A1	בבלי כתב יד AIU: III A.1
Bavli MS CUL T S AS 84minute fragments14	בבלי כתב יד CUL: T-S AS 84.minute fragments.1.[4] +
Bavli MS AIU III A56	בבלי כתב יד AIU: III A.5–6
Bavli MS נירנברג (פפנהיים)	בבלי כתב יד נירנברג (פפנהיים)
Bavli MS נירנברג פפנהיים	בבלי כתב יד נירנברג (פפנהיים)
Bavli MS AIU III A80	בבלי כתב יד AIU: III A.80
Bavli MS Munich BS Cod hebr 436XVI	בבלי כתב יד Munich, BS: Cod. hebr. 436.XVI
Bavli MS AIU III A86	בבלי כתב יד AIU: III A.86
Bavli MS Radolfzell: Hebr. Frag. A–B	בבלי כתב יד Radolfzell: Hebr. Frag. A–B
Bavli MS Radolfzell Hebr Frag AB	בבלי כתב יד Radolfzell: Hebr. Frag. A–B
Bavli MS Munich BS Cod hebr 436VIVII	בבלי כתב יד Munich, BS: Cod. hebr. 436.VI–VII
Bavli MS Munich BS Cod hebr 436VIII	בבלי כתב יד Munich, BS: Cod. hebr. 436.VIII
Bavli MS Sold: –	בבלי כתב יד Sold: –
Bavli MS Sold	בבלי כתב יד Sold: –
Bavli MS Budapest OSK Fol Hebr 7VI	בבלי כתב יד Budapest, OSK: Fol. Hebr. 7/VI
Bavli MS Munich BS Cod hebr 153II1	בבלי כתב יד Munich, BS: Cod. hebr. 153.II.1
Bavli MS AIU III A54	בבלי כתב יד AIU: III A.54
Bavli MS Munich BS Cod hebr 151VIII	בבלי כתב יד Munich, BS: Cod. hebr. 151.VIII
Bavli MS Melk: Fragm. VI	בבלי כתב יד Melk: Fragm. VI
Bavli MS Melk Fragm VI	בבלי כתב יד Melk: Fragm. VI
Bavli MS Melk Fragm IV12	בבלי כתב יד Melk: Fragm. IV.1–2 +
Bavli MS AIU VIB155	בבלי כתב יד AIU: VI.B.155
Bavli MS יד הרב הרצוג	בבלי כתב יד יד הרב הרצוג
Bavli MS Praha NKCR XIXB26	בבלי כתב יד Praha, NKCR: XIX.B.26
Bavli MS AIU III A46	בבלי כתב יד AIU: III A.46
Bavli MS AIU III B248	בבלי כתב יד AIU: III B.248
Bavli MS Sankt Paul Cod 112a4	בבלי כתב יד Sankt Paul: Cod. 112a.4
Bavli MS Columbia: X893IN Z64	בבלי כתב יד Columbia: X893IN Z64
Bavli MS Columbia X893IN Z64	בבלי כתב יד Columbia: X893IN Z64
Bavli MS Munich BS Cod hebr 436X	בבלי כתב יד Munich, BS: Cod. hebr. 436.X
Bavli MS Munich BS Cod hebr 436XXI	בבלי כתב יד Munich, BS: Cod. hebr. 436.XXI
Bavli MS Sankt Paul Cod 593E	בבלי כתב יד Sankt Paul: Cod. 59.3.E
Bavli MS Munich BS Cod hebr 153II3	בבלי כתב יד Munich, BS: Cod. hebr. 153.II.3
Bavli MS CUL T S NS 17038f	בבלי כתב יד CUL: T-S NS 170.38.[f]
Bavli MS Innsbruck BPCW XXXII A11	בבלי כתב יד Innsbruck, BPCW: XXXII A.11
Bavli MS Madrid CSIC MS CVIM106	בבלי כתב יד Madrid, CSIC: MS CVI–M/106
Bavli MS Munich BS Cod hebr 419II4	בבלי כתב יד Munich, BS: Cod. hebr. 419.II.4
Bavli MS AIU III A93	בבלי כתב יד AIU: III A.93
Bavli MS ששון-לונצר	בבלי כתב יד ששון-לונצר
Bavli MS ששון לונצר	בבלי כתב יד ששון-לונצר
Bavli MS Maastricht: III a–d	בבלי כתב יד Maastricht: III a–d
Bavli MS Maastricht III ad	בבלי כתב יד Maastricht: III a–d
Bavli MS AIU III B89	בבלי כתב יד AIU: III B.89 +
Bavli MS AIU III A43	בבלי כתב יד AIU: III A.43
Bavli MS CUL T S NS 29194c	בבלי כתב יד CUL: T-S NS 291.94c +
Bavli MS Latina: –	בבלי כתב יד Latina: –
Bavli MS Latina	בבלי כתב יד Latina: –
Bavli MS JTS: ENA NS I.94c	בבלי כתב יד JTS: ENA NS I.94c
Bavli MS JTS ENA NS I94c	בבלי כתב יד JTS: ENA NS I.94c
Bavli MS Barbasrto, A: –	בבלי כתב יד Barbasrto, A: –
Bavli MS Barbasrto A	בבלי כתב יד Barbasrto, A: –
Bavli MS Praha NKCR XXIVD3	בבלי כתב יד Praha, NKCR: XXIV.D.3
Bavli MS Munich BS Cod hebr 151I4	בבלי כתב יד Munich, BS: Cod. hebr. 151.I.4
Bavli MS Munich BS Cod hebr 419II2	בבלי כתב יד Munich, BS: Cod. hebr. 419.II.2
Bavli MS Budapest Museum 6321C	בבלי כתב יד Budapest, Museum: 63.21.C
Bavli MS פרידברג	בבלי כתב יד פרידברג
Bavli MS Munich BS Cod hebr 419XIX4	בבלי כתב יד Munich, BS: Cod. hebr. 419.XIX.4
Bavli MS Munich BS Cod hebr 436V	בבלי כתב יד Munich, BS: Cod. hebr. 436.V
Bavli MS Munich BS Cod hebr 436XVIIXVIII	בבלי כתב יד Munich, BS: Cod. hebr. 436.XVII–XVIII
Bavli MS Columbia: X893 T144	בבלי כתב יד Columbia: X893 T144
Bavli MS Columbia X893 T144	בבלי כתב יד Columbia: X893 T144
Bavli MS Munich BS Cod hebr 436XIXXX	בבלי כתב יד Munich, BS: Cod. hebr. 436.XIX–XX
Bavli MS Munich BS Cod hebr 436XIII	בבלי כתב יד Munich, BS: Cod. hebr. 436.XIII
Bavli MS Munich BS Cod hebr 436XXIIXXIII	בבלי כתב יד Munich, BS: Cod. hebr. 436.XXII–XXIII
Bavli MS JTS ENA 20841v 2v	בבלי כתב יד JTS: ENA 2084.1v-2v
Bavli MS JTS ENA 20843v 8v	בבלי כתב יד JTS: ENA 2084.3v-8v
Bavli MS Munich BS Cod hebr 153II2	בבלי כתב יד Munich, BS: Cod. hebr. 153.II.2
Bavli MS AIU II B260	בבלי כתב יד AIU: II B.260 +
Bavli MS Munich BS Cod hebr 419XIII	בבלי כתב יד Munich, BS: Cod. hebr. 419.XIII
Bavli MS Darmstadt, UL: W4147	בבלי כתב יד Darmstadt, UL: W4147
Bavli MS Darmstadt UL W4147	בבלי כתב יד Darmstadt, UL: W4147
Bavli MS Munich BS Cod hebr 153II4	בבלי כתב יד Munich, BS: Cod. hebr. 153.II.4
Bavli MS Munich BS Cod hebr 419II1	בבלי כתב יד Munich, BS: Cod. hebr. 419.II.1
Bavli MS AIU III A49	בבלי כתב יד AIU: III A.49
Bavli MS Praha NKCR XIXC49	בבלי כתב יד Praha, NKCR: XIX.C.49
Bavli MS Munich BS Cod hebr 419XII	בבלי כתב יד Munich, BS: Cod. hebr. 419.XII
Bavli MS Roncofreddo: –	בבלי כתב יד Roncofreddo: –
Bavli MS Roncofreddo	בבלי כתב יד Roncofreddo: –
Bavli MS Munich BS Cod hebr 436XI	בבלי כתב יד Munich, BS: Cod. hebr. 436.XI
Bavli MS Bologna BUB AVBBV34	בבלי כתב יד Bologna, BUB: A.V.BB.V.34
Bavli MS Munich BS Cod hebr 436XII	בבלי כתב יד Munich, BS: Cod. hebr. 436.XII
Bavli Printing ואד אלחגארה (ר\"מ בערך)	בבלי דפוס ואד אלחגארה (ר\"מ בערך)
Bavli Printing ואד אלחגארה רמ בערך	בבלי דפוס ואד אלחגארה (ר\"מ בערך)
Bavli Printing טולידו? (ר\"מ - ר\"ן)	בבלי דפוס טולידו? (ר\"מ - ר\"ן)
Bavli Printing טולידו רמ רן	בבלי דפוס טולידו? (ר\"מ - ר\"ן)
Bavli Printing שונצינו (רמ\"ד - רמ\"ט)	בבלי דפוס שונצינו (רמ\"ד - רמ\"ט)
Bavli Printing שונצינו רמד רמט	בבלי דפוס שונצינו (רמ\"ד - רמ\"ט)
Bavli Printing איטליה (רמ\"ט - רנ\"ח)	בבלי דפוס איטליה (רמ\"ט - רנ\"ח)
Bavli Printing איטליה רמט רנח	בבלי דפוס איטליה (רמ\"ט - רנ\"ח)
Bavli Printing פארה? (לפני רנ\"ח)	בבלי דפוס פארה? (לפני רנ\"ח)
Bavli Printing פארה לפני רנח	בבלי דפוס פארה? (לפני רנ\"ח)
Bavli Printing פארה (רנ\"ז בערך)	בבלי דפוס פארה (רנ\"ז בערך)
Bavli Printing פארה רנז בערך	בבלי דפוס פארה (רנ\"ז בערך)
Bavli Printing ברקו (רנ\"ח - רנ\"ט)	בבלי דפוס ברקו (רנ\"ח - רנ\"ט)
Bavli Printing ברקו רנח רנט	בבלי דפוס ברקו (רנ\"ח - רנ\"ט)
Bavli Printing קושטא (רס\"ה - רס\"ט)	בבלי דפוס קושטא (רס\"ה - רס\"ט)
Bavli Printing קושטא רסה רסט	בבלי דפוס קושטא (רס\"ה - רס\"ט)
Bavli Printing פיזרו (רס\"ט - רע\"ו)	בבלי דפוס פיזרו (רס\"ט - רע\"ו)
Bavli Printing פיזרו רסט רעו	בבלי דפוס פיזרו (רס\"ט - רע\"ו)
Bavli Printing פס (רע\"ו - רפ\"ב)	בבלי דפוס פס (רע\"ו - רפ\"ב)
Bavli Printing פס רעו רפב	בבלי דפוס פס (רע\"ו - רפ\"ב)
Bavli Printing ונציה (ר\"פ - רפ\"ג)	בבלי דפוס ונציה (ר\"פ - רפ\"ג)
Bavli Printing ונציה רפ רפג	בבלי דפוס ונציה (ר\"פ - רפ\"ג)
Bavli Printing וילנא	בבלי דפוס וילנא
Bereshit Rabbah	בראשית רבה
Bereshit Rabba	בראשית רבה
B\"R	בראשית רבה
Bereishit Rabbah	בראשית רבה
Genesis Rabbah	בראשית רבה
Vayikra Rabbah	ויקרא רבה
Vayikra Rabba	ויקרא רבה
Leviticus Rabbah	ויקרא רבה
Eikhah Rabbah	איכה רבה
Eikhah Rabba	איכה רבה
Lamentations Rabbah	איכה רבה
Pesikta DeRav Kahana	פסיקתא דרב כהנא
Psikta DeRav Kahana	פסיקתא דרב כהנא
Pesikta DeRab Kahana	פסיקתא דרב כהנא
Shir HaShirim Rabbah	שיר השירים רבה
Shir HaShirim Rabba	שיר השירים רבה
Song of Songs Rabbah	שיר השירים רבה
Canticles Rabbah	שיר השירים רבה
Kohelet Rabbah	קהלת רבה
Kohelet Rabba	קהלת רבה
Ecclesiastes Rabbah	קהלת רבה
Rut Rabbah	רות רבה
Rut Rabba	רות רבה
Ruth Rabba	רות רבה
Ruth Rabbah	רות רבה
Rut Rabbah (Lerner)	רות רבה (לרנר)
Rut Rabba Lerner	רות רבה (לרנר)
Ruth Rabbah Lerner	רות רבה (לרנר)
Esther Rabbah	אסתר רבה
Esther Rabba	אסתר רבה
Devarim Rabbah (Vilna)	דברים רבה (וילנא)
Devarim Rabbah	דברים רבה (וילנא)
Devarim Rabba	דברים רבה (וילנא)
Deuteronomy Rabbah	דברים רבה (וילנא)
Shemot Rabbah	שמות רבה
Shemot Rabba	שמות רבה
Exodus Rabbah	שמות רבה
Bemidbar Rabbah	במדבר רבה
Bemidbar Rabba	במדבר רבה
Numbers Rabbah	במדבר רבה
Devarim Rabbah (Lieberman)	דברים רבה (ליברמן)
Tanchuma	תנחומא
Midrash Tanchuma	תנחומא
Midrash Tanhuma	תנחומא
Tanhuma	תנחומא
Tanchuma (Buber)	תנחומא (בובר)
Tanchuma Buber	תנחומא (בובר)
Tanhuma Buber	תנחומא (בובר)
Appendix	הוספה
Tanchuma (Buber) Appendix	הוספה
Midrash Yelamedeinu	מדרש ילמדנו
Yelamedeinu	מדרש ילמדנו
Midrash Yelamedenu	מדרש ילמדנו
Yelamedenu	מדרש ילמדנו
Midrash Yelamdenu	מדרש ילמדנו
Yelamdenu	מדרש ילמדנו
Midrash Yelamdeinu	מדרש ילמדנו
Yelamdeinu	מדרש ילמדנו
Pesikta Rabbati	פסיקתא רבתי
Pesikta Rabati	פסיקתא רבתי
Pesikta Rabbasi	פסיקתא רבתי
Pesikta Rabasi	פסיקתא רבתי
Midrash Shemuel	מדרש שמואל
Midrash Shmuel	מדרש שמואל
Megillat Antiochus	מגילת אנטיוכס
Megillat Benei Chashmonai	מגילת אנטיוכס
Megilat Benei Chashmonai	מגילת אנטיוכס
Megilat Antiochus	מגילת אנטיוכס
Megillat Chanukkah	מגילת אנטיוכס
Megilat Chanukkah	מגילת אנטיוכס
Megillat Antiochus Yemenite	מגילת אנטיוכס נוסח תימן
Septuagint	תרגום השבעים
LXX	תרגום השבעים
Peshitta	פשיטתא
Peshita	פשיטתא
Targum Yerushalmi (Neofiti)	תרגום ירושלמי (ניאופיטי)
Targum Neofiti	תרגום ירושלמי (ניאופיטי)
Neofiti	תרגום ירושלמי (ניאופיטי)
Targum Onkelos	תרגום אונקלוס
Onkelos	תרגום אונקלוס
Targum Yerushalmi (Yonatan)	תרגום ירושלמי (יונתן)
Targum PsJ	תרגום ירושלמי (יונתן)
Targum Pseudo-Jonathan	תרגום ירושלמי (יונתן)
Targum Pseudo Jonathan	תרגום ירושלמי (יונתן)
Targum Pseudo-Yonatan	תרגום ירושלמי (יונתן)
Targum Pseudo Yonatan	תרגום ירושלמי (יונתן)
Targum Yerushalmi (Fragmentary)	תרגום ירושלמי (קטעים)
Targum Yerushalmi	תרגום ירושלמי (קטעים)
Jerusalem Targum	תרגום ירושלמי (קטעים)
Targum Yerushalmi (Fragmentary) MS Paris	תרגום ירושלמי (קטעים) כ\"י פריס
Targum Yerushalmi MS Paris	תרגום ירושלמי (קטעים) כ\"י פריס
Jerusalem Targum MS Paris	תרגום ירושלמי (קטעים) כ\"י פריס
Targum Yonatan	תרגום יונתן
Targum Jonathan	תרגום יונתן
Targum Ketuvim	תרגום כתובים
First Targum of Megillat Esther	תרגום ראשון למגילת אסתר
First Targum of Megilat Esther	תרגום ראשון למגילת אסתר
First Targum Megillat Esther	תרגום ראשון למגילת אסתר
First Targum Megilat Esther	תרגום ראשון למגילת אסתר
First Targum Esther	תרגום ראשון למגילת אסתר
First Targum	תרגום ראשון למגילת אסתר
Targum Rishon	תרגום ראשון למגילת אסתר
Targum Esther	תרגום ראשון למגילת אסתר
Second Targum of Megillat Esther	תרגום שני למגילת אסתר
Second Targum	תרגום שני למגילת אסתר
Second Targum of Megilat Esther	תרגום שני למגילת אסתר
Second Targum Megillat Esther	תרגום שני למגילת אסתר
Second Targum Megilat Esther	תרגום שני למגילת אסתר
Second Targum Esther	תרגום שני למגילת אסתר
Targum Sheini	תרגום שני למגילת אסתר
Targum Sheni	תרגום שני למגילת אסתר
Toseftot Targum	תוספתות תרגום
Avot DeRabbi Natan	אבות דרבי נתן
Avot DeR. Natan	אבות דרבי נתן
Avos DeR. Nasan	אבות דרבי נתן
Masekhet Avot DeRabbi Natan	אבות דרבי נתן
Avot DeRabbi Natan Ordered by Mishna	אבות דרבי נתן על סדר המשנה
Avot DeRabbi Natan Nusach B	אבות דרבי נתן נוסח ב
Avot DeRabbi Natan Hosafah	אבות דרבי נתן הוספה
Masekhet Soferim	מסכת סופרים
Masekhet Sofrim	מסכת סופרים
Masechet Soferim	מסכת סופרים
Masechet Sofrim	מסכת סופרים
Soferim	מסכת סופרים
Masekhes Soferim	מסכת סופרים
Maseches Soferim	מסכת סופרים
Masekhes Sofrim	מסכת סופרים
Maseches Sofrim	מסכת סופרים
Masekhet Semachot	מסכת שמחות
Aveil Rabbati	מסכת שמחות
Avel Rabbati	מסכת שמחות
Masechet Semachot	מסכת שמחות
Masechet Semakhot	מסכת שמחות
Masekhet Semakhot	מסכת שמחות
Masekhes Semachos	מסכת שמחות
Maseches Semakhos	מסכת שמחות
Masekhet Kallah	מסכת כלה
Masechet Kallah	מסכת כלה
Masekhet Kalah	מסכת כלה
Masechet Kalah	מסכת כלה
Masekhes Kallah	מסכת כלה
Maseches Kallah	מסכת כלה
Masekhes Kalah	מסכת כלה
Maseches Kalah	מסכת כלה
Kallah Rabbati	כלה רבתי
Kallah Rabati	כלה רבתי
Derekh Eretz Rabbah	דרך ארץ רבה
Derekh Erez Rabbah	דרך ארץ רבה
Derech Eretz Rabbah	דרך ארץ רבה
Derech Erez Rabbah	דרך ארץ רבה
Derekh Eretz Zuta	דרך ארץ זוטא
Derekh Erez Zuta	דרך ארץ זוטא
Derech Eretz Zuta	דרך ארץ זוטא
Derech Erez Zuta	דרך ארץ זוטא
Masekhet Geirim	מסכת גרים
Masechet Geirim	מסכת גרים
Masechet Gerim	מסכת גרים
Masekhet Gerim	מסכת גרים
Masekhes Geirim	מסכת גרים
Maseches Geirim	מסכת גרים
Masekhes Gerim	מסכת גרים
Maseches Gerim	מסכת גרים
Masekhet Kutim	מסכת כותים
Masechet Kutim	מסכת כותים
Masekhes Kutim	מסכת כותים
Maseches Kutim	מסכת כותים
Masekhet Avadim	מסכת עבדים
Masechet Avadim	מסכת עבדים
Masekhes Avadim	מסכת עבדים
Maseches Avadim	מסכת עבדים
Masekhet Sefer Torah	מסכת ספר תורה
Masechet Sefer Torah	מסכת ספר תורה
Masekhes Sefer Torah	מסכת ספר תורה
Maseches Sefer Torah	מסכת ספר תורה
Masekhet Tefillin	מסכת תפילין
Masechet Tefillin	מסכת תפילין
Masechet Tefilin	מסכת תפילין
Masekhet Tefilin	מסכת תפילין
Masekhes Tefillin	מסכת תפילין
Maseches Tefillin	מסכת תפילין
Masekhes Tefilin	מסכת תפילין
Maseches Tefilin	מסכת תפילין
Masekhet Tzitzit	מסכת ציצית
Masechet Tzitzit	מסכת ציצית
Masekhes Tzitzis	מסכת ציצית
Maseches Tzitzis	מסכת ציצית
Masekhet Mezuzah	מסכת מזוזה
Masechet Mezuzah	מסכת מזוזה
Masekhes Mezuzah	מסכת מזוזה
Maseches Mezuzah	מסכת מזוזה
Pirkei DeRabbi Eliezer	פרקי דרבי אליעזר
Pirke DeRabbi Eliezer	פרקי דרבי אליעזר
Pirkei DeR. Eliezer	פרקי דרבי אליעזר
Pirke DeR. Eliezer	פרקי דרבי אליעזר
Aggadat Bereshit	אגדת בראשית
Agadat Bereshit	אגדת בראשית
Seder Olam Zuta	סדר עולם זוטא
Seder Eliyahu	סדר אליהו
Tanna Debe Eliyahu	סדר אליהו
Seder Eliyahu Rabbah	סדר אליהו רבה
Seder Eliyahu Rabba	סדר אליהו רבה
Tanna Debe Eliyahu Rabbah	סדר אליהו רבה
Tanna Debe Eliyahu Rabba	סדר אליהו רבה
Eliyahu Rabbah	סדר אליהו רבה
Eliyahu Rabba	סדר אליהו רבה
Seder Eliyahu Zuta	סדר אליהו זוטא
Tanna Debe Eliyahu Zuta	סדר אליהו זוטא
Eliyahu Zuta	סדר אליהו זוטא
Midrash Mishlei	מדרש משלי
Midrash Mishle	מדרש משלי
Midrash Tehillim	מדרש תהלים
Midrash Tehilim	מדרש תהלים
Midrash Abba Gurion	מדרש אבא גוריון
Midrash Panim Acherot	מדרש פנים אחרים נוסח א
Aggadat Esther	אגדת אסתר
Agadat Esther	אגדת אסתר
Midrash Esther	מדרש אסתר
Midrash Zuta	מדרש זוטא
Shir HaShirim Zuta	שיר השירים זוטא
Midrash Zuta Shir HaShirim	שיר השירים זוטא
Rut Zuta	רות זוטא
Midrash Zuta Rut	רות זוטא
Ruth Zuta	רות זוטא
Midrash Zuta Ruth	רות זוטא
Eikhah Zuta	איכה זוטא
Midrash Zuta Eikhah	איכה זוטא
Kohelet Zuta	קהלת זוטא
Midrash Zuta Kohelet	קהלת זוטא
Mishnat R. Eliezer	משנת רבי אליעזר
Mishnat Rabbi Eliezer	משנת רבי אליעזר
Bereshit Rabbati	בראשית רבתי
Bereshit Rabati	בראשית רבתי
Midrash Petirat Moshe	מדרש פטירת משה
Midrash Petirat Mosheh	מדרש פטירת משה
Midrash Aggadah (Buber)	מדרש אגדה (בובר)
Midrash Aggadah	מדרש אגדה (בובר)
Midrash Agadah	מדרש אגדה (בובר)
Otzar HaMidrashim	אוצר המדרשים
Ozar HaMidrashim	אוצר המדרשים
Sefer HaYashar	ספר הישר
Midrash MS	מדרש כ\"י
Aggadat Karnei Reemim	אגדת קרני ראמים
Aggadat Mashiach	אגדת משיח
Aggadat R. Yishmael	אגדת רבי ישמעאל
Aggadat Tefilat Shemoneh Esrei	אגדת תפלת שמונה עשרה
Baraita al HaSeder	אגדת תפלת שמונה עשרה
Aggadat Yemot HaMashiach	אגדת ימות המשיח
Amirot LeAtid	אמירות לעתיד
Asarah Mili DeChasiduta	עשרה מילי דחסידותא
Atidot Rashbi	עתידות רבי שמעון בן יוחאי
Baraita Beriyato Shel Olam	ברייתא ברייתו של עולם
Baraita DeMasekhet Niddah Nusach A	ברייתא דמסכת נדה נוסח א
Baraita DeRabbi Pinechas ben Yair	ברייתא דרבי פינחס בן יאיר
Baraita DeRabbi Yishmael	ברייתא דרבי ישמעאל
Baraita Dishuah	ברייתא דישועה
Baraita Middat Orekh HaOlam	ברייתא מידת אורך העולם
Baraita of Thirty Two Middot	ברייתא של שלושים ושנים מדות
Baraita Shel Esrim VeArbaah Devarim	ברייתא של עשרים וארבעה דברים
Baraita Shel Mishmarot Kohanim	ברייתא של משמרות כהנים
Bereshit Rabbah Shittah Chadashah	בראשית רבה שיטה חדשה
Chamesh Esreh Nekudot SheBaMikra	חמש עשרה נקודות שבמקרא
Chazon Daniel	חזון דניאל
Chuppat Eliyahu	חופת אליהו
Chushbena DeKitza DeRashbi	חושבנה דקיצא דרבי שמעון בן יוחאי
Demut Kise Shelomo	דמות כסא שלמה
Derash LeYom HaKippurim	דרש ליום הכיפורים
Derashah BeSevach HaTorah	דרשה בשבח התורה
Derashah LeEser Makkot	דרשה לעשר מכות
Derashat R. Benaah	דרשת רבי בנאה
Divrei HaYamim Shel Moshe	דברי הימים של משה
Divrei HaYamim LeMoshe Rabbeinu	דברי הימים של משה
Divrei HaYamim LeMoshe Rabbenu	דברי הימים של משה
Divrei HaYamim LeMosheh Rabbeinu	דברי הימים של משה
Divrei HaYamim LeMosheh Rabbenu	דברי הימים של משה
Inyan Chiram Melekh Tzor	ענין חירם מלך צור
Inyan Gog UMagog	ענין גוג ומגוג
Inyan Kise Shelomo	ענין כסא שלמה
Keta Genizah LeParashat Acharei Mot	קטע גניזה לפרשת אחרי מות
Keta Genizah LeParashat Vayigash	קטע גניזה לפרשת ויגש
Keta Midrash LeParashat Shemini - Chukkat	קטע מדרש לפרשת שמיני חוקת
Kuntres Acharon MiMidrash Yelamdeinu	קונטרס אחרון ממדרש ילמדנו
Likkutei Maasiyot UMidrashim	לקוטי מעשיות ומדרשים
Likkutei Midrashim Min HaGenizah Bereshit	לקוטי מדרשים מן הגניזה בראשית
Likkutim MiBaraita of Forty Nine Middot	לקוטים מברייתא דארבעים ותשע מדות
Baraita of Forty Nine Middot	לקוטים מברייתא דארבעים ותשע מדות
Likkutim MiMidrash Mei HaShiloach	ליקוטים ממדרש מי השילוח
Likkutim MiMidrash Vayekhulu	ליקוטים ממדרש ויכולו
Likkutim MiSefer Adam HaRishon	ליקוטים מספר אדם הראשון
Likut MiMidrash Alpha Beitot	ליקוט ממדרש אלפא ביתות
Likut MiSefer HaZikhronot LeYerachmiel	ליקוט מספר הזכרונות לירחמאל
Maamar Arbaah Melakhim	מאמר ארבעה מלכים
Maaseh Avraham Avinu	מעשה אברהם אבינו
Maaseh DeR. Yehoshua b. Levi	מעשה דר' יהושע בן לוי
Maaseh MiShelomo HaMelekh	מעשה משלמה המלך
Maaseh Rav Kahana VeSalik Beno	מעשה רב כהנא וסליק בנו
Maaseh Yoav	מעשה יואב
Maasim al Aseret HaDibberot	מעשים על עשרת הדברות
Maasim UMeshalim Shel Shelomo HaMelekh	מעשים ומשלים של שלמה המלך
Margenita DeR. Meir	מרגניתא דרבי מאיר
Masekhet Atzilut	מסכת אצילות
Masekhet Gan Eden	מסכת גן עדן
Masekhet Gehinom	מסכת גיהנם
Masekhet Keilim Shel Kelei Beit HaMikdash	מסכת כלים של כלי בית המקדש
Masekhet Semakhot Zutrati DeR. Chiyya	מסכת שמחות זוטרתי דרבי חייא
Menazpakh Tzofim Amarum	מנצפך צופים אמרום
Midrash Akeidat Yitzchak	מדרש עקדת יצחק
Midrash Al Yithalel	מדרש אל יתהלל
Midrash Aseret HaDibberot	מדרש עשרת הדברות
Midrash Aseret HaMelakhim	מדרש עשרת מלכים
Midrash Gadol UGedulah	מדרש גדול וגדולה
Midrash Gedulat Moshe	מדרש גדולת משה - כתפוח בעצי היער
Midrash Golyat HaPelishti	מדרש גלית הפלשתי
Midrash Hallel	מדרש הלל
Midrash HaNesiah	מדרש הנסיעה
Midrash HaOtiyot HaTagin Ketanot UGedolot	מדרש האותיות התגין קטנות וגדולות
Midrash Hashem BeChokhmah Yasad Aretz	מדרש י\"י בחכמה יסד ארץ
Midrash Hashem BeChokhmah Yasad Eretz	מדרש י\"י בחכמה יסד ארץ
Midrash Hashkem	מדרש השכם
Midrash Keri VeLo Ketiv	מדרש קרי ולא כתיב
Midrash Konen	מדרש כונן
Midrash LeAtid Lavo	מדרש לעתיד לבא
Midrash LeOlam	מדרש לעולם
Midrash Mashiach	מדרש משיח
Midrash Minayin	מדרש מנין
Midrash Otiyot DeR. Akiva Nusach B	מדרש אותיות דרבי עקיבה נוסח ב
Midrash Petirat Aharon	מדרש פטירת אהרן
Midrash Petirat Moshe Nusach A	מדרש פטירת משה נוסח א
Midrash Petirat Moshe Nusach B	מדרש פטירת משה נוסח ב
Midrash Shenei Ketuvim	מדרש שני כתובים
Midrash Tadshe	מדרש תדשא
Midrash Temurah	מדרש תמורה
Midrash Vayissau	מדרש ויסעו
Milchamot Benei Yaakov	מדרש ויסעו
Midrash Vayosha	מדרש ויושע
Midrash Zo Hi Sheneemrah BeRuach HaKodesh	מדרש זו היא שנאמרה ברוח הקודש
Nevuat HaYeled	נבואת הילד
Nistarot Rashbi	נסתרות רשב\"י
Otot HaMashiach	אותות המשיח
Peirush Kadish	פירוש קדיש
Pirkei Chibbut HaKever	פרקי חיבוט הקבר
Pirkei R. Yosi	פרקי רבי יוסי
Pittum HaKetoret	פטום הקטורת
Seder Arakim	סדר ארקים
Seder Gan Eden	סדר גן עדן
Seder Rabbah DiBreshit DeMerkavah	סדר רבה דבראשית דמרכבה דרבי ישמעאל כהן גדול
Seder Rechitzah LeHillel HaZaken	סדר רחיצה להלל הזקן
Seder Techiyat HaMeitim	סדר תחיית המתים
Seder Yetzirat HaVelad	סדר יצירת הולד
Sefer Eliyahu	ספר אליהו
Sefer HaMaasim MS Oxford	ספר המעשים כתב יד אוקספורד
Sefer Noach	ספר נח
Sefer Zerubavel	ספר זרובבל
Seudat Gan Eden	סעודת גן עדן
Seudat Livyatan	סעודת לויתן
Sheelot R. Eliezer MeInyan Techiyat HaMeitim	שאלות רבי אליעזר מענין תחיית המתים
Taam Arba Tekufot	טעם ארבע תקופות
Taam Sheva Nekudot Shel Shivah Melakhim	טעם שבע נקודות של שבעה מלכים
Taam UPeirush LeAvnei HaChoshen	טעם ופירוש לאבני החשן
Tefilat Eliyahu HaNavi	תפילת אליהו הנביא
Tefilat Rashbi	תפלת רשב\"י
Teshuvat R. Hayyei Gaon MeInyan HaYeshuah	תשובה מרב האיי גאון מענין הישועה
Tzavaat Naftali	צוואת נפתלי
Tzavaat R. Eliezer HaGadol	צוואת רבי אליעזר הגדול
Yesod Aleph Bet	יסוד אלף בית
Siddur	סידור
Haggadah	הגדה
R. Yehudai Gaon	ר' יהודאי גאון
Halakhot Pesukot	הלכות פסוקות
Halachot Pesukot	הלכות פסוקות
Sheiltot	שאילתות
Shiltot	שאילתות
Pirkoi b. Bavoi	פרקוי בן באבוי
Iggeret Pirkoi b. Bavoi	פרקוי בן באבוי
Pirkoi b. Baboi	פרקוי בן באבוי
Iggeret Pirkoi b. Baboi	פרקוי בן באבוי
R. Shimon Kayyara	ר' שמעון קיירא
R. Simeon Kiara	ר' שמעון קיירא
Halakhot Gedolot	הלכות גדולות
Halachot Gedolot	הלכות גדולות
Bahag Minyan HaMitzvot	בה\"ג מניין המצוות
Halakhot Gedolot Minyan HaMitzvot	בה\"ג מניין המצוות
Punishments	עונשים
Halakhot Gedolot Minyan HaMitzvot Punishments	עונשים
Halakhot Gedolot Minyan HaMitzvot Negative Commandments	מצוות לא תעשה
Halakhot Gedolot Minyan HaMitzvot Positive Commandments	מצוות עשה
Parshiyot	פרשיות
Halakhot Gedolot Minyan HaMitzvot Parshiyot	פרשיות
R. Sar Shalom Gaon	ר' שר שלום גאון
R. Natronai Gaon	ר' נטרונאי גאון
R. Natronai b. Hilai Gaon	ר' נטרונאי גאון
Teshuvot R. Natronai Gaon	תשובות ר' נטרונאי גאון
R. Amram Gaon	ר' עמרם גאון
Rav Amram Gaon	ר' עמרם גאון
Seder R. Amram Gaon	סדר רב עמרם גאון
R. Nachshon Gaon	ר' נחשון גאון
R. Nahshon Gaon	ר' נחשון גאון
Daniel AlKumisi the Karaite	דניאל אלקומיסי הקראי
Daniel AlKumsi the Karaite	דניאל אלקומיסי הקראי
Daniel AlKumisi	דניאל אלקומיסי הקראי
Daniel AlKumsi	דניאל אלקומיסי הקראי
R. Saadia Gaon	ר' סעדיה גאון
Rasag	ר' סעדיה גאון
R. Saadia	ר' סעדיה גאון
R. Saadya	ר' סעדיה גאון
R. Saadya Gaon	ר' סעדיה גאון
Tafsir	תפסיר
R. Saadia Gaon Tafsir	תפסיר
Tafsir Yemenite	תפסיר נוסח תימן
R. Saadia Gaon Tafsir Yemenite	תפסיר נוסח תימן
Tafsir Menukad	תפסיר מנוקד
R. Saadia Gaon Tafsir Menukad	תפסיר מנוקד
Commentary	פירוש
R. Saadia Gaon Commentary	פירוש
Commentary R. Saadia Gaon	פירוש
HaEmunot VeHaDeiot	האמונות והדעות
R. Saadia Gaon HaEmunot VeHaDeiot	האמונות והדעות
HaEmunot VeHaDeot	האמונות והדעות
Emunot VeDeiot	האמונות והדעות
Emunot VeDeot	האמונות והדעות
Azharot Taryag Mitzvot	אזהרות תרי\"ג מצוות
R. Saadia Gaon Azharot Taryag Mitzvot	אזהרות תרי\"ג מצוות
Full Piyyut	הפיוט המלא
R. Saadia Gaon Azharot Taryag Mitzvot Full Piyyut	הפיוט המלא
R. Saadia Gaon Azharot Taryag Mitzvot Positive Commandments	מצוות עשה
R. Saadia Gaon Azharot Taryag Mitzvot Negative Commandments	מצוות לא תעשה
R. Saadia Gaon Azharot Taryag Mitzvot Punishments	עונשים
R. Saadia Gaon Azharot Taryag Mitzvot Parshiyot	פרשיות
Sefer HaMitzvot of R. Saadia Gaon	ספר המצוות לרב סעדיה גאון
R. Saadia Gaon Sefer HaMitzvot	ספר המצוות לרב סעדיה גאון
Sefer Korot HaZeman of R. Saadia Gaon	ספר קורות הזמן לרב סעדיה גאון
R. Saadia Gaon Sefer Korot HaZeman	ספר קורות הזמן לרב סעדיה גאון
Beit Midrash of R. Saadia Gaon	מבית מדרשו של ר' סעדיה גאון
R. Mubashir HaLevi	ר' מבשר הלוי
R. Mevasser HaLevi	ר' מבשר הלוי
Critique of the Writings of R. Saadia Gaon	ר' מבשר הלוי
Attributed to Student of R. Saadia Gaon	מיוחס לתלמיד ר' סעדיה גאון
R. Chefetz b. Yatzliach	ר' חפץ בן יצליח
R. Hefez b. Yazliah	ר' חפץ בן יצליח
Sefer HaMitzvot of R. Chefetz b. Yatzliach	ספר המצוות לר' חפץ בן יצליח
R. Sherira Gaon	רב שרירא גאון
R. Sherira Gaon Nusach	רב שרירא גאון נוסח
Peirush Milim of R. Sherira Gaon	פירוש מלים לרב שרירא גאון
R. Sherira Gaon Peirush Milim	פירוש מלים לרב שרירא גאון
Machberet Menachem	מחברת מנחם
Machberes Menachem	מחברת מנחם
Menachem b. Saruq	מחברת מנחם
Dunash b. Labrat	דונש בן לברט
Teshuvot Dunash	תשובות דונש
Teshuvot Dunash al Rasag	תשובות דונש על רס\"ג
Teshuvot Talmidei Menachem	תשובות תלמידי מנחם
Teshuvos Talmidei Menachem	תשובות תלמידי מנחם
Teshuvot Yehudi b. Sheshet	תשובות יהודי בן ששת
Teshuvos Yehudi b. Sheshet	תשובות יהודי בן ששת
Yefet b. Eli the Karaite	יפת בן עלי הקראי
Yefet b. Ali the Karaite	יפת בן עלי הקראי
Yefet b. Eli	יפת בן עלי הקראי
Yefet b. Ali	יפת בן עלי הקראי
Yefet	יפת בן עלי הקראי
Japhet b. Eli the Karaite	יפת בן עלי הקראי
Japhet b. Ali the Karaite	יפת בן עלי הקראי
Japhet b. Eli	יפת בן עלי הקראי
Japhet b. Ali	יפת בן עלי הקראי
Japhet	יפת בן עלי הקראי
Salmon b. Yerucham the Karaite	סלמון בן ירוחם הקראי
Salmon b. Yeruham the Karaite	סלמון בן ירוחם הקראי
Salmon b. Yerocham the Karaite	סלמון בן ירוחם הקראי
Salmon b. Yeroham the Karaite	סלמון בן ירוחם הקראי
Salmon b. Jeroham the Karaite	סלמון בן ירוחם הקראי
Salmon b. Yerucham	סלמון בן ירוחם הקראי
Salmon b. Yeruham	סלמון בן ירוחם הקראי
Salmon b. Yerocham	סלמון בן ירוחם הקראי
Salmon b. Yeroham	סלמון בן ירוחם הקראי
Salmon b. Jeroham	סלמון בן ירוחם הקראי
Solomon b. Yerucham	סלמון בן ירוחם הקראי
Solomon b. Yeruham	סלמון בן ירוחם הקראי
Solomon b. Yerocham	סלמון בן ירוחם הקראי
Solomon b. Yeroham	סלמון בן ירוחם הקראי
Solomon b. Jeroham	סלמון בן ירוחם הקראי
R. Shemuel b. Chofni Gaon	ר' שמואל בן חפני גאון
R. Shemuel b. Chofni	ר' שמואל בן חפני גאון
R. Shmuel b. Chofni	ר' שמואל בן חפני גאון
R. Shmuel b. Chofni Gaon	ר' שמואל בן חפני גאון
R. Shemuel b. Hofni Gaon	ר' שמואל בן חפני גאון
R. Shemuel b. Hofni	ר' שמואל בן חפני גאון
R. Samuel b. Hofni	ר' שמואל בן חפני גאון
R. Samuel b. Chofni	ר' שמואל בן חפני גאון
Sefer HaMitzvot of R. Shemuel b. Chofni Gaon	ספר המצוות לרב שמואל בן חפני גאון
R. Shemuel b. Chofni Gaon Sefer HaMitzvot	ספר המצוות לרב שמואל בן חפני גאון
Sefer HaShemot VeHaToarim of R. Shemuel b. Chofni Gaon	ספר השמות והתארים לרב שמואל בן חפני גאון
R. Shemuel b. Chofni Gaon Sefer HaShemot VeHaToarim	ספר השמות והתארים לרב שמואל בן חפני גאון
Sefer Dinei Mitzvat Tzitzit of R. Shemuel b. Chofni Gaon	ספר דיני מצות ציצית לרב שמואל בן חפני גאון
R. Shemuel b. Chofni Gaon Sefer Dinei Mitzvat Tzitzit	ספר דיני מצות ציצית לרב שמואל בן חפני גאון
Sefer HaBagrut of R. Shemuel b. Chofni Gaon	ספר הבגרות לרב שמואל בן חפני גאון
R. Shemuel b. Chofni Gaon Sefer HaBagrut	ספר הבגרות לרב שמואל בן חפני גאון
R. Hayyei Gaon	רב האיי גאון
R. Hai Gaon	רב האיי גאון
Mishpetei Shevuot	משפטי שבועות
Teshuvot HaGeonim (Coronel)	תשובות הגאונים (קורונל)
Teshuvot HaGeonim Coronel	תשובות הגאונים (קורונל)
Teshuvot HaGeonim (Harkavy)	תשובות הגאונים (הרכבי)
Teshuvot HaGeonim Harkavy	תשובות הגאונים (הרכבי)
Teshuvot HaGeonim (Mussafia)	תשובות הגאונים (מוסאפיה)
Teshuvot HaGeonim Mussafia	תשובות הגאונים (מוסאפיה)
Teshuvot HaGeonim (Shaarei Teshuvah)	תשובות הגאונים (שערי תשובה)
Teshuvot HaGeonim Shaarei Teshuvah	תשובות הגאונים (שערי תשובה)
Otzar HaGeonim	אוצר הגאונים
Ozar HaGeonim	אוצר הגאונים
Torat HaGeonim	תורת הגאונים
R. Yehuda ibn Chayyuj	ר' יהודה אבן חיוג'
Ibn Chayyuj	ר' יהודה אבן חיוג'
Ibn Chayyug	ר' יהודה אבן חיוג'
R. Yehuda ibn Chayyug	ר' יהודה אבן חיוג'
R. Yehuda ibn Hayyuj	ר' יהודה אבן חיוג'
Ibn Hayyuj	ר' יהודה אבן חיוג'
Ibn Hayyug	ר' יהודה אבן חיוג'
R. Yehuda ibn Hayyug	ר' יהודה אבן חיוג'
R. Gershom	ר' גרשום
R. Gershom Meor HaGolah	ר' גרשום
R. Gershom b. Yehuda	ר' גרשום
Attributed to R. Gershom	מיוחס לר' גרשום
R. Chananel	ר' חננאל
Rabbenu Chananel	ר' חננאל
Rabbenu Hananel	ר' חננאל
R. Hananel	ר' חננאל
R. Hananel b. Hushiel	ר' חננאל
R. Nissim Gaon	ר' נסים גאון
Peirush HaGeonim LeSeder Taharot	פירוש הגאונים לסדר טהרות
R. Yonah ibn Janach	ר' יונה אבן ג'נאח
Ibn Janach	ר' יונה אבן ג'נאח
R. Yonah ibn Janah	ר' יונה אבן ג'נאח
Ibn Janah	ר' יונה אבן ג'נאח
R. Yonah ibn Janakh	ר' יונה אבן ג'נאח
Ibn Janakh	ר' יונה אבן ג'נאח
R. Jonah ibn Janach	ר' יונה אבן ג'נאח
R. Jonah ibn Janah	ר' יונה אבן ג'נאח
R. Jonah ibn Janakh	ר' יונה אבן ג'נאח
Sefer HaShorashim LeR. Yonah	ספר השרשים לר' יונה
SHS LeR. Yonah	ספר השרשים לר' יונה
Collected from R. Yonah ibn Janach	ליקוט מר' יונה אבן ג'נאח
R. Shemuel HaNagid	ר' שמואל הנגיד
R. Samuel ibn Naghrillah	ר' שמואל הנגיד
Levi b. Yefet the Karaite	לוי בן יפת הקראי
Levi b. Yefet	לוי בן יפת הקראי
Levi b. Japhet the Karaite	לוי בן יפת הקראי
Levi b. Japhet	לוי בן יפת הקראי
R. Natan Av HaYeshivah	ר' נתן אב הישיבה
HaMeasef MiPeirush R. Natan Av HaYeshivah	המאסף מפירוש ר' נתן אב הישיבה
Rif	רי\"ף
R. Yitzchak Alfasi	רי\"ף
Alfasi	רי\"ף
Alfas	רי\"ף
Rif by Bavli	רי\"ף לפי סדר תלמוד בבלי
R. Shelomo ibn Gabirol	ר' שלמה אבן גבירול
R. Shlomo Ibn Gabirol	ר' שלמה אבן גבירול
Azharot R. Shelomo ibn Gabirol	אזהרות ר' שלמה אבן גבירול
Azharot ibn Gabirol	אזהרות ר' שלמה אבן גבירול
Tikkun Middot HaNefesh	תיקון מידות הנפש
Tikun Midot HaNefesh	תיקון מידות הנפש
R. Yitzchak ibn Giat	ר' יצחק אבן גיאת
R. Yitzhak ibn Giat	ר' יצחק אבן גיאת
Shaarei Simchah	שערי שמחה
Meah Shearim	מאה שערים
R. Elyakim	ר' אליקים
R. Moshe ibn Chiquitilla	ר' משה אבן ג'יקטילה
Ibn Chiquitilla	ר' משה אבן ג'יקטילה
R. Moshe ibn Giquitilla	ר' משה אבן ג'יקטילה
Ibn Giquitilla	ר' משה אבן ג'יקטילה
R. Moses ibn Chiquitilla	ר' משה אבן ג'יקטילה
R. Yehuda ibn Balaam	ר' יהודה אבן בלעם
Ibn Balaam	ר' יהודה אבן בלעם
R. Judah ibn Balaam	ר' יהודה אבן בלעם
R. Menachem b. Chelbo	ר' מנחם בר חלבו
R. Menahem b. Helbo	ר' מנחם בר חלבו
Sefer HeArukh	ספר הערוך
Sefer HaArukh	ספר הערוך
HaArukh	ספר הערוך
Arukh	ספר הערוך
Collected from HeArukh	הערוך על סדר הש\"ס
Rashi	רש\"י
R. Shlomo Yitzchaki	רש\"י
R. Shelomo Yitzhaki	רש\"י
R. Shlomo Yitzhaki	רש\"י
R. Shelomo b. Yitzchak	רש\"י
R. Shlomo b. Yitzchak	רש\"י
R. Shelomo b. Yitzhak	רש\"י
R. Shlomo b. Yitzhak	רש\"י
R. Solomon b. Isaac	רש\"י
Leipzig	כ\"י לייפציג 1
Rome Printing	דפוס רומא
Rashi Rome Printing	דפוס רומא
Teshuvot Rashi	תשובות רש\"י
Issur VeHeter LeRashi	איסור והיתר לרש\"י
Siddur Rashi	סידור רש\"י
Sefer HaOreh	ספר האורה
Sefer HaPardes LeRashi	ספר הפרדס לרש\"י
Likkutei HaPardes	לקוטי הפרדס
Attributed to Rashi	מיוחס לרש\"י
Meyuchas LeRashi	מיוחס לרש\"י
From Rashi's Beit Midrash	מבית מדרשו של רש\"י
Lekach Tov	לקח טוב
Lekah Tov	לקח טוב
Chovot HaLevavot	חובות הלבבות
R. Yosef Kara	ר' יוסף קרא
R. Yosef Qara	ר' יוסף קרא
R\"Y Kara	ר' יוסף קרא
R\"Y Qara	ר' יוסף קרא
R. Joseph Kara	ר' יוסף קרא
R. Joseph Qara	ר' יוסף קרא
First Commentary	פירוש א
R. Yosef Kara First Commentary	פירוש א
Second Commentary	פירוש ב
R. Yosef Kara Second Commentary	פירוש ב
Third Commentary	פירוש ג
R. Yosef Kara Third Commentary	פירוש ג
Glosses on Rashi	הגהות על פירוש רש\"י
R. Yosef Kara Glosses on Rashi	הגהות על פירוש רש\"י
Glosses	הגהות על פירוש רש\"י
Attributed to R. Yosef Kara	מיוחס לר\"י קרא
R. Yitzchak b. Asher	ר' יצחק בן אשר
R. Shemayah	ר' שמעיה
R. Shemaiah	ר' שמעיה
R. Yaakov b. Shimshon	ר' יעקב בר שמשון
R. Simchah of Vitry	ר' שמחה מויטרי
Machzor Vitry	מחזור ויטרי
Kuzari	כוזרי
R. Judah HaLevi	כוזרי
Rivan	ריב\"ן
R. Shelomo b. Natan	ר' שלמה בר נתן
Ri MiGash	ר\"י מיגש
R. Yosef MiGash	ר\"י מיגש
Teshuvot Ri MiGash	תשובות ר\"י מיגש
R. Yehuda b. Barzilai	ר' יהודה אלברצלוני
Sefer HaIttim	ספר העתים
HaIttim	ספר העתים
R. Avraham Av Beit Din	ר' אברהם אב בית דין
Raavad II	ר' אברהם אב בית דין
Abraham ben Isaac of Narbonne	ר' אברהם אב בית דין
Sefer HaEshkol	ספר האשכול
Rashbam	רשב\"ם
R. Shmuel b. Meir	רשב\"ם
R. Samuel b. Meir	רשב\"ם
Reconstructed	המשוחזר
Rashbam Reconstructed	המשוחזר
Reconstructed Rashbam	המשוחזר
Dayyakot LeRashbam	דייקות לרשב\"ם
Sefer HaDayyakot	דייקות לרשב\"ם
Sefer HaDayakot	דייקות לרשב\"ם
Attributed to Rashbam	מיוחס לרשב\"ם
Ibn Ezra	אבן עזרא
R. Abraham ibn Ezra	אבן עזרא
Avraham ibn Ezra	אבן עזרא
Abraham ibn Ezra	אבן עזרא
Lexical Commentary	דקדוק המלים
Ibn Ezra Lexical Commentary	דקדוק המלים
Explanation of the Meaning	פירוש הטעמים
Ibn Ezra Explanation of the Meaning	פירוש הטעמים
Ibn Ezra First Commentary	פירוש ראשון
Short Commentary	פירוש ראשון
First Commentary Lexical	פירוש ראשון מלים
Ibn Ezra First Commentary Lexical	פירוש ראשון מלים
First Commentary Peshat	פירוש ראשון פשט
Ibn Ezra First Commentary Peshat	פירוש ראשון פשט
First Commentary Midrash	פירוש ראשון מדרש
Ibn Ezra First Commentary Midrash	פירוש ראשון מדרש
Ibn Ezra Second Commentary	פירוש שני
Additional Commentary	פירוש שני
Long Commentary	פירוש שני
Second Commentary Lexical	פירוש שני מלים
Ibn Ezra Second Commentary Lexical	פירוש שני מלים
Second Commentary Peshat	פירוש שני פשט
Ibn Ezra Second Commentary Peshat	פירוש שני פשט
Second Commentary Midrash	פירוש שני מדרש
Ibn Ezra Second Commentary Midrash	פירוש שני מדרש
Ibn Ezra Third Commentary	פירוש שלישי
Yesod Mora	יסוד מורא
R. Shemuel b. Ali	שמואל בר עלי
Raavan	ראב\"ן
Teshuvot Raavan	תשובות ראב\"ן
Siddur Chasidei Ashkenaz	סידור חסידי אשכנז
R. Tam	ר' תם
R. Tam Sefer HaYashar	ספר הישר
Hakhraot R. Tam	הכרעות ר' תם
R. Shelomo Parchon	ר' שלמה פרחון
Machberet HeArukh LeR. Shelomo Parchon	מחברת הערוך לר' שלמה פרחון
Machberet HeArukh	מחברת הערוך לר' שלמה פרחון
R. Yosef Kimchi	ר' יוסף קמחי
R. Yosef Kimhi	ר' יוסף קמחי
R\"Y Kimchi	ר' יוסף קמחי
R\"Y Kimhi	ר' יוסף קמחי
R. Joseph Kimchi	ר' יוסף קמחי
R. Joseph Kimhi	ר' יוסף קמחי
R. Yosef Kimchi Long Commentary	הפירוש הארוך
Peirush HaArokh	הפירוש הארוך
HaArokh	הפירוש הארוך
Perush HaArokh	הפירוש הארוך
R. Yosef Kimchi Short Commentary	הפירוש הקצר
Peirush HaKatzar	הפירוש הקצר
HaKatzar	הפירוש הקצר
Perush HaKatzar	הפירוש הקצר
Sefer HaGalui LeR. Yosef Kimchi	ספר הגלוי לר' יוסף קמחי
Sefer HaGaluy	ספר הגלוי לר' יוסף קמחי
Seikhel Tov	שכל טוב
Sekhel Tov	שכל טוב
Seichel Tov	שכל טוב
R. Menachem b. Shlomo	שכל טוב
R. Yitzchak b. Malki Tzedek	ר' יצחק בן מלכי צדק
R. Ephraim of Regensburg	ר' אפרים מרגנשבורג
R. Avraham ibn Daud	ר' אברהם אבן דאוד
Ibn Daud	ר' אברהם אבן דאוד
R. Abraham ibn Daud	ר' אברהם אבן דאוד
Sefer HaEmunah HaRamah	ספר האמונה הרמה
R. Avraham ibn Daud Sefer HaEmunah HaRamah	ספר האמונה הרמה
R. Eliezer of Beaugency	ר' אליעזר מבלגנצי
R. Yosef Bekhor Shor	ר' יוסף בכור שור
R\"Y Bekhor Shor	ר' יוסף בכור שור
R. Joseph Bekhor Shor	ר' יוסף בכור שור
Baal HaMaor	בעל המאור
R. Zerachya HaLevi	בעל המאור
Sefer HaMaor	בעל המאור
Baal HaMaor Rif	בעל המאור
Sela HaMachlekot	סלע המחלקות
Sela HaMachlakot	סלע המחלקות
Raavad	ראב\"ד
R. Abraham b. David	ראב\"ד
Katuv Sham	כתוב שם
Raavad Katuv Sham	כתוב שם
Kasuv Sham	כתוב שם
Katuv Sham Rif	כתוב שם
Raavad Katuv Sham Rif	כתוב שם
Kasuv Sham Rif	כתוב שם
Hasagot Raavad on Rif	השגות ראב\"ד על רי\"ף
Hasagot HaRaavad al HaRif	השגות ראב\"ד על רי\"ף
Baalei HaNefesh	בעלי הנפש
Ri HaZaken	ר\"י הזקן
R. Baruch b. Shemuel HaSefaradi	ר' ברוך בר שמואל הספרדי
R. Zekharyah Agmati	ר' זכריה אגמתי
Sefer HaNer	ספר הנר
Yereim	יראים
Sefer Yereim	יראים
R. Yitzchak ben Abba Mari	ר' יצחק בר אבא מרי
Sefer HaIttur	ספר העיטור
R. Moshe Kimchi	ר' משה קמחי
R. Moshe Kimhi	ר' משה קמחי
R\"M Kimchi	ר' משה קמחי
R\"M Kimhi	ר' משה קמחי
R. Moses Kimchi	ר' משה קמחי
R. Moses Kimhi	ר' משה קמחי
R. Moshe Kimchi Lexical Commentary	דקדוק מלות המענה
R. Yehuda b. Kelonimus	ר' יהודה בן קלונימוס
R. Yehudah b. Kelonimus	ר' יהודה בן קלונימוס
Yichusei Tanaaim VaAmoraim	יחוסי תנאים ואמוראים
R. Shelomo b. HaYatom	ר' שלמה בן היתום
Ri MiLunel	ר\"י מלוניל
Ri MiLunel on Rif	ר\"י מלוניל על רי\"ף
Rambam	רמב\"ם
R. Moses b. Maimon	רמב\"ם
Maimonides	רמב\"ם
Moses Maimonides	רמב\"ם
Iggeret HaShemad	איגרת השמד
Igeret HaShemad	איגרת השמד
Iggeres HaShemad	איגרת השמד
Igeres HaShemad	איגרת השמד
Iggeret HaShmad	איגרת השמד
Igeret HaShmad	איגרת השמד
Iggeres HaShmad	איגרת השמד
Igeres HaShmad	איגרת השמד
Rambam Commentary on the Mishna	פירוש המשנה לרמב\"ם
Rambam Commentary on the Mishnah	פירוש המשנה לרמב\"ם
Mishnah Commentary	פירוש המשנה לרמב\"ם
Rambam Mishna	פירוש המשנה לרמב\"ם
Rambam Mishnah	פירוש המשנה לרמב\"ם
Rambam Commentary on the Mishna Printed Editions	פירוש המשנה לרמב\"ם דפוסים
Rambam Commentary on the Mishna Draft	פירוש המשנה לרמב\"ם טיוטה
Introduction to Zeraim	הקדמה לזרעים
Rambam Commentary on the Mishna Introduction to Zeraim	הקדמה לזרעים
Introduction	הקדמה לזרעים
Zeraim Introduction	הקדמה לזרעים
Introduction to Seder Zeraim	הקדמה לזרעים
Introduction to Taharot	הקדמה לטהרות
Rambam Commentary on the Mishna Introduction to Taharot	הקדמה לטהרות
Introduction to Seder Taharot	הקדמה לטהרות
Taharot Introduction	הקדמה לטהרות
Shemonah Perakim	שמונה פרקים
Rambam Shemonah Perakim	שמונה פרקים
Introduction to Pirkei Avot	שמונה פרקים
Shemonah Prakim	שמונה פרקים
Shemoneh Perakim	שמונה פרקים
Shemoneh Prakim	שמונה פרקים
Shemona Perakim	שמונה פרקים
Shemona Prakim	שמונה פרקים
Shmona Prokim	שמונה פרקים
Hilkhot HaYerushalmi LaRambam	הלכות הירושלמי לרמב\"ם
Rambam Commentary on the Yerushalmi	הלכות הירושלמי לרמב\"ם
Rambam Commentary on Bavli	פירוש רמב\"ם
Iggeret Teiman	איגרת תימן
Igeret Teiman	איגרת תימן
Iggeres Teiman	איגרת תימן
Igeres Teiman	איגרת תימן
Iggeres Teimon	איגרת תימן
Igeres Teimon	איגרת תימן
Sefer HaMitzvot	ספר המצוות
Rambam Sefer HaMitzvot	ספר המצוות
Book of Precepts	ספר המצוות
Book of Commandments	ספר המצוות
Rambam Sefer HaMitzvot Introduction	הקדמה
Principles	שרשים
Rambam Sefer HaMitzvot Principles	שרשים
Rambam Sefer HaMitzvot Positive Commandments	מצוות עשה
Positive Commandments Conclusion	סיום מצוות עשה
Rambam Sefer HaMitzvot Positive Commandments Conclusion	סיום מצוות עשה
Rambam Sefer HaMitzvot Negative Commandments	מצוות לא תעשה
Hilkhot	הלכות
Rambam Hilkhot	הלכות
Mishneh Torah	הלכות
Mishnah Torah	הלכות
Mishne Torah	הלכות
Mishne Tora	הלכות
Yad HaChazakah	הלכות
Yad HaChazaka	הלכות
Mishneh Torah Draft	משנה תורה טיוטה
Huggah MiSifri	הוגה מספרי
Mishneh Torah Printed Versions	משנה תורה דפוסים
Rambam Mishneh Torah Printed Versions	משנה תורה דפוסים
Mishneh Torah Rav Kapach	משנה תורה – הרב קאפח
Rambam Mishneh Torah Rav Kapach	משנה תורה – הרב קאפח
Mishneh Torah Yemenite MSS	משנה תורה כ\"י תימניים
Rambam Mishneh Torah Yemenite MSS	משנה תורה כ\"י תימניים
Rambam Mishneh Torah MS BL OR 5558P31	רמב\"ם כתב יד BL: OR 5558P.31
Rambam Mishneh Torah MS BL OR 5558P32	רמב\"ם כתב יד BL: OR 5558P.32
Rambam Mishneh Torah MS BL OR 5558P33	רמב\"ם כתב יד BL: OR 5558P.33
Rambam Mishneh Torah MS BL OR 5558P34	רמב\"ם כתב יד BL: OR 5558P.34
Rambam Mishneh Torah MS AIU IIIB59	רמב\"ם כתב יד AIU: III.B.59
Rambam Mishneh Torah MS AIU IIIB61	רמב\"ם כתב יד AIU: III.B.61
Rambam Mishneh Torah MS AIU IIIB63	רמב\"ם כתב יד AIU: III.B.63
Rambam Mishneh Torah MS AIU IIIB64	רמב\"ם כתב יד AIU: III.B.64
Rambam Mishneh Torah MS AIU IIIB76	רמב\"ם כתב יד AIU: III.B.76
Rambam Mishneh Torah MS CUL T-S K25110	רמב\"ם כתב יד CUL: T-S K25.110
Rambam Mishneh Torah MS CUL T-S K2755	רמב\"ם כתב יד CUL: T-S K27.55
Rambam Mishneh Torah MS AIU IIIB154	רמב\"ם כתב יד AIU: III.B.154
Rambam Mishneh Torah MS AIU IIIB157	רמב\"ם כתב יד AIU: III.B.157
Rambam Mishneh Torah MS Mosseri Moss III1451 Privat	רמב\"ם כתב יד Mosseri: Moss. III,145.1 (Private)
Rambam Mishneh Torah MS AIU IIIB189	רמב\"ם כתב יד AIU: III.B.189
Rambam Mishneh Torah MS AIU IIIB194	רמב\"ם כתב יד AIU: III.B.194
Rambam Mishneh Torah MS AIU IIIB209	רמב\"ם כתב יד AIU: III.B.209
Rambam Mishneh Torah MS AIU IIIB212	רמב\"ם כתב יד AIU: III.B.212
Rambam Mishneh Torah MS Mosseri Moss III161 Private	רמב\"ם כתב יד Mosseri: Moss. III,161 (Private)
Rambam Mishneh Torah MS AIU IIIB216	רמב\"ם כתב יד AIU: III.B.216
Rambam Mishneh Torah MS AIU IIIB218	רמב\"ם כתב יד AIU: III.B.218
Rambam Mishneh Torah MS AIU IIIB219	רמב\"ם כתב יד AIU: III.B.219
Rambam Mishneh Torah MS AIU IIIB221	רמב\"ם כתב יד AIU: III.B.221
Rambam Mishneh Torah MS Mosseri Moss III1711 Privat	רמב\"ם כתב יד Mosseri: Moss. III,171.1 (Private)
Rambam Mishneh Torah MS Mosseri Moss III1712 Privat	רמב\"ם כתב יד Mosseri: Moss. III,171.2 (Private)
Rambam Mishneh Torah MS AIU IIIB234	רמב\"ם כתב יד AIU: III.B.234
Rambam Mishneh Torah MS Mosseri Moss III1771 Privat	רמב\"ם כתב יד Mosseri: Moss. III,177.1 (Private)
Rambam Mishneh Torah MS AIU IIIB242	רמב\"ם כתב יד AIU: III.B.242
Rambam Mishneh Torah MS Mosseri Moss III1781 Privat	רמב\"ם כתב יד Mosseri: Moss. III,178.1 (Private)
Rambam Mishneh Torah MS JTS ENA 257218d	רמב\"ם כתב יד JTS: ENA 2572.18d
Rambam Mishneh Torah MS BL OR 5557I52	רמב\"ם כתב יד BL: OR 5557I.52
Rambam Mishneh Torah MS Mosseri Moss III1813 Privat	רמב\"ם כתב יד Mosseri: Moss. III,181.3 (Private)
Rambam Mishneh Torah MS CUL T-S 8K1310	רמב\"ם כתב יד CUL: T-S 8K13.10
Rambam Mishneh Torah MS AIU IIIB285	רמב\"ם כתב יד AIU: III.B.285
Rambam Mishneh Torah MS AIU IIIB286	רמב\"ם כתב יד AIU: III.B.286
Rambam Mishneh Torah MS AIU IIIB289	רמב\"ם כתב יד AIU: III.B.289
Rambam MS AIU: III.B.299bis	רמב\"ם כתב יד AIU: III.B.299bis
Rambam Mishneh Torah MS AIU IIIB299bis	רמב\"ם כתב יד AIU: III.B.299bis
Rambam Mishneh Torah MS AIU IIIB300	רמב\"ם כתב יד AIU: III.B.300
Rambam Mishneh Torah MS AIU IIIC14	רמב\"ם כתב יד AIU: III.C.14
Rambam Mishneh Torah MS CUL T-S 10K81	רמב\"ם כתב יד CUL: T-S 10K8.1
Rambam Mishneh Torah MS CUL T-S 10K153	רמב\"ם כתב יד CUL: T-S 10K15.3
Rambam Mishneh Torah MS CUL T-S 10K154	רמב\"ם כתב יד CUL: T-S 10K15.4
Rambam Mishneh Torah MS CUL T-S 10K155	רמב\"ם כתב יד CUL: T-S 10K15.5
Rambam Mishneh Torah MS CUL T-S 10K156	רמב\"ם כתב יד CUL: T-S 10K15.6
Rambam Mishneh Torah MS CUL T-S 10K1512	רמב\"ם כתב יד CUL: T-S 10K15.12
Rambam MS CUL: T-S 13F2	רמב\"ם כתב יד CUL: T-S 13F2
Rambam Mishneh Torah MS CUL T-S 13F2	רמב\"ם כתב יד CUL: T-S 13F2
Rambam Mishneh Torah MS AIU IIIC56	רמב\"ם כתב יד AIU: III.C.56
Rambam Mishneh Torah MS Mosseri Moss III2492 Privat	רמב\"ם כתב יד Mosseri: Moss. III,249.2 (Private)
Rambam Mishneh Torah MS CUL Or1080 B182	רמב\"ם כתב יד CUL: Or.1080 B18.2
Rambam Mishneh Torah MS Mosseri Moss V20 Private	רמב\"ם כתב יד Mosseri: Moss. V,20 (Private)
Rambam Mishneh Torah MS CUL T-S 13K31	רמב\"ם כתב יד CUL: T-S 13K3.1
Rambam Mishneh Torah MS Mosseri Moss I842 Private	רמב\"ם כתב יד Mosseri: Moss. I,84.2 (Private)
Rambam Mishneh Torah MS CUL T-S 18K11	רמב\"ם כתב יד CUL: T-S 18K1.1
Rambam Mishneh Torah MS CUL T-S 18K12	רמב\"ם כתב יד CUL: T-S 18K1.2
Rambam Mishneh Torah MS Oxford MS heb e7668	רמב\"ם כתב יד Oxford: MS heb. e.76/68
Rambam Mishneh Torah MS Oxford MS heb e7669	רמב\"ם כתב יד Oxford: MS heb. e.76/69
Rambam Mishneh Torah MS CUL T-S Ar2140	רמב\"ם כתב יד CUL: T-S Ar.21.40
Rambam Mishneh Torah MS CUL T-S A2572	רמב\"ם כתב יד CUL: T-S A25.72
Rambam Mishneh Torah MS Oxford MS heb e946	רמב\"ם כתב יד Oxford: MS heb. e.94/6
Rambam Mishneh Torah MS Oxford MS heb e9816	רמב\"ם כתב יד Oxford: MS heb. e.98/16
Rambam Mishneh Torah MS Oxford MS heb e10018	רמב\"ם כתב יד Oxford: MS heb. e.100/18
Rambam Mishneh Torah MS Oxford MS heb e10019	רמב\"ם כתב יד Oxford: MS heb. e.100/19
Rambam Mishneh Torah MS Oxford MS heb e10020	רמב\"ם כתב יד Oxford: MS heb. e.100/20
Rambam Mishneh Torah MS Oxford MS heb e1017	רמב\"ם כתב יד Oxford: MS heb. e.101/7
Rambam Mishneh Torah MS Oxford MS heb e1018	רמב\"ם כתב יד Oxford: MS heb. e.101/8
Rambam Mishneh Torah MS Oxford MS heb e1059	רמב\"ם כתב יד Oxford: MS heb. e.105/9
Rambam Mishneh Torah MS Oxford MS heb e10510	רמב\"ם כתב יד Oxford: MS heb. e.105/10
Rambam Mishneh Torah MS Oxford MS heb e10511	רמב\"ם כתב יד Oxford: MS heb. e.105/11
Rambam Mishneh Torah MS Oxford MS heb e10512	רמב\"ם כתב יד Oxford: MS heb. e.105/12
Rambam Mishneh Torah MS Oxford MS heb e10513	רמב\"ם כתב יד Oxford: MS heb. e.105/13
Rambam Mishneh Torah MS Oxford MS heb e10514	רמב\"ם כתב יד Oxford: MS heb. e.105/14
Rambam Mishneh Torah MS Oxford MS heb e10515	רמב\"ם כתב יד Oxford: MS heb. e.105/15
Rambam Mishneh Torah MS Oxford MS heb e10516	רמב\"ם כתב יד Oxford: MS heb. e.105/16
Rambam Mishneh Torah MS Oxford MS heb e10517	רמב\"ם כתב יד Oxford: MS heb. e.105/17
Rambam Mishneh Torah MS Oxford MS heb e10518	רמב\"ם כתב יד Oxford: MS heb. e.105/18
Rambam Mishneh Torah MS Oxford MS heb e10519	רמב\"ם כתב יד Oxford: MS heb. e.105/19
Rambam Mishneh Torah MS Oxford MS heb e10520	רמב\"ם כתב יד Oxford: MS heb. e.105/20
Rambam Mishneh Torah MS Oxford MS heb e10521	רמב\"ם כתב יד Oxford: MS heb. e.105/21
Rambam Mishneh Torah MS Oxford MS heb e10522	רמב\"ם כתב יד Oxford: MS heb. e.105/22
Rambam Mishneh Torah MS Oxford MS heb e10523	רמב\"ם כתב יד Oxford: MS heb. e.105/23
Rambam Mishneh Torah MS Oxford MS heb e10524	רמב\"ם כתב יד Oxford: MS heb. e.105/24
Rambam Mishneh Torah MS Oxford MS heb e10525	רמב\"ם כתב יד Oxford: MS heb. e.105/25
Rambam Mishneh Torah MS Oxford MS heb e10526	רמב\"ם כתב יד Oxford: MS heb. e.105/26
Rambam Mishneh Torah MS Oxford MS heb e10527	רמב\"ם כתב יד Oxford: MS heb. e.105/27
Rambam Mishneh Torah MS Oxford MS heb e10528	רמב\"ם כתב יד Oxford: MS heb. e.105/28
Rambam Mishneh Torah MS Oxford MS heb e10529	רמב\"ם כתב יד Oxford: MS heb. e.105/29
Rambam Mishneh Torah MS Oxford MS heb e10530	רמב\"ם כתב יד Oxford: MS heb. e.105/30
Rambam Mishneh Torah MS Oxford MS heb e10531	רמב\"ם כתב יד Oxford: MS heb. e.105/31
Rambam Mishneh Torah MS Oxford MS heb e10532	רמב\"ם כתב יד Oxford: MS heb. e.105/32
Rambam Mishneh Torah MS Oxford MS heb e10533	רמב\"ם כתב יד Oxford: MS heb. e.105/33
Rambam Mishneh Torah MS Oxford MS heb e10534	רמב\"ם כתב יד Oxford: MS heb. e.105/34
Rambam Mishneh Torah MS Oxford MS heb e10535	רמב\"ם כתב יד Oxford: MS heb. e.105/35
Rambam Mishneh Torah MS Oxford MS heb e10536	רמב\"ם כתב יד Oxford: MS heb. e.105/36
Rambam Mishneh Torah MS Oxford MS heb e1061	רמב\"ם כתב יד Oxford: MS heb. e.106/1
Rambam Mishneh Torah MS Oxford MS heb e1062	רמב\"ם כתב יד Oxford: MS heb. e.106/2
Rambam Mishneh Torah MS Oxford MS heb e1063	רמב\"ם כתב יד Oxford: MS heb. e.106/3
Rambam Mishneh Torah MS Oxford MS heb e1064	רמב\"ם כתב יד Oxford: MS heb. e.106/4
Rambam Mishneh Torah MS Oxford MS heb e1065	רמב\"ם כתב יד Oxford: MS heb. e.106/5
Rambam Mishneh Torah MS Oxford MS heb e1066	רמב\"ם כתב יד Oxford: MS heb. e.106/6
Rambam Mishneh Torah MS Oxford MS heb e1067	רמב\"ם כתב יד Oxford: MS heb. e.106/7
Rambam Mishneh Torah MS Oxford MS heb e1068	רמב\"ם כתב יד Oxford: MS heb. e.106/8
Rambam Mishneh Torah MS Oxford MS heb e1069	רמב\"ם כתב יד Oxford: MS heb. e.106/9
Rambam Mishneh Torah MS Oxford MS heb e10610	רמב\"ם כתב יד Oxford: MS heb. e.106/10
Rambam Mishneh Torah MS Oxford MS heb e10611	רמב\"ם כתב יד Oxford: MS heb. e.106/11
Rambam Mishneh Torah MS Oxford MS heb e10612	רמב\"ם כתב יד Oxford: MS heb. e.106/12
Rambam Mishneh Torah MS Oxford MS heb e10613	רמב\"ם כתב יד Oxford: MS heb. e.106/13
Rambam Mishneh Torah MS Oxford MS heb e10614	רמב\"ם כתב יד Oxford: MS heb. e.106/14
Rambam Mishneh Torah MS Oxford MS heb e10615	רמב\"ם כתב יד Oxford: MS heb. e.106/15
Rambam Mishneh Torah MS Oxford MS heb e10616	רמב\"ם כתב יד Oxford: MS heb. e.106/16
Rambam Mishneh Torah MS Oxford MS heb e10617	רמב\"ם כתב יד Oxford: MS heb. e.106/17
Rambam Mishneh Torah MS Oxford MS heb e10618	רמב\"ם כתב יד Oxford: MS heb. e.106/18
Rambam Mishneh Torah MS Oxford MS heb e10619	רמב\"ם כתב יד Oxford: MS heb. e.106/19
Rambam Mishneh Torah MS Oxford MS heb e10620	רמב\"ם כתב יד Oxford: MS heb. e.106/20
Rambam Mishneh Torah MS Oxford MS heb e10621	רמב\"ם כתב יד Oxford: MS heb. e.106/21
Rambam Mishneh Torah MS Oxford MS heb e10622	רמב\"ם כתב יד Oxford: MS heb. e.106/22
Rambam Mishneh Torah MS Oxford MS heb e10623	רמב\"ם כתב יד Oxford: MS heb. e.106/23
Rambam Mishneh Torah MS Oxford MS heb e10624	רמב\"ם כתב יד Oxford: MS heb. e.106/24
Rambam Mishneh Torah MS Oxford MS heb e10625	רמב\"ם כתב יד Oxford: MS heb. e.106/25
Rambam Mishneh Torah MS Oxford MS heb e10626	רמב\"ם כתב יד Oxford: MS heb. e.106/26
Rambam Mishneh Torah MS Oxford MS heb e10627	רמב\"ם כתב יד Oxford: MS heb. e.106/27
Rambam Mishneh Torah MS Oxford MS heb e10628	רמב\"ם כתב יד Oxford: MS heb. e.106/28
Rambam Mishneh Torah MS Oxford MS heb e10629	רמב\"ם כתב יד Oxford: MS heb. e.106/29
Rambam Mishneh Torah MS Oxford MS heb e10630	רמב\"ם כתב יד Oxford: MS heb. e.106/30
Rambam Mishneh Torah MS Oxford MS heb e10631	רמב\"ם כתב יד Oxford: MS heb. e.106/31
Rambam Mishneh Torah MS Oxford MS heb e10632	רמב\"ם כתב יד Oxford: MS heb. e.106/32
Rambam Mishneh Torah MS Oxford MS heb e10633	רמב\"ם כתב יד Oxford: MS heb. e.106/33
Rambam Mishneh Torah MS Oxford MS heb e10634	רמב\"ם כתב יד Oxford: MS heb. e.106/34
Rambam Mishneh Torah MS Oxford MS heb e10635	רמב\"ם כתב יד Oxford: MS heb. e.106/35
Rambam Mishneh Torah MS Oxford MS heb e10636	רמב\"ם כתב יד Oxford: MS heb. e.106/36
Rambam Mishneh Torah MS Oxford MS heb e10637	רמב\"ם כתב יד Oxford: MS heb. e.106/37
Rambam Mishneh Torah MS Oxford MS heb e10638	רמב\"ם כתב יד Oxford: MS heb. e.106/38
Rambam Mishneh Torah MS Oxford MS heb e10639	רמב\"ם כתב יד Oxford: MS heb. e.106/39
Rambam Mishneh Torah MS Oxford MS heb e10640	רמב\"ם כתב יד Oxford: MS heb. e.106/40
Rambam Mishneh Torah MS Oxford MS heb e10641	רמב\"ם כתב יד Oxford: MS heb. e.106/41
Rambam Mishneh Torah MS Oxford MS heb e10642	רמב\"ם כתב יד Oxford: MS heb. e.106/42
Rambam Mishneh Torah MS Oxford MS heb e10643	רמב\"ם כתב יד Oxford: MS heb. e.106/43
Rambam Mishneh Torah MS Oxford MS heb e10644	רמב\"ם כתב יד Oxford: MS heb. e.106/44
Rambam Mishneh Torah MS Oxford MS heb e10645	רמב\"ם כתב יד Oxford: MS heb. e.106/45
Rambam Mishneh Torah MS Oxford MS heb e10646	רמב\"ם כתב יד Oxford: MS heb. e.106/46
Rambam Mishneh Torah MS Oxford MS heb e10647	רמב\"ם כתב יד Oxford: MS heb. e.106/47
Rambam Mishneh Torah MS Oxford MS heb e10648	רמב\"ם כתב יד Oxford: MS heb. e.106/48
Rambam Mishneh Torah MS Oxford MS heb e10649	רמב\"ם כתב יד Oxford: MS heb. e.106/49
Rambam Mishneh Torah MS Oxford MS heb e10650	רמב\"ם כתב יד Oxford: MS heb. e.106/50
Rambam Mishneh Torah MS Oxford MS heb e10651	רמב\"ם כתב יד Oxford: MS heb. e.106/51
Rambam Mishneh Torah MS Oxford MS heb e10652	רמב\"ם כתב יד Oxford: MS heb. e.106/52
Rambam Mishneh Torah MS Oxford MS heb e10653	רמב\"ם כתב יד Oxford: MS heb. e.106/53
Rambam Mishneh Torah MS Oxford MS heb e10654	רמב\"ם כתב יד Oxford: MS heb. e.106/54
Rambam Mishneh Torah MS Oxford MS heb e10655	רמב\"ם כתב יד Oxford: MS heb. e.106/55
Rambam Mishneh Torah MS Oxford MS heb e10656	רמב\"ם כתב יד Oxford: MS heb. e.106/56
Rambam Mishneh Torah MS Oxford MS heb e10657	רמב\"ם כתב יד Oxford: MS heb. e.106/57
Rambam Mishneh Torah MS Oxford MS heb e10658	רמב\"ם כתב יד Oxford: MS heb. e.106/58
Rambam Mishneh Torah MS Oxford MS heb e10659	רמב\"ם כתב יד Oxford: MS heb. e.106/59
Rambam Mishneh Torah MS Oxford MS heb e10660	רמב\"ם כתב יד Oxford: MS heb. e.106/60
Rambam Mishneh Torah MS Oxford MS heb e10661	רמב\"ם כתב יד Oxford: MS heb. e.106/61
Rambam Mishneh Torah MS Oxford MS heb e10662	רמב\"ם כתב יד Oxford: MS heb. e.106/62
Rambam Mishneh Torah MS Oxford MS heb e10663	רמב\"ם כתב יד Oxford: MS heb. e.106/63
Rambam Mishneh Torah MS Oxford MS heb e10854	רמב\"ם כתב יד Oxford: MS heb. e.108/54
Rambam Mishneh Torah MS AIU IVB23	רמב\"ם כתב יד AIU: IV.B.23
Rambam Mishneh Torah MS AIU IVB33	רמב\"ם כתב יד AIU: IV.B.33
Rambam Mishneh Torah MS AIU IVB35	רמב\"ם כתב יד AIU: IV.B.35
Rambam Mishneh Torah MS Mosseri Moss I111 Private	רמב\"ם כתב יד Mosseri: Moss. I,11.1 (Private)
Rambam Mishneh Torah MS CUL T-S Ar39423	רמב\"ם כתב יד CUL: T-S Ar.39.423
Rambam Mishneh Torah MS Mosseri Moss V2965 Private	רמב\"ם כתב יד Mosseri: Moss. V,296.5 (Private)
Rambam Mishneh Torah MS CUL T-S Ar4073	רמב\"ם כתב יד CUL: T-S Ar.40.73
Rambam Mishneh Torah MS Mosseri Moss V303 Private	רמב\"ם כתב יד Mosseri: Moss. V,303 (Private)
Rambam Mishneh Torah MS Mosseri Moss V304 Private	רמב\"ם כתב יד Mosseri: Moss. V,304 (Private)
Rambam Mishneh Torah MS Mosseri Moss I121 Private	רמב\"ם כתב יד Mosseri: Moss. I,12.1 (Private)
Rambam Mishneh Torah MS CUL T-S Ar4726	רמב\"ם כתב יד CUL: T-S Ar.47.26
Rambam Mishneh Torah MS CUL T-S Ar4824	רמב\"ם כתב יד CUL: T-S Ar.48.24
Rambam Mishneh Torah MS CUL T-S Ar48258	רמב\"ם כתב יד CUL: T-S Ar.48.258
Rambam Mishneh Torah MS CUL T-S Ar49162	רמב\"ם כתב יד CUL: T-S Ar.49.162
Rambam Mishneh Torah MS CUL T-S Ar50238	רמב\"ם כתב יד CUL: T-S Ar.50.238
Rambam Mishneh Torah MS Oxford MS heb f10218	רמב\"ם כתב יד Oxford: MS heb. f.102/18
Rambam Mishneh Torah MS Oxford MS heb f10219	רמב\"ם כתב יד Oxford: MS heb. f.102/19
Rambam Mishneh Torah MS Mosseri Moss I131 Private	רמב\"ם כתב יד Mosseri: Moss. I,13.1 (Private)
Rambam Mishneh Torah MS Oxford MS heb c1618	רמב\"ם כתב יד Oxford: MS heb. c.16/18
Rambam Mishneh Torah MS Oxford MS heb c1619	רמב\"ם כתב יד Oxford: MS heb. c.16/19
Rambam Mishneh Torah MS Oxford MS heb c1620	רמב\"ם כתב יד Oxford: MS heb. c.16/20
Rambam Mishneh Torah MS BL OR 5558E1	רמב\"ם כתב יד BL: OR 5558E.1
Rambam Mishneh Torah MS Oxford MS heb c1621	רמב\"ם כתב יד Oxford: MS heb. c.16/21
Rambam Mishneh Torah MS BL OR 5558E2	רמב\"ם כתב יד BL: OR 5558E.2
Rambam Mishneh Torah MS Oxford MS heb c1622	רמב\"ם כתב יד Oxford: MS heb. c.16/22
Rambam Mishneh Torah MS BL OR 5558E3	רמב\"ם כתב יד BL: OR 5558E.3
Rambam Mishneh Torah MS Oxford MS heb c1623	רמב\"ם כתב יד Oxford: MS heb. c.16/23
Rambam Mishneh Torah MS BL OR 5558E4	רמב\"ם כתב יד BL: OR 5558E.4
Rambam Mishneh Torah MS BL OR 5558E5	רמב\"ם כתב יד BL: OR 5558E.5
Rambam Mishneh Torah MS BL OR 5558E6	רמב\"ם כתב יד BL: OR 5558E.6
Rambam Mishneh Torah MS BL OR 5558E7	רמב\"ם כתב יד BL: OR 5558E.7
Rambam Mishneh Torah MS BL OR 5558E8	רמב\"ם כתב יד BL: OR 5558E.8
Rambam Mishneh Torah MS BL OR 5558E9 BL OR 5558E10	רמב\"ם כתב יד BL: OR 5558E.9 + BL: OR 5558E.10
Rambam Mishneh Torah MS BL OR 5558E11	רמב\"ם כתב יד BL: OR 5558E.11
Rambam Mishneh Torah MS BL OR 5558E12	רמב\"ם כתב יד BL: OR 5558E.12
Rambam Mishneh Torah MS BL OR 5558E13	רמב\"ם כתב יד BL: OR 5558E.13
Rambam Mishneh Torah MS BL OR 5558E14	רמב\"ם כתב יד BL: OR 5558E.14
Rambam Mishneh Torah MS Oxford MS heb f10748	רמב\"ם כתב יד Oxford: MS heb. f.107/48
Rambam Mishneh Torah MS BL OR 5558I18	רמב\"ם כתב יד BL: OR 5558I.18
Rambam Mishneh Torah MS BL OR 5558I19	רמב\"ם כתב יד BL: OR 5558I.19
Rambam Mishneh Torah MS Oxford MS heb c1831	רמב\"ם כתב יד Oxford: MS heb. c.18/31
Rambam Mishneh Torah MS BL OR 5558I23	רמב\"ם כתב יד BL: OR 5558I.23
Rambam Mishneh Torah MS Oxford MS heb c1832	רמב\"ם כתב יד Oxford: MS heb. c.18/32
Rambam Mishneh Torah MS BL OR 5558I24	רמב\"ם כתב יד BL: OR 5558I.24
Rambam Mishneh Torah MS AIU VB69	רמב\"ם כתב יד AIU: V.B.69
Rambam Mishneh Torah MS AIU VB70	רמב\"ם כתב יד AIU: V.B.70
Rambam Mishneh Torah MS AIU VB72	רמב\"ם כתב יד AIU: V.B.72
Rambam Mishneh Torah MS AIU VB75	רמב\"ם כתב יד AIU: V.B.75
Rambam Mishneh Torah MS AIU VB77	רמב\"ם כתב יד AIU: V.B.77
Rambam Mishneh Torah MS AIU IIIB67 AIU VB78	רמב\"ם כתב יד AIU: III.B.67 + AIU: V.B.78
Rambam Mishneh Torah MS AIU VC7	רמב\"ם כתב יד AIU: V.C.7
Rambam Mishneh Torah MS BL OR 5558L12	רמב\"ם כתב יד BL: OR 5558L.12
Rambam Mishneh Torah MS BL OR 5558L13	רמב\"ם כתב יד BL: OR 5558L.13
Rambam Mishneh Torah MS BL OR 5558L14	רמב\"ם כתב יד BL: OR 5558L.14
Rambam Mishneh Torah MS BL OR 5558L15	רמב\"ם כתב יד BL: OR 5558L.15
Rambam Mishneh Torah MS BL OR 5558L16	רמב\"ם כתב יד BL: OR 5558L.16
Rambam Mishneh Torah MS BL OR 5558L17	רמב\"ם כתב יד BL: OR 5558L.17
Rambam Mishneh Torah MS BL OR 5558L18	רמב\"ם כתב יד BL: OR 5558L.18
Rambam Mishneh Torah MS BL OR 5558L19	רמב\"ם כתב יד BL: OR 5558L.19
Rambam Mishneh Torah MS BL OR 5558L20	רמב\"ם כתב יד BL: OR 5558L.20
Rambam Mishneh Torah MS BL OR 5558L21	רמב\"ם כתב יד BL: OR 5558L.21
Rambam Mishneh Torah MS BL OR 5558L22	רמב\"ם כתב יד BL: OR 5558L.22
Rambam Mishneh Torah MS BL OR 5558L23	רמב\"ם כתב יד BL: OR 5558L.23
Rambam Mishneh Torah MS BL OR 5558L24	רמב\"ם כתב יד BL: OR 5558L.24
Rambam Mishneh Torah MS BL OR 5558L25	רמב\"ם כתב יד BL: OR 5558L.25
Rambam Mishneh Torah MS BL OR 5558L26	רמב\"ם כתב יד BL: OR 5558L.26
Rambam Mishneh Torah MS BL OR 5558L27	רמב\"ם כתב יד BL: OR 5558L.27
Rambam Mishneh Torah MS BL OR 5558L28	רמב\"ם כתב יד BL: OR 5558L.28
Rambam Mishneh Torah MS BL OR 5558L29	רמב\"ם כתב יד BL: OR 5558L.29
Rambam Mishneh Torah MS BL OR 5558L30	רמב\"ם כתב יד BL: OR 5558L.30
Rambam Mishneh Torah MS BL OR 5558L31	רמב\"ם כתב יד BL: OR 5558L.31
Rambam Mishneh Torah MS BL OR 5558L32	רמב\"ם כתב יד BL: OR 5558L.32
Rambam Mishneh Torah MS Mosseri Moss I15 Private	רמב\"ם כתב יד Mosseri: Moss. I,15 (Private)
Rambam Mishneh Torah MS CUL T-S Misc7100	רמב\"ם כתב יד CUL: T-S Misc.7.100
Rambam Mishneh Torah MS BL OR 5558L33	רמב\"ם כתב יד BL: OR 5558L.33
Rambam Mishneh Torah MS BL OR 5558L34	רמב\"ם כתב יד BL: OR 5558L.34
Rambam Mishneh Torah MS BL OR 5558L35	רמב\"ם כתב יד BL: OR 5558L.35
Rambam Mishneh Torah MS BL OR 5558L36	רמב\"ם כתב יד BL: OR 5558L.36
Rambam Mishneh Torah MS BL OR 5558L39	רמב\"ם כתב יד BL: OR 5558L.39
Rambam Mishneh Torah MS BL OR 5558L40	רמב\"ם כתב יד BL: OR 5558L.40
Rambam Mishneh Torah MS BL OR 5558M8	רמב\"ם כתב יד BL: OR 5558M.8
Rambam Mishneh Torah MS BL OR 5558M9	רמב\"ם כתב יד BL: OR 5558M.9
Rambam Mishneh Torah MS BL OR 5558M10	רמב\"ם כתב יד BL: OR 5558M.10
Rambam Mishneh Torah MS BL OR 5558M15	רמב\"ם כתב יד BL: OR 5558M.15
Rambam Mishneh Torah MS BL OR 5558M16	רמב\"ם כתב יד BL: OR 5558M.16
Rambam Mishneh Torah MS BL OR 5558M17	רמב\"ם כתב יד BL: OR 5558M.17
Rambam Mishneh Torah MS BL OR 5558M18	רמב\"ם כתב יד BL: OR 5558M.18
Rambam Mishneh Torah MS CUL T-S Misc1038	רמב\"ם כתב יד CUL: T-S Misc.10.38
Rambam Mishneh Torah MS CUL T-S Misc10200	רמב\"ם כתב יד CUL: T-S Misc.10.200
Rambam Mishneh Torah MS CUL T-S Misc1142	רמב\"ם כתב יד CUL: T-S Misc.11.42
Rambam Mishneh Torah MS BL OR 5558N10	רמב\"ם כתב יד BL: OR 5558N.10
Rambam Mishneh Torah MS CUL T-S Misc11149	רמב\"ם כתב יד CUL: T-S Misc.11.149
Rambam Mishneh Torah MS BL OR 5558N21	רמב\"ם כתב יד BL: OR 5558N.21
Rambam Mishneh Torah MS CUL T-S Misc11207	רמב\"ם כתב יד CUL: T-S Misc.11.207
Rambam Mishneh Torah MS CUL T-S Misc11215	רמב\"ם כתב יד CUL: T-S Misc.11.215
Rambam Mishneh Torah MS Mosseri Moss VI110 Private	רמב\"ם כתב יד Mosseri: Moss. VI,110 (Private)
Rambam Mishneh Torah MS CUL T-S Misc134	רמב\"ם כתב יד CUL: T-S Misc.13.4
Rambam Mishneh Torah MS CUL T-S Misc1423	רמב\"ם כתב יד CUL: T-S Misc.14.23
Rambam Mishneh Torah MS CUL T-S Misc1424	רמב\"ם כתב יד CUL: T-S Misc.14.24
Rambam Mishneh Torah MS CUL T-S Misc1436b	רמב\"ם כתב יד CUL: T-S Misc.14.36b
Rambam Mishneh Torah MS CUL T-S Misc1436c	רמב\"ם כתב יד CUL: T-S Misc.14.36c
Rambam Mishneh Torah MS CUL T-S Misc1436e	רמב\"ם כתב יד CUL: T-S Misc.14.36e
Rambam Mishneh Torah MS CUL T-S Misc1436f	רמב\"ם כתב יד CUL: T-S Misc.14.36f
Rambam Mishneh Torah MS CUL T-S Misc14371c	רמב\"ם כתב יד CUL: T-S Misc.14.37.1c
Rambam Mishneh Torah MS CUL T-S Misc14371e	רמב\"ם כתב יד CUL: T-S Misc.14.37.1e
Rambam Mishneh Torah MS CUL T-S Misc14371f	רמב\"ם כתב יד CUL: T-S Misc.14.37.1f
Rambam Mishneh Torah MS CUL T-S Misc1532	רמב\"ם כתב יד CUL: T-S Misc.15.32
Rambam Mishneh Torah MS BL OR 5558N70	רמב\"ם כתב יד BL: OR 5558N.70
Rambam Mishneh Torah MS BL OR 5558N71	רמב\"ם כתב יד BL: OR 5558N.71
Rambam Mishneh Torah MS BL OR 5558N72	רמב\"ם כתב יד BL: OR 5558N.72
Rambam Mishneh Torah MS BL OR 5558N73	רמב\"ם כתב יד BL: OR 5558N.73
Rambam Mishneh Torah MS BL OR 5558N77	רמב\"ם כתב יד BL: OR 5558N.77
Rambam Mishneh Torah MS BL OR 5558N78	רמב\"ם כתב יד BL: OR 5558N.78
Rambam Mishneh Torah MS CUL T-S Misc173	רמב\"ם כתב יד CUL: T-S Misc.17.3
Rambam Mishneh Torah MS BL OR 5558N81	רמב\"ם כתב יד BL: OR 5558N.81
Rambam Mishneh Torah MS BL OR 5558N82	רמב\"ם כתב יד BL: OR 5558N.82
Rambam Mishneh Torah MS BL OR 5558N86	רמב\"ם כתב יד BL: OR 5558N.86
Rambam Mishneh Torah MS BL OR 5558N87	רמב\"ם כתב יד BL: OR 5558N.87
Rambam Mishneh Torah MS BL OR 5558N88	רמב\"ם כתב יד BL: OR 5558N.88
Rambam Mishneh Torah MS BL OR 5558N89	רמב\"ם כתב יד BL: OR 5558N.89
Rambam Mishneh Torah MS BL OR 5558N90	רמב\"ם כתב יד BL: OR 5558N.90
Rambam Mishneh Torah MS BL OR 5558N91	רמב\"ם כתב יד BL: OR 5558N.91
Rambam Mishneh Torah MS BL OR 5558N92	רמב\"ם כתב יד BL: OR 5558N.92
Rambam Mishneh Torah MS BL OR 5558N93	רמב\"ם כתב יד BL: OR 5558N.93
Rambam Mishneh Torah MS BL OR 5558N94	רמב\"ם כתב יד BL: OR 5558N.94
Rambam Mishneh Torah MS BL OR 5558O1	רמב\"ם כתב יד BL: OR 5558O.1
Rambam Mishneh Torah MS BL OR 5558O15	רמב\"ם כתב יד BL: OR 5558O.15
Rambam Mishneh Torah MS CUL T-S Misc2053	רמב\"ם כתב יד CUL: T-S Misc.20.53
Rambam Mishneh Torah MS CUL T-S Misc20158	רמב\"ם כתב יד CUL: T-S Misc.20.158
Rambam Mishneh Torah MS CUL T-S Misc20185	רמב\"ם כתב יד CUL: T-S Misc.20.185
Rambam Mishneh Torah MS Heidelberg Papyrology p Hei	רמב\"ם כתב יד Heidelberg, Papyrology: p. Heid. Hebr. 21
Rambam Mishneh Torah MS BL OR 5558P25	רמב\"ם כתב יד BL: OR 5558P.25
Rambam Mishneh Torah MS CUL T-S Misc22165	רמב\"ם כתב יד CUL: T-S Misc.22.165
Rambam Mishneh Torah MS CUL T-S Misc22232	רמב\"ם כתב יד CUL: T-S Misc.22.232
Rambam Mishneh Torah MS BL OR 5558P35	רמב\"ם כתב יד BL: OR 5558P.35
Rambam Mishneh Torah MS BL OR 5558P36	רמב\"ם כתב יד BL: OR 5558P.36
Rambam Mishneh Torah MS BL OR 5558P37	רמב\"ם כתב יד BL: OR 5558P.37
Rambam Mishneh Torah MS BL OR 5558P38	רמב\"ם כתב יד BL: OR 5558P.38
Rambam Mishneh Torah MS BL OR 5558P39	רמב\"ם כתב יד BL: OR 5558P.39
Rambam Mishneh Torah MS BL OR 5558P40	רמב\"ם כתב יד BL: OR 5558P.40
Rambam Mishneh Torah MS BL OR 5558P41	רמב\"ם כתב יד BL: OR 5558P.41
Rambam Mishneh Torah MS BL OR 5558P42	רמב\"ם כתב יד BL: OR 5558P.42
Rambam Mishneh Torah MS BL OR 5558P43	רמב\"ם כתב יד BL: OR 5558P.43
Rambam Mishneh Torah MS BL OR 5558P44	רמב\"ם כתב יד BL: OR 5558P.44
Rambam Mishneh Torah MS BL OR 5558P45	רמב\"ם כתב יד BL: OR 5558P.45
Rambam Mishneh Torah MS CUL T-S Misc2412	רמב\"ם כתב יד CUL: T-S Misc.24.12
Rambam Mishneh Torah MS BL OR 5558P46	רמב\"ם כתב יד BL: OR 5558P.46
Rambam Mishneh Torah MS BL OR 5558P47	רמב\"ם כתב יד BL: OR 5558P.47
Rambam Mishneh Torah MS CUL T-S Misc24177	רמב\"ם כתב יד CUL: T-S Misc.24.177
Rambam Mishneh Torah MS Mosseri Moss VI1572 Private	רמב\"ם כתב יד Mosseri: Moss. VI,157.2 (Private)
Rambam Mishneh Torah MS CUL T-S Misc25142	רמב\"ם כתב יד CUL: T-S Misc.25.142
Rambam Mishneh Torah MS CUL T-S Misc2628	רמב\"ם כתב יד CUL: T-S Misc.26.28
Rambam Mishneh Torah MS CUL T-S Misc2645	רמב\"ם כתב יד CUL: T-S Misc.26.45
Rambam Mishneh Torah MS CUL T-S Misc26532	רמב\"ם כתב יד CUL: T-S Misc.26.53.2
Rambam Mishneh Torah MS CUL T-S Misc2838	רמב\"ם כתב יד CUL: T-S Misc.28.38
Rambam Mishneh Torah MS CUL T-S Misc2894	רמב\"ם כתב יד CUL: T-S Misc.28.94
Rambam Mishneh Torah MS CUL T-S Misc28101	רמב\"ם כתב יד CUL: T-S Misc.28.101
Rambam Mishneh Torah MS CUL T-S Misc28188	רמב\"ם כתב יד CUL: T-S Misc.28.188
Rambam Mishneh Torah MS CUL T-S Misc28247	רמב\"ם כתב יד CUL: T-S Misc.28.247
Rambam Mishneh Torah MS Lewis-Gibson L-G BibI30	רמב\"ם כתב יד Lewis-Gibson: L-G Bib.I.30
Rambam Mishneh Torah MS Mosseri Moss VI2432 Private	רמב\"ם כתב יד Mosseri: Moss. VI,243.2 (Private)
Rambam Mishneh Torah MS Oxford MS heb c5330	רמב\"ם כתב יד Oxford: MS heb. c.53/30
Rambam Mishneh Torah MS Oxford MS heb c5331	רמב\"ם כתב יד Oxford: MS heb. c.53/31
Rambam Mishneh Torah MS Oxford MS heb c5332	רמב\"ם כתב יד Oxford: MS heb. c.53/32
Rambam Mishneh Torah MS Oxford MS heb c5333	רמב\"ם כתב יד Oxford: MS heb. c.53/33
Rambam Mishneh Torah MS Oxford MS heb c5334	רמב\"ם כתב יד Oxford: MS heb. c.53/34
Rambam Mishneh Torah MS Oxford MS heb c5335	רמב\"ם כתב יד Oxford: MS heb. c.53/35
Rambam Mishneh Torah MS Oxford MS heb c5336	רמב\"ם כתב יד Oxford: MS heb. c.53/36
Rambam Mishneh Torah MS Oxford MS heb c5337	רמב\"ם כתב יד Oxford: MS heb. c.53/37
Rambam Mishneh Torah MS Oxford MS heb c5338	רמב\"ם כתב יד Oxford: MS heb. c.53/38
Rambam Mishneh Torah MS Oxford MS heb c5339	רמב\"ם כתב יד Oxford: MS heb. c.53/39
Rambam Mishneh Torah MS Mosseri Moss I183 Private	רמב\"ם כתב יד Mosseri: Moss. I,18.3 (Private)
Rambam Mishneh Torah MS Oxford MS heb c5528	רמב\"ם כתב יד Oxford: MS heb. c.55/28
Rambam Mishneh Torah MS Oxford MS heb c5529	רמב\"ם כתב יד Oxford: MS heb. c.55/29
Rambam Mishneh Torah MS Mosseri Moss I191 Private	רמב\"ם כתב יד Mosseri: Moss. I,19.1 (Private)
Rambam Mishneh Torah MS AIU VIIIB23	רמב\"ם כתב יד AIU: VIII.B.23
Rambam Mishneh Torah MS AIU VIIID10	רמב\"ם כתב יד AIU: VIII.D.10
Rambam Mishneh Torah MS Mosseri Moss II461 Private	רמב\"ם כתב יד Mosseri: Moss. II,46.1 (Private)
Rambam Mishneh Torah MS JTS Krengel68b	רמב\"ם כתב יד JTS: Krengel.68b
Rambam Mishneh Torah MS BL OR 5564A44	רמב\"ם כתב יד BL: OR 5564A.44
Rambam Mishneh Torah MS Mosseri Moss I211 Private	רמב\"ם כתב יד Mosseri: Moss. I,21.1 (Private)
Rambam Mishneh Torah MS AIU IA234 AIU IA235 AIU XI1	רמב\"ם כתב יד AIU: I.A.234 + AIU: I.A.235 + AIU: XI.101-102
Rambam Mishneh Torah MS AIU XI107	רמב\"ם כתב יד AIU: XI.107
Rambam Mishneh Torah MS Mosseri Moss I212 Private	רמב\"ם כתב יד Mosseri: Moss. I,21.2 (Private)
Rambam Mishneh Torah MS AIU XI161	רמב\"ם כתב יד AIU: XI.161
Rambam Mishneh Torah MS AIU XI171	רמב\"ם כתב יד AIU: XI.171
Rambam Mishneh Torah MS AIU XI186	רמב\"ם כתב יד AIU: XI.186
Rambam Mishneh Torah MS Columbia X893 J757 Columbia	רמב\"ם כתב יד Columbia: X893 J757 + Columbia: X893 Se62 pt. 4
Rambam MS JTS: MS R1558	רמב\"ם כתב יד JTS: MS R1558
Rambam Mishneh Torah MS JTS MS R1558	רמב\"ם כתב יד JTS: MS R1558
Rambam Mishneh Torah MS Mosseri Moss I213 Private	רמב\"ם כתב יד Mosseri: Moss. I,21.3 (Private)
Rambam Mishneh Torah MS AIU XI289	רמב\"ם כתב יד AIU: XI.289
Rambam Mishneh Torah MS Freer F 190844MM	רמב\"ם כתב יד Freer: F 1908.44MM
Rambam Mishneh Torah MS Mosseri Moss I232 Private	רמב\"ם כתב יד Mosseri: Moss. I,23.2 (Private)
Rambam Mishneh Torah MS Mosseri Moss I24 Private	רמב\"ם כתב יד Mosseri: Moss. I,24 (Private)
Rambam Mishneh Torah MS CUL T-S D129	רמב\"ם כתב יד CUL: T-S D1.29
Rambam Mishneh Torah MS JTS Krengel104a JTS Krengel	רמב\"ם כתב יד JTS: Krengel.104a + JTS: Krengel.104b + CUL: T-S NS 162.130
Rambam Mishneh Torah MS BL OR 10578C28	רמב\"ם כתב יד BL: OR 10578C.28
Rambam Mishneh Torah MS CUL T-S E1160	רמב\"ם כתב יד CUL: T-S E1.160
Rambam Mishneh Torah MS CUL T-S E1161	רמב\"ם כתב יד CUL: T-S E1.161
Rambam Mishneh Torah MS Oxford MS heb d1912	רמב\"ם כתב יד Oxford: MS heb. d.19/12
Rambam Mishneh Torah MS Oxford MS heb d1913	רמב\"ם כתב יד Oxford: MS heb. d.19/13
Rambam Mishneh Torah MS BL OR 10578F14	רמב\"ם כתב יד BL: OR 10578F.14
Rambam Mishneh Torah MS BL OR 10578F21	רמב\"ם כתב יד BL: OR 10578F.21
Rambam Mishneh Torah MS BL OR 10578F23 BL OR 10578F	רמב\"ם כתב יד BL: OR 10578F.23 + BL: OR 10578F.30
Rambam Mishneh Torah MS BL OR 10578F26 BL OR 10578F	רמב\"ם כתב יד BL: OR 10578F.26 + BL: OR 10578F.27 + BL: OR 10578F.32
Rambam Mishneh Torah MS BL OR 10578F25 BL OR 10578F	רמב\"ם כתב יד BL: OR 10578F.25 + BL: OR 10578F.35 + BL: OR 10578F.38
Rambam Mishneh Torah MS BL OR 10578F41 BL OR 10578F	רמב\"ם כתב יד BL: OR 10578F.41 + BL: OR 10578F.42
Rambam Mishneh Torah MS CUL T-S E296	רמב\"ם כתב יד CUL: T-S E2.96
Rambam Mishneh Torah MS CUL T-S E2106	רמב\"ם כתב יד CUL: T-S E2.106
Rambam Mishneh Torah MS CUL T-S E2107	רמב\"ם כתב יד CUL: T-S E2.107
Rambam MS Columbia: X893 M2818	רמב\"ם כתב יד Columbia: X893 M2818
Rambam Mishneh Torah MS Columbia X893 M2818	רמב\"ם כתב יד Columbia: X893 M2818
Rambam Mishneh Torah MS CUL T-S E2116	רמב\"ם כתב יד CUL: T-S E2.116
Rambam Mishneh Torah MS BL OR 10578G38	רמב\"ם כתב יד BL: OR 10578G.38
Rambam Mishneh Torah MS CUL T-S E2120	רמב\"ם כתב יד CUL: T-S E2.120
Rambam Mishneh Torah MS CUL T-S E2130	רמב\"ם כתב יד CUL: T-S E2.130
Rambam MS Columbia: X893 M2819	רמב\"ם כתב יד Columbia: X893 M2819
Rambam Mishneh Torah MS Columbia X893 M2819	רמב\"ם כתב יד Columbia: X893 M2819
Rambam Mishneh Torah MS BL OR 10578M15	רמב\"ם כתב יד BL: OR 10578M.15
Rambam Mishneh Torah MS BL OR 10578M16	רמב\"ם כתב יד BL: OR 10578M.16
Rambam Mishneh Torah MS BL OR 10578M25	רמב\"ם כתב יד BL: OR 10578M.25
Rambam MS Columbia: X893 M282	רמב\"ם כתב יד Columbia: X893 M282
Rambam Mishneh Torah MS Columbia X893 M282	רמב\"ם כתב יד Columbia: X893 M282
Rambam Mishneh Torah MS CUL T-S F119	רמב\"ם כתב יד CUL: T-S F1(1).9
Rambam Mishneh Torah MS Oxford MS heb d3239	רמב\"ם כתב יד Oxford: MS heb. d.32/39
Rambam Mishneh Torah MS Oxford MS heb d3240	רמב\"ם כתב יד Oxford: MS heb. d.32/40
Rambam Mishneh Torah MS Oxford MS heb d3241	רמב\"ם כתב יד Oxford: MS heb. d.32/41
Rambam Mishneh Torah MS Oxford MS heb d3242	רמב\"ם כתב יד Oxford: MS heb. d.32/42
Rambam Mishneh Torah MS Oxford MS heb d3243	רמב\"ם כתב יד Oxford: MS heb. d.32/43
Rambam Mishneh Torah MS Oxford MS heb d3244	רמב\"ם כתב יד Oxford: MS heb. d.32/44
Rambam Mishneh Torah MS Oxford MS heb d3245	רמב\"ם כתב יד Oxford: MS heb. d.32/45
Rambam Mishneh Torah MS Oxford MS heb d3246	רמב\"ם כתב יד Oxford: MS heb. d.32/46
Rambam Mishneh Torah MS BL OR 10578Q2	רמב\"ם כתב יד BL: OR 10578Q.2
Rambam Mishneh Torah MS Oxford MS heb d3257	רמב\"ם כתב יד Oxford: MS heb. d.32/57
Rambam Mishneh Torah MS Oxford MS heb d3258	רמב\"ם כתב יד Oxford: MS heb. d.32/58
Rambam Mishneh Torah MS Oxford MS heb d3259	רמב\"ם כתב יד Oxford: MS heb. d.32/59
Rambam Mishneh Torah MS Oxford MS heb d3260	רמב\"ם כתב יד Oxford: MS heb. d.32/60
Rambam Mishneh Torah MS Oxford MS heb d3261	רמב\"ם כתב יד Oxford: MS heb. d.32/61
Rambam Mishneh Torah MS Oxford MS heb d3262	רמב\"ם כתב יד Oxford: MS heb. d.32/62
Rambam Mishneh Torah MS CUL T-S Misc22290 CUL T-S F	רמב\"ם כתב יד CUL: T-S Misc.22.290 + CUL: T-S F1(1).53
Rambam Mishneh Torah MS CUL T-S F1214	רמב\"ם כתב יד CUL: T-S F1(2).14
Rambam Mishneh Torah MS Oxford MS heb d3449	רמב\"ם כתב יד Oxford: MS heb. d.34/49
Rambam Mishneh Torah MS Oxford MS heb d3450	רמב\"ם כתב יד Oxford: MS heb. d.34/50
Rambam Mishneh Torah MS Oxford MS heb d3451	רמב\"ם כתב יד Oxford: MS heb. d.34/51
Rambam Mishneh Torah MS Oxford MS heb d3452	רמב\"ם כתב יד Oxford: MS heb. d.34/52
Rambam Mishneh Torah MS Oxford MS heb d3453	רמב\"ם כתב יד Oxford: MS heb. d.34/53
Rambam Mishneh Torah MS Oxford MS heb d3454	רמב\"ם כתב יד Oxford: MS heb. d.34/54
Rambam Mishneh Torah MS Oxford MS heb d3455	רמב\"ם כתב יד Oxford: MS heb. d.34/55
Rambam Mishneh Torah MS Oxford MS heb d3456	רמב\"ם כתב יד Oxford: MS heb. d.34/56
Rambam Mishneh Torah MS Oxford MS heb d3457	רמב\"ם כתב יד Oxford: MS heb. d.34/57
Rambam Mishneh Torah MS Oxford MS heb d3458	רמב\"ם כתב יד Oxford: MS heb. d.34/58
Rambam Mishneh Torah MS Mosseri Moss I29 Private	רמב\"ם כתב יד Mosseri: Moss. I,29 (Private)
Rambam Mishneh Torah MS Mosseri Moss I301 Private	רמב\"ם כתב יד Mosseri: Moss. I,30.1 (Private)
Rambam Mishneh Torah MS CUL T-S NS 2567c	רמב\"ם כתב יד CUL: T-S NS 256.7c
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI1	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.1
Rambam Mishneh Torah MS CUL T-S F399	רמב\"ם כתב יד CUL: T-S F3.99
Rambam Mishneh Torah MS Mosseri Moss I321 Private	רמב\"ם כתב יד Mosseri: Moss. I,32.1 (Private)
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI30	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.30
Rambam Mishneh Torah MS CUL T-S F5118	רמב\"ם כתב יד CUL: T-S F5.118
Rambam Mishneh Torah MS CUL T-S F73	רמב\"ם כתב יד CUL: T-S F7.3
Rambam Mishneh Torah MS CUL T-S F74	רמב\"ם כתב יד CUL: T-S F7.4
Rambam Mishneh Torah MS CUL T-S F75	רמב\"ם כתב יד CUL: T-S F7.5
Rambam Mishneh Torah MS CUL T-S F76	רמב\"ם כתב יד CUL: T-S F7.6
Rambam Mishneh Torah MS CUL T-S F77	רמב\"ם כתב יד CUL: T-S F7.7
Rambam Mishneh Torah MS CUL T-S F78	רמב\"ם כתב יד CUL: T-S F7.8
Rambam Mishneh Torah MS CUL T-S F79	רמב\"ם כתב יד CUL: T-S F7.9
Rambam Mishneh Torah MS CUL T-S F710	רמב\"ם כתב יד CUL: T-S F7.10
Rambam Mishneh Torah MS CUL T-S F711	רמב\"ם כתב יד CUL: T-S F7.11
Rambam Mishneh Torah MS CUL T-S F712	רמב\"ם כתב יד CUL: T-S F7.12
Rambam Mishneh Torah MS CUL T-S F713	רמב\"ם כתב יד CUL: T-S F7.13
Rambam Mishneh Torah MS CUL T-S F714	רמב\"ם כתב יד CUL: T-S F7.14
Rambam Mishneh Torah MS CUL T-S F716	רמב\"ם כתב יד CUL: T-S F7.16
Rambam Mishneh Torah MS CUL T-S F717	רמב\"ם כתב יד CUL: T-S F7.17
Rambam Mishneh Torah MS CUL T-S F718	רמב\"ם כתב יד CUL: T-S F7.18
Rambam Mishneh Torah MS CUL T-S F719	רמב\"ם כתב יד CUL: T-S F7.19
Rambam Mishneh Torah MS CUL T-S F721	רמב\"ם כתב יד CUL: T-S F7.21
Rambam Mishneh Torah MS CUL T-S F722	רמב\"ם כתב יד CUL: T-S F7.22
Rambam Mishneh Torah MS CUL T-S F723	רמב\"ם כתב יד CUL: T-S F7.23
Rambam Mishneh Torah MS CUL T-S F724	רמב\"ם כתב יד CUL: T-S F7.24
Rambam Mishneh Torah MS CUL T-S F725	רמב\"ם כתב יד CUL: T-S F7.25
Rambam Mishneh Torah MS CUL T-S F726	רמב\"ם כתב יד CUL: T-S F7.26
Rambam Mishneh Torah MS CUL T-S F727	רמב\"ם כתב יד CUL: T-S F7.27
Rambam Mishneh Torah MS CUL T-S F728	רמב\"ם כתב יד CUL: T-S F7.28
Rambam Mishneh Torah MS CUL T-S F729	רמב\"ם כתב יד CUL: T-S F7.29
Rambam Mishneh Torah MS CUL T-S F730	רמב\"ם כתב יד CUL: T-S F7.30
Rambam Mishneh Torah MS CUL T-S F731	רמב\"ם כתב יד CUL: T-S F7.31
Rambam Mishneh Torah MS CUL T-S F732	רמב\"ם כתב יד CUL: T-S F7.32
Rambam Mishneh Torah MS CUL T-S F733	רמב\"ם כתב יד CUL: T-S F7.33
Rambam Mishneh Torah MS CUL T-S F734	רמב\"ם כתב יד CUL: T-S F7.34
Rambam Mishneh Torah MS CUL T-S F736	רמב\"ם כתב יד CUL: T-S F7.36
Rambam Mishneh Torah MS CUL T-S F737	רמב\"ם כתב יד CUL: T-S F7.37
Rambam Mishneh Torah MS CUL T-S F738	רמב\"ם כתב יד CUL: T-S F7.38
Rambam Mishneh Torah MS CUL T-S F739	רמב\"ם כתב יד CUL: T-S F7.39
Rambam Mishneh Torah MS CUL T-S F740	רמב\"ם כתב יד CUL: T-S F7.40
Rambam Mishneh Torah MS CUL T-S F741	רמב\"ם כתב יד CUL: T-S F7.41
Rambam Mishneh Torah MS CUL T-S F742	רמב\"ם כתב יד CUL: T-S F7.42
Rambam Mishneh Torah MS CUL T-S F744	רמב\"ם כתב יד CUL: T-S F7.44
Rambam Mishneh Torah MS CUL T-S F745	רמב\"ם כתב יד CUL: T-S F7.45
Rambam Mishneh Torah MS CUL T-S F747	רמב\"ם כתב יד CUL: T-S F7.47
Rambam Mishneh Torah MS CUL T-S F749	רמב\"ם כתב יד CUL: T-S F7.49
Rambam Mishneh Torah MS CUL T-S F750	רמב\"ם כתב יד CUL: T-S F7.50
Rambam Mishneh Torah MS CUL T-S F751	רמב\"ם כתב יד CUL: T-S F7.51
Rambam Mishneh Torah MS CUL T-S F752	רמב\"ם כתב יד CUL: T-S F7.52
Rambam Mishneh Torah MS CUL T-S F753	רמב\"ם כתב יד CUL: T-S F7.53
Rambam Mishneh Torah MS CUL T-S F754	רמב\"ם כתב יד CUL: T-S F7.54
Rambam Mishneh Torah MS CUL T-S F756	רמב\"ם כתב יד CUL: T-S F7.56
Rambam Mishneh Torah MS CUL T-S F757	רמב\"ם כתב יד CUL: T-S F7.57
Rambam Mishneh Torah MS CUL T-S F759	רמב\"ם כתב יד CUL: T-S F7.59
Rambam Mishneh Torah MS CUL T-S F760	רמב\"ם כתב יד CUL: T-S F7.60
Rambam Mishneh Torah MS CUL T-S F761	רמב\"ם כתב יד CUL: T-S F7.61
Rambam Mishneh Torah MS CUL T-S F762	רמב\"ם כתב יד CUL: T-S F7.62
Rambam Mishneh Torah MS CUL T-S F763	רמב\"ם כתב יד CUL: T-S F7.63
Rambam Mishneh Torah MS CUL T-S F766	רמב\"ם כתב יד CUL: T-S F7.66
Rambam Mishneh Torah MS CUL T-S F767	רמב\"ם כתב יד CUL: T-S F7.67
Rambam Mishneh Torah MS CUL T-S F770	רמב\"ם כתב יד CUL: T-S F7.70
Rambam Mishneh Torah MS CUL T-S F771	רמב\"ם כתב יד CUL: T-S F7.71
Rambam Mishneh Torah MS CUL T-S F772	רמב\"ם כתב יד CUL: T-S F7.72
Rambam Mishneh Torah MS CUL T-S F773	רמב\"ם כתב יד CUL: T-S F7.73
Rambam Mishneh Torah MS CUL T-S F774	רמב\"ם כתב יד CUL: T-S F7.74
Rambam Mishneh Torah MS CUL T-S F775	רמב\"ם כתב יד CUL: T-S F7.75
Rambam Mishneh Torah MS CUL T-S F777	רמב\"ם כתב יד CUL: T-S F7.77
Rambam Mishneh Torah MS CUL T-S F778	רמב\"ם כתב יד CUL: T-S F7.78
Rambam Mishneh Torah MS CUL T-S F780	רמב\"ם כתב יד CUL: T-S F7.80
Rambam Mishneh Torah MS CUL T-S F781	רמב\"ם כתב יד CUL: T-S F7.81
Rambam Mishneh Torah MS CUL T-S F785	רמב\"ם כתב יד CUL: T-S F7.85
Rambam Mishneh Torah MS CUL T-S F786	רמב\"ם כתב יד CUL: T-S F7.86
Rambam Mishneh Torah MS CUL T-S F787	רמב\"ם כתב יד CUL: T-S F7.87
Rambam Mishneh Torah MS CUL T-S F788	רמב\"ם כתב יד CUL: T-S F7.88
Rambam Mishneh Torah MS CUL T-S F789	רמב\"ם כתב יד CUL: T-S F7.89
Rambam Mishneh Torah MS CUL T-S F790	רמב\"ם כתב יד CUL: T-S F7.90
Rambam Mishneh Torah MS CUL T-S F791	רמב\"ם כתב יד CUL: T-S F7.91
Rambam Mishneh Torah MS CUL T-S F792	רמב\"ם כתב יד CUL: T-S F7.92
Rambam Mishneh Torah MS CUL T-S F793	רמב\"ם כתב יד CUL: T-S F7.93
Rambam Mishneh Torah MS CUL T-S F794	רמב\"ם כתב יד CUL: T-S F7.94
Rambam Mishneh Torah MS CUL T-S F796	רמב\"ם כתב יד CUL: T-S F7.96
Rambam Mishneh Torah MS CUL T-S F797	רמב\"ם כתב יד CUL: T-S F7.97
Rambam Mishneh Torah MS CUL T-S F798	רמב\"ם כתב יד CUL: T-S F7.98
Rambam Mishneh Torah MS CUL T-S F799	רמב\"ם כתב יד CUL: T-S F7.99
Rambam Mishneh Torah MS CUL T-S F7101	רמב\"ם כתב יד CUL: T-S F7.101
Rambam Mishneh Torah MS CUL T-S F7102	רמב\"ם כתב יד CUL: T-S F7.102
Rambam Mishneh Torah MS CUL T-S F7103	רמב\"ם כתב יד CUL: T-S F7.103
Rambam Mishneh Torah MS CUL T-S F7104	רמב\"ם כתב יד CUL: T-S F7.104
Rambam Mishneh Torah MS CUL T-S F7105	רמב\"ם כתב יד CUL: T-S F7.105
Rambam Mishneh Torah MS CUL T-S F7106	רמב\"ם כתב יד CUL: T-S F7.106
Rambam Mishneh Torah MS CUL T-S F7107	רמב\"ם כתב יד CUL: T-S F7.107
Rambam Mishneh Torah MS CUL T-S F7109	רמב\"ם כתב יד CUL: T-S F7.109
Rambam Mishneh Torah MS CUL T-S F7110	רמב\"ם כתב יד CUL: T-S F7.110
Rambam Mishneh Torah MS CUL T-S F7111	רמב\"ם כתב יד CUL: T-S F7.111
Rambam Mishneh Torah MS CUL T-S F7112	רמב\"ם כתב יד CUL: T-S F7.112
Rambam Mishneh Torah MS CUL T-S F7114	רמב\"ם כתב יד CUL: T-S F7.114
Rambam Mishneh Torah MS CUL T-S F7115	רמב\"ם כתב יד CUL: T-S F7.115
Rambam Mishneh Torah MS CUL T-S F7116	רמב\"ם כתב יד CUL: T-S F7.116
Rambam Mishneh Torah MS CUL T-S F814	רמב\"ם כתב יד CUL: T-S F8.14
Rambam Mishneh Torah MS CUL T-S F823	רמב\"ם כתב יד CUL: T-S F8.23
Rambam Mishneh Torah MS CUL T-S F827	רמב\"ם כתב יד CUL: T-S F8.27
Rambam Mishneh Torah MS CUL T-S F836	רמב\"ם כתב יד CUL: T-S F8.36
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI66	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.66
Rambam Mishneh Torah MS CUL T-S F8117	רמב\"ם כתב יד CUL: T-S F8.117
Rambam Mishneh Torah MS CUL T-S F8135	רמב\"ם כתב יד CUL: T-S F8.135
Rambam Mishneh Torah MS CUL T-S F8139	רמב\"ם כתב יד CUL: T-S F8.139
Rambam Mishneh Torah MS CUL T-S F918	רמב\"ם כתב יד CUL: T-S F9.18
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI72	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.72
Rambam Mishneh Torah MS CUL T-S F958	רמב\"ם כתב יד CUL: T-S F9.58
Rambam Mishneh Torah MS CUL T-S F963	רמב\"ם כתב יד CUL: T-S F9.63
Rambam Mishneh Torah MS CUL T-S F991	רמב\"ם כתב יד CUL: T-S F9.91
Rambam Mishneh Torah MS CUL T-S F998	רמב\"ם כתב יד CUL: T-S F9.98
Rambam Mishneh Torah MS CUL T-S F9109	רמב\"ם כתב יד CUL: T-S F9.109
Rambam Mishneh Torah MS CUL T-S F9143	רמב\"ם כתב יד CUL: T-S F9.143
Rambam Mishneh Torah MS CUL T-S F9146	רמב\"ם כתב יד CUL: T-S F9.146
Rambam Mishneh Torah MS CUL T-S Misc1436a CUL T-S M	רמב\"ם כתב יד CUL: T-S Misc.14.36a + CUL: T-S Misc.14.39.2 + CUL: T-S NS 325.2e
Rambam Mishneh Torah MS Oxford MS heb d5466	רמב\"ם כתב יד Oxford: MS heb. d.54/66
Rambam Mishneh Torah MS CUL T-S F1055	רמב\"ם כתב יד CUL: T-S F10.55
Rambam Mishneh Torah MS Oxford MS heb d5467	רמב\"ם כתב יד Oxford: MS heb. d.54/67
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI95	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.95
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI98	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.98
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI100	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.100
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI101	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.101
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI104	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.104
Rambam Mishneh Torah MS CUL T-S F1457	רמב\"ם כתב יד CUL: T-S F14.57
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmI108	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.I.108
Rambam Mishneh Torah MS CUL T-S F1466	רמב\"ם כתב יד CUL: T-S F14.66
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII25	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.25
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII26	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.26
Rambam Mishneh Torah MS CUL T-S G2147	רמב\"ם כתב יד CUL: T-S G2.147
Rambam Mishneh Torah MS AIU IIB231	רמב\"ם כתב יד AIU: II.B.231
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII40	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.40
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII51	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.51
Rambam Mishneh Torah MS CUL T-S H53	רמב\"ם כתב יד CUL: T-S H5.3
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII68 L	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.68 + Lewis-Gibson: L-G Talm.II.73
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII80	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.80
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII84	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.84
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII85	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.85
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII86	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.86
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII87	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.87
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII88	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.88
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII89	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.89
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII90	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.90
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII91	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.91
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII96	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.96
Rambam Mishneh Torah MS Mosseri Moss I61 Private	רמב\"ם כתב יד Mosseri: Moss. I,6.1 (Private)
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII108	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.108
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII116	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.116
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII118	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.118
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII123	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.123
Rambam Mishneh Torah MS Oxford MS heb d7630	רמב\"ם כתב יד Oxford: MS heb. d.76/30
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII421	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.42.1
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII441	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.44.1
Rambam Mishneh Torah MS Oxford MS heb d8031	רמב\"ם כתב יד Oxford: MS heb. d.80/31
Rambam Mishneh Torah MS Oxford MS heb d8128	רמב\"ם כתב יד Oxford: MS heb. d.81/28
Rambam Mishneh Torah MS Oxford MS heb d8129	רמב\"ם כתב יד Oxford: MS heb. d.81/29
Rambam Mishneh Torah MS Oxford MS heb d8130	רמב\"ם כתב יד Oxford: MS heb. d.81/30
Rambam Mishneh Torah MS Oxford MS heb d8131	רמב\"ם כתב יד Oxford: MS heb. d.81/31
Rambam Mishneh Torah MS Oxford MS heb d8132	רמב\"ם כתב יד Oxford: MS heb. d.81/32
Rambam Mishneh Torah MS Oxford MS heb d8133	רמב\"ם כתב יד Oxford: MS heb. d.81/33
Rambam Mishneh Torah MS Oxford MS heb d8134	רמב\"ם כתב יד Oxford: MS heb. d.81/34
Rambam Mishneh Torah MS Oxford MS heb d8135	רמב\"ם כתב יד Oxford: MS heb. d.81/35
Rambam Mishneh Torah MS Oxford MS heb d8136	רמב\"ם כתב יד Oxford: MS heb. d.81/36
Rambam Mishneh Torah MS Oxford MS heb d8137	רמב\"ם כתב יד Oxford: MS heb. d.81/37
Rambam Mishneh Torah MS Oxford MS heb d8138	רמב\"ם כתב יד Oxford: MS heb. d.81/38
Rambam Mishneh Torah MS Oxford MS heb d8139	רמב\"ם כתב יד Oxford: MS heb. d.81/39
Rambam Mishneh Torah MS Oxford MS heb d8140	רמב\"ם כתב יד Oxford: MS heb. d.81/40
Rambam Mishneh Torah MS Oxford MS heb d8141	רמב\"ם כתב יד Oxford: MS heb. d.81/41
Rambam Mishneh Torah MS Oxford MS heb d8142	רמב\"ם כתב יד Oxford: MS heb. d.81/42
Rambam Mishneh Torah MS Oxford MS heb d8143	רמב\"ם כתב יד Oxford: MS heb. d.81/43
Rambam Mishneh Torah MS AIU IIIA26	רמב\"ם כתב יד AIU: III.A.26
Rambam Mishneh Torah MS AIU IIIA30	רמב\"ם כתב יד AIU: III.A.30
Rambam Mishneh Torah MS BL OR 5558L41 BL OR 5558L42	רמב\"ם כתב יד BL: OR 5558L.41 + BL: OR 5558L.42 + CUL: T-S AS 83.46
Rambam Mishneh Torah MS Lewis-Gibson L-G TalmII72	רמב\"ם כתב יד Lewis-Gibson: L-G Talm.II.7.2
Rambam Mishneh Torah MS AIU IIIA67	רמב\"ם כתב יד AIU: III.A.67
Rambam Mishneh Torah MS Mosseri Moss III243 Private	רמב\"ם כתב יד Mosseri: Moss. III,24.3 (Private)
Rambam Mishneh Torah MS Mosseri Moss I282 Private C	רמב\"ם כתב יד Mosseri: Moss. I,28.2 (Private) + CUL: T-S AS 93.230
Rambam Mishneh Torah MS Mosseri Moss VI1631 Private	רמב\"ם כתב יד Mosseri: Moss. VI,163.1 (Private) + CUL: T-S AS 93.377
Rambam Mishneh Torah MS AIU IIIA96	רמב\"ם כתב יד AIU: III.A.96
Rambam Mishneh Torah MS CUL T-S E2121 CUL T-S F7108	רמב\"ם כתב יד CUL: T-S E2.121 + CUL: T-S F7.108 + CUL: T-S AS 94.309
Rambam Mishneh Torah MS AIU IIIA97	רמב\"ם כתב יד AIU: III.A.97
Rambam Mishneh Torah MS BL OR 10578R128 CUL T-S AS	רמב\"ם כתב יד BL: OR 10578R.128 + CUL: T-S AS 99.55
Rambam Mishneh Torah MS AIU IIIA105	רמב\"ם כתב יד AIU: III.A.105
Rambam Mishneh Torah MS AIU IIIB4	רמב\"ם כתב יד AIU: III.B.4
Rambam Mishneh Torah MS CUL T-S K6137	רמב\"ם כתב יד CUL: T-S K6.137
Rambam Mishneh Torah MS AIU IIIB9	רמב\"ם כתב יד AIU: III.B.9
Rambam Mishneh Torah MS CUL T-S K6185	רמב\"ם כתב יד CUL: T-S K6.185
Rambam Mishneh Torah MS CUL T-S K6191	רמב\"ם כתב יד CUL: T-S K6.191
Rambam Mishneh Torah MS Mosseri Moss III53 Private	רמב\"ם כתב יד Mosseri: Moss. III,53 (Private)
Rambam Mishneh Torah MS AIU IIIB17	רמב\"ם כתב יד AIU: III.B.17
Rambam Mishneh Torah MS AIU IIIB23	רמב\"ם כתב יד AIU: III.B.23
Rambam Mishneh Torah MS AIU IIIB25	רמב\"ם כתב יד AIU: III.B.25
Rambam Mishneh Torah MS AIU IIIB32	רמב\"ם כתב יד AIU: III.B.32
Rambam Mishneh Torah MS AIU IIIB34	רמב\"ם כתב יד AIU: III.B.34
Rambam Mishneh Torah MS AIU IIIB35	רמב\"ם כתב יד AIU: III.B.35
Rambam Mishneh Torah MS AIU IIIB36	רמב\"ם כתב יד AIU: III.B.36
Rambam Mishneh Torah MS CUL T-S K1122	רמב\"ם כתב יד CUL: T-S K11.22
Rambam Mishneh Torah MS AIU IIIB37	רמב\"ם כתב יד AIU: III.B.37
Rambam Mishneh Torah MS AIU IIIB38	רמב\"ם כתב יד AIU: III.B.38
Rambam Mishneh Torah MS AIU IIIB39	רמב\"ם כתב יד AIU: III.B.39
Rambam Mishneh Torah MS AIU IIIB40	רמב\"ם כתב יד AIU: III.B.40
Rambam Mishneh Torah MS AIU IIIB43	רמב\"ם כתב יד AIU: III.B.43
Rambam Mishneh Torah MS Lewis-Gibson L-G LitI176	רמב\"ם כתב יד Lewis-Gibson: L-G Lit.I.176
Rambam Mishneh Torah MS Mosseri Moss III721 Private	רמב\"ם כתב יד Mosseri: Moss. III,72.1 (Private)
Rambam Mishneh Torah MS Mosseri Moss III74 Private	רמב\"ם כתב יד Mosseri: Moss. III,74 (Private)
Rambam Mishneh Torah MS AIU IIIB56	רמב\"ם כתב יד AIU: III.B.56
Rambam Mishneh Torah MS AIU XI105	רמב\"ם כתב יד AIU: XI.105
Rambam Mishneh Torah MS CUL T-S H881	רמב\"ם כתב יד CUL: T-S H8.81
Rambam Mishneh Torah MS Mosseri Moss III1462 Privat	רמב\"ם כתב יד Mosseri: Moss. III,146.2 (Private)
Rambam Mishneh Torah MS Mosseri Moss III1461 Privat	רמב\"ם כתב יד Mosseri: Moss. III,146.1 (Private)
Rambam Mishneh Torah MS CUL T-S NS 31731e JTS ENA N	רמב\"ם כתב יד CUL: T-S NS 317.31e + JTS: ENA NS 76.385.1
Rambam Mishneh Torah MS Oxford MS heb d227	רמב\"ם כתב יד Oxford: MS heb. d.22/7
Rambam Mishneh Torah MS Oxford MS Heb c724	רמב\"ם כתב יד Oxford: MS Heb. c.72/4
Rambam Mishneh Torah MS Oxford MS Heb c725	רמב\"ם כתב יד Oxford: MS Heb. c.72/5
Rambam Mishneh Torah MS CUL T-S F898	רמב\"ם כתב יד CUL: T-S F8.98
Rambam Mishneh Torah MS CUL T-S Misc20128 CUL T-S A	רמב\"ם כתב יד CUL: T-S Misc.20.128 + CUL: T-S AS 214.287
Rambam Mishneh Torah MS CUL T-S 18k14	רמב\"ם כתב יד CUL: T-S 18k1.4
Rambam Mishneh Torah MS JTS ENA 257218c	רמב\"ם כתב יד JTS: ENA 2572.18c
Rambam Printing Warsaw-Vilna	רמב\"ם דפוס ורשה-וילנה
Rambam Mishneh Torah Printing Warsaw-Vilna	רמב\"ם דפוס ורשה-וילנה
Rambam Printing Rav Kapach	רמב\"ם דפוס הרב קאפח
Rambam Mishneh Torah Printing Rav Kapach	רמב\"ם דפוס הרב קאפח
Rambam Printing Rav Sheilat	רמב\"ם דפוס הרב שילת
Rambam Mishneh Torah Printing Rav Sheilat	רמב\"ם דפוס הרב שילת
Responsa of Rambam Related to Mishneh Torah	תשובות הרמב\"ם הקשורות למשנה תורה
Moreh Nevukhim	מורה נבוכים
Guide to the Perplexed	מורה נבוכים
Moreh Nevuchim	מורה נבוכים
More Nevukhim	מורה נבוכים
More Nevuchim	מורה נבוכים
Moreh Nevokhim	מורה נבוכים
Moreh Nevochim	מורה נבוכים
Moreh Nevukhim Ibn Tibbon	מורה נבוכים
Moreh Nevukhim Schwartz Edition	מורה נבוכים מהדורת שוורץ
Moreh Nevukhim Mifal Mishneh Torah	מורה נבוכים מפעל משנה תורה
Milot HaHigayon	מלות ההגיון
Likkut	ליקוט
Rambam Likkut	ליקוט
Teshuvot HaRambam	תשובות הרמב\"ם
R. Moshe HaKohen	ר' משה הכהן
Hagahot HaRamakh	הגהות הרמ\"ך
R. Yehuda Almadari	ר' יהודה אלמדארי
Raavyah	ראבי\"ה
R. Elchanan b. Ri HaZaken	ר' אלחנן בן ר\"י הזקן
Tosefot R. Elchanan	תוספות ר' אלחנן
Tosafot R. Elchanan	תוספות ר' אלחנן
R. Shimshon of Sens	ר\"ש משאנץ
Tosefot R. Shimshon of Sens	תוספות ר\"ש משאנץ
Tosafot R. Shimshon of Sens	תוספות ר\"ש משאנץ
Tosafot	תוספות
Ba'alei HaTosafot	תוספות
Baalei HaTosafot	תוספות
Tosafos	תוספות
Tosefot	תוספות
Tosfos	תוספות
Baalei HaTosafos	תוספות
Baalei HaTosfos	תוספות
Tosefot Yeshanim	תוספות ישנים
Tosafot Yeshanim	תוספות ישנים
R. Yehuda HeChasid	ר' יהודה החסיד
R. Judah the Chasid	ר' יהודה החסיד
R. Yehudah HeChasid	ר' יהודה החסיד
R. Yehuda HaChasid	ר' יהודה החסיד
Sefer Chasidim	ספר חסידים
R. Yehuda b. Yakar	ר' יהודה בר יקר
R. Avraham b. Natan of Lunel	ר' אברהם בן נתן הירחי
HaManhig	המנהיג
Radak	רד\"ק
R. David Kimhi	רד\"ק
Esoteric Commentary	פירוש הנסתר
Radak Esoteric Commentary	פירוש הנסתר
Allegorical Commentary	פירוש הנסתר
Sefer HaShorashim LeRadak	ספר השרשים לרד\"ק
SHS LeRadak	ספר השרשים לרד\"ק
R. Avraham b. Azriel	ר' אברהם בן עזריאל
Arugat HaBosem	ערוגת הבשם
R. Elazar HaRokeach	ר' אלעזר הרוקח
HaRokeach	ר' אלעזר הרוקח
Rokeach	ר' אלעזר הרוקח
Sefer HaRokeach	ספר הרוקח
Rid	רי\"ד
R. Yeshaya of Trani	רי\"ד
R. Yeshayah MiTrani	רי\"ד
R. Yeshaya MiTrani	רי\"ד
R. Isaiah of Trani	רי\"ד
Tosefot Rid	תוספות רי\"ד
Tosafot Rid	תוספות רי\"ד
Tosefot Rid Second Recension	תוספות רי\"ד מהדורה תנינא
Tosafot Rid Second Recension	תוספות רי\"ד מהדורה תנינא
Tosefot Rid Third Recension	תוספות רי\"ד מהדורה תליתאה
Tosafot Rid Third Recension	תוספות רי\"ד מהדורה תליתאה
Tosefot Rid Fourth Recension	תוספות רי\"ד מהדורה רביעאה
Tosafot Rid Fourth Recension	תוספות רי\"ד מהדורה רביעאה
Piskei Rid	פסקי רי\"ד
Piskei HaRid	פסקי רי\"ד
Sefer HaMakhria	ספר המכריע
R. Yehuda of Paris	ר' יהודה שירליאון
Tosefot R. Yehuda SirLeon	תוספות ר' יהודה שירליאון
Tosafot R. Yehuda SirLeon	תוספות ר' יהודה שירליאון
Tosefot R. Yehuda	תוספות ר' יהודה שירליאון
R. Asher b. Shaul of Lunel	ר' אשר בן שאול מלוניל
Sefer HaMinhagot	ספר המנהגות
R. Barukh b. Yitzchak of Worms	ר' ברוך בן יצחק מורמייזא
R. Barukh b. Yitzchak	ר' ברוך בן יצחק מורמייזא
Sefer HaTerumah	ספר התרומה
Hilkhot Eretz Yisrael	הלכות ארץ ישראל
Ramah	רמ\"ה
HaHashlamah	ההשלמה
Sefer HaHashlamah	ההשלמה
R. Yitzchak b. Moshe of Vienna	ר' יצחק בן משה מוינא
Or Zarua	אור זרוע
Ohr Zarua	אור זרוע
R. Yonah	ר' יונה
R. Yonah Gerondi	ר' יונה
R. Yona b. Avraham Gerondi	ר' יונה
R. Yona	ר' יונה
R. Yona Gerondi	ר' יונה
Talmidei R. Yonah	תלמידי ר' יונה
Talmidei R. Yonah on Rif	תלמידי ר' יונה על רי\"ף
R. Yonah Shaarei Teshuvah	שערי תשובה לר' יונה
Sefer HaYirah	ספר היראה
R. Avraham b. HaRambam	ר' אברהם בן הרמב\"ם
R. Avraham Maimonides	ר' אברהם בן הרמב\"ם
R. Abraham b. HaRambam	ר' אברהם בן הרמב\"ם
R. Abraham Maimonides	ר' אברהם בן הרמב\"ם
Birkat Avraham	ברכת אברהם
Birkat Avraham on Mishneh Torah	ברכת אברהם על משנה תורה
Responsa of R. Avraham b. HaRambam on Mishneh Torah	תשובות ר' אברהם בן הרמב\"ם על משנה תורה
HaMaspik LeOvdei Hashem	המספיק לעובדי השם
Milchamot HaShem	מלחמות השם
R. Avraham b. HaRambam Milchamot HaShem	מלחמות השם
R. Meir HaKohen of Saragossa	ר' מאיר הכהן מסרקסטה
HaMeorot	המאורות
Sefer HaMeorot	המאורות
Sefer HaGan	ספר הג\"ן
Likkut Munich-Oxford	ליקוט אוקספורד-מינכן
Munich-Oxford	ליקוט אוקספורד-מינכן
Chizkuni	חזקוני
Hizkuni	חזקוני
R. Hizkiyah b. Manoah	חזקוני
R. Hezekiah b. Manoah	חזקוני
R. Berekhyah HaNakdan	ר' ברכיה הנקדן
R. Berekhya HaNakdan	ר' ברכיה הנקדן
R. Shelomo of Montpellier	ר' שלמה מן ההר
R. Shelomo b. Avraham	ר' שלמה מן ההר
Pseudo-Rashi	פסאודו-רש\"י
Pseudo Rashi	פסאודו-רש\"י
Peshat Commentary	פירוש הפשט
Pseudo-Rashi Peshat Commentary	פירוש הפשט
Pseudo-Rashi Peshat	פירוש הפשט
Anonymous Northern French Commentary	פירוש מחכמי צרפת
Anonymous Northern French	פירוש מחכמי צרפת
Anonymous N. French	פירוש מחכמי צרפת
Collected Northern French Commentary	ליקוט מחכמי צרפת
Collected Northern French	ליקוט מחכמי צרפת
Collected N. French	ליקוט מחכמי צרפת
Paneach Raza	פענח רזא
Paneakh Raza	פענח רזא
Paneah Raza	פענח רזא
R. Isaac b. Judah	פענח רזא
Paneach Raza Second Commentary	פירוש שני
Kitzur Paneach Raza	קיצור פענח רזא
Kitzur Paneakh Raza	קיצור פענח רזא
Kitzur Paneah Raza	קיצור פענח רזא
R. Shemuel HaSardi	ר' שמואל הסרדי
Sefer HaTerumot	ספר התרומות
R. Yechiel of Paris	ר' יחיאל מפריז
R. Yehiel of Paris	ר' יחיאל מפריז
R. Moshe of London	ר' משה מלונדריש
Tosefot R. Moshe of London	תוספות ר' משה מלונדריש
Ramban	רמב\"ן
R. Moshe b. Nachman	רמב\"ן
R. Moshe b. Nahman	רמב\"ן
R. Moses Nachmanides	רמב\"ן
R. Moses Nahmanides	רמב\"ן
Nachmanides	רמב\"ן
Nahmanides	רמב\"ן
Ramban Lexical Commentary	פירוש המלים
Hilkhot Nedarim LaRamban	הלכות נדרים לרמב\"ן
Ramban Milchamot HaShem	מלחמות ה'
Milchamot	מלחמות ה'
Milchamos	מלחמות ה'
Milchamos HaShem	מלחמות ה'
Ramban Milchamot HaShem Rif	מלחמות ה'
Ramban Sefer HaZekhut	ספר הזכות לרמב\"ן
Sefer HaZekhut	ספר הזכות לרמב\"ן
Sefer HaZechut	ספר הזכות לרמב\"ן
Derashot	דרשות
Ramban Derashot	דרשות
Sefer HaGeulah	ספר הגאולה
Ramban Sefer HaGeulah	ספר הגאולה
Sefer HaVikuach	ספר הוויכוח
Ramban Sefer HaVikuach	ספר הוויכוח
Hasagot Ramban Sefer HaMitzvot	השגות רמב\"ן לספר המצוות
Hasagot Ramban Sefer HaMitzvot Introduction	הקדמה
Hasagot Ramban Sefer HaMitzvot Principles	שרשים
Hasagot Ramban Sefer HaMitzvot Positive Commandments	מצוות עשה
Forgotten Positive Commandments	מצוות עשה ששכחן
Hasagot Ramban Sefer HaMitzvot Forgotten Positive Commandments	מצוות עשה ששכחן
Hasagot Ramban Sefer HaMitzvot Negative Commandments	מצוות לא תעשה
Forgotten Negative Commandments	מצוות לא תעשה ששכחן
Hasagot Ramban Sefer HaMitzvot Forgotten Negative Commandments	מצוות לא תעשה ששכחן
Conclusion	סיום
Hasagot Ramban Sefer HaMitzvot Conclusion	סיום
Hilkhot Bekhorot LaRamban	הלכות בכורות לרמב\"ן
Hilkhot Niddah LaRamban	הלכות נדה לרמב\"ן
Torat HaAdam	תורת האדם
Derashah LeRosh HaShanah	דרשה לראש השנה
Dina DeGarmei	דינא דגרמי
Mishpat HaCherem	משפט החרם
R. Chaim Eliezer b. Yitzchak of Vienna	ר' חיים אליעזר בן יצחק מוינא
Teshuvot Maharach Or Zarua	תשובות מהר\"ח אור זרוע
R. Avigdor Kohen Tzedek	ר' אביגדור כהן צדק
R. Avigdor Kohen Zedek	ר' אביגדור כהן צדק
Semag	סמ\"ג
Smag	סמ\"ג
Semag Introduction	הקדמה
Semag Positive Commandments	מצוות עשה
Rabbinic Positive Commandments	מצוות עשה מדרבנן
Semag Rabbinic Positive Commandments	מצוות עשה מדרבנן
Semag Negative Commandments	מצוות לא תעשה
Semak	סמ\"ק
Smak	סמ\"ק
Maharam of Rothenburg	מהר\"ם מרוטנברג
Teshuvot Maharam	תשובות מהר\"ם
Cremona Printing	דפוס קרימונה
Teshuvot Maharam Cremona	דפוס קרימונה
Lemberg Printing	דפוס לבוב
Teshuvot Maharam Lemberg	דפוס לבוב
Prague Printing	דפוס פראג
Teshuvot Maharam Prague	דפוס פראג
Berlin Printing – MS Parma	דפוס ברלין – כ\"י פרמא
Teshuvot Maharam Berlin MS Parma	דפוס ברלין – כ\"י פרמא
Berlin Printing – MS Amsterdam	דפוס ברלין – כ\"י אמסטרדם
Teshuvot Maharam Berlin MS Amsterdam	דפוס ברלין – כ\"י אמסטרדם
Berlin Printing – MS Prague	דפוס ברלין – כ\"י פראג
Teshuvot Maharam Berlin MS Prague	דפוס ברלין – כ\"י פראג
R. Meir b. Yekutiel	ר' מאיר בן יקותיאל
Hagahot Maimoniyot	הגהות מיימוניות
R. Eliezer of Tukh	ר' אליעזר מטוך
Tosefot Tukh	תוספות טוך
Tosafot Tukh	תוספות טוך
Sefer HaMenuchah	ספר המנוחה
Zohar	זוהר
Zohar Chadash	זוהר החדש
Yalkut Shimoni	ילקוט שמעוני
R. Natan b. Yehuda	ר' נתן בר יהודה
Sefer HaMachkim	ספר המחכים
HaMachkim	ספר המחכים
R. Menachem b. Yosef Chazan of Troyes	ר' מנחם בר יוסף חזן מטרוייש
Seder Troyes	סדר טרוייש
R. Moshe b. Sheneur of Evreux	ר' משה בר שניאור מאיוורא
Tosefot Evreux	תוספות איוורא
Tosafot Evreux	תוספות איוורא
R. Shemuel b. Sheneur of Evreux	ר' שמואל בר שניאור מאיוורא
R. Elazar b. Matityah	ר' אלעזר בן מתתיה
R. Yeshayah b. Meir	ר' ישעיה בן מאיר
Avvat Nefesh	אות נפש
R. Moshe b. Yehuda Min HaNearim	ר' משה בן יהודה מן הנערים
Even HaEzer leR. Yehuda Mosconi	אבן העזר לר' יהודה משקוני
Even HaEzer leR. Yehuda Leon b. Moshe	אבן העזר לר' יהודה משקוני
Tzafenat Paneach (Bonfils)	צפנת פענח לר' יוסף טוב עלם
R. Reuven b. Chayyim	ר' ראובן בן חיים
Sefer HaTamid	ר' ראובן בן חיים
Rivevan	ריבב\"ן
R. Binyamin b. Avraham HaRofe Anav	ר' בנימין בן אברהם הרופא ענו
R. Zidkiyah b. Avraham Anav	ר' צדקיה בן אברהם ענו
Shibbolei HaLeket	שבלי הלקט
Haggadat Shibbolei HaLeket	הגדת שבלי הלקט
R. Yeshayah the Younger	ר' ישעיה אחרון
Piskei Riaz	פסקי ריא\"ז
R. Peretz	ר' פרץ
Tosefot R. Peretz	תוספות רבנו פרץ
Hagahot R. Peretz on Semak	הגהות ר' פרץ על הסמ\"ק
Mordekhai	מרדכי
Mordechai	מרדכי
R. Zerachyah b. Yitzchak b. Shealtiel	ר' זרחיה בן יצחק בן שאלתיאל
R. Zerachyah b. Shealtiel	ר' זרחיה בן יצחק בן שאלתיאל
R. Tanchum HaYerushalmi	ר' תנחום הירושלמי
R. Tanhum HaYerushalmi	ר' תנחום הירושלמי
R. Tanchum HaYerushalmi Second Commentary	פירוש שני
R. Yishmael b. Chakhmon	ר' ישמעאל בן חכמון
R. David Bonafed	ר' דוד בונפיד
R. David Bonfils	ר' דוד בונפיד
R. David Bonfil	ר' דוד בונפיד
R. Yitzchak of Carcassonne	ר' יצחק קרקושא
Rashba	רשב\"א
R. Shlomo b. Aderet	רשב\"א
R. Solomon b. Aderet	רשב\"א
R. Shlomo b. Adret	רשב\"א
R. Solomon b. Adret	רשב\"א
Piskei Challah	פסקי חלה
Avodat HaKodesh	עבודת הקודש
Torat HaBayit HaArokh	תורת הבית הארוך
Torat HaBayit HaKatzar	תורת הבית הקצר
Mishmeret HaBayit	משמרת הבית
Shaar HaMayim HaArokh	שער המים הארוך
Shaar HaMayim HaKatzar	שער המים הקצר
Teshuvot HaRashba	תשובות הרשב\"א
HaMeyuchasot LaRamban	המיוחסות לרמב\"ן
Teshuvot HaRashba HaMeyuchasot LaRamban	המיוחסות לרמב\"ן
Raah	רא\"ה
R. Aharon b. Yosef HaLevi	רא\"ה
R. Aharon of Barcelona	רא\"ה
Bedek HaBayit	בדק הבית
R. Shimshon b. Tzadok	ר' שמשון בן צדוק
Piskei Tashbetz	פסקי תשב\"ץ
HaMikhtam	המכתם
Mikhtam	המכתם
Meiri	מאירי
HaMeiri	מאירי
R. Menahem HaMeiri	מאירי
Chidushei HaMeiri	חידושי המאירי
Sefer HaChinukh	ספר החינוך
Sefer HaChinnukh	ספר החינוך
Sefer HaChinuch	ספר החינוך
Sefer HaChinnuch	ספר החינוך
R. Avraham of Montpellier	ר' אברהם מן ההר
R. Avraham of Montpelier	ר' אברהם מן ההר
R. Moshe Parnas of Rothenburg	ר' משה פרנס מרוטנברג
Sefer HaParnas	ספר הפרנס
R. Yitzchak of Dura	ר' יצחק מדורא
Shaarei Dura	שערי דורא
R. Shemuel b. Meshulam	ר' שמואל בן משולם גירונדי
Ohel Moed	אהל מועד
R. Yehoshua ibn Shuib	ר' יהושע אבן שועיב
Ibn Shuib	ר' יהושע אבן שועיב
R. Joshua Ibn Shuib	ר' יהושע אבן שועיב
R. Menachem b. Binyamin Recanati	ר' מנחם בן בנימין רקנטי
R. Menahem b. Binyamin Recanati	ר' מנחם בן בנימין רקנטי
Piskei Recanati	פסקי רקנטי
R. Aharon HaKohen	ר' אהרן מלוניל
Orechot Chayyim	ארחות חיים
Orchot Chayyim	ארחות חיים
Haggadat Orechot Chayyim	ארחות חיים
Haggadat Orchot Chayyim	ארחות חיים
Kol Bo	כל בו
Haggadat Kol Bo	כל בו
R. Dan	ר' דן
Rosh	רא\"ש
R. Asher b. Yehiel	רא\"ש
Tosefot Rosh	תוספות רא\"ש
Tosfot Rosh	תוספות רא\"ש
Tosfot HaRosh	תוספות רא\"ש
Tosefot HaRosh	תוספות רא\"ש
Tosafot HaRosh	תוספות רא\"ש
Peirush HaRosh	פירוש הרא\"ש
Perush HaRosh	פירוש הרא\"ש
Teshuvot HaRosh	תשובות הרא\"ש
Ritva	ריטב\"א
Migdal Oz	מגדל עוז
Aharon b. Yosef the Karaite	אהרן בן יוסף הקראי
Aharon b. Yosef	אהרן בן יוסף הקראי
R. Bachya	ר' בחיי
R. Bahya	ר' בחיי
R. Bahya b. Asher	ר' בחיי
Kad HaKemach	כד הקמח
Shulchan Shel Arba	שלחן של ארבע
R. David HaKochavi	ר' דוד הכוכבי
Sefer HaBattim	ספר הבתים
HaBattim	ספר הבתים
Immanuel HaRomi	עמנואל הרומי
Tur	טור
Baal HaTurim	טור
R. Jacob b. Asher	טור
Tur Long Commentary	הפירוש הארוך
Tur Short Commentary	הפירוש הקצר
R. Chayyim b. Shemuel	ר' חיים בן שמואל
Tzeror HaChayyim	צרור החיים
R. Alexander Suslin HaKohen	ר' אלכסנדר זוסלין הכהן
R. Alexander Suslin	ר' אלכסנדר זוסלין הכהן
HaAgudah	האגודה
R. Yerucham	ר' ירוחם
Toledot Adam VeChavah	תולדות אדם וחוה
Meisharim	מישרים
Issur VeHeter LeR. Yerucham	איסור והיתר לר' ירוחם
R. Ishtori HaParchi	ר' אשתורי הפרחי
Kaftor VaPerach	כפתור ופרח
R. David b. Yosef Abudraham	ר' דוד בן יוסף אבודרהם
Abudraham	אבודרהם
Avudraham	אבודרהם
R. Asher b. Chayyim	ר' אשר בן חיים
Sefer HaPardes	ספר הפרדס
Shut Min HaShamayim	שו\"ת מן השמים
R. Yosef Nachmias	ר' יוסף נחמיאש
R. Yosef Nachmiash	ר' יוסף נחמיאש
R. Joseph Nachmias	ר' יוסף נחמיאש
R. Joseph Nachmiash	ר' יוסף נחמיאש
Midrash HaGadol	מדרש הגדול
Hadar Zekeinim	הדר זקנים
Hadar Zekenim	הדר זקנים
Minchat Yehuda	מנחת יהודה
Minchat Yehudah	מנחת יהודה
Minchas Yehuda	מנחת יהודה
Minchas Yehudah	מנחת יהודה
R. Judah b. Elazar	מנחת יהודה
Daat Zekeinim	דעת זקנים
Da'at Zekeinim	דעת זקנים
Da'at Zekenim	דעת זקנים
Daat Zekenim	דעת זקנים
Daas Zekeinim	דעת זקנים
Da'as Zekeinim	דעת זקנים
Da'as Zekenim	דעת זקנים
Daas Zekenim	דעת זקנים
Imrei Noam	אמרי נעם
Attributed to Rosh	מיוחס לרא\"ש
Peirush HaMeyuchas LaRosh	מיוחס לרא\"ש
Perush HaMeyuchas LaRosh	מיוחס לרא\"ש
R. Chaim Paltiel	ר' חיים פלטיאל
R. Hayyim Paltiel	ר' חיים פלטיאל
Moshav Zekeinim	מושב זקנים
Moshav Zekenim	מושב זקנים
Maggid Mishneh	מגיד משנה
Magid Mishneh	מגיד משנה
R. Binyamin b. Yehuda	ר' בנימין ב\"ר יהודה
R. Benjamin b. Judah	ר' בנימין ב\"ר יהודה
R. Yosef ibn Kaspi	ר' יוסף אבן כספי
R. Yosef ibn Caspi	ר' יוסף אבן כספי
Ibn Kaspi	ר' יוסף אבן כספי
Ibn Caspi	ר' יוסף אבן כספי
R. Joseph ibn Caspi	ר' יוסף אבן כספי
R. Yosef ibn Kaspi First Commentary	פירוש ראשון
R. Yosef ibn Kaspi Second Commentary	פירוש שני
Parashat HaKesef	פרשת הכסף
Ammudei Kesef	עמודי כסף
Maskiyot Kesef	משכיות כסף
Ralbag	רלב\"ג
Gersonides	רלב\"ג
R. Levi b. Gershon	רלב\"ג
Beur HaMilot	ביאור המילות
Ralbag Beur HaMilot	ביאור המילות
Beiur HaMilot	ביאור המילות
Beur HaMillot	ביאור המילות
Beiur HaMillot	ביאור המילות
Beur Milot HaSippur	ביאור המילות
Beiur Milot HaSippur	ביאור המילות
Beur Milot HaParashah	ביאור המילות
Beur Milot HaParasha	ביאור המילות
Beur HaParashah	ביאור הפרשה
Ralbag Beur HaParashah	ביאור הפרשה
Beur HaSippur	ביאור הפרשה
Beur Divrei HaSippur	ביאור הפרשה
Beiur HaSippur	ביאור הפרשה
Beiur Divrei HaSippur	ביאור הפרשה
Beiur HaParashah	ביאור הפרשה
Beur Divrei HaParashah	ביאור הפרשה
Beiur Divrei HaParashah	ביאור הפרשה
Beur HaParasha	ביאור הפרשה
Beiur HaParasha	ביאור הפרשה
Beur Divrei HaParasha	ביאור הפרשה
Beiur Divrei HaParasha	ביאור הפרשה
Toalot	תועלות
Ralbag Toalot	תועלות
Milchamot Hashem	מלחמות השם
Ralbag Milchamot Hashem	מלחמות השם
R. Moshe of Narbonne	ר' משה נרבוני
R. Peretz HaKohen	ר' פרץ הכהן
R. Yehoshua HaNagid	ר' יהושע הנגיד
Responsa of R. Yehoshua HaNagid on Mishneh Torah	תשובות ר' יהושע הנגיד על משנה תורה
R. Yisrael of Krems	ר' ישראל מקרמז
Hagahot Oshri	הגהות אשרי
R. Menachem b. Aharon	ר' מנחם בן אהרן בן זרח
Tzeidah LaDerekh	צדה לדרך
Ran	ר\"ן
R. Nisim Gerondi	ר\"ן
Ran on Rif	ר\"ן על רי\"ף
Derashot HaRan	דרשות הר\"ן
Drashos HaRan	דרשות הר\"ן
Teshuvot HaRan	תשובות הר\"ן
Attributed to Ran	מיוחס לר\"ן
Attributed to Shitah Mekubetzet	מיוחס לשיטה מקובצת
Attributed to Shittah Mekubetzet	מיוחס לשיטה מקובצת
Attributed to Shitah Mekubezet	מיוחס לשיטה מקובצת
Attributed to Shittah Mekubezet	מיוחס לשיטה מקובצת
R. Moshe Chalava	מהר\"ם חלאווה
R. Yisrael Alnaqua	ר' ישראל אלנקאוה
Menorat HaMaor (Alnaqua)	מנורת המאור (אלנקאוה)
Rivash	ריב\"ש
R. Yitzchak b. Sheshet Perfet	ריב\"ש
Teshuvot HaRivash	תשובות הריב\"ש
R. Shelomo Astruc	ר' שלמה אסטרוק
Midreshei HaTorah	ר' שלמה אסטרוק
Midreshe HaTorah	ר' שלמה אסטרוק
R. Solomon Astruc	ר' שלמה אסטרוק
R. David b. R. Yehoshua HaNagid	ר' דוד ב\"ר יהושע הנגיד
R. Chasdai Crescas	ר' חסדאי קרשקש
R. Hasdai Crescas	ר' חסדאי קרשקש
Crescas	ר' חסדאי קרשקש
Or Hashem	אור ה'
Bittul Ikkarei HaNotzerim	ביטול עיקרי הנוצרים
R. Yitzchak b. Moshe HaLevi	ר' יצחק בן משה הלוי
Efodi	אפודי
R. Moshe of Zurich	ר' משה מצוריך
Semak of Zurich	סמ\"ק מצוריך
R. Avraham Klausner	ר' אברהם קלויזנר
Sefer HaMinhagim of R. Avraham Klausner	ספר המנהגים ר' אברהם קלויזנר
R. Menachem Tziyoni	ר' מנחם ציוני
R. Menahem Zioni	ר' מנחם ציוני
Sefer Nitzachon Yashan	ספר נצחון ישן
Sefer Nizahon Yashan	ספר נצחון ישן
R. Shalom of Neustadt	ר' שלום מנוישטט
Sefer HaNitzachon	ספר הנצחון
Sefer HaNizahon	ספר הנצחון
R. Yosef b. David Chaviva	ר' יוסף בן דוד חביבא
R. Joseph b. David of Saragosa	ר' יוסף בן דוד חביבא
Nimmukei Yosef	נימוקי יוסף
Nimukei Yosef	נימוקי יוסף
Nimmukei Yosef on Rif	נימוקי יוסף על רי\"ף
R. Shimon b. Tzemach Duran	רשב\"ץ
R. Shimon Duran	רשב\"ץ
Tashbetz	רשב\"ץ
Zohar HaRakia LaTashbetz	זהר הרקיע לתשב\"ץ
Zohar HaRakia LaRashbatz	זהר הרקיע לתשב\"ץ
Zohar HaRakia	זהר הרקיע לתשב\"ץ
Sefer Tashbetz	ספר תשב\"ץ
R. Yitzchak of Tyrnau	ר' אייזיק טירנא
R. Isaac of Tyrnau	ר' אייזיק טירנא
Sefer HaMinhagim of R. Yitzchak of Tyrnau	ספר המנהגים ר' אייזיק טירנא
R. Yaakov ben Moshe Levi Moelin	ר' יעקב בן משה הלוי מולין
Sefer Maharil	ספר מהרי\"ל
Teshuvot Maharil	תשובות מהרי\"ל
Sefer HaIkkarim	ספר העיקרים
R\"Y Albo	ספר העיקרים
R. Joseph Albo	ספר העיקרים
R. Yaakov Weil	ר' יעקב וייל
R. Yisrael Isserlein	ר' ישראל איסרלין
Terumat HaDeshen	תרומת הדשן
Teshuvot	תשובות
Terumat HaDeshen Teshuvot	תשובות
Pesakim	פסקים
Terumat HaDeshen Pesakim	פסקים
Beurei Maharai	ביאורי מהרא\"י – תרומת הדשן
Issur VeHeter HaArokh	איסור והיתר הארוך
R. Yisrael Bruna	ר' ישראל ברונא
R. Asher Crescas	ר' אשר קרשקש
R. Avraham b. Shelomo	ר' אברהם בר שלמה
R. Tzemach Duran	ר' צמח דוראן
R. Yehudah Mintz	ר' יהודה מינץ
R. Yehudah Minz	ר' יהודה מינץ
Mahari Mintz	ר' יהודה מינץ
R. Yosef Colon	ר' יוסף קולון
R. Yosef Kolon	ר' יוסף קולון
Teshuvot Maharik	תשובות מהרי\"ק
R. Moshe Mintz	ר' משה מינץ
R. Moshe Minz	ר' משה מינץ
R. Yaakov Landa	ר' יעקב לנדא
HeAgur	האגור
HaAgur	האגור
Agur	האגור
R. Yosef ibn Shushan	ר' יוסף אבן שושן
Midrash HaCheifetz	מדרש החפץ
Midrash HaHeifetz	מדרש החפץ
R. Yosef Chayyun	ר' יוסף חיון
R. Yosef Hayyun	ר' יוסף חיון
R\"Y Chayyun	ר' יוסף חיון
R\"Y Hayyun	ר' יוסף חיון
R. Joseph Chayyun	ר' יוסף חיון
R. Joseph Hayyun	ר' יוסף חיון
Akeidat Yitzchak	עקדת יצחק
Akedat Yitzchak	עקדת יצחק
Akeidat Yitzhak	עקדת יצחק
Akedat Yitzhak	עקדת יצחק
Akeidat Yizhak	עקדת יצחק
Akedat Yizhak	עקדת יצחק
Akedas Yitzchak	עקדת יצחק
Akeidas Yitzchak	עקדת יצחק
R. Yitzhak Arama	עקדת יצחק
R. Yizhak Arama	עקדת יצחק
R. Isaac Arama	עקדת יצחק
R\"Y Arama	עקדת יצחק
Peirush	פירוש
Akeidat Yitzchak Peirush	פירוש
Derush	דרוש
Akeidat Yitzchak Derush	דרוש
Mashal	משל
Akeidat Yitzchak Mashal	משל
Chazut Kashah	חזות קשה
Akeidat Yitzchak Chazut Kashah	חזות קשה
R. Shem Tov ibn Shem Tov	ר' שם טוב אבן שם טוב
R. Yosef b. Moshe	ר' יוסף בר' משה
Leket Yosher	לקט יושר
R. Eliyahu Mizrachi	ר' אליהו מזרחי
R\"E Mizrachi	ר' אליהו מזרחי
R. Eliyahu Mizrahi	ר' אליהו מזרחי
Mizrachi	ר' אליהו מזרחי
Mizrahi	ר' אליהו מזרחי
Abarbanel	אברבנאל
R. Yitzhak Abarbanel	אברבנאל
R. Yizhak Abarbanel	אברבנאל
R. Isaac Abarbanel	אברבנאל
Abravanel	אברבנאל
R. Yitzchak Abravanel	אברבנאל
R. Isaac Abravanel	אברבנאל
Mashmia Yeshuah	משמיע ישועה
Abarbanel Mashmia Yeshuah	משמיע ישועה
Nachalat Avot	נחלת אבות
Nahalat Avot	נחלת אבות
Abarbanel Zevach Pesach	זבח פסח לאברבנאל
R. Avraham Saba	ר' אברהם סבע
R\"A Saba	ר' אברהם סבע
R. Abraham Saba	ר' אברהם סבע
Tzeror HaMor	צרור המור
Zror HaMor	צרור המור
Zeror HaMor	צרור המור
Tzror HaMor	צרור המור
Eshkol HaKofer	אשכול הכופר
Eshkol HaKopher	אשכול הכופר
R. Yaakov ibn Chaviv	ר' יעקב אבן חביב
Ein Yaakov	עין יעקב
R. Ovadyah MiBartenura	ר' עובדיה מברטנורא
R. Ovadyah of Bartenura	ר' עובדיה מברטנורא
R. Ovadiah MiBartenura	ר' עובדיה מברטנורא
R. Obadiah MiBartenura	ר' עובדיה מברטנורא
Bartenura	ר' עובדיה מברטנורא
Amar Nekei	עמר נקא
Toledot Yitzchak	תולדות יצחק
Toledot Yitzhak	תולדות יצחק
Toledot Yizhak	תולדות יצחק
Toldot Yitzchak	תולדות יצחק
Toldot Yitzhak	תולדות יצחק
Toldot Yizhak	תולדות יצחק
Toldos Yitzchak	תולדות יצחק
Toledos Yitzchak	תולדות יצחק
R. Isaac Karo	תולדות יצחק
R. Yosef Kurkus	ר' יוסף קורקוס
R. Moshe Alashkar	ר' משה אלאשקר
R. Eliyahu Bachur	ר' אליהו בחור
Nimmukei R. Eliyahu Bachur	נימוקי ר' אליהו בחור
Sefer HaTishbi	ספר התשבי
R. Meir Arama	ר' מאיר עראמה
Maggid Mishneh Hilkhot Shechitah	מגיד משנה הלכות שחיטה
Sforno	ספורנו
Seforno	ספורנו
R. Ovadiah Sforno	ספורנו
R. Ovadia Sforno	ספורנו
R. Ovadya Sforno	ספורנו
R. Ovadiah Seforno	ספורנו
R. Ovadia Seforno	ספורנו
R. Ovadya Seforno	ספורנו
R. Obadiah Sforno	ספורנו
Shiurei Sforno	שיעורי ר' עובדיה ספורנו
Amar HaGaon	שיעורי ר' עובדיה ספורנו
Shiurei Seforno	שיעורי ר' עובדיה ספורנו
Likkutei Sforno	ליקוטי ספורנו
Likutei Sforno	ליקוטי ספורנו
Likutei Seforno	ליקוטי ספורנו
Maamar Kavvanot HaTorah	מאמר כוונות התורה
Sforno Maamar Kavvanot HaTorah	מאמר כוונות התורה
Maamar Kavanot HaTorah	מאמר כוונות התורה
Kavanot HaTorah	מאמר כוונות התורה
Or Ammim	אור עמים
Maharam of Padua	מהר\"ם מפדואה
Glosses of Maharam of Padua on Mishneh Torah	הגהות מהר\"ם מפדואה על משנה תורה
R. Yaakov Bei-Rav	ר' יעקב בי רב
Chidushei Mahari Bei-Rav	חידושי מהר\"י בי רב
Radbaz	רדב\"ז
R. David b. Shelomo ibn Zimra	רדב\"ז
Teshuvot Radbaz	תשובות רדב\"ז
Responsa of Radbaz on Mishneh Torah	תשובות רדב\"ז על משנה תורה
R. Levi ibn Chaviv	ר' לוי אבן חביב
R. David b. Ovadiah	ר' דוד בר' עובדיה
Anonymous Commentary Sefer HaMadda	פירוש אנונימי על ספר המדע
R. Yaakov Pollak	ר' יעקב פולק
R. Yosef Karo	ר' יוסף קארו
R. Joseph Karo	ר' יוסף קארו
Kesef Mishneh	כסף משנה
Kesef Mishne	כסף משנה
Beit Yosef	בית יוסף
Bet Yosef	בית יוסף
Beit Yosef (Shirat Devorah)	בית יוסף (שירת דבורה)
Beit Yosef Shirat Devorah	בית יוסף (שירת דבורה)
Beit Yosef for copying	בית יוסף לצורכי העתקה
Shulchan Arukh	שולחן ערוך
S\"A	שולחן ערוך
Shulhan Arukh	שולחן ערוך
Shulhan Aruch	שולחן ערוך
Shulchan Aruch	שולחן ערוך
Shulkhan Arukh	שולחן ערוך
Shulkhan Aruch	שולחן ערוך
Teshuvot Avkat Rokhel	תשובות אבקת רוכל
R. Shalom Shachna	ר' שלום שכנא
R. Yosef ibn Yachya	ר' יוסף אבן יחייא
R. Joseph ibn Yachya	ר' יוסף אבן יחייא
Toledot Aharon	תולדות אהרן
Toledos Aharon	תולדות אהרן
Toldos Ahron	תולדות אהרן
R. Moshe Alshikh	ר' משה אלשיך
Alshikh	ר' משה אלשיך
Alshich	ר' משה אלשיך
Alshekh	ר' משה אלשיך
Alshech	ר' משה אלשיך
R. Moshe Alshich	ר' משה אלשיך
R. Moshe Alshekh	ר' משה אלשיך
R. Moshe Alshech	ר' משה אלשיך
R. Moses Alshikh	ר' משה אלשיך
R. Moses Alshich	ר' משה אלשיך
R. Moses Alshekh	ר' משה אלשיך
R. Moses Alshech	ר' משה אלשיך
R\"M Alshikh	ר' משה אלשיך
R\"M Alshekh	ר' משה אלשיך
R. Shelomo Luria	ר' שלמה לוריא
Maharshal Chokhmat Shelomo	מהרש\"ל חכמת שלמה
Maharshal Chokhmat Shlomo	מהרש\"ל חכמת שלמה
Yam Shel Shelomo	ים של שלמה
Yeriot Shelomo	יריעות שלמה
Teshuvot Maharshal	תשובות מהרש\"ל
R. Eliezer Ashkenazi	ר' אליעזר אשכנזי
R\"E Ashkenazi	ר' אליעזר אשכנזי
Ma'asei Hashem	מעשי ה'
Maasei Hashem	מעשי ה'
Yosef Lekach	יוסף לקח
Yosef Lekah	יוסף לקח
R. Yehoshua Boaz	ר' יהושע בועז
Ein Mishpat Ner Mitzvah	עין משפט נר מצוה
Shiltei HaGibborim	שלטי הגבורים
R. Betzalel Ashkenazi	ר' בצלאל אשכנזי
R\"B Ashkenazi	ר' בצלאל אשכנזי
Shitah Mekubetzet	שיטה מקובצת
Shittah Mekubetzet	שיטה מקובצת
Shitah Mekubezet	שיטה מקובצת
Shittah Mekubezet	שיטה מקובצת
Teshuvot R. Betzalel Ashkenazi	תשובות ר' בצלאל אשכנזי
Minchah Belulah	מנחה בלולה
Mincha Belula	מנחה בלולה
R. Abraham Porto	מנחה בלולה
Maharal	מהר\"ל
Gur Aryeh	גור אריה
Gur Arye	גור אריה
Or Chadash	אור חדש למהר\"ל
Derekh Chayyim Mishna Avot	דרך חיים למהר\"ל
Derekh Hayyim	דרך חיים למהר\"ל
Derech Chayyim	דרך חיים למהר\"ל
Derech Hayyim	דרך חיים למהר\"ל
Derekh HaHayyim	דרך חיים למהר\"ל
Derekh HaChayyim	דרך חיים למהר\"ל
Derech HaChayyim	דרך חיים למהר\"ל
Derech HaHayyim	דרך חיים למהר\"ל
Be'er HaGolah	באר הגולה
Maharal Be'er HaGolah	באר הגולה
Gevurot Hashem	גבורות ה'
Maharal Gevurot Hashem	גבורות ה'
Ner Mitzvah	נר מצוה
Maharal Ner Mitzvah	נר מצוה
Netivot Olam	נתיבות עולם
Maharal Netivot Olam	נתיבות עולם
Netzach Yisrael	נצח ישראל
Maharal Netzach Yisrael	נצח ישראל
Tiferet Yisrael	תפארת ישראל
Maharal Tiferet Yisrael	תפארת ישראל
R. Moshe Cordovero	ר' משה קורדובירו
R. Moshe Isserles	ר' משה איסרליש
Rema	ר' משה איסרליש
Rama	ר' משה איסרליש
Darkhei Moshe	דרכי משה
Darchei Moshe	דרכי משה
Mechir Yayin	מחיר יין
Teshuvot Rema	תשובות רמ\"א
R. Yitzchak Luria	ר' יצחק לוריא
R. Mordecai Yoffe	ר' מרדכי יפה
R. Mordecai Yafe	ר' מרדכי יפה
Levush	לבוש
Levush HaOrah	לבוש האורה
R. Chaim Vital	ר' חיים ויטאל
R. Yehoshua Falk	ר' יהושע פלק
Derishah	דרישה
Perishah	פרישה
Sema	סמ\"ע
Sefer Meirat Einayim	סמ\"ע
Lechem Mishneh	לחם משנה
Lekhem Mishneh	לחם משנה
Keli Yekar	כלי יקר
Keli Yakar	כלי יקר
Kli Yekar	כלי יקר
Kli Yakar	כלי יקר
R. Shelomo Lunshitz	כלי יקר
R. Ephraim Lunshitz	כלי יקר
R. Solomon Ephraim of Lunshitz	כלי יקר
R. Shemuel Eidels	ר' שמואל אידלש
R. Shmuel Eidels	ר' שמואל אידלש
Maharsha	ר' שמואל אידלש
Meharsha	ר' שמואל אידלש
Maharsha Chidushei Halakhot	מהרש\"א חידושי הלכות
Maharsha Chiddushei Halakhot	מהרש\"א חידושי הלכות
Maharsha Chidushei Aggadot	מהרש\"א חידושי אגדות
Maharsha Chiddushei Aggadot	מהרש\"א חידושי אגדות
Midrash Shemuel Mishna Avot	מדרש שמואל אבות
Midrash Shmuel Avot	מדרש שמואל אבות
R. Yissachar Eilenburg	ר' יששכר בער איילנבורג
R. Yissachar Eilenberg	ר' יששכר בער איילנבורג
Be'er Sheva	באר שבע
Beer Sheva	באר שבע
Maharam MiLublin	מהר\"ם מלובלין
Maharam Lublin	מהר\"ם מלובלין
R. Meir Lublin	מהר\"ם מלובלין
Minchat Shai	מנחת שי
R. Yeshayah Horowitz	ר' ישעיה הורוויץ
Shelah	ר' ישעיה הורוויץ
Shenei Luchot HaBerit	שני לוחות הברית
Shnei Luchot HaBrit	שני לוחות הברית
Bach	ב\"ח
Bayit Chadash	ב\"ח
Teshuvot Bach	תשובות ב\"ח
Yeshanot	ישנות
Teshuvot Bach Yeshanot	ישנות
Chadashot	חדשות
Teshuvot Bach Chadashot	חדשות
Kuntres Acharon	קונטרס אחרון
Teshuvot Bach Kuntres Acharon	קונטרס אחרון
Melekhet Shelomo	מלאכת שלמה
Melechet Shelomo	מלאכת שלמה
Tosefot Yom Tov	תוספות יום טוב
Tosafot Yom Tov	תוספות יום טוב
Ikkar Tosefot Yom Tov	עיקר תוספות יום טוב
Ikkar Tosafot Yom Tov	עיקר תוספות יום טוב
R. Azariah Figo	ר' עזריה פיגו
R. Azaryah Figo	ר' עזריה פיגו
R. Azaria Figo	ר' עזריה פיגו
R. Azarya Figo	ר' עזריה פיגו
R. Yitzchak b. Shemuel HaLevi	ר' יצחק בן שמואל הלוי
Chidushei Mahari HaLevi	חידושי מהר\"י הלוי
Chiddushei Mahari HaLevi	חידושי מהר\"י הלוי
R. David HaLevi Segal	ר' דוד הלוי סגל
Taz	ט\"ז
Turei Zahav	ט\"ז
Divrei David	דברי דוד
R. Chaim Benveniste	ר' חיים בנבנישתי
Keneset HaGedolah	כנסת הגדולה
Kenesset HaGedolah	כנסת הגדולה
Chelkat Mechokek	חלקת מחוקק
Chelkas Mechokek	חלקת מחוקק
R. Shabbetai HaKohen	ר' שבתי הכהן
Shakh	ש\"ך
Siftei Kohen	ש\"ך
Nekudot HaKesef	נקודות הכסף
Nekudot HaKasef	נקודות הכסף
Beer HaGolah	באר הגולה
Magen Avraham	מגן אברהם
Mogen Avraham	מגן אברהם
Ateret Zekeinim	עטרת זקנים
Ateret Zekenim	עטרת זקנים
Siftei Chakhamim	שפתי חכמים
Sifsei Chakhamim	שפתי חכמים
Sifsei Chachamim	שפתי חכמים
Beit Shemuel	בית שמואל
Beis Shemuel	בית שמואל
R. Tzvi Hirsch Ashkenazi	ר' צבי הירש אשכנזי
Teshuvot Chakham Tzvi	תשובות חכם צבי
Mishneh LaMelekh	משנה למלך
Mishne LaMelekh	משנה למלך
Mishneh LaMelech	משנה למלך
Mishne LaMelech	משנה למלך
R. Chizkiyah da Silva	ר' חזקיה די סילוה
R. Hezekiah da Silva	ר' חזקיה די סילוה
Peri Chadash	פרי חדש
Pri Chadash	פרי חדש
Eliyah Rabbah	אליה רבה
R. Yaakov Reischer	ר' יעקב ריישר
Chok Yaakov	חק יעקב
Hok Yaakov	חק יעקב
Torat HaShelamim	תורת השלמים
Toras HaShelamim	תורת השלמים
Melekhet Machshevet	מלאכת מחשבת
Melekhes Machsheves	מלאכת מחשבת
Meleches Machsheves	מלאכת מחשבת
R. Moshe Hefez	מלאכת מחשבת
R. Moshe Chefetz	מלאכת מחשבת
R. Moshe Cheifetz	מלאכת מחשבת
R. Moses Hefetz	מלאכת מחשבת
Baer Heitev	באר היטב
Ba'er Hetev	באר היטב
Ba'er Heiteiv	באר היטב
Baer Heiteiv	באר היטב
Penei Yehoshua	פני יהושע
Pnei Yehoshua	פני יהושע
Maaseh Rokeach	מעשה רקח
Ma'aseh Rokeach	מעשה רקח
Metzudot	מצודות
Metzudat Zion	מצודת ציון
Metzudat David	מצודת דוד
R. Yehonatan Eibeschutz	ר' יהונתן אייבשיץ
Kereti uPleti - Kereti	כרתי ופלתי – כרתי
Kereti uPleti - Kereti Yoreh Deah	כרתי ופלתי – כרתי
Kreti	כרתי ופלתי – כרתי
Kereti uPleti - Pleti	כרתי ופלתי – פלתי
Kereti uPleti - Pleti Yoreh Deah	כרתי ופלתי – פלתי
Pleti	כרתי ופלתי – פלתי
Urim veTumim – Urim	אורים ותומים – אורים
Urim veTumim - Urim Choshen Mishpat	אורים ותומים – אורים
Urim	אורים ותומים – אורים
Urim veTumim – Tumim	אורים ותומים – תומים
Urim veTumim - Tumim Choshen Mishpat	אורים ותומים – תומים
Tumim	אורים ותומים – תומים
Benei Ahuvah	בני אהובה
Bnei Ahuvah	בני אהובה
R. Aryeh Leib Gunzberg	ר' אריה לייב גינצבורג
Teshuvot R. Aryeh Leib Gunzberg	תשובות ר' אריה לייב גינצבורג
Teshuvot Sha'agat Aryeh	תשובות שאגת אריה
Teshuvot Sha'agat Aryeh HeChadashot	תשובות שאגת אריה החדשות
Dinei Chadash	דיני חדש
Or HaChayyim	אור החיים
Ohr HaChayyim	אור החיים
Or HaChayim	אור החיים
Ohr HaChayim	אור החיים
R. Hayyim b. Atar	אור החיים
R. Yaakov Emden	ר' יעקב עמדין
R. Jacob Emden	ר' יעקב עמדין
Shaar HaMelekh	שער המלך
Sha'ar HaMelekh	שער המלך
R. Moshe Chaim Luzzatto	ר' משה חיים לוצאטו
Mesilat Yesharim	מסילת ישרים
R. David Frankel	ר' דוד פרנקל
R\"D Frankel	ר' דוד פרנקל
Korban HaEdah	קרבן העדה
Korban HaEidah	קרבן העדה
Sheyarei Korban	שיירי קרבן
Sheyare Korban	שיירי קרבן
R. Moshe Margalit	ר' משה מרגלית
R\"M Margalit	ר' משה מרגלית
Penei Moshe	פני משה
Penei Mosheh	פני משה
Pnei Moshe	פני משה
Mareh HaPanim	מראה הפנים
Mare Hapanim	מראה הפנים
R. Yechezkel Landau	ר' יחזקאל לנדאו
R. Ezekiel Landau	ר' יחזקאל לנדאו
Dagul MeRevavah	דגול מרבבה
Teshuvot Noda Bihuda Mahadura Kamma	תשובות נודע ביהודה מהדורא קמא
Teshuvot Noda Bihuda Mahadura Kamma Orach Chayyim	אורח חיים
Teshuvot Noda Bihuda Mahadura Kamma Yoreh Deah	יורה דעה
Teshuvot Noda Bihuda Mahadura Kamma Even HaEzer	אבן העזר
Teshuvot Noda Bihuda Mahadura Kamma Choshen Mishpat	חושן משפט
Teshuvot Noda Bihuda Mahadura Tinyana	תשובות נודע ביהודה מהדורא תנינא
Teshuvot Noda Bihuda Mahadura Tinyana Orach Chayyim	אורח חיים
Teshuvot Noda Bihuda Mahadura Tinyana Yoreh Deah	יורה דעה
Teshuvot Noda Bihuda Mahadura Tinyana Even HaEzer	אבן העזר
Teshuvot Noda Bihuda Mahadura Tinyana Choshen Mishpat	חושן משפט
R. Shelomo of Chelm	ר' שלמה מחעלמא
R. Shlomo of Chelm	ר' שלמה מחעלמא
Mirkevet HaMishneh	מרכבת המשנה
Mirkevet HaMishne	מרכבת המשנה
Mirkevet HaMishneh Mahadura Batra	מרכבת המשנה מהדורה בתרא
Mirkevet HaMishne More	מרכבת המשנה מהדורה בתרא
R. David Pardo	ר' דוד פרדו
Maskil LeDavid	משכיל לדוד
R. Yeshaye Pick Berlin	ר' ישעיה פיק ברלין
Minei Targuma	מיני תרגומא
Eishel Avraham (Oppenheim)	אשל אברהם (אופנהיים)
Vilna Gaon (GR\"A)	הגאון מוילנא (הגר\"א)
Vilna Gaon	הגאון מוילנא (הגר\"א)
GR\"A	הגאון מוילנא (הגר\"א)
GRA	הגאון מוילנא (הגר\"א)
Beur HaGra	ביאור הגר\"א
Maaseh Rav	מעשה רב
Machatzit HaShekel	מחצית השקל
Mahatzit HaShekel	מחצית השקל
R. Chaim Yosef David Azulai	ר' חיים יוסף דוד אזולאי
Birkei Yosef	ברכי יוסף
Peri Megadim	פרי מגדים
Pri Megadim	פרי מגדים
Peri Megadim Mishbetzot Zahav	פרי מגדים משבצות זהב
Peri Megadim Eishel Avraham	פרי מגדים אשל אברהם
Peri Megadim Siftei Daat	פרי מגדים שפתי דעת
R. N.H. Wessely	ר' נ\"ה וויזל
R. N\"H Wessely	ר' נ\"ה וויזל
Yein Levanon	יין לבנון
Moses Mendelssohn	משה מנדלסון
R. Pinchas HaLevi Horowitz	ר' פנחס הלוי הורוויץ
Haflaah	הפלאה
HaMiknah	המקנה
HaMakneh	המקנה
R. Shelomo Dubno	ר' שלמה דובנא
R. Shelomo Dubnow	ר' שלמה דובנא
R. Solomon Dubno	ר' שלמה דובנא
R. Solomon Dubnow	ר' שלמה דובנא
Beur	באור
Biur	באור
Netivot HaShalom	באור
Beur Lexical Commentary	באור המלות
Beur Explanation of the Meaning	באור הטעמים
R. Levi Yitzchak of Berditchev	ר' לוי יצחק מברדיצ'ב
Kedushat Levi	קדושת לוי
HaRekhasim Levik'ah	הרכסים לבקעה
HaRekhasim Levikah	הרכסים לבקעה
R. Aryeh Leib HaKohen Heller	ר' אריה לייב הכהן הלר
Ketzot HaChoshen	קצות החושן
Ketzot HaChoshen Choshen Mishpat	קצות החושן
Ketzot	קצות החושן
R. Shneur Zalman of Liadi	ר' שניאור זלמן מלאדי
Shulchan Arukh HaRav	שולחן ערוך הרב
Shulkhan Arukh HaRav	שולחן ערוך הרב
Tanya	תניא
R. Avraham Danzig	ר' אברהם דנציג
Chayyei Adam	חיי אדם
Hayyei Adam	חיי אדם
Nishmat Adam	נשמת אדם
Chokhmat Adam	חכמת אדם
Binat Adam	בינת אדם
R. Chaim Volozhiner	ר' חיים מוולוזין
Nefesh HaChayyim	נפש החיים
Teshuvot R. Chaim Volozhiner	תשובות ר' חיים מוולוזין
HaKorem	הכורם
HaMeamer	המעמר
Levushei Serad	לבושי שרד
R. Akiva Eiger	ר' עקיבא איגר
R. Akiva Eger	ר' עקיבא איגר
Chidushei R. Akiva Eiger	חידושי ר' עקיבא איגר
Gilyon HaShas	גליון הש\"ס לרע\"א
Gilayon HaShas	גליון הש\"ס לרע\"א
Hagahot R. Akiva Eiger	הגהות ר' עקיבא איגר
Teshuvot R. Akiva Eiger	תשובות ר' עקיבא איגר
Mahadura Kamma	מהדורא קמא
Teshuvot R. Akiva Eiger Mahadura Kamma	מהדורא קמא
R. Moshe Schreiber	ר' משה סופר
Chidushei Chatam Sofer	חידושי חתם סופר
Chiddushei Chatam Sofer	חידושי חתם סופר
Chidushei Chatam Sofer Mahadura Tinyana	חידושי חתם סופר מהדורה תנינא
Chiddushei Chatam Sofer Mahadura Tinyana	חידושי חתם סופר מהדורה תנינא
Teshuvot Chatam Sofer	תשובות חתם סופר
Teshuvot Chatam Sofer Orach Chayyim	אורח חיים
Teshuvot Chatam Sofer Yoreh Deah	יורה דעה
Teshuvot Chatam Sofer Choshen Mishpat	חושן משפט
Likkutim	ליקוטים
Teshuvot Chatam Sofer Likkutim	ליקוטים
R. Avraham b. HaGRA	ר' אברהם בן הגר\"א
Shaarei Teshuvah	שערי תשובה
R. Yaakov Lorberbaum	ר' יעקב לורברבוים
Netivot HaMishpat Beurim	נתיבות המשפט ביאורים
Netivot HaMishpat Beurim Choshen Mishpat	נתיבות המשפט ביאורים
Netivot Beurim	נתיבות המשפט ביאורים
Netivot HaMishpat Chiddushim	נתיבות המשפט חידושים
Netivot HaMishpat Chiddushim Choshen Mishpat	נתיבות המשפט חידושים
Netivot Chiddushim	נתיבות המשפט חידושים
R. Ephraim Zalman Margaliyot	ר' אפרים זלמן מרגליות
Yad Ephraim	יד אפרים
Mateh Shimon	מטה שמעון
Eishel Avraham (Buchach)	אשל אברהם (בוטשאטש)
R. Wolf Heidenheim	ר' ב\"ז (וולף) היידנהיים
Havanat HaMikra	ר' ב\"ז (וולף) היידנהיים
Tiferes Yisroel	תפארת ישראל
Tiferet Yisrael Yakhin	תפארת ישראל יכין
Tiferet Yisrael Boaz	תפארת ישראל בועז
R. Y.S. Reggio	ר' י\"ש ריגייו
R. Y\"S Reggio	ר' י\"ש ריגייו
Torah Min HaShamayim	תורה מן השמים
R. Y.S. Reggio Torah Min HaShamayim	תורה מן השמים
HaKetav VeHaKabbalah	הכתב והקבלה
HaKetav VeHaKabalah	הכתב והקבלה
HaKesav VeHaKabbalah	הכתב והקבלה
HaKesav VeHaKabalah	הכתב והקבלה
R. Yaakov Mecklenberg	הכתב והקבלה
R. Shelomo Kluger	ר' שלמה קלוגר
Chokhmat Shelomo	חכמת שלמה
R. Yaakov Ettlinger	ר' יעקב עטלינגר
Arukh LaNer	ערוך לנר
Teshuvot R. Yaakov Ettlinger	תשובות ר' יעקב עטלינגר
Teshuvot Binyan Tziyon	תשובות בנין ציון
Teshuvot Binyan Tziyon HeChadashot	תשובות בנין ציון החדשות
R. Yosef Babad	ר' יוסף באבד
Minchat Chinukh	מנחת חינוך
Minchat Chinuch	מנחת חינוך
Minchat Chinnuch	מנחת חינוך
Minchat Chinnukh	מנחת חינוך
Kometz Minchah	קומץ מנחה
Shadal	שד\"ל
R. Shmuel David Luzzatto	שד\"ל
R. Samuel David Luzzatto	שד\"ל
Shadal Translation	שד\"ל תרגום
HaMishtadel	המשתדל
Hamishtadel	המשתדל
Ohev Ger	אוהב גר
Shadal Yesodei HaTorah	שד\"ל יסודי התורה
Mechkarei HaYahadut	מחקרי היהדות
Shadal Mechkarei HaYahadut	מחקרי היהדות
R. Nathan Marcus Adler	ר' נתן מרקוס אדלר
R. Natan Marcus Adler	ר' נתן מרקוס אדלר
Netinah LaGer	נתינה לגר
Ahavat Yonatan	אהבת יונתן
R. Tzvi Hirsch Chajes	ר' צבי הירש חיות
R. S.R. Hirsch	רש\"ר הירש
R. Shimshon Refael Hirsch	רש\"ר הירש
R. Shimshon Rephael Hirsch	רש\"ר הירש
R. S\"R Hirsch	רש\"ר הירש
R. Hirsch	רש\"ר הירש
Hirsch	רש\"ר הירש
Chorev	חורב
Horeb	חורב
Iggerot Tzafun	אגרות צפון
Nineteen Letters	אגרות צפון
Malbim	מלבי\"ם
Malbim Beur HaMilot	ביאור המילות
Beur HaInyan	ביאור הענין
Malbim Beur HaInyan	ביאור הענין
Beiur HaInyan	ביאור הענין
Torah Ohr	תורה אור
Malbim Torah Ohr	תורה אור
Torah Or	תורה אור
Rimzei HaMishkan	רמזי המשכן
Malbim Rimzei HaMishkan	רמזי המשכן
Ayelet HaShachar	אילת השחר
Malbim Ayelet HaShachar	אילת השחר
Ayelet HaShakhar	אילת השחר
Added to Malbim	נתווסף למלבי\"ם
Added to Malbim Torah Ohr	תורה אור
Attributed to Malbim	מיוחס למלבי\"ם
R. Yosef Shaul Nathansohn	ר' יוסף שאול נתנזון
Shut Shoel UMeshiv	שו\"ת שואל ומשיב
Pitchei Teshuvah	פתחי תשובה
Pischei Teshuvah	פתחי תשובה
Netziv	נצי\"ב
Neziv	נצי\"ב
Ha'amek Davar	נצי\"ב
Haamek Davar	נצי\"ב
Hamek Davar	נצי\"ב
Netziv Imrei Shefer	אמרי שפר לנצי\"ב
Beit HaLevi	בית הלוי
Teshuvot Beit HaLevi	תשובות בית הלוי
R. Azriel Hildesheimer	ר' עזריאל הילדסהיימר
R. Esriel Hildesheimer	ר' עזריאל הילדסהיימר
Hoil Moshe	הואיל משה
R. Moshe Yitzchak Tedeschi	הואיל משה
Em LaMikra	אם למקרא
R. Yechiel Michel HaLevi Epstein	ר' יחיאל מיכל הלוי אפשטיין
Arukh HaShulchan	ערוך השולחן
R. Yosef Zekharyah Stern	ר' יוסף זכריה שטרן
Maamar Tahalukhot HaAggadot	מאמר תהלוכות האגדות
R. Yachya Korach	ר' יחיא קורח
Marpe Lashon	מרפא לשון
R. Yehuda Leib Krinsky	ר' יהודה ליב קרינסקי
Mechokekei Yehuda Yahel Or	מחוקקי יהודה – יהל אור
Mechokekei Yehuda Karnei Or	מחוקקי יהודה – קרני אור
R. Yisrael Meir HaKohen Kagan	ר' ישראל מאיר הכהן מראדין
Mishna Berurah	משנה ברורה
Mishna Berurah Orach Chayyim	משנה ברורה
Mishna Brura	משנה ברורה
Mishna Brurah	משנה ברורה
Mishna Berura	משנה ברורה
Mishnah Berurah	משנה ברורה
Mishnah Berura	משנה ברורה
Mishnah Brura	משנה ברורה
Mishnah Brurah	משנה ברורה
MB	משנה ברורה
Shaar HaTziyyun	שער הציון
Shaar HaTziyyun Orach Chayyim	שער הציון
R. David Zvi Hoffmann	ר' דוד צבי הופמן
R. D.Z. Hoffmann	ר' דוד צבי הופמן
R. D\"Z Hoffmann	ר' דוד צבי הופמן
Teshuvot Melamed LeHoil	תשובות מלמד להועיל
R. Meir Simcha of Dvinsk	ר' מאיר שמחה מדווינסק
R. Meir Simchah of Dvinsk	ר' מאיר שמחה מדווינסק
R. Meir Simchah	ר' מאיר שמחה מדווינסק
Meshekh Chokhmah	משך חכמה
Meshekh Chokhma	משך חכמה
Meshech Chokhmah	משך חכמה
Meshekh Hokhmah	משך חכמה
Or Sameach	אור שמח
Ohr Sameach	אור שמח
Ridbaz	רידב\"ז
R. Yaakov Dovid Wilovsky	רידב\"ז
Chidushei Ridbaz	חידושי רידב\"ז
Chiddushei Ridbaz	חידושי רידב\"ז
Chidushei Ridvaz	חידושי רידב\"ז
Tosefot Ridbaz	תוספות רידב\"ז
Tosefot Ridvaz	תוספות רידב\"ז
Tosafot Ridbaz	תוספות רידב\"ז
Chevel Yosef	חבל יוסף
Ulam HaMishpat	חבל יוסף
R. Perlow Sefer HaMitzvot LeRasag	ר' פרלא ספר המצוות לרס\"ג
R. Perlow Sefer HaMitzvot LeRasag Introduction	מבוא
R. Perlow Sefer HaMitzvot LeRasag Positive Commandments	מצוות עשה
R. Perlow Sefer HaMitzvot LeRasag Negative Commandments	מצוות לא תעשה
Punishments Introduction	מבוא לעונשין
R. Perlow Sefer HaMitzvot LeRasag Punishments Introduction	מבוא לעונשין
R. Perlow Sefer HaMitzvot LeRasag Punishments	עונשין
Parshiyot Introduction	מבוא לפרשיות
R. Perlow Sefer HaMitzvot LeRasag Parshiyot Introduction	מבוא לפרשיות
R. Perlow Sefer HaMitzvot LeRasag Parshiyot	פרשיות
Miluim	מילואים
R. Perlow Sefer HaMitzvot LeRasag Miluim	מילואים
R. Yehudah Aryeh Leib Alter	ר' יהודה אריה ליב אלתר
Sefat Emet	שפת אמת
Sefas Emes	שפת אמת
R. Chaim Soloveitchik	ר' חיים הלוי סולוביצ'יק
R. Chaim Soloveichik	ר' חיים הלוי סולוביצ'יק
Chidushei R. Chaim HaLevi	חידושי ר' חיים הלוי
Chiddushei R. Chaim HaLevi	חידושי ר' חיים הלוי
R. Chaim Hirschensohn	ר' חיים הירשנזון
R. Yosef Rosin	ר' יוסף רוזין
Tzafenat Paneach (Rogatchover)	צפנת פענח
R. Yosef Engel	ר' יוסף ענגל
Derekh HaKodesh	דרך הקדש
Torah Temimah	תורה תמימה
Benno Jacob	בנו יעקב
R. Chaim Ozer Grodzinski	ר' חיים עוזר גרודזנסקי
Achiezer	אחיעזר
R. Avraham Yitzchak HaKohen Kook	ר' אברהם יצחק הכהן קוק
Ein Ayah	עין איה
Shabbat HaAretz	שבת הארץ
Olat Reiyah	עולת ראיה
Shemonah Kevatzim	שמונה קבצים
Pinkas Acharon BeBoisk	פנקס אחרון בבויסק
Pinkas Rishon LeYafo	פנקס ראשון ליפו
Pinkas Reshimot MiLondon	פנקס רשימות מלונדון
Arpelei Tohar	ערפלי טוהר
Orot	אורות
Orot HaKodesh Hakdamah	אורות הקודש הקדמה
Orot HaKodesh Nispachim	אורות הקודש נספחים
Orot HaTeshuvah	אורות התשובה
Orot HaTorah	אורות התורה
Orot HaEmunah	אורות האמונה
Orot HaNevuah	אורות הנבואה
LiNvukhei HaDor	לנבוכי הדור
Midbar Shur	מדבר שור
Musar Avikha	מוסר אביך
Maamar HaDor	מאמר הדור
Avodat HaMelekh	עבודת המלך
R. Yaakov Chayyim Sofer	ר' יעקב חיים סופר
Kaf HaChayyim	כף החיים
R. Isser Zalman Meltzer	ר' איסר זלמן מלצר
Even HaEzel	אבן האזל
R. Amram Korach	ר' עמרם קרח
Neveh Shalom	נוה שלום
R. Tzvi Pesach Frank	ר' צבי פסח פראנק
R. Zvi Pesach Frank	ר' צבי פסח פראנק
R. Elchonon Wasserman	ר' אלחנן וסרמן
Kovetz Shiurim	קובץ שיעורים
R. Avraham Yeshayahu Karelitz	ר' אברהם ישעיהו קרליץ
R. Moshe Soloveichik	ר' משה סולוביצ'יק
R. Moses Soloveichik	ר' משה סולוביצ'יק
R. Moses Soloveitchik	ר' משה סולוביצ'יק
Chidushei HaGram HaLevi	חדושי הגר\"מ הלוי
Chiddushei HaGram HaLevi	חדושי הגר\"מ הלוי
Chidushei HaGram VeHaGrid	חדושי הגר\"מ והגרי\"ד
Chiddushei HaGram VeHaGrid	חדושי הגר\"מ והגרי\"ד
Oznayim LaTorah	אזנים לתורה
R. Yosef Eliyahu Henkin	ר' יוסף אליהו הנקין
R. Moshe Avigdor Amiel	ר' משה אביגדור עמיאל
R. Moshe Amiel	ר' משה אביגדור עמיאל
Darkhei Moshe Derekh HaKodesh	דרכי משה דרך הקודש
Darchei Moshe Derech HaKodesh	דרכי משה דרך הקודש
Darkhei Moshe Darkhei HaKinyanim	דרכי משה דרכי הקנינים
Darchei Moshe Darchei HaKinyanim	דרכי משה דרכי הקנינים
Derashot El Ammi	דרשות אל עמי
LiNvukhei HaTekufah	לנבוכי התקופה
Darkah Shel Torah	דרכה של תורה
Ethics and Legality in Jewish Law	הצדק הסוציאלי והצדק המשפטי והמוסרי שלנו
Justice in the Jewish State	הצדק הסוציאלי והצדק המשפטי והמוסרי שלנו
U. Cassuto	מ\"ד קאסוטו
Prof. U. Cassuto	מ\"ד קאסוטו
M.D. Cassuto	מ\"ד קאסוטו
Umberto Cassuto	מ\"ד קאסוטו
Cassuto	מ\"ד קאסוטו
R. Yechiel Yaakov Weinberg	ר' יחיאל יעקב ווינברג
Chidushei Baal Seridei Eish	חדושי בעל שרידי אש
Chidushei Baal Seridei Aish	חדושי בעל שרידי אש
Mechkarim Seridei Eish	מחקרים – שרידי אש
Mechkarim	מחקרים – שרידי אש
Mechkarim Intro	על דרך המחקר
Mechkarim Mishna	מחקרים במשנה
Mechkarim Tosefta	מחקרים בתוספתא
Mechkarim Bavli	מחקרים בתלמוד בבלי
Mechkarim Yerushalmi	מחקרים בתלמוד ירושלמי
Mechkarim Targumim	מחקרים בתרגומים
Mechkarim Rambam	מחקרים ברמב\"ם
Mechkarim Shonim	מחקרים שונים
Lifrakim	לפרקים
Lifrakim Meorot HaMusar	לפרקים – מאורות המוסר
Lifrakim Geon Yaakov	לפרקים – גאון יעקב
Lifrakim LeNefesh Tidreshenu	לפרקים – לנפש תדרשנו
Lifrakim Adat Yisrael	לפרקים – עדת ישראל
Lifrakim Hosafot	לפרקים – הוספות
Lifrakim Al HaParashah	לפרקים – על הפרשה
Lifrakim Original Edition	לפרקים – מהדורה קמא
Teshuvot Seridei Eish	תשובות שרידי אש
Introduction and Contents	הקדמה ותוכן
Teshuvot Seridei Eish Introduction and Contents	הקדמה ותוכן
Teshuvot Seridei Eish Orach Chayyim	אורח חיים
Teshuvot Seridei Eish Yoreh Deah	יורה דעה
Teshuvot Seridei Eish Even HaEzer	אבן העזר
Teshuvot Seridei Eish Choshen Mishpat	חושן משפט
Kodashim and Taharot	קדשים וטהרות
Teshuvot Seridei Eish Kodashim and Taharot	קדשים וטהרות
R. Yitzchok Ze'ev Soloveitchik	ר' יצחק זאב סולוביצ'יק
Griz	ר' יצחק זאב סולוביצ'יק
R. Yitzchok Zeev Soloveitchik	ר' יצחק זאב סולוביצ'יק
R. Yitzchok Ze'ev Soloveichik	ר' יצחק זאב סולוביצ'יק
R. Yitzchok Zeev Soloveichik	ר' יצחק זאב סולוביצ'יק
Chidushei HaGriz	חדושי הגרי\"ז
R. Aharon Kotler	ר' אהרן קוטלר
R. Aaron Kotler	ר' אהרן קוטלר
Otzar HaPoskim	אוצר הפוסקים
R. Yaakov Kamenetsky	ר' יעקב קמינצקי
Emet LeYaakov	אמת ליעקב
R. Yaakov Kamenetsky Emet LeYaakov	אמת ליעקב
R. Menachem Kasher	ר' מנחם כשר
Rav Kasher	ר' מנחם כשר
Torah Shelemah	תורה שלמה
R. Moshe Feinstein	ר' משה פיינשטיין
R. Moses Feinstein	ר' משה פיינשטיין
Iggerot Moshe	אגרות משה
Igros Moshe	אגרות משה
Dibberot Moshe	דברות משה
Dibros Moshe	דברות משה
R. Shaul Lieberman	ר' שאול ליברמן
R. Saul Lieberman	ר' שאול ליברמן
Tosefta Kifshutah	תוספתא כפשוטה
Tosefta KiPeshutah	תוספתא כפשוטה
Tosefta KiPshutah	תוספתא כפשוטה
Tosefta KiPeshuta	תוספתא כפשוטה
Tosefta KiPshuta	תוספתא כפשוטה
Tosefta Short Commentary	פירוש קצר לתוספתא
Masoret HaTosefta	מסורת התוספתא
Massoret HaTosefta	מסורת התוספתא
HaYerushalmi Kifshuto	הירושלמי כפשוטו
Yerushalmi Kifshuto	הירושלמי כפשוטו
HaYerushalmi KiPeshuto	הירושלמי כפשוטו
HaYerushalmi KiPshuto	הירושלמי כפשוטו
Yerushalmi KiPeshuto	הירושלמי כפשוטו
Yerushalmi KiPshuto	הירושלמי כפשוטו
R. Menachem Mendel Schneerson	ר' מנחם מנדל שניאורסון
Lubavitcher Rebbe	ר' מנחם מנדל שניאורסון
R. Yosef Dov Soloveitchik	ר' יוסף דב סולוביצ'יק
R. Yosef Dov Soloveichik	ר' יוסף דב סולוביצ'יק
R. Joseph B. Soloveitchik	ר' יוסף דב סולוביצ'יק
R. Joseph B. Soloveichik	ר' יוסף דב סולוביצ'יק
R. Yosef Soloveitchik	ר' יוסף דב סולוביצ'יק
R. Yosef Soloveichik	ר' יוסף דב סולוביצ'יק
R. Joseph Soloveitchik	ר' יוסף דב סולוביצ'יק
R. Joseph Soloveichik	ר' יוסף דב סולוביצ'יק
R. Y\"D Soloveitchik	ר' יוסף דב סולוביצ'יק
R. Y.D. Soloveitchik	ר' יוסף דב סולוביצ'יק
Chumash Mesoras HaRav	חומש מסורת הרב
Reshimot Shiurim	רשימות שיעורים לגרי\"ד
Nechama Leibowitz	נחמה ליבוביץ
Nechama	נחמה ליבוביץ
R. Shelomo Zalman Auerbach	ר' שלמה זלמן אויערבאך
R. Shlomo Zalman Auerbach	ר' שלמה זלמן אויערבאך
Yehuda Elitzur	יהודה אליצור
R. Yosef Kapach	ר' יוסף קאפח
R. Yosef Qafih	ר' יוסף קאפח
Peirush HaRav Kapach	פירוש הרב קאפח
Rav Kapach Notes on Tafsir Rasag	הערות הרב קאפח על תפסיר רס\"ג
R. Ahron Soloveichik	ר' אהרן סולובייצ'יק
Logic of the Heart	ההיגיון של הלב
R. Aharon Lichtenstein	ר' אהרן ליכטנשטיין
Rav Lichtenstein	ר' אהרן ליכטנשטיין
Shiurei HaRav Aharon Lichtenstein	שיעורי הרב אהרן ליכטנשטיין
R. Nachum Rabinovitch	ר' נחום רבינוביץ
Rav Rabinovitch	ר' נחום רבינוביץ
Yad Peshutah	יד פשוטה
Yad Kifshutah	יד כפשוטה
Parshegen	פרשגן
Steinsaltz Commentary	ביאור שטיינזלץ
Teshuvot BeMareh HaBazak	שו\"ת במראה הבזק
BeMareh HaBazak	שו\"ת במראה הבזק
Mishnat Eretz Yisrael	משנת ארץ ישראל
Mishnat Erez Yisrael	משנת ארץ ישראל
Hebrew Translation	תרגום עברי
Penei Moshe - Derekh HaKadmonim	פני משה – דרך הקדמונים
Beikvot Rashi	בעקבות רש\"י
R. Elhanan Samet	ר' אלחנן סמט
Rav Samet	ר' אלחנן סמט
Shiurei HaRav Elhanan Samet	שיעורי הרב אלחנן סמט
Torah Temimah R. Shemuel Navon	תורה תמימה – הרב שמואל נבון
Lev Aharon	לב אהרן
Mareh Rachel	מראה רחל
Mikraot Sheluvot	מקראות שלובות
Avnei HaTargum	אבני התרגום
Peshat VeOmek BaMikra	פשט ועומק במקרא
Ohr LaYesharim	אור לישרים
Or LaYesharim	אור לישרים
Galei Yam	גלי ים
Commentary on Rambam Commentary on the Mishna	ביאור לפירוש רמב\"ם למשנה
Tosefta Commentary	ביאור לתוספתא
Tosefta Excurses	הרחבות לביאור התוספתא
Tosefta Apparatus	שינויי נוסחאות לתוספתא
Hilkhot HaRif Kifshutan	הלכות הרי\"ף כפשוטן
Aggan HaSahar - Collected from Zohar	אגן הסהר - מלוקט מספר הזהר
Shulchan Arukh Kifshuto	שולחן ערוך כפשוטו
Or Chadash - Tashlum Beit Yosef	אור חדש - תשלום בית יוסף
Selected Masoretic Notes	ליקוט הערות מסורה
R. Shemuel Avraham Adler	ר' שמואל אברהם אדלר
Aspaklaria	אספקלריא
Aleph	א
Aspaklaria Aleph	א
Bet	ב
Aspaklaria Bet	ב
Gimel	ג
Aspaklaria Gimel	ג
Daled	ד
Aspaklaria Daled	ד
Heh	ה
Aspaklaria Heh	ה
Vav	ו
Aspaklaria Vav	ו
Zayin	ז
Aspaklaria Zayin	ז
Chet	ח
Aspaklaria Chet	ח
Tet	ט
Aspaklaria Tet	ט
Yod	י
Aspaklaria Yod	י
Kaf	כ
Aspaklaria Kaf	כ
Lamed	ל
Aspaklaria Lamed	ל
Mem	מ
Aspaklaria Mem	מ
Nun	נ
Aspaklaria Nun	נ
Samekh	ס
Aspaklaria Samekh	ס
Ayin	ע
Aspaklaria Ayin	ע
Peh	פ
Aspaklaria Peh	פ
Tzadi	צ
Aspaklaria Tzadi	צ
Qof	ק
Aspaklaria Qof	ק
Resh	ר
Aspaklaria Resh	ר
Shin	ש
Aspaklaria Shin	ש
Tav	ת
Aspaklaria Tav	ת
Biblical Parallels	מקבילות במקרא
Mitzvot Links	מוני המצוות
Illuminated Haggadot	הגדות מאויירות
Illuminated Siddurim	סידורים מאויירים
Versions Variants	חילופים בתרגומים
Rabbinic Variants	חילופים בספרות חז\"ל
Masoretic Variants	חילופים בכ\"י של המסורה
Spelling, Vowels, and Accents	כתיב, ניקוד, וטעמים
Audio	אודיו
Audio Bavli	דף יומי אודיו
Audio Yerushalmi	דף יומי אודיו
Olam HaMikra	עולם המקרא
Olam HaMishna	עולם המשנה
Olam HaTalmud	עולם התלמוד
Olam HaHaggadah	עולם ההגדה
Olam HaSiddur	עולם הסידור
Haggadat Eretz Yisrael	הגדה ארץ-ישראלית
Siddur Eretz Yisrael	סידור ארץ-ישראלי
Collected Articles	אסופת מאמרים
Kishurim LaTalmudim	קישורים לתלמודים
Kishurim	קישורים
Mishneh Torah Sources	מקורות למשנה תורה
Tur Sources	מקורות לטור
Shulchan Arukh Sources	מקורות לשולחן ערוך
Siddur Arba Kanfot HaAretz	סידור ארבע כנפות הארץ
Collected from Arugat HaBosem	ליקוט מערוגת הבשם
Collected from Shibbolei HaLeket	ליקוט משבלי הלקט
Collected from Orchot Chayyim	ליקוט מארחות חיים
Collected from Kol Bo	ליקוט מכל בו
Collected from Meiri	ליקוט מן המאירי
Collected from R. S.R. Hirsch	ליקוט מרש\"ר הירש
Collected from R. David Zvi Hoffmann	ליקוט מר' דוד צבי הופמן
Collected from Abarbanel	ליקוט מאברבנאל
Collected from Amar Nekei	ליקוט מעמר נקא
Collected from Anonymous Northern French Commentary	ליקוט מפירוש מחכמי צרפת
Collected from Attributed to Rosh	ליקוט ממיוחס לרא\"ש
Collected from Chizkuni	ליקוט מחזקוני
Collected from Daat Zekeinim	ליקוט מדעת זקנים
Collected from Divrei David	ליקוט מדברי דוד
Collected from Em LaMikra	ליקוט מאם למקרא
Collected from HaKetav VeHaKabbalah	ליקוט מהכתב והקבלה
Collected from HaRekhasim Levik'ah	ליקוט מהרכסים לבקעה
Collected from Hadar Zekeinim	ליקוט מהדר זקנים
Collected from Hoil Moshe	ליקוט מהואיל משה
Collected from Ibn Ezra	ליקוט מאבן עזרא
Collected from Keli Yekar	ליקוט מכלי יקר
Collected from Lekach Tov	ליקוט מלקח טוב
Collected from Maharal	ליקוט מספרי מהר\"ל
Collected from Malbim	ליקוט ממלבי\"ם
Collected from Maskil LeDavid	ליקוט ממשכיל לדוד
Collected from Meshekh Chokhmah	ליקוט ממשך חכמה
Collected from Metzudat David	ליקוט ממצודת דוד
Collected from Metzudat Zion	ליקוט ממצודת ציון
Collected from Minchat Yehuda	ליקוט ממנחת יהודה
Collected from Netziv	ליקוט מנצי\"ב
Collected from Or HaChayyim	ליקוט מאור החיים
Collected from R. Avraham b. HaRambam	ליקוט מר' אברהם בן הרמב\"ם
Collected from R. Bachya	ליקוט מר' בחיי
Collected from R. Eliezer of Beaugency	ליקוט מר' אליעזר מבלגנצי
Collected from R. Eliyahu Mizrachi	ליקוט מר' אליהו מזרחי
Collected from R. Moshe Alshikh	ליקוט מר' משה אלשיך
Collected from R. Moshe ibn Chiquitilla	ליקוט מר' משה אבן ג'יקטילה
Collected from R. Yehuda ibn Balaam	ליקוט מר' יהודה אבן בלעם
Collected from R. Yosef Bekhor Shor	ליקוט מר' יוסף בכור שור
Collected from R. Yosef ibn Kaspi	ליקוט מר' יוסף אבן כספי
Collected from R. Yosef Kara	ליקוט מר' יוסף קרא
Collected from Radak	ליקוט מרד\"ק
Collected from Ralbag	ליקוט מרלב\"ג
Collected from Rambam	ליקוט מרמב״ם
Collected from Ramban	ליקוט מרמב\"ן
Collected from Rashbam	ליקוט מרשב\"ם
Collected from Rashi	ליקוט מפירושי רש\"י
Collected from Sefat Emet	ליקוט משפת אמת
Collected from Seikhel Tov	ליקוט משכל טוב
Collected from Seridei Eish	הגדה על פי השרידי אש
Collected from Sforno	ליקוט מספורנו
Collected from Shadal	ליקוט משד\"ל
Collected from Shiurei Sforno	ליקוט משיעורי ר' עובדיה ספורנו
Collected from Siftei Chakhamim	ליקוט משפתי חכמים
Collected from Toledot Yitzchak	ליקוט מתולדות יצחק
Collected from Torah Temimah	ליקוט מתורה תמימה
Collected from Tur	ליקוט מטור
Collected from Tzeror HaMor	ליקוט מצרור המור
Collected from Vilna Gaon (GR\"A)	ליקוט מהגאון מוילנא (הגר\"א)
"""

    public static let (enToHe, heToEn): ([String: String], [String: String]) = {
        var e2h: [String: String] = [:]
        var h2e: [String: String] = [:]
        let lines = data.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let en = String(parts[0])
            let he = String(parts[1])
            if e2h[en] == nil { e2h[en] = he }
            if h2e[he] == nil { h2e[he] = en }
        }
        return (e2h, h2e)
    }()

    public static func hebrew(for english: String) -> String? {
        enToHe[english]
    }

    public static func english(for hebrew: String) -> String? {
        heToEn[hebrew]
    }
}

public enum HebrewNames {
    public static func hebrewBook(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let canonical = AlHaTorahCanonicalTitles.hebrew(for: trimmed) {
            return canonical
        }
        return trimmed
    }

    public static func englishBook(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let canonical = AlHaTorahCanonicalTitles.english(for: trimmed) {
            return canonical
        }
        return trimmed
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

    public static func canonicalMg(from base: String?) -> String {
        guard let base = base?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else {
            return "Tanakh"
        }
        switch base.lowercased() {
        case "tanakh", "torah", "bible":
            return "Tanakh"
        case "shas", "bavli", "talmud":
            return "Shas"
        case "mishna", "mishnah":
            return "Mishna"
        case "rambam":
            return "Rambam"
        case "tur":
            return "Tur"
        case "shulchan arukh", "shulchanarukh", "shulchan_arukh":
            return "Shulchan Arukh"
        case "tosefta":
            return "Tosefta"
        case "yerushalmi":
            return "Yerushalmi"
        case "library":
            return "Library"
        default:
            return base.prefix(1).uppercased() + base.dropFirst()
        }
    }
}
