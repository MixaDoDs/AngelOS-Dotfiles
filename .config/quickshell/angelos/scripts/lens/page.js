// What LensWorker.qml runs inside Google's pages (an isolated JS world: Google's own scripts
// don't see these names). Only roles, heading levels, tags, href shapes and geometry — never
// Google's class names, which change every few weeks. Every call returns a JSON string.
var __aosLens = (function () {
    var HEAD = '[role="heading"][aria-level="3"], h3';
    var PRICE = /(?:[$€£¥₽₴₹]|руб\.?|USD|EUR|RUB|zł|Kč|kr)\s?\d[\d\s.,]*|\d[\d\s.,]*\s?(?:[$€£¥₽₴₹]|руб\.?|USD|EUR|RUB|zł|Kč|kr)\*?/i;
    var SIZE = /\d[\d.,]*\s?[x×]\s?\d/;

    function abs(h) {
        try {
            return new URL(h, "https://www.google.com").href;
        } catch (e) {
            return "";
        }
    }
    function lines(el) {
        return String(el.innerText || "").split("\n").map(function (s) {
            return s.trim();
        }).filter(Boolean);
    }
    function src(img) {
        var s = img.currentSrc || img.src || "";
        // a lazy picture not there yet is a 1×1 placeholder
        if (!/^(data:image|https:)/.test(s) || img.naturalWidth <= 2)
            return "";
        return s;
    }
    function google(u) {
        return /^https?:\/\/([a-z0-9-]+\.)*google\.[a-z.]+(\/|$)/i.test(u);
    }
    // a result: an outside page, or Google's own /goto? jump to one (its token stays opaque)
    function isResult(href) {
        if (!href)
            return false;
        var u = abs(href);
        if (/^https?:\/\/www\.google\.[a-z.]+\/goto\?/i.test(u))
            return true;
        return /^https?:/.test(u) && !google(u) && !/usercontent\.google|gstatic\.com/.test(u);
    }
    function preview() {
        var imgs = document.querySelectorAll("img");
        for (var i = 0; i < imgs.length; i++)
            if (/lens\.usercontent\.google\.com/.test(imgs[i].currentSrc || imgs[i].src))
                return imgs[i];
        return null;
    }
    // the card's picture is beside its link, not in it: the nearest ancestor holding one shown
    // wider than 60 px, as long as that ancestor holds no other card
    function thumb(a) {
        var me = abs(a.getAttribute("href")), el = a;
        for (var k = 0; k < 4 && el.parentElement; k++) {
            el = el.parentElement;
            var others = el.querySelectorAll("a[href]");
            for (var j = 0; j < others.length; j++) {
                var o = others[j];
                if (o !== a && o.querySelector(HEAD) && abs(o.getAttribute("href")) !== me)
                    return "";
            }
            var imgs = el.querySelectorAll("img");
            for (var i = 0; i < imgs.length; i++) {
                if (a.contains(imgs[i]))
                    continue;
                var s = src(imgs[i]);
                if (s && imgs[i].getBoundingClientRect().width > 60 && !/lens\.usercontent/.test(s))
                    return s;
            }
        }
        return "";
    }
    function favicon(a) {
        var imgs = a.querySelectorAll("img");
        for (var i = 0; i < imgs.length; i++) {
            var w = imgs[i].getBoundingClientRect().width;
            if (w > 0 && w <= 24 && src(imgs[i]))
                return src(imgs[i]);
        }
        return "";
    }
    function price(ls) {
        for (var i = 0; i < ls.length; i++) {
            var m = PRICE.exec(ls[i]);
            if (m)
                return m[0].trim();
        }
        return "";
    }

    function visual() {
        var out = [], seen = {};
        var heads = document.querySelectorAll(HEAD);
        for (var i = 0; i < heads.length; i++) {
            var h = heads[i], a = h.closest("a[href]");
            if (!a || !isResult(a.getAttribute("href")))
                continue;
            var url = abs(a.getAttribute("href")), title = String(h.innerText || h.textContent || "").trim();
            if (!url || !title || seen[url])
                continue;
            seen[url] = true;
            var ls = lines(a).filter(function (s) {
                return s !== title;
            });
            out.push({
                "title": title,
                "site": ls[0] || "",
                "url": url,
                "thumb": thumb(a),
                "favicon": favicon(a),
                "price": price(ls.slice(1)),
                "extra": ls.slice(1).filter(function (s) {
                    return !PRICE.test(s);
                }).slice(0, 3).join(" · ")
            });
        }
        return out;
    }

    // exact matches (udm=48): no level-3 headings; a card is a link whose text has a size "1.280 x 1.280"
    function exact() {
        var out = [], seen = {};
        var as = document.querySelectorAll("a[href]");
        for (var i = 0; i < as.length; i++) {
            var a = as[i];
            if (!isResult(a.getAttribute("href")))
                continue;
            var ls = lines(a), size = "";
            for (var k = 0; k < ls.length; k++)
                if (SIZE.test(ls[k])) {
                    size = ls[k];
                    break;
                }
            var url = abs(a.getAttribute("href"));
            if (!size || !ls.length || seen[url])
                continue;
            seen[url] = true;
            var rest = ls.filter(function (s) {
                return s !== size && s !== "·" && s !== ls[0];
            });
            var big = "", small = "", imgs = a.querySelectorAll("img");
            for (var j = 0; j < imgs.length; j++) {
                var w = imgs[j].getBoundingClientRect().width, s = src(imgs[j]);
                if (!s)
                    continue;
                if (w > 40 && !big)
                    big = s;
                else if (w > 0 && w <= 24 && !small)
                    small = s;
            }
            out.push({
                "title": ls[0],
                "site": rest.length ? rest[rest.length - 1] : "",
                "url": url,
                // its picture is in the link (a neighbour's beside it would be the wrong one)
                "thumb": big,
                "favicon": small,
                "price": "",
                "extra": size + (rest.length > 1 ? " · " + rest[0] : "")
            });
        }
        return out;
    }

    // the recognised words: one-word buttons over the uploaded picture; rows by overlap, then x
    function words() {
        var pv = preview();
        if (!pv)
            return [];
        var R = pv.getBoundingClientRect(), ws = [];
        var bs = document.querySelectorAll('button, [role="button"]');
        for (var i = 0; i < bs.length; i++) {
            var b = bs[i], t = String(b.innerText || b.textContent || "").trim();
            if (!t || /\s/.test(t) || t.length > 40 || b.querySelector("svg, img"))
                continue;
            var r = b.getBoundingClientRect();
            if (r.width <= 0 || r.height <= 0)
                continue;
            var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
            if (cx < R.left - 2 || cx > R.right + 2 || cy < R.top - 2 || cy > R.bottom + 2)
                continue;
            ws.push({
                "t": t,
                "x": r.left,
                "top": r.top,
                "bot": r.bottom
            });
        }
        ws.sort(function (p, q) {
            return p.top - q.top;
        });
        var rows = [];
        ws.forEach(function (w) {
            var row = rows.length ? rows[rows.length - 1] : null;
            var h = Math.min(w.bot - w.top, row ? row.bot - row.top : 0);
            if (row && Math.min(w.bot, row.bot) - Math.max(w.top, row.top) > h / 2) {
                row.ws.push(w);
                row.bot = Math.max(row.bot, w.bot);
            } else
                rows.push({
                    "top": w.top,
                    "bot": w.bot,
                    "ws": [w]
                });
        });
        return rows.map(function (row) {
            return row.ws.sort(function (p, q) {
                return p.x - q.x;
            }).map(function (w) {
                return w.t;
            }).join(" ");
        });
    }

    // the first level-2 block with real text is the AI overview (it streams in: its length is
    // watched until it stops growing)
    function overview() {
        var hs = document.querySelectorAll('[role="heading"][aria-level="2"], h2');
        for (var i = 0; i < hs.length; i++) {
            var h = hs[i], ht = String(h.innerText || "").trim();
            if (!ht || h.getBoundingClientRect().height <= 0)
                continue;
            var box = h;
            for (var k = 0; k < 5 && box.parentElement && String(box.innerText || "").length < ht.length + 80; k++)
                box = box.parentElement;
            var text = String(box.innerText || "");
            if (text.length < ht.length + 80)
                continue;
            var first = lines(box).filter(function (s) {
                return s !== ht && s.length >= 40 && !/\bAI\b|ИИ/.test(s);
            })[0] || "";
            return {
                "len": text.length,
                "text": first.length > 600 ? first.slice(0, 600) + "…" : first
            };
        }
        return {
            "len": 0,
            "text": ""
        };
    }
    function norm(s) {
        return String(s || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
    }
    // the object's name: a "related search" link whose text is its own query
    function entityName() {
        var as = document.querySelectorAll("a[href]");
        for (var i = 0; i < as.length; i++) {
            var href = as[i].getAttribute("href") || "";
            if (!/^(https:\/\/www\.google\.[a-z.]+)?\/search\?/.test(href))
                continue;
            var t = String(as[i].innerText || "").trim(), q = "";
            try {
                q = new URL(href, "https://www.google.com").searchParams.get("q") || "";
            } catch (e) {}
            if (t.length >= 2 && t.length <= 80 && q && norm(q) === norm(t))
                return t;
        }
        return "";
    }
    function tabs() {
        var out = {}, as = document.querySelectorAll('a[href*="udm="]');
        for (var i = 0; i < as.length; i++) {
            var m = /[?&]udm=(\d+)/.exec(as[i].getAttribute("href"));
            if (m && !out[m[1]])
                out[m[1]] = abs(as[i].getAttribute("href"));
        }
        return out;
    }
    function translateButton() {
        var bs = document.querySelectorAll('button, [role="button"]');
        for (var i = 0; i < bs.length; i++)
            if (/translat|перев|übersetz|tradu/i.test(bs[i].getAttribute("aria-label") || ""))
                return bs[i];
        return null;
    }
    function counts(cards) {
        var as = document.querySelectorAll("a[href]"), go = 0, ext = 0;
        for (var i = 0; i < as.length; i++) {
            var u = abs(as[i].getAttribute("href"));
            if (/\/goto\?/.test(u))
                go++;
            else if (/^https?:/.test(u) && !google(u))
                ext++;
        }
        var t = tabs();
        return {
            "tabs": Object.keys(t).length,
            "h1": document.querySelectorAll('[role="heading"][aria-level="1"], h1').length,
            "h2": document.querySelectorAll('[role="heading"][aria-level="2"], h2').length,
            "h3": document.querySelectorAll(HEAD).length,
            "cards": cards,
            "goto": go,
            "ext": ext
        };
    }

    return {
        // the picture as a form posted from this google.com page: same-site, so the consent cookie goes
        "upload": function (b64, mime, url) {
            var b = atob(b64), a = new Uint8Array(b.length);
            for (var i = 0; i < b.length; i++)
                a[i] = b.charCodeAt(i);
            var blob = new Blob([a], {
                "type": mime
            });
            function send(bl, type) {
                var f = document.createElement("form");
                f.method = "POST";
                f.enctype = "multipart/form-data";
                f.action = url;
                var inp = document.createElement("input");
                inp.type = "file";
                inp.name = "encoded_image";
                var dt = new DataTransfer();
                dt.items.add(new File([bl], type === "image/jpeg" ? "image.jpg" : "image.png", {
                    "type": type
                }));
                inp.files = dt.files;
                f.appendChild(inp);
                (document.body || document.documentElement).appendChild(f);
                f.submit();
            }
            // the long side down to 1600 px: Lens doesn't need more, the post stays small
            createImageBitmap(blob).then(function (bm) {
                var long = Math.max(bm.width, bm.height);
                if (long <= 1600 && (mime === "image/png" || mime === "image/jpeg"))
                    return send(blob, mime);
                var k = Math.min(1, 1600 / long), c = document.createElement("canvas");
                c.width = Math.round(bm.width * k);
                c.height = Math.round(bm.height * k);
                c.getContext("2d").drawImage(bm, 0, 0, c.width, c.height);
                c.toBlob(function (bl) {
                    send(bl || blob, bl ? "image/png" : mime);
                }, "image/png");
            }).catch(function () {
                send(blob, mime);
            });
            return JSON.stringify({
                "ok": true
            });
        },
        // a readiness poll: counts only, and a step down the page so lazy pictures load
        "scan": function (scroll) {
            var cards = visual().length, ov = overview();
            if (scroll)
                window.scrollBy(0, Math.round(window.innerHeight * 0.8));
            var c = counts(cards);
            c.ai = ov.len;
            c.bottom = window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 4;
            c.consentModal = !!document.querySelector('[role="dialog"][aria-modal="true"]') && cards === 0;
            return JSON.stringify(c);
        },
        "results": function () {
            var v = visual(), ov = overview();
            return JSON.stringify({
                "visual": v,
                "words": words(),
                "entity": {
                    "name": entityName(),
                    "description": ov.text
                },
                "tabs": tabs(),
                "translate": !!translateButton(),
                "counts": counts(v.length)
            });
        },
        "tabs": function () {
            return JSON.stringify(tabs());
        },
        "exact": function () {
            var e = exact();
            return JSON.stringify({
                "exact": e,
                "counts": counts(e.length)
            });
        },
        // the owner's own choice only (never by default): consent's "Reject all" form, submitted
        // (a click from a script doesn't keep the choice, a submit does)
        "reject": function () {
            var fs = document.querySelectorAll('form[action*="consent.google.com/save"]');
            for (var i = 0; i < fs.length; i++)
                if (fs[i].querySelector('input[name="set_eom"][value="true"]')) {
                    fs[i].submit();
                    return JSON.stringify({
                        "ok": true
                    });
                }
            return JSON.stringify({
                "ok": false
            });
        },
        "translate": function () {
            var b = translateButton();
            if (b)
                b.click();
            return JSON.stringify({
                "clicked": !!b
            });
        },
        // the translation is drawn into pixels (a JPEG data: picture and a canvas over it): both
        // are put together into one picture
        "translated": function () {
            var img = null, imgs = document.querySelectorAll('img[src^="data:image/jpeg"]');
            for (var i = 0; i < imgs.length; i++) {
                var w = imgs[i].getBoundingClientRect().width;
                if (w >= 150 && (!img || w > img.getBoundingClientRect().width))
                    img = imgs[i];
            }
            if (!img || !img.naturalWidth)
                return JSON.stringify({
                    "img": ""
                });
            var ir = img.getBoundingClientRect(), c = document.createElement("canvas");
            c.width = img.naturalWidth;
            c.height = img.naturalHeight;
            var sx = c.width / ir.width, sy = c.height / ir.height, ctx = c.getContext("2d");
            ctx.drawImage(img, 0, 0);
            var cvs = document.querySelectorAll("canvas");
            for (var j = 0; j < cvs.length; j++) {
                var r = cvs[j].getBoundingClientRect();
                if (r.width < 150 || r.right <= ir.left || r.left >= ir.right || r.bottom <= ir.top || r.top >= ir.bottom)
                    continue;
                try {
                    ctx.drawImage(cvs[j], (r.left - ir.left) * sx, (r.top - ir.top) * sy, r.width * sx, r.height * sy);
                } catch (e) {}
            }
            var out = "";
            try {
                out = c.toDataURL("image/jpeg", 0.9);
            } catch (e) {
                out = img.src;
            }
            return JSON.stringify({
                "img": out
            });
        }
    };
})();
