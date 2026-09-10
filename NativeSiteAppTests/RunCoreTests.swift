import Foundation

// Simple assertion helper
func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if actual != expected {
        print("FAIL: [\(file):\(line)] expected \(expected) but got \(actual). \(message)")
        exit(1)
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if !condition {
        print("FAIL: [\(file):\(line)] condition was false. \(message)")
        exit(1)
    }
}

@main
struct CoreTestRunner {
    static func main() {
        print("Running AlHaTorah Core Unit Tests...")

        // MARK: - Test 1: Location URL Parsing & Generation
        do {
            print("  -> Testing AlHaTorahLocation URL Parsing & Generation")
            
            // 1A: Tanakh Full Mode with explicit corpus (4 segments: Full / Tanakh / Shemot / 6.1)
            let url1 = URL(string: "https://mg.alhatorah.org/Full/Tanakh/Shemot/6.1")!
            let loc1 = AlHaTorahLocation.from(url: url1)
            assertTrue(loc1 != nil, "Should parse Tanakh URL")
            assertEqual(loc1?.mg, "Tanakh")
            assertEqual(loc1?.book, "Shemot")
            assertEqual(loc1?.unit, "6")
            assertEqual(loc1?.subUnit, 1)
            assertEqual(loc1?.parshan, "_mainVerse")
            assertEqual(loc1?.displayTitle, "שמות ו, א")
            assertEqual(loc1?.displayTitleEn, "Shemot 6:1")
            assertEqual(loc1?.readerURL?.absoluteString, "https://mg.alhatorah.org/Full/Tanakh/Shemot/6.1")

            // 1B: Tanakh Full Mode with implicit corpus (3 segments: Full / Devarim / 32.1)
            // Real device failure: previously parsed as mg="Devarim", book="32.1"
            let urlDevarim = URL(string: "https://mg.alhatorah.org/Full/Devarim/32.1")!
            let locDevarim = AlHaTorahLocation.from(url: urlDevarim)
            assertTrue(locDevarim != nil, "Should parse 3-segment Full URL")
            assertEqual(locDevarim?.type, "mg-full")
            assertEqual(locDevarim?.mg, "Tanakh")
            assertEqual(locDevarim?.book, "Devarim")
            assertEqual(locDevarim?.unit, "32")
            assertEqual(locDevarim?.subUnit, 1)
            assertEqual(locDevarim?.parshan, "_mainVerse")
            assertEqual(locDevarim?.displayTitle, "דברים לב, א")

            // 1C: Dual Mode with Commentator (4 segments: Dual / Rashi / Shemot / 6.1)
            let url2 = URL(string: "https://mg.alhatorah.org/Dual/Rashi/Shemot/6.1")!
            let loc2 = AlHaTorahLocation.from(url: url2)
            assertTrue(loc2 != nil, "Should parse Dual mode URL")
            assertEqual(loc2?.type, "mg-dual")
            assertEqual(loc2?.parshan, "Rashi")
            assertEqual(loc2?.book, "Shemot")
            assertEqual(loc2?.unit, "6")
            assertEqual(loc2?.subUnit, 1)
            assertEqual(loc2?.displayTitle, "שמות ו, א • Rashi")
            assertEqual(loc2?.readerURL?.absoluteString, "https://mg.alhatorah.org/Dual/Rashi/Shemot/6.1")

            // 1D: Shas Full Mode (4 segments: Full / Shas / Berakhot / 2a)
            let url3 = URL(string: "https://shas.alhatorah.org/Full/Shas/Berakhot/2a")!
            let loc3 = AlHaTorahLocation.from(url: url3)
            assertTrue(loc3 != nil, "Should parse Shas URL")
            assertEqual(loc3?.mg, "Shas")
            assertEqual(loc3?.book, "Berakhot")
            assertEqual(loc3?.unit, "2a")
            assertEqual(loc3?.displayTitle, "ברכות ב, ע\"א")
            assertEqual(loc3?.readerURL?.absoluteString, "https://shas.alhatorah.org/Full/Shas/Berakhot/2a")

            // 1E: Shas 3-segment URL (Full / Berakhot / 2a)
            let urlShas3 = URL(string: "https://shas.alhatorah.org/Full/Berakhot/2a")!
            let locShas3 = AlHaTorahLocation.from(url: urlShas3)
            assertTrue(locShas3 != nil, "Should parse 3-segment Shas URL")
            assertEqual(locShas3?.mg, "Shas")
            assertEqual(locShas3?.book, "Berakhot")
            assertEqual(locShas3?.unit, "2a")

            // 1F: Shas Daf 141b display title
            let loc4 = AlHaTorahLocation(type: "mg-full", mg: "Shas", book: "Shabbat", unit: "141b", subUnit: 0)
            assertEqual(loc4.displayTitle, "שבת קמא, ע\"ב")
        }

        // MARK: - Test 2: Canonical MG normalization
        do {
            print("  -> Testing HebrewNames.canonicalMg")
            assertEqual(HebrewNames.canonicalMg(from: "tanakh"), "Tanakh")
            assertEqual(HebrewNames.canonicalMg(from: "Tanakh"), "Tanakh")
            assertEqual(HebrewNames.canonicalMg(from: "shas"), "Shas")
            assertEqual(HebrewNames.canonicalMg(from: "mishna"), "Mishna")
            assertEqual(HebrewNames.canonicalMg(from: "rambam"), "Rambam")
            assertEqual(HebrewNames.canonicalMg(from: "tur"), "Tur")
            assertEqual(HebrewNames.canonicalMg(from: "shulchan arukh"), "Shulchan Arukh")
            assertEqual(HebrewNames.canonicalMg(from: "unknown_custom"), "Unknown_custom")
        }

        // MARK: - Test 3: FormURLEncoder & Paragraph Normalization
        do {
            print("  -> Testing FormURLEncoder & Paragraph Normalization")
            
            // Paragraph 0 should normalize to omitted in form payload
            var loc = AlHaTorahLocation(book: "Shemot", unit: "6", subUnit: 1, parshan: "Rashi", paragraph: 0, begin: 5, end: 15)
            let form = loc.formUrlEncodedString()
            assertTrue(form.contains("type=mg-full"))
            assertTrue(form.contains("book=Shemot"))
            assertTrue(form.contains("unit=6"))
            assertTrue(form.contains("subUnit=1"))
            assertTrue(form.contains("parshan=Rashi"))
            assertTrue(!form.contains("paragraph=0"), "Paragraph 0 should be normalized/omitted in form payload")
            assertTrue(form.contains("begin=5"))
            assertTrue(form.contains("end=15"))

            // Paragraph 1 should be explicitly preserved
            loc.paragraph = 1
            let form2 = loc.formUrlEncodedString()
            assertTrue(form2.contains("paragraph=1"), "Paragraph 1 should be included in form payload")

            // FormURLEncoder RFC 3986 encoding test with spaces, Hebrew, and special chars
            let rawParams: [(String, String)] = [
                ("text", "שלום עולם & testing + more = 1"),
                ("tag", "תורה")
            ]
            let encoded = FormURLEncoder.encode(rawParams)
            assertTrue(encoded.contains("%20"), "Spaces should be %20 encoded")
            assertTrue(encoded.contains("%26"), "& should be encoded as %26")
            assertTrue(encoded.contains("%2B"), "+ should be encoded as %2B")
            assertTrue(encoded.contains("%3D"), "= should be encoded as %3D")
            assertTrue(!encoded.contains(" "), "Should not contain unencoded spaces")

            // JSON Encoding normalization: paragraph 0 -> null
            loc.paragraph = 0
            let encoder = JSONEncoder()
            let data = try! encoder.encode(loc)
            let jsonString = String(data: data, encoding: .utf8)!
            assertTrue(jsonString.contains("\"paragraph\":null"), "Paragraph 0 should encode to null in JSON: \(jsonString)")

            loc.paragraph = 2
            let data2 = try! encoder.encode(loc)
            let jsonString2 = String(data: data2, encoding: .utf8)!
            assertTrue(jsonString2.contains("\"paragraph\":2"), "Paragraph 2 should encode to 2 in JSON: \(jsonString2)")
        }

        // MARK: - Test 4: Dashboard HTML Parser (SSR without class="history-item")
        do {
            print("  -> Testing AlHaTorahDashboardParser with SSR rows lacking history-item class")

            let htmlFixture = """
            <div class="board-section board-history">
              <table class="table">
                <tbody>
                  <tr data-id="6a46445db5203c009940b197"
                      data-base="tanakh"
                      data-locnum="001:004:031:1902"
                      data-date="2026-07-02T10:58:37.303Z">
                    <td class="pr-1"><span class="mg-lang-he lang-he">תנ"ך</span><span class="mg-lang-en lang-en">Tanakh</span></td>
                    <td class="pr-1"><a href="https://mg.alhatorah.org/Dual/Sifre Bemidbar/Bemidbar/31.1">במדבר לא, א</a></td>
                    <td class="pr-1"><span class="mg-lang-he lang-he">ספרי במדבר</span><span class="mg-lang-en lang-en">Sifre Bemidbar</span></td>
                    <td><time datetime="2026-07-02T10:58:37.303Z" data-format="calendar">02/07/2026</time></td>
                    <td class="pr-1"><span class="btn-delete"></span></td>
                  </tr>
                  <tr data-id="6a46445db5203c009940b198"
                      data-base="shas"
                      data-locnum="012:014:141:0002:027:7214"
                      data-date="2026-07-01T08:15:00.000Z"
                      class="history-item">
                    <td class="pr-1"><span class="mg-lang-he lang-he">ש"ס</span></td>
                    <td class="pr-1"><a href="https://shas.alhatorah.org/Full/Shas/Shabbat/141b">שבת קמא, ב</a></td>
                    <td class="pr-1"></td>
                    <td><time datetime="2026-07-01T08:15:00.000Z">01/07/2026</time></td>
                    <td class="pr-1"><span class="btn-delete"></span></td>
                  </tr>
                </tbody>
              </table>
            </div>
            """

            let history = AlHaTorahDashboardParser.parseHistory(from: htmlFixture)
            assertEqual(history.count, 2, "Should parse both history items even when class='history-item' is missing")

            let first = history[0]
            assertEqual(first.id, "6a46445db5203c009940b197")
            assertEqual(first.base, "tanakh")
            assertEqual(first.locnum, "001:004:031:1902")
            assertEqual(first.title, "במדבר לא, א")
            assertEqual(first.urlString, "https://mg.alhatorah.org/Dual/Sifre Bemidbar/Bemidbar/31.1")
            assertEqual(first.commentator, "ספרי במדבר")
            assertEqual(first.displayCorpus, "תנ\"ך")

            let second = history[1]
            assertEqual(second.id, "6a46445db5203c009940b198")
            assertEqual(second.base, "shas")
            assertEqual(second.title, "שבת קמא, ב")
            assertEqual(second.urlString, "https://shas.alhatorah.org/Full/Shas/Shabbat/141b")
            assertEqual(second.displayCorpus, "ש\"ס")
        }

        // MARK: - Test 5: Tolerant Export JSON Decoding
        do {
            print("  -> Testing Tolerant Export JSON Decoding (corrupt items isolated)")

            let jsonWithOneCorruptedItem = """
            {
              "_id": "user-123",
              "data": {
                "bookmark": [
                  {
                    "_id": "bm-1",
                    "dataType": "bookmark",
                    "location": {
                      "base": "tanakh",
                      "book": "Bereishit",
                      "largeUnit": "1",
                      "subUnit": 1
                    },
                    "date": "2026-01-01T00:00:00.000Z"
                  },
                  {
                    "corrupt": true
                  }
                ],
                "gilayon": [
                  {
                    "_id": "note-1",
                    "dataType": "gilayon",
                    "location": {
                      "base": "tanakh",
                      "book": "Shemot",
                      "largeUnit": "2",
                      "subUnit": "3",
                      "parshan": "_mainVerse"
                    },
                    "content": "<p>הערה לדוגמה</p>",
                    "date": "2026-01-02T00:00:00.000Z"
                  }
                ],
                "highlight": []
              }
            }
            """.data(using: .utf8)!

            let decoder = JSONDecoder()
            let response = try! decoder.decode(AlHaTorahExportResponse.self, from: jsonWithOneCorruptedItem)
            guard let payload = response.data else {
                assertTrue(false, "Response data payload should not be nil")
                return
            }
            
            assertEqual(payload.bookmark?.count ?? 0, 1, "Should salvage the valid bookmark and drop the corrupt one")
            assertEqual(payload.bookmark?[0].location?.book, "Bereishit")
            assertEqual(payload.bookmark?[0].toBookmark()?.location.mg, "Tanakh", "Should normalize base to canonical Mg")

            assertEqual(payload.gilayon?.count ?? 0, 1, "Should parse the valid note")
            let note = payload.gilayon?[0].toNote()
            assertTrue(note != nil)
            assertEqual(note?.id, "note-1")
            assertEqual(note?.location.subUnit, 3, "subUnit string '3' should decode tolerantly to 3")
            assertEqual(note?.location.mg, "Tanakh")
            assertEqual(note?.plainContent, "הערה לדוגמה")
        }

        // MARK: - Test 6: Notes HTML Stripping
        do {
            print("  -> Testing AlHaTorahNote HTML stripping")
            let rawHtml = "<p dir=\"rtl\" class=\"ql-align-right\">רש״י ורשב״ם פירשו...<br>פירוש נוסף &amp; הסבר</p>"
            let plain = AlHaTorahNote.stripHTML(from: rawHtml)
            assertTrue(plain.contains("רש״י ורשב״ם פירשו..."))
            assertTrue(plain.contains("פירוש נוסף & הסבר"))
            assertTrue(!plain.contains("<p"))
            assertTrue(!plain.contains("</p>"))
            assertTrue(!plain.contains("&amp;"))
        }

        // MARK: - Test 7: Color Palette
        do {
            print("  -> Testing AlHaTorahPaletteColor presets")
            assertEqual(AlHaTorahPaletteColor.all.count, 6)
            assertEqual(AlHaTorahPaletteColor.yellow.hex, "#fffc6a")
            assertEqual(AlHaTorahPaletteColor.pink.hex, "#ffaed7")
            assertEqual(AlHaTorahPaletteColor.orange.hex, "#ffa579")
            assertEqual(AlHaTorahPaletteColor.green.hex, "#88ff88")
            assertEqual(AlHaTorahPaletteColor.blue.hex, "#81d1ff")
            assertEqual(AlHaTorahPaletteColor.purple.hex, "#bf80ff")
        }

        print("ALL CORE UNIT TESTS PASSED SUCCESSFULLY! (7/7)")
    }
}
