# AlHaTorah Logged-in User API Research

This document details the observed API architecture, endpoints, authentication model, and data formats for AlHaTorah's logged-in user features (bookmarks, personal notes, highlights, and history), recorded directly from real browser network activity on `users.alhatorah.org` and `mg.alhatorah.org`.

---

## 1. Authentication & Session Model

* **Base Auth Domain**: `https://users.alhatorah.org`
* **Session Cookie**:
  * **Name**: `connect.sid`
  * **Domain**: `users.alhatorah.org`
  * **Path**: `/`
  * **Security Flags**: `HttpOnly: true`, `Secure: true`, `SameSite: None`
  * **Nature**: Standard Express.js session cookie (`x-powered-by: Express`).
* **Cross-Origin / CORS**:
  * The frontend reader apps run on subdomains (`https://mg.alhatorah.org`, `https://shas.alhatorah.org`, `https://library.alhatorah.org`, etc.).
  * Requests to `https://users.alhatorah.org` use `credentials: 'include'` (jQuery `xhrFields: { withCredentials: true }`).
  * Response headers include:
    * `access-control-allow-origin: <calling-origin>`
    * `access-control-allow-credentials: true`
    * `vary: Origin,User-Agent`
* **CSRF Token**:
  * **None**. No CSRF token header (`X-CSRF-Token`) or parameter is required or used.
* **Session Verification Endpoint (`whois`)**:
  * **Endpoint**: `GET https://users.alhatorah.org/json/whois`
  * **Query Parameters**: None
  * **Response (Logged In)**:
    ```json
    { "email": "user@example.com" }
    ```
  * **Response (Not Logged In)**:
    ```json
    { "err": "Please login" }
    ```
* **Full Data Export**:
  * **Endpoint**: `GET https://users.alhatorah.org/json/export`
  * **Description**: Returns the user profile and all user annotations in JSON format:
    ```json
    {
      "_id": "65ef11b14981cd91b4050fac",
      "name": "User Name",
      "email": "user@example.com",
      "createdAt": "2024-03-11T14:14:09.473Z",
      "settings": { "language.interface": "he" },
      "data": {
        "bookmark": [ ... ],
        "gilayon": [ ... ],
        "highlight": [ ... ],
        "tanakhlab": [ ... ]
      }
    }
    ```

---

## 2. Text Location Identification & Schema

AlHaTorah identifies locations across its corpus using two representations:

### Structured Location Model (Used in API Requests & Responses)
```json
{
  "type": "mg-full",            // "mg-full" (single column / Mikraot Gedolot), "mg-dual" (bilingual / two-pane), or "library"
  "mg": "Tanakh",               // Corpus identifier: "Tanakh", "Shas", "Mishna", "Rambam", "Tur", "Shulchan Arukh"
  "book": "Shemot",             // Book / tractate name (e.g. "Bereshit", "Shemot", "Shabbat", "Choshen Mishpat")
  "unit": "6",                  // Chapter or Daf (e.g. "6", "141b", "280")
  "subUnit": 1,                 // Verse or segment number (e.g. 1 for verse, 27 for Daf line, or 0 for dual-mode chapter)
  "parshan": "_mainVerse",      // "_mainVerse" (primary verse text), "_mainVerseEn" (translation), "_mainTur", or commentator name (e.g. "Rashi", "Ramban", "Beit Yosef")
  "paragraph": 0,               // 0-indexed paragraph index within the commentator/verse block (null for verse level)
  "begin": 10,                  // Character start offset within the paragraph string
  "end": 25                     // Character end offset within the paragraph string (equal to begin for insertion points like notes)
}
```

### Hierarchical Colon-Separated String (`locnum`)
Used for sorting and filtering in dashboard tables:
* **Tanakh**: `001:002:006:001:0000` (`Corpus:BookNumber:Chapter:Verse:Segment`)
* **Shas**: `012:014:141:0002:027:7214` (`Corpus:Tractate:Daf:Amud:Line:Hash`)
* **Library**: Free-form identifier string, e.g. `"Rosh Bava Kamma 2"`.

### Commentator vs. Verse Location & Paragraph Semantics

The location anchoring behavior was tested on both verse text (`_mainVerse`) and commentator paragraphs (e.g., Rashi on Shemot 6:1):

1. **`parshan` Identifier**:
   - For primary biblical text: `_mainVerse` (or `_mainVerseEn` for translation, `_mainTur` for Tur text).
   - For commentators: Set to the commentator's canonical name string matching `data-parshan` on the container element (e.g., `"Rashi"`, `"Ramban"`, `"Ibn Ezra"`, `"Rashbam"`, `"Sforno"`).

2. **`paragraph` Index Semantics**:
   - For verse text (`_mainVerse`): Always `null` (or `0` which normalizes to `null`), since each verse subunit is treated as a single container.
   - For commentators: 0-indexed integer counting preceding paragraphs within that commentator's block (`paragraph.prevAll(".parshan-p").length`).
   - **Server Normalization Behavior**:
     - When submitting `paragraph: 0` (the first paragraph of a commentary): The server normalizes this to `null` in the stored record (e.g. `"paragraph": null`).
     - When submitting `paragraph: 1`, `2`, ... (subsequent paragraphs): The server preserves the explicit integer (e.g. `"paragraph": 1`).
   - **Client Reconstruction (`locationToRange`)**:
     - In Mikraot Gedolot mode (`MG.mode === "MG"`), the web reader locates the target paragraph using `parshan.find(".parshan-p").eq(data.paragraph)[0]`.
     - In jQuery, `.eq(null)` and `.eq(0)` both resolve to the first matching element (`index 0`). Thus, `paragraph: null` correctly selects paragraph `0`, while `paragraph: 1` selects paragraph `1`.
     - When a commentator spans multiple visual columns, the reader accounts for column continuations (`.hemshekh`) by adjusting the index accordingly.

3. **`begin` and `end` Character Offsets**:
   - Measured as character offsets from the start of `paragraph[0].innerText` (or text nodes).
   - For commentary paragraphs (`.parshan-p`): The text contains no leading verse label, so `begin` and `end` directly correspond to character indices within that paragraph text.
   - For primary verses (`.pasuk`): The reader accounts for the leading verse numeral (`.pasuk-num`) during range reconstruction by adjusting the offset (`offset = $(paragraph).find('.pasuk-num').text().length`).

---

## 3. Endpoints by Feature

### A. Bookmarks / Saved Items

#### 1. Add Bookmark
* **Endpoint**: `POST https://users.alhatorah.org/json/bookmarks/add`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload**:
  * Full mode:
    ```text
    type=mg-full&mg=Tanakh&book=Shemot&unit=6&subUnit=1&parshan=_mainVerse
    ```
  * Dual mode:
    ```text
    type=mg-dual&mg=Tanakh&book=Shemot&unit=6&subUnit=0&parshan=Rashi
    ```
* **Observed Response**:
  ```json
  { "success": "added bookmark" }
  ```

#### 2. Remove Bookmark (via Bookmark Endpoint)
* **Endpoint**: `POST https://users.alhatorah.org/json/bookmarks/remove`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload**: Same payload as add.
* **Observed Response**:
  ```json
  { "success": "removed bookmark" }
  ```

#### 3. Remove Bookmark (via Generic Remove Endpoint)
* **Endpoint**: `POST https://users.alhatorah.org/json/data/remove`
* **Payload**: `id=<bookmark_object_id>`
* **Observed Response**:
  ```json
  { "success": "removed data", "removed": 1 }
  ```

#### 4. Read / Fetch Chapter Bookmarks
* Handled as part of the unified fetch endpoint `GET /json/data/get` (see Section 4).

---

### B. Personal Notes (Gilyonot / `gilayon`)

#### 1. Create Note
* **Endpoint**: `POST https://users.alhatorah.org/json/data/add`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload Parameters**:
  * `dataType`: `gilayon`
  * `title`: Note title / heading string
  * `content`: Rich-text HTML content generated by Quill editor (e.g. `<p dir="rtl">...</p>`)
  * `type`: `mg-full` or `mg-dual`
  * `mg`: Corpus name (e.g. `Tanakh`)
  * `book`: Book name (e.g. `Shemot`)
  * `unit`: Chapter/Daf (e.g. `6`)
  * `subUnit`: Verse/segment (e.g. `1`)
  * `parshan`: `_mainVerse` or commentator name
  * `paragraph`: Paragraph index (e.g. `0`)
  * `begin`: Offset anchor (integer)
  * `end`: Offset anchor (integer, matches `begin`)
* **Observed Response**:
  ```json
  {
    "success": "added data",
    "data": {
      "_id": "6aa2eddcd3defdb4a55f30b7",
      "dataType": "gilayon",
      "title": "הערת בדיקה",
      "content": "<p dir="rtl">תוכן הערת בדיקה זמנית</p>",
      "paragraph": null,
      "begin": 10,
      "end": 10,
      "type": "mg-full",
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "subUnit": 1,
        "parshan": "_mainVerse"
      }
    }
  }
  ```

#### 2. Edit / Update Note
* **Endpoint**: `POST https://users.alhatorah.org/json/data/edit`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload Parameters**:
  * `id`: MongoDB ObjectId string (e.g. `6aa2eddcd3defdb4a55f30b7`)
  * `dataType`: `gilayon` (Strictly required; sending `highlight` triggers HTTP 400 `"Invalid value"`)
  * `content`: Updated HTML string from Quill editor
* **Observed Response**:
  ```json
  {
    "success": "edited data",
    "data": {
      "_id": "6aa2eddcd3defdb4a55f30b7",
      "dataType": "gilayon",
      "title": "הערת בדיקה",
      "content": "<p dir="rtl">תוכן הערה מעודכן לחלוטין</p>",
      "paragraph": null,
      "begin": 10,
      "end": 10,
      "type": "mg-full",
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "subUnit": 1,
        "parshan": "_mainVerse"
      }
    }
  }
  ```

#### 3. Delete Note
* **Endpoint**: `POST https://users.alhatorah.org/json/data/remove`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload Parameters**:
  * `id`: Note ID string (e.g. `6aa2eddcd3defdb4a55f30b7`)
* **Observed Response**:
  ```json
  { "success": "removed data", "removed": 1 }
  ```

---

### C. Highlights & Colors (`highlight`)

#### 1. Add Highlight
* **Endpoint**: `POST https://users.alhatorah.org/json/data/add`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload Parameters**:
  * `dataType`: `highlight`
  * `color`: CSS color string. Default palette uses 6 presets:
    * Yellow: `rgb(255, 252, 106)` (`#fffc6a`)
    * Pink: `rgb(255, 174, 215)` (`#ffaed7`)
    * Orange: `rgb(255, 165, 121)` (`#ffa579`)
    * Green: `rgb(136, 255, 136)` (`#88ff88`)
    * Blue: `rgb(129, 209, 255)` (`#81d1ff`)
    * Purple: `rgb(191, 128, 255)` (`#bf80ff`)
  * `type`: `mg-full`, `mg-dual`, or `library`
  * `mg`: Corpus name (e.g. `Tanakh`)
  * `book`: Book name (e.g. `Shemot`)
  * `unit`: Chapter/Daf (e.g. `6`)
  * `subUnit`: Verse/segment (e.g. `1`)
  * `parshan`: `_mainVerse` or commentator name
  * `paragraph`: Paragraph index within container (integer)
  * `begin`: Start character offset within paragraph (integer)
  * `end`: End character offset within paragraph (integer)
* **Observed Response**:
  ```json
  {
    "success": "added data",
    "data": {
      "_id": "6aa2eda7195dedd059b36de8",
      "dataType": "highlight",
      "color": "rgb(255, 252, 106)",
      "paragraph": null,
      "begin": 5,
      "end": 15,
      "type": "mg-full",
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "subUnit": 1,
        "parshan": "_mainVerse"
      }
    }
  }
  ```

#### 2. Change Highlight Color
* **Endpoint Behavior**:
  * Calling `POST /json/data/edit` with `dataType: highlight` fails with HTTP 400 (`Invalid value`).
  * The web client deletes the existing highlight ID via `POST /json/data/remove` and creates a new one via `POST /json/data/add` with the updated `color`.

#### 3. Remove Highlight
* **Endpoint**: `POST https://users.alhatorah.org/json/data/remove`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload Parameters**:
  * `id`: Highlight ID string, or multiple IDs joined by semicolon `;` (e.g. `id1;id2`)
* **Observed Response**:
  ```json
  { "success": "removed data", "removed": 1 }
  ```

---

### D. History / Recent Activity (`history`)

#### 1. Record History Entry
* Triggered automatically whenever a reader navigates to a chapter / page.
* **Endpoint**: `POST https://users.alhatorah.org/json/data/add`
* **Content-Type**: `application/x-www-form-urlencoded; charset=UTF-8`
* **Payload Parameters**:
  * `dataType`: `history`
  * `type`: `mg-full` or `mg-dual`
  * `mg`: Corpus name (e.g. `Tanakh`)
  * `book`: Book name (e.g. `Shemot`)
  * `unit`: Chapter/Daf (e.g. `6`)
  * `subUnit`: `0` (or verse number if verse-specific)
  * `parshan`: `_mainVerse` or active commentator
* **Observed Response**:
  ```json
  {
    "success": "added data",
    "data": {
      "_id": "6aa2ecb6195dedd059b36c04",
      "dataType": "history",
      "type": "mg-full",
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "parshan": "_mainVerse"
      }
    }
  }
  ```

#### 2. Read History Entries (Dashboard Mechanism)
* **Actual Source**: **Server-Side Rendered (SSR) HTML** upon `GET https://users.alhatorah.org/dashboard`.
  * There is **no client-side AJAX endpoint** (such as `/json/history` or `/json/data/get?type=history`) called by the dashboard. The server template renders the history list directly into the initial HTML document payload.
* **HTML Table Structure**:
  * Located inside container: `<div class="board-section board-history"><table class="table ..."><tbody>...</tbody></table></div>`.
  * Each recent navigation item is rendered as a `<tr class="history-item" ...>` containing up to 100 recent entries.
* **Row Attributes & Fields**:
  ```html
  <tr data-id="6a46445db5203c009940b197"
      data-base="tanakh"
      data-locnum="001:004:031:1902"
      data-date="2026-07-02T10:58:37.303Z">
    <td class="pr-1"><span class="mg-lang-he lang-he">תנ"ך</span><span class="mg-lang-en lang-en">Tanakh</span></td>
    <td class="pr-1"><a href="https:////mg.alhatorah.org/Dual/Sifre Bemidbar/Bemidbar/31.1">במדבר לא, א</a></td>
    <td class="pr-1"><span class="mg-lang-he lang-he">ספרי במדבר</span><span class="mg-lang-en lang-en">Sifre Bemidbar</span></td>
    <td><time datetime="2026-07-02T10:58:37.303Z" data-format="calendar">02/07/2026</time></td>
    <td class="pr-1"><span class="btn-delete"></span></td>
  </tr>
  ```
  * `data-id`: MongoDB ObjectId string (e.g. `6a46445db5203c009940b197`). Used as the target `id` parameter when calling `POST /json/data/remove`.
  * `data-base`: Corpus identifier string (e.g., `tanakh`, `shas`, `mishna`, `library`, `tosefta`, `rambam`).
  * `data-locnum`: Hierarchical colon-delimited location code (e.g., `001:004:031:1902`).
  * `data-date`: ISO 8601 UTC timestamp string of when the item was visited.
  * **Column 1 (`<td>`)**: Corpus badge with Hebrew/English localization labels (`.lang-he`, `.lang-en`).
  * **Column 2 (`<td>`)**: Anchor `<a href="...">` pointing to the full or dual reader URL, containing the localized book and chapter display title (e.g., `במדבר לא, א`).
  * **Column 3 (`<td>`)**: Active commentator name if opened in commentator focus/dual mode (e.g., `ספרי במדבר`), or empty if opened in standard verse mode.
  * **Column 4 (`<td>`)**: `<time datetime="..." data-format="calendar">` containing the formatted local date string and the raw ISO UTC datetime attribute.
  * **Column 5 (`<td>`)**: Individual delete button `<span class="btn-delete"></span>` wired to `POST /json/data/remove`.
* **Complete JSON Export Alternative**:
  * `GET https://users.alhatorah.org/json/export` returns user metadata and data arrays (`bookmark`, `gilayon`, `highlight`, `tanakhlab`). Note that ephemeral history records are maintained in a dedicated collection rendered exclusively on the dashboard.

#### 3. Delete History Entry
* **Endpoint**: `POST https://users.alhatorah.org/json/data/remove`
* **Payload Parameters**:
  * `id`: History item ID (e.g. `6aa2ecb6195dedd059b36c04`)
* **Observed Response**:
  ```json
  { "success": "removed data", "removed": 1 }
  ```

---

## 4. Chapter-Level Data Retrieval (`/json/data/get`)

When opening any text on AlHaTorah, the reader client queries all user annotations (bookmarks, notes, highlights) for that specific unit:

* **Endpoint**: `GET https://users.alhatorah.org/json/data/get`
* **Query Parameters**:
  * `type`: `mg-all`
  * `mg`: Corpus name (e.g. `Tanakh`, `Shas`)
  * `book`: Book/Tractate name (e.g. `Shemot`, `Shabbat`)
  * `unit`: Chapter or Daf (e.g. `6`, `141b`)
* **Observed Response**:
  A JSON array containing objects differentiated by `dataType`:
  ```json
  [
    {
      "_id": "6792aa67de794d02a27f7e8c",
      "dataType": "bookmark",
      "type": "mg-full",
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "subUnit": 12,
        "parshan": "R. Avraham b. HaRambam"
      }
    },
    {
      "_id": "6968ed2cbddab8009ea3d76e",
      "dataType": "gilayon",
      "type": "mg-full",
      "title": "כִּ֣י בְיָ֤ד חֲזָקָה֙ יְשַׁלְּחֵ֔ם",
      "content": "<p dir="rtl" class="ql-align-right">רש״י ורשב״ם פירשו...</p>",
      "paragraph": null,
      "begin": 93,
      "end": 93,
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "subUnit": 1,
        "parshan": "_mainVerse"
      }
    },
    {
      "_id": "6aa2eda7195dedd059b36de8",
      "dataType": "highlight",
      "type": "mg-full",
      "color": "rgb(255, 252, 106)",
      "paragraph": null,
      "begin": 5,
      "end": 15,
      "location": {
        "base": "tanakh",
        "book": "Shemot",
        "largeUnit": "6",
        "subUnit": 1,
        "parshan": "_mainVerse"
      }
    }
  ]
  ```

---

## 5. Summary Table of Endpoints

| Feature | Action | Method | URL | Parameters | Response Summary |
|---|---|---|---|---|---|
| **Session** | Verify Login | `GET` | `/json/whois` | None | `{"email": "..."}` or `{"err": "Please login"}` |
| **All Data** | Export Full User DB | `GET` | `/json/export` | None | JSON document of user + all arrays |
| **Chapter Data** | Fetch Annotations | `GET` | `/json/data/get` | `type=mg-all&mg=...&book=...&unit=...` | Array of bookmarks, notes, highlights |
| **Bookmark** | Add | `POST` | `/json/bookmarks/add` | `type, mg, book, unit, subUnit, parshan` | `{"success": "added bookmark"}` |
| **Bookmark** | Remove (by loc) | `POST` | `/json/bookmarks/remove` | `type, mg, book, unit, subUnit, parshan` | `{"success": "removed bookmark"}` |
| **Bookmark** | Remove (by ID) | `POST` | `/json/data/remove` | `id=<mongo_id>` | `{"success": "removed data", "removed": 1}` |
| **Note (Gilayon)** | Create | `POST` | `/json/data/add` | `dataType=gilayon, title, content, type, mg, book, unit, subUnit, parshan, paragraph, begin, end` | `{"success": "added data", "data": {...}}` |
| **Note (Gilayon)** | Edit | `POST` | `/json/data/edit` | `dataType=gilayon, id, content` | `{"success": "edited data", "data": {...}}` |
| **Note (Gilayon)** | Delete | `POST` | `/json/data/remove` | `id=<mongo_id>` | `{"success": "removed data", "removed": 1}` |
| **Highlight** | Add | `POST` | `/json/data/add` | `dataType=highlight, color, type, mg, book, unit, subUnit, parshan, paragraph, begin, end` | `{"success": "added data", "data": {...}}` |
| **Highlight** | Change Color | `POST` | `/json/data/remove` + `/json/data/add` | Old `id`, then new highlight parameters | Remove old, add new |
| **Highlight** | Remove | `POST` | `/json/data/remove` | `id=<mongo_id>` (supports semicolon `;` list) | `{"success": "removed data", "removed": 1}` |
| **History** | Add (automatic) | `POST` | `/json/data/add` | `dataType=history, type, mg, book, unit, subUnit, parshan` | `{"success": "added data", "data": {...}}` |
| **History** | Remove | `POST` | `/json/data/remove` | `id=<mongo_id>` | `{"success": "removed data", "removed": 1}` |

---

## 6. Native iOS (`WKWebView`) Session Integration

### The Cookie Isolation Challenge
* In WebKit on iOS, web browsing executes out-of-process in `com.apple.WebKit.Networking`.
* The `connect.sid` cookie has the flags:
  * `HttpOnly: true`
  * `Secure: true`
  * `SameSite: None`
  * `Domain: users.alhatorah.org`
* Because `HttpOnly` is enabled, scripts running inside `WKWebView` cannot access `connect.sid` via `document.cookie`.
* Furthermore, WebKit cookies are stored in `WKWebsiteDataStore` and are **not** automatically mirrored into the Foundation default `HTTPCookieStorage.shared`.

### Verified Native iOS Behavior (`WKHTTPCookieStore`)
* Since iOS 11, WebKit provides the native API `WKHTTPCookieStore`, accessible through `WKWebsiteDataStore.default().httpCookieStore` (or `webView.configuration.websiteDataStore.httpCookieStore`).
* Unlike in-page JavaScript, **native Swift code using `WKHTTPCookieStore` has full access to `HttpOnly` cookies**.
* Calling `httpCookieStore.getAllCookies { cookies in ... }` returns all cookies for `users.alhatorah.org`, including `connect.sid`.

### Recommended Native Integration Architecture

The safest, most practical architecture for `NativeSiteApp` to interact with `users.alhatorah.org` consists of a dedicated native session manager using native `URLSession` and `WKHTTPCookieStoreObserver`:

```
 +--------------------------------------------------------------------+
 |                             iOS App                                |
 |                                                                    |
 |  +-----------------------+           +--------------------------+  |
 |  |       WKWebView       |           |   AlHaTorahSessionStore  |  |
 |  | (Login & Book Reader) |           |      (Native Swift)      |  |
 |  +-----------+-----------+           +------------+-------------+  |
 |              |                                    |                |
 |              v                                    v                |
 |  +-------------------------------------------------------------+  |
 |  |          WKWebsiteDataStore.default().httpCookieStore        |  |
 |  |         (Stores connect.sid with HttpOnly: true)            |  |
 |  +-------------------------------------------------------------+  |
 |                                                   |                |
 |                                                   v                |
 |                                      +--------------------------+  |
 |                                      |    Native URLSession     |  |
 |                                      |  (whois, export, data)   |  |
 |                                      +------------+-------------+  |
 +---------------------------------------------------|----------------+
                                                     |
                                                     v
                                      https://users.alhatorah.org
```

#### 1. Extracting the Session Cookie
```swift
func fetchSessionCookie() async -> HTTPCookie? {
    await withCheckedContinuation { continuation in
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let session = cookies.first {
                $0.name == "connect.sid" &&
                ($0.domain == "users.alhatorah.org" || $0.domain == ".alhatorah.org")
            }
            continuation.resume(returning: session)
        }
    }
}
```

#### 2. Observing Cookie Changes in Real Time (`WKHTTPCookieStoreObserver`)
Instead of polling, the app registers a `WKHTTPCookieStoreObserver`:
```swift
final class AlHaTorahSessionStore: NSObject, WKHTTPCookieStoreObserver {
    private let cookieStore = WKWebsiteDataStore.default().httpCookieStore

    override init() {
        super.init()
        cookieStore.add(self)
    }

    deinit {
        cookieStore.remove(self)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        // Automatically invoked whenever the user logs in, logs out,
        // or has their session cookie refreshed inside WKWebView.
        Task {
            await self.validateSession()
        }
    }
}
```

#### 3. Attaching the Session to Native `URLSession` Requests
When making native requests to `users.alhatorah.org`:
* **Header Injection**:
  ```swift
  var request = URLRequest(url: endpointURL)
  if let sessionCookie = await fetchSessionCookie() {
      let headers = HTTPCookie.requestHeaderFields(with: [sessionCookie])
      for (field, value) in headers {
          request.setValue(value, forHTTPHeaderField: field)
      }
  }
  ```
* **Session Validation**:
  Querying `GET https://users.alhatorah.org/json/whois` with this request determines whether the user is actively authenticated.

### Why Native `URLSession` via `WKHTTPCookieStore` is the Safest Approach
1. **Lifecycle Decoupling**: Native UI (such as a native `HistoryViewController` or `BookmarksViewController`) can load, refresh, or delete items even when the `WKWebView` is navigating, displaying another URL, unmounted, or in the background.
2. **Robust Error Handling**: Native `URLSession` provides precise network error types, HTTP status codes, and cancellation tokens without relying on `evaluateJavaScript` string escaping or DOM ready states.
3. **No Script Injection Risks**: Avoids injecting script into third-party or untrusted web pages if the user navigates outside `alhatorah.org`.
4. **Clean Logout Sync**: When `WKWebsiteDataStore.default().removeData(...)` is called (e.g. from Settings "Clear Website Data"), the cookie store observer automatically detects the removal and transitions native UI to the logged-out state.

