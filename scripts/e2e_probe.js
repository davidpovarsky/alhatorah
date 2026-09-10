// scripts/e2e_probe.js
const fs = require('fs');
const path = require('path');

const email = process.env.ALHATORAH_TEST_EMAIL;
const password = process.env.ALHATORAH_TEST_PASSWORD;

if (!email || !password) {
    console.error("ERROR: ALHATORAH_TEST_EMAIL or ALHATORAH_TEST_PASSWORD environment variable is not set.");
    process.exit(1);
}

// Cookie jar
const cookieJar = new Map();

function storeCookies(setCookieHeaders) {
    if (!setCookieHeaders) return;
    const list = Array.isArray(setCookieHeaders) ? setCookieHeaders : [setCookieHeaders];
    for (const header of list) {
        // e.g. connect.sid=s%3A...; Path=/; Domain=users.alhatorah.org; HttpOnly; Secure
        const parts = header.split(';').map(p => p.trim());
        const [kv, ...attributes] = parts;
        const eqIdx = kv.indexOf('=');
        if (eqIdx !== -1) {
            const name = kv.substring(0, eqIdx);
            const value = kv.substring(eqIdx + 1);
            let domain = 'users.alhatorah.org';
            let path = '/';
            let httpOnly = false;
            let secure = false;
            for (const attr of attributes) {
                const [aName, aVal] = attr.split('=').map(x => x.trim());
                if (aName.toLowerCase() === 'domain') domain = aVal;
                else if (aName.toLowerCase() === 'path') path = aVal;
                else if (aName.toLowerCase() === 'httponly') httpOnly = true;
                else if (aName.toLowerCase() === 'secure') secure = true;
            }
            cookieJar.set(name, { value, domain, path, httpOnly, secure });
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

async function run() {
    console.log("=================================================");
    console.log("Starting AlHaTorah Authenticated E2E Probe");
    console.log("=================================================");

    const report = {
        timestamp: new Date().toISOString(),
        auth: {},
        exportSchema: {},
        websiteNoteRequest: null,
        nativeNoteRequest: null,
        comparison: null
    };

    // 1. Authenticate via POST /login
    console.log("\n[1/4] Authenticating via POST https://users.alhatorah.org/login...");
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

    console.log(`Login response status: ${loginRes.status} (${loginRes.statusText})`);
    console.log(`Redirect location: ${loginRes.headers.get('location') || 'none'}`);
    console.log("Cookies captured (metadata only):", JSON.stringify(getSanitizedCookieMetadata(), null, 2));

    // 2. Prove session with GET /json/whois
    console.log("\n[2/4] Proving session via GET https://users.alhatorah.org/json/whois...");
    const whoisRes = await fetch('https://users.alhatorah.org/json/whois', {
        method: 'GET',
        headers: {
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
    });

    const whoisStatus = whoisRes.status;
    let whoisJson = {};
    try {
        whoisJson = await whoisRes.json();
    } catch (e) {
        whoisJson = { error: 'Failed to parse JSON' };
    }

    const hasValidEmail = typeof whoisJson.email === 'string' && whoisJson.email.includes('@');
    console.log(`whois HTTP Status: ${whoisStatus}`);
    console.log(`whois valid email returned: ${hasValidEmail ? 'YES' : 'NO'}`);
    if (whoisJson.err) {
        console.error(`whois error returned: ${whoisJson.err}`);
    }

    report.auth = {
        whoisStatus,
        hasValidEmail,
        cookieMetadata: getSanitizedCookieMetadata()
    };

    if (!hasValidEmail) {
        console.error("CRITICAL: Authentication failed - whois did not return a valid email.");
        fs.mkdirSync('build_logs', { recursive: true });
        fs.writeFileSync('build_logs/e2e_probe_report.json', JSON.stringify(report, null, 2));
        process.exit(1);
    }

    // 3. Inspect authenticated GET /json/export
    console.log("\n[3/4] Inspecting authenticated GET https://users.alhatorah.org/json/export...");
    const exportRes = await fetch('https://users.alhatorah.org/json/export', {
        method: 'GET',
        headers: {
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
    });

    console.log(`export HTTP Status: ${exportRes.status}`);
    const exportJson = await exportRes.json();

    const dataObj = exportJson.data || {};
    const bookmarkArray = dataObj.bookmark || [];
    const gilayonArray = dataObj.gilayon || [];
    const highlightArray = dataObj.highlight || [];

    console.log(`Total bookmarks returned: ${bookmarkArray.length}`);
    console.log(`Total notes (gilayon) returned: ${gilayonArray.length}`);
    console.log(`Total highlights returned: ${highlightArray.length}`);

    // Inspect first bookmark structure
    let bookmarkSample = null;
    if (bookmarkArray.length > 0) {
        const firstBm = bookmarkArray[0];
        bookmarkSample = {
            keys: Object.keys(firstBm),
            locKey: firstBm.location ? 'location' : (firstBm.loc ? 'loc' : 'none'),
            locKeys: firstBm.location ? Object.keys(firstBm.location) : (firstBm.loc ? Object.keys(firstBm.loc) : []),
            hasDataType: 'dataType' in firstBm,
            dataTypeValue: firstBm.dataType,
            hasId: '_id' in firstBm || 'id' in firstBm,
            idKey: '_id' in firstBm ? '_id' : ('id' in firstBm ? 'id' : 'none'),
            sample: firstBm
        };
        console.log("Sample Bookmark Schema Analysis:", JSON.stringify(bookmarkSample, null, 2));
    } else {
        console.log("Notice: data.bookmark array is currently empty on this account.");
    }

    // Inspect first note structure
    let noteSample = null;
    if (gilayonArray.length > 0) {
        const firstNote = gilayonArray[0];
        noteSample = {
            keys: Object.keys(firstNote),
            locKey: firstNote.location ? 'location' : (firstNote.loc ? 'loc' : 'none'),
            locKeys: firstNote.location ? Object.keys(firstNote.location) : (firstNote.loc ? Object.keys(firstNote.loc) : []),
            hasDataType: 'dataType' in firstNote,
            dataTypeValue: firstNote.dataType,
            contentKey: 'content' in firstNote ? 'content' : ('data' in firstNote ? 'data' : ('text' in firstNote ? 'text' : 'none')),
            hasId: '_id' in firstNote || 'id' in firstNote,
            idKey: '_id' in firstNote ? '_id' : ('id' in firstNote ? 'id' : 'none'),
            sample: {
                ...firstNote,
                content: firstNote.content ? (firstNote.content.substring(0, 50) + '...') : undefined
            }
        };
        console.log("Sample Note (gilayon) Schema Analysis:", JSON.stringify(noteSample, null, 2));
    } else {
        console.log("Notice: data.gilayon array is currently empty on this account.");
    }

    // Inspect first highlight structure
    let highlightSample = null;
    if (highlightArray.length > 0) {
        const firstHl = highlightArray[0];
        highlightSample = {
            keys: Object.keys(firstHl),
            locKey: firstHl.location ? 'location' : (firstHl.loc ? 'loc' : 'none'),
            locKeys: firstHl.location ? Object.keys(firstHl.location) : (firstHl.loc ? Object.keys(firstHl.loc) : []),
            hasDataType: 'dataType' in firstHl,
            hasColor: 'color' in firstHl,
            colorValue: firstHl.color
        };
        console.log("Sample Highlight Schema Analysis:", JSON.stringify(highlightSample, null, 2));
    }

    report.exportSchema = {
        topLevelKeys: Object.keys(exportJson),
        dataKeys: Object.keys(dataObj),
        counts: {
            bookmarks: bookmarkArray.length,
            notes: gilayonArray.length,
            highlights: highlightArray.length
        },
        bookmarkSample,
        noteSample,
        highlightSample
    };

    // 4. Test note creation against /json/data/add to analyze HTTP 400 validation error
    console.log("\n[4/4] Testing note creation parameters against POST https://users.alhatorah.org/json/data/add...");
    
    // Test Case A: The CURRENT Native App Payload (that returns 400)
    const testTitle = `AHT_E2E_${Date.now()}`;
    const testContent = `Testing note creation at ${new Date().toISOString()}`;

    const nativeParams = [
        ["dataType", "gilayon"],
        ["title", testTitle],
        ["content", testContent],
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Devarim"],
        ["unit", "32"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"],
        ["begin", "0"],
        ["end", "0"]
    ];

    const nativeBody = nativeParams.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');

    console.log("Submitting native payload to /json/data/add:");
    console.log("Body:", nativeBody);

    const nativeRes = await fetch('https://users.alhatorah.org/json/data/add', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        },
        body: nativeBody
    });

    const nativeStatus = nativeRes.status;
    const nativeRespText = await nativeRes.text();
    console.log(`Native payload HTTP response status: ${nativeStatus}`);
    console.log(`Native payload HTTP response body: ${nativeRespText}`);

    report.nativeNoteRequest = {
        status: nativeStatus,
        bodySent: nativeBody,
        response: nativeRespText
    };

    // Test Case B: Variations to isolate exact validation requirement
    console.log("\n--- Probing Payload Variations to Isolate Exact Validation Schema ---");
    
    // Variation 1: Wrapped in <p dir="rtl">
    const v1Params = [
        ["dataType", "gilayon"],
        ["title", testTitle],
        ["content", `<p dir="rtl">${testContent}</p>`],
        ["type", "mg-full"],
        ["mg", "Tanakh"],
        ["book", "Devarim"],
        ["unit", "32"],
        ["subUnit", "1"],
        ["parshan", "_mainVerse"],
        ["begin", "0"],
        ["end", "0"]
    ];
    const v1Body = v1Params.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    const v1Res = await fetch('https://users.alhatorah.org/json/data/add', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        },
        body: v1Body
    });
    console.log(`Variation 1 (<p dir="rtl">) Status: ${v1Res.status}, Body: ${await v1Res.text()}`);

    // Variation 2: with paragraph=0 or paragraph=null
    const v2Params = [...v1Params, ["paragraph", "0"]];
    const v2Body = v2Params.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    const v2Res = await fetch('https://users.alhatorah.org/json/data/add', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        },
        body: v2Body
    });
    console.log(`Variation 2 (paragraph=0) Status: ${v2Res.status}, Body: ${await v2Res.text()}`);

    // Variation 3: with color empty or color not set
    const v3Params = [...v1Params, ["color", ""]];
    const v3Body = v3Params.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    const v3Res = await fetch('https://users.alhatorah.org/json/data/add', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Cookie': getCookieHeader(),
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        },
        body: v3Body
    });
    console.log(`Variation 3 (color="") Status: ${v3Res.status}, Body: ${await v3Res.text()}`);

    // Save report
    fs.mkdirSync('build_logs', { recursive: true });
    fs.writeFileSync('build_logs/e2e_probe_report.json', JSON.stringify(report, null, 2));
    console.log("\nProbe completed successfully. Report saved to build_logs/e2e_probe_report.json");
}

run().catch(err => {
    console.error("FATAL ERROR in e2e_probe:", err);
    process.exit(1);
});
