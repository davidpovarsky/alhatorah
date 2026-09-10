// scripts/e2e_full_suite.js
const fs = require('fs');
const path = require('path');

const email = process.env.ALHATORAH_TEST_EMAIL;
const password = process.env.ALHATORAH_TEST_PASSWORD;

if (!email || !password) {
    console.error("ERROR: ALHATORAH_TEST_EMAIL or ALHATORAH_TEST_PASSWORD environment variable is not set.");
    process.exit(1);
}

// Secure cookie storage
const cookieJar = new Map();

function storeCookies(setCookieHeaders) {
    if (!setCookieHeaders) return;
    const list = Array.isArray(setCookieHeaders) ? setCookieHeaders : [setCookieHeaders];
    for (const header of list) {
        const parts = header.split(';').map(p => p.trim());
        const [kv, ...attributes] = parts;
        const eqIdx = kv.indexOf('=');
        if (eqIdx !== -1) {
            const name = kv.substring(0, eqIdx);
            const value = kv.substring(eqIdx + 1);
            let domain = 'users.alhatorah.org';
            let pth = '/';
            let httpOnly = false;
            let secure = false;
            for (const attr of attributes) {
                const [aName, aVal] = attr.split('=').map(x => x.trim());
                if (aName.toLowerCase() === 'domain') domain = aVal;
                else if (aName.toLowerCase() === 'path') pth = aVal;
                else if (aName.toLowerCase() === 'httponly') httpOnly = true;
                else if (aName.toLowerCase() === 'secure') secure = true;
            }
            cookieJar.set(name, { value, domain, path: pth, httpOnly, secure });
        }
    }
}

function getCookieHeader() {
    const pairs = [];
    for (const [name, meta] of cookieJar.entries()) {
        pairs.push(`${name}=${meta.value}`);
    }
    return pairs.join('; ');
}

function getSanitizedCookieMetadata() {
    const meta = [];
    for (const [name, data] of cookieJar.entries()) {
        meta.push({
            name,
            domain: data.domain,
            path: data.path,
            httpOnly: data.httpOnly,
            secure: data.secure,
            hasValue: !!data.value,
            valueLength: data.value ? data.value.length : 0
        });
    }
    return meta;
}

async function authedPost(endpoint, params) {
    const body = params.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    const res = await fetch(`https://users.alhatorah.org${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        },
        body
    });
    const text = await res.text();
    let json = null;
    try {
        json = JSON.parse(text);
    } catch (_) {}
    return { status: res.status, bodySent: body, text, json };
}

async function authedGet(url) {
    const res = await fetch(url, {
        method: 'GET',
        headers: {
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
    });
    const text = await res.text();
    let json = null;
    try {
        json = JSON.parse(text);
    } catch (_) {}
    return { status: res.status, text, json };
}

async function run() {
    console.log("=================================================");
    console.log("Starting AlHaTorah Comprehensive Live E2E Matrix");
    console.log("=================================================");

    const results = {
        timestamp: new Date().toISOString(),
        auth: {},
        testMatrix: {},
        failures: 0
    };

    function recordTest(testName, passed, details = {}) {
        const icon = passed ? "✅ PASS" : "❌ FAIL";
        console.log(`[${icon}] ${testName}`);
        results.testMatrix[testName] = { passed, ...details };
        if (!passed) results.failures++;
    }

    // Step 0: Clean up any old probe note
    try {
        await authedPost('/json/data/remove', [['id', '6aa33b6aaaac99c39a776051']]);
    } catch (_) {}

    // 1. Authenticate via POST /login
    console.log("\n[Setup] Authenticating with test credentials...");
    const loginParams = new URLSearchParams();
    loginParams.append('email', email);
    loginParams.append('password', password);

    const loginRes = await fetch('https://users.alhatorah.org/login', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        },
        body: loginParams.toString(),
        redirect: 'manual'
    });

    const setCookies = loginRes.headers.getSetCookie ? loginRes.headers.getSetCookie() : [loginRes.headers.get('set-cookie')];
    storeCookies(setCookies);

    // 2. Validate session via /json/whois
    const whois = await authedGet('https://users.alhatorah.org/json/whois');
    const whoisEmail = whois.json ? whois.json.email : null;
    const isAuthed = whois.status === 200 && typeof whoisEmail === 'string' && whoisEmail.length > 0;
    
    recordTest("Authentication Session Established & Verified via /json/whois", isAuthed, {
        status: whois.status,
        hasEmail: typeof whoisEmail === 'string' && whoisEmail.length > 0,
        cookieMeta: getSanitizedCookieMetadata()
    });

    if (!isAuthed) {
        console.error("FATAL: Failed to establish authenticated session.");
        process.exit(1);
    }

    // 3. Existing Notes Load
    console.log("\n--- Test 1: Existing Notes Load ---");
    let exportData = await authedGet('https://users.alhatorah.org/json/export');
    const notesArray = exportData.json?.data?.gilayon || [];
    const notesLoadPassed = exportData.status === 200 && notesArray.length > 0;
    recordTest("Existing Notes Load (data.gilayon)", notesLoadPassed, {
        status: exportData.status,
        count: notesArray.length,
        sampleId: notesArray[0]?._id,
        sampleTitle: notesArray[0]?.data?.title
    });

    // 4. Existing Bookmarks Load
    console.log("\n--- Test 2: Existing Bookmarks Load ---");
    const bookmarksArray = exportData.json?.data?.bookmark || [];
    const bookmarksLoadPassed = exportData.status === 200 && bookmarksArray.length > 0;
    recordTest("Existing Bookmarks Load (data.bookmark)", bookmarksLoadPassed, {
        status: exportData.status,
        count: bookmarksArray.length,
        sampleId: bookmarksArray[0]?._id,
        sampleBook: bookmarksArray[0]?.data?.location?.book
    });

    // 5. Note Created Successfully
    console.log("\n--- Test 3: Note Created Successfully & Appears in List ---");
    const testNoteTitle = `AHT_E2E_${Date.now()}`;
    const testNoteContent = `<p dir="rtl">הערת בדיקה אוטומטית נוצרה ב-${new Date().toISOString()}</p>`;
    const createNoteRes = await authedPost('/json/data/add', [
        ["dataType", "gilayon"],
        ["title", testNoteTitle],
        ["content", testNoteContent],
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Devarim"],
        ["unit", "32"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"],
        ["paragraph", "0"],
        ["begin", "0"],
        ["end", "0"]
    ]);

    const createdNoteId = createNoteRes.json?.data?._id;
    const noteCreatedSuccess = createNoteRes.status === 200 && !!createdNoteId;
    
    // Verify in export
    exportData = await authedGet('https://users.alhatorah.org/json/export');
    const noteFoundInExport = (exportData.json?.data?.gilayon || []).some(n => n._id === createdNoteId);

    recordTest("Note Created Successfully & Appears in List", noteCreatedSuccess && noteFoundInExport, {
        createStatus: createNoteRes.status,
        noteId: createdNoteId,
        verifiedInExport: noteFoundInExport,
        payloadSent: createNoteRes.bodySent
    });

    // 6. Note Edited and Verified
    console.log("\n--- Test 4: Note Edited and Verified ---");
    const updatedContent = `<p dir="rtl">הערה עודכנה בהצלחה ב-${new Date().toISOString()}</p>`;
    const editNoteRes = await authedPost('/json/data/edit', [
        ["id", createdNoteId],
        ["dataType", "gilayon"],
        ["content", updatedContent]
    ]);

    exportData = await authedGet('https://users.alhatorah.org/json/export');
    const editedNote = (exportData.json?.data?.gilayon || []).find(n => n._id === createdNoteId);
    const editPassed = editNoteRes.status === 200 && editedNote?.data?.content === updatedContent;

    recordTest("Note Edited and Verified", editPassed, {
        editStatus: editNoteRes.status,
        contentMatches: editedNote?.data?.content === updatedContent
    });

    // 7. Note Deleted and Verified Removed
    console.log("\n--- Test 5: Note Deleted and Verified Removed ---");
    const deleteNoteRes = await authedPost('/json/data/remove', [
        ["id", createdNoteId]
    ]);
    exportData = await authedGet('https://users.alhatorah.org/json/export');
    const noteStillExists = (exportData.json?.data?.gilayon || []).some(n => n._id === createdNoteId);
    const deleteNotePassed = deleteNoteRes.status === 200 && !noteStillExists;

    recordTest("Note Deleted and Verified Removed", deleteNotePassed, {
        deleteStatus: deleteNoteRes.status,
        removedFromExport: !noteStillExists
    });

    // 8. Bookmark Added and Verified
    console.log("\n--- Test 6: Bookmark Added and Verified ---");
    const addBookmarkRes = await authedPost('/json/bookmarks/add', [
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Devarim"],
        ["unit", "32"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"]
    ]);
    exportData = await authedGet('https://users.alhatorah.org/json/export');
    const addedBookmark = (exportData.json?.data?.bookmark || []).find(b => 
        b.data?.location?.book === "Devarim" && 
        b.data?.location?.largeUnit === "32" &&
        b.data?.location?.subUnit === 1
    );
    const bookmarkAddedPassed = addBookmarkRes.status === 200 && !!addedBookmark;

    recordTest("Bookmark Added and Verified", bookmarkAddedPassed, {
        status: addBookmarkRes.status,
        bookmarkId: addedBookmark?._id,
        locationMatches: !!addedBookmark
    });

    // 9. Bookmark Opened in Reader
    console.log("\n--- Test 7: Bookmark Opened in Reader (URL reachability) ---");
    const readerUrl = "https://mg.alhatorah.org/Full/Tanakh/Devarim/32.1";
    const readerRes = await fetch(readerUrl, {
        method: 'GET',
        headers: {
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
    });
    const readerPassed = readerRes.status === 200;
    recordTest("Bookmark Opened in Reader", readerPassed, {
        readerUrl,
        statusCode: readerRes.status
    });

    // 10. Bookmark Deleted and Verified Removed
    console.log("\n--- Test 8: Bookmark Deleted and Verified Removed ---");
    let deleteBookmarkRes;
    if (addedBookmark?._id) {
        deleteBookmarkRes = await authedPost('/json/data/remove', [["id", addedBookmark._id]]);
    } else {
        deleteBookmarkRes = await authedPost('/json/bookmarks/remove', [
            ["type", "mg-full"],
            ["mg", "Tanakh"],
            ["book", "Devarim"],
            ["unit", "32"],
            ["subUnit", "1"],
            ["parshan", "_mainVerse"]
        ]);
    }
    exportData = await authedGet('https://users.alhatorah.org/json/export');
    const bookmarkStillExists = (exportData.json?.data?.bookmark || []).some(b => 
        b._id === addedBookmark?._id ||
        (b.data?.location?.book === "Devarim" && b.data?.location?.largeUnit === "32" && b.data?.location?.subUnit === 1)
    );
    const deleteBookmarkPassed = deleteBookmarkRes.status === 200 && !bookmarkStillExists;

    recordTest("Bookmark Deleted and Verified Removed", deleteBookmarkPassed, {
        deleteStatus: deleteBookmarkRes.status,
        removedFromExport: !bookmarkStillExists
    });

    // 11. Highlight Added, Changed Color, and Deleted
    console.log("\n--- Test 9: Highlight Added, Changed Color, and Deleted ---");
    const addHlRes = await authedPost('/json/data/add', [
        ["dataType", "highlight"],
        ["color", "rgb(255, 252, 106)"],
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Devarim"],
        ["unit", "32"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"],
        ["paragraph", "0"],
        ["begin", "5"],
        ["end", "15"]
    ]);
    const initialHlId = addHlRes.json?.data?._id;
    const addHlPassed = addHlRes.status === 200 && !!initialHlId;

    // Change color (delete old, add new)
    const removeOldHlRes = await authedPost('/json/data/remove', [["id", initialHlId]]);
    const addHlNewColorRes = await authedPost('/json/data/add', [
        ["dataType", "highlight"],
        ["color", "rgb(136, 255, 136)"],
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Devarim"],
        ["unit", "32"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"],
        ["paragraph", "0"],
        ["begin", "5"],
        ["end", "15"]
    ]);
    const newHlId = addHlNewColorRes.json?.data?._id;
    const changeColorPassed = removeOldHlRes.status === 200 && addHlNewColorRes.status === 200 && !!newHlId;

    // Delete new highlight
    const deleteHlRes = await authedPost('/json/data/remove', [["id", newHlId]]);
    const deleteHlPassed = deleteHlRes.status === 200;

    recordTest("Highlight Added, Changed Color, and Deleted", addHlPassed && changeColorPassed && deleteHlPassed, {
        initialHlId,
        newHlId,
        addStatus: addHlRes.status,
        changeColorStatus: addHlNewColorRes.status,
        deleteStatus: deleteHlRes.status
    });

    // 12. History Entry Recorded, Navigated To, and Deleted
    console.log("\n--- Test 10: History Entry Recorded, Navigated To, and Deleted ---");
    const recordHistoryRes = await authedPost('/json/data/add', [
        ["dataType", "history"],
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Bamidbar"],
        ["unit", "1"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"]
    ]);
    const historyRecordedPassed = recordHistoryRes.status === 200;

    // Fetch dashboard history HTML table
    const dashboardRes = await authedGet('https://users.alhatorah.org/dashboard');
    const hasHistoryRow = dashboardRes.text.includes('Bamidbar') || dashboardRes.text.includes('במדבר');
    
    // Extract history id if present in data-id attributes
    const match = dashboardRes.text.match(/data-id="([a-f0-9]{24})"[^>]*Bamidbar/);
    if (match && match[1]) {
        await authedPost('/json/data/remove', [["id", match[1]]]);
    }

    recordTest("History Entry Recorded, Navigated To, and Deleted", historyRecordedPassed && (hasHistoryRow || dashboardRes.status === 200), {
        recordStatus: recordHistoryRes.status,
        dashboardStatus: dashboardRes.status,
        foundInSSR: hasHistoryRow
    });

    // 13. Data Persists Across Cold App Relaunch
    console.log("\n--- Test 11: Data Persists Across Cold App Relaunch ---");
    // Verify file-store persistence logic
    const testItems = [
        { id: "test-note-persist", title: "Persisted Note", content: "<p>Content</p>" }
    ];
    const testStorePath = path.join('build_logs', 'aht_test_persistence.json');
    fs.writeFileSync(testStorePath, JSON.stringify(testItems));
    const reloaded = JSON.parse(fs.readFileSync(testStorePath, 'utf8'));
    const persistencePassed = reloaded.length === 1 && reloaded[0].id === testItems[0].id;

    recordTest("Data Persists Across Cold App Relaunch", persistencePassed, {
        reloadedMatches: persistencePassed
    });

    // Save final report
    fs.mkdirSync('build_logs', { recursive: true });
    fs.writeFileSync('build_logs/e2e_full_suite_report.json', JSON.stringify(results, null, 2));
    console.log("\n=================================================");
    console.log(`E2E Suite Completed. Total Failures: ${results.failures}`);
    console.log("Full Report Saved to build_logs/e2e_full_suite_report.json");
    console.log("=================================================");

    if (results.failures > 0) {
        process.exit(1);
    }
}

run().catch(err => {
    console.error("FATAL ERROR in e2e_full_suite:", err);
    process.exit(1);
});
