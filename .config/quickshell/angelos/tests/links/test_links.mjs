// links, mail and phones in free text (services/Links.js): Circle, the clipboard, notifications
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../../services/Links.js", import.meta.url), "utf8").replace(/^\.pragma library/m, "");
const L = new Function(src + "\nreturn { scan, find, linkify };")();
const urls = t => L.find(t, 20).map(l => l.kind + " " + l.url);
let n = 0;
const is = (t, want) => { assert.deepEqual(urls(t), want, t); n++; };

is("https://example.org/x", ["url https://example.org/x"]);
is("see www.angel.dev, and github.com/mixadod/angelOS.", ["url https://www.angel.dev", "url https://github.com/mixadod/angelOS"]);
is("(ссылка: Github.com/x)", ["url https://Github.com/x"]);
is("пиши на angel@mail.ru или звони +7 (999) 123-45-67", ["mail mailto:angel@mail.ru", "phone tel:+79991234567"]);
is("8 999 123 45 67", ["phone tel:89991234567"]);
is("https://en.wikipedia.org/wiki/Halo_(series)).", ["url https://en.wikipedia.org/wiki/Halo_(series)"]);
is("«пример.рф»", ["url https://пример.рф"]);
is("t.me/angelos и t.me", ["url https://t.me/angelos"]);
is("localhost:8080 и 127.0.0.1", []);
// not links: file names, versions, sentences glued by a dot, dates, short numbers
for (const t of ["readme.md", "main.py", "index.html", "photo.jpg", "v1.2.3 и 1.2.3", "Hello.World", "ок.Дальше",
                 "2026-10-15", "123-45", "цена 1500 руб", "script.sh", ""])
  is(t, []);
// a link once, even twice in the text; the limit
is("a.com a.com b.com", ["url https://a.com", "url https://b.com"]);
assert.equal(L.find("a.com b.com c.com d.com e.com f.com g.com h.com").length, 6); n++;
// linkify: bare ones wrapped, an existing <a> and tags left alone, phones not linked
assert.equal(L.linkify("<b>go</b> github.com/x now"), "<b>go</b> <a href=\"https://github.com/x\">github.com/x</a> now"); n++;
assert.equal(L.linkify("<a href=\"https://a.com\">a.com</a>"), "<a href=\"https://a.com\">a.com</a>"); n++;
assert.equal(L.linkify("call +7 999 123 45 67"), "call +7 999 123 45 67"); n++;
assert.equal(L.linkify("x@y.ru"), "<a href=\"mailto:x@y.ru\">x@y.ru</a>"); n++;
console.log(`  ✓ links: ${n} checks`);
