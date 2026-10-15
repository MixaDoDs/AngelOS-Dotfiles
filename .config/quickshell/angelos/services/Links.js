.pragma library

// Links, mail and phones in free text: what Circle read off the screen (OCR), a clipboard
// entry, a notification's body. A bare address counts too ("github.com/x"), but not a file
// name ("readme.md"), a version ("1.2.3") or two sentences glued by a dot ("ок.Дальше").
//
//   scan(text)      → [{kind: "url"|"mail"|"phone", text, url, start, end}] in order
//   find(text, max) → the same, each address once, at most `max`
//   linkify(markup) → the markup with bare links/mail made <a href> (existing <a> kept)

// the zones a bare address may end in (with a scheme or www. any zone goes)
const ZONES = new Set(("com net org info biz edu gov mil int io ai app dev me tv gg co cc to ly fm ws " + "xyz site online store shop tech pro blog wiki club live news space link page art design studio " + "games game cloud email so sh im is it su рф рус uk us eu de fr nl pl cz sk ua by kz ru jp cn kr in " + "br es pt ca au nz ch at se no fi dk ee lv lt ge am az uz kg tj md ro bg hu gr tr il ir ae sa sg hk tw vn th id ph my").split(" "));
// two-letter zones that are more often a file's extension: those need a path ("ps.md/x")
const FILEISH = new Set(["md", "sh", "so", "ps", "pl", "in", "it", "is", "me", "to", "co", "ai", "am"]);

const LEAD = /^[(\[{«"'“‘<]+/;
const TRAIL = ")]}.,;:!?»\"'”’>…";

function count(t, ch) {
    return t.split(ch).length - 1;
}
// OCR and prose put punctuation around a link: it goes, but a ")" closing a "(" inside stays
function trim(tok) {
    const t0 = tok.replace(LEAD, "");
    let t = t0;
    while (t && TRAIL.includes(t[t.length - 1])) {
        if (t.endsWith(")") && count(t, "(") >= count(t, ")"))
            break;
        t = t.slice(0, -1);
    }
    return {
        "text": t,
        "lead": tok.length - t0.length
    };
}

function classify(t) {
    if (/^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zа-я]{2,}$/i.test(t))
        return {
            "kind": "mail",
            "url": "mailto:" + t
        };
    if (/^(https?|ftp):\/\/[^\s/$.?#][^\s]*$/i.test(t))
        return {
            "kind": "url",
            "url": t
        };
    if (/^www\.[\w-]+(\.[\w-]+)+(\S*)$/i.test(t))
        return {
            "kind": "url",
            "url": "https://" + t
        };
    // the zone in small letters: "Hello.World" and "ок.Дальше" are sentences, "Github.com" is OCR
    const m = t.match(/^((?:[A-Za-zА-Яа-яЁё0-9](?:[A-Za-zА-Яа-яЁё0-9-]*[A-Za-zА-Яа-яЁё0-9])?\.)+)([a-zа-яё]{2,})(:\d{1,5})?(\/\S*)?$/);
    if (!m)
        return null;
    const zone = m[2];
    if (!ZONES.has(zone) || (FILEISH.has(zone) && !m[4] && !m[3]))
        return null;
    return {
        "kind": "url",
        "url": "https://" + t
    };
}

function scan(text) {
    const s = String(text || "");
    const out = [];
    const re = /\S+/g;
    let m;
    while ((m = re.exec(s))) {
        const tr = trim(m[0]);
        if (!tr.text)
            continue;
        const c = classify(tr.text);
        if (c) {
            const start = m.index + tr.lead;
            out.push({
                "kind": c.kind,
                "text": tr.text,
                "url": c.url,
                "start": start,
                "end": start + tr.text.length
            });
        }
    }
    // phones: "+7 (999) 123-45-67", "8 999 123 45 67"; a date or a plain number is not one
    const pr = /(?:^|[^\w+])(\+?\d[\d ()\-]{5,}\d)(?![\w])/g;
    while ((m = pr.exec(s))) {
        const p = m[1];
        const digits = p.replace(/\D/g, "").length;
        const start = m.index + m[0].length - p.length;
        if (digits > 15 || digits < (p[0] === "+" ? 7 : 10) || /^\d{4}-\d{2}-\d{2}/.test(p) || out.some(o => start < o.end && o.start < start + p.length))
            continue;
        out.push({
            "kind": "phone",
            "text": p,
            "url": "tel:" + p.replace(/[^\d+]/g, ""),
            "start": start,
            "end": start + p.length
        });
    }
    return out.sort((a, b) => a.start - b.start);
}

function find(text, max) {
    const seen = {};
    return scan(text).filter(l => !seen[l.url] && (seen[l.url] = true)).slice(0, max || 6);
}

function esc(t) {
    return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// the text between tags gets its bare links wrapped; inside an <a> it stays as it is
function linkify(markup) {
    let inA = false;
    return String(markup || "").split(/(<[^>]*>)/).map(part => {
        if (part.startsWith("<")) {
            if (/^<a[\s>]/i.test(part))
                inA = true;
            else if (/^<\/a\s*>/i.test(part))
                inA = false;
            return part;
        }
        if (inA || !part)
            return part;
        // shortcut: entities (&amp;) inside a bare link stay encoded in its href; fine for StyledText
        let res = "", at = 0;
        for (const l of scan(part)) {
            if (l.kind === "phone")
                continue;
            res += part.slice(at, l.start) + "<a href=\"" + esc(l.url) + "\">" + part.slice(l.start, l.end) + "</a>";
            at = l.end;
        }
        return res + part.slice(at);
    }).join("");
}
