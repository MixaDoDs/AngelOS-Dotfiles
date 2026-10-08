// angelOS for Steam (Millennium; scripts/steam-theme.py writes this theme). Steam keeps its
// colours in its own stylesheets, under class names that change with every update — so
// they are not named here: every colour Steam writes is recoloured by what it is, the way
// scripts/telegram-theme.py recolours Telegram. Greys (Steam's are a little blue) go onto
// angelOS's surfaces and text by their brightness, Steam's blues onto the accent, its greens
// onto "ok", its reds onto "danger"; the rest stays. They become the --ao-* variables, which
// colors.json fills in — fetched again every few seconds, so a new palette, the dark or light
// mode, the demon's hell and each of its circles show up at once.
const ROOT = document.documentElement;
const COLORS = new URL("colors.json", import.meta.url);

// where Steam's greys sit by brightness, and the variable each mark becomes
const RAMP = [[0.0, "s0"], [0.08, "s1"], [0.13, "s2"], [0.19, "s3"], [0.3, "s4"], [0.55, "s5"], [0.85, "s6"], [1.0, "s7"]];
const NUM = "([\\d.]+%?)";
const COLOUR = new RegExp("#(?:[0-9a-f]{8}|[0-9a-f]{6}|[0-9a-f]{3,4})\\b|rgba?\\(\\s*" + NUM + "\\s*,?\\s*" + NUM + "\\s*,?\\s*" + NUM + "\\s*(?:[,/]\\s*" + NUM + "\\s*)?\\)", "gi");

function channel(v, max) {
    return v.endsWith("%") ? parseFloat(v) / 100 : parseFloat(v) / max;
}
function parse(text) {
    if (text[0] === "#") {
        let h = text.slice(1);
        if (h.length <= 4)
            h = h.split("").map(c => c + c).join("");
        const n = i => parseInt(h.slice(i, i + 2), 16) / 255;
        return [n(0), n(2), n(4), h.length === 8 ? n(6) : 1];
    }
    const m = text.match(/[\d.]+%?/g);
    return [channel(m[0], 255), channel(m[1], 255), channel(m[2], 255), m.length > 3 ? channel(m[3], 1) : 1];
}
function hue(r, g, b) {
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
    if (d === 0)
        return 0;
    const h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return (h * 60 + 360) % 360;
}
function mix(a, b, t) {
    const pct = Math.round(t * 100);
    return pct <= 0 ? "var(--ao-" + a + ")" : pct >= 100 ? "var(--ao-" + b + ")" : "color-mix(in srgb, var(--ao-" + a + ") " + (100 - pct) + "%, var(--ao-" + b + "))";
}
// one of Steam's colours, as angelOS's
function recolour(text) {
    const [r, g, b, a] = parse(text);
    const y = 0.299 * r + 0.587 * g + 0.114 * b;
    const chroma = Math.max(r, g, b) - Math.min(r, g, b);
    const h = hue(r, g, b);
    let out;
    if (chroma < 0.24 || (chroma < 0.32 && y < 0.3)) {
        let i = 0;
        while (i < RAMP.length - 2 && y > RAMP[i + 1][0])
            i++;
        const [y0, s0] = RAMP[i], [y1, s1] = RAMP[i + 1];
        out = mix(s0, s1, Math.max(0, Math.min(1, (y - y0) / (y1 - y0))));
    } else if (h >= 180 && h <= 240) {
        out = mix("accent", "accentText", Math.max(0, Math.min(1, (y - 0.3) / 0.45)));
    } else if (h >= 70 && h <= 160) {
        out = "var(--ao-ok)";
    } else if (h >= 340 || h <= 12) {
        out = "var(--ao-danger)";
    } else {
        return text;
    }
    const alpha = Math.round(a * 100);
    return alpha >= 100 ? out : "color-mix(in srgb, " + out + " " + alpha + "%, transparent)";
}

const done = new WeakSet();
function style(st) {
    for (let i = 0; i < st.length; i++) {
        const prop = st[i];
        const value = st.getPropertyValue(prop);
        if (!value || value.indexOf("--ao-") >= 0 || !/#|rgb/i.test(value))
            continue;
        const next = value.replace(COLOUR, recolour);
        if (next !== value)
            st.setProperty(prop, next, st.getPropertyPriority(prop));
    }
}
function rules(list) {
    for (const rule of list) {
        if (rule.style)
            style(rule.style);
        if (rule.cssRules)
            rules(rule.cssRules);
    }
}
function sheet(s) {
    if (done.has(s))
        return;
    let list;
    try {
        list = s.cssRules;      // another site's sheet (none in the client) can't be read
    } catch (e) {
        return;
    }
    // still loading: next time
    if (!list || !list.length)
        return;
    // ours are already in angelOS's colours
    if (s.href && s.href.indexOf("/themes/angelOS/") >= 0) {
        done.add(s);
        return;
    }
    done.add(s);
    rules(list);
}
function sweep() {
    for (const s of document.styleSheets)
        sheet(s);
}

// the palette: the variables, fetched again now and then (colors.json is rewritten for every
// palette, mode, realm and circle)
let last = "";
async function palette() {
    try {
        const r = await fetch(COLORS.href + "?t=" + Date.now(), {
            cache: "no-store"
        });
        const text = await r.text();
        if (text === last)
            return;
        last = text;
        const vars = JSON.parse(text);
        for (const k in vars)
            ROOT.style.setProperty("--ao-" + k, vars[k]);
        ROOT.dataset.angelos = vars.realm || "heaven";
    } catch (e) {}
}

sweep();
palette();
// Steam loads its stylesheets in pieces as you go: the new ones are recoloured as they arrive
new MutationObserver(() => setTimeout(sweep, 50)).observe(document.head || ROOT, {
    childList: true,
    subtree: true
});
// a stylesheet that is still loading has no rules yet: it is swept once it loads — a
// notification toast lives five seconds, the 4 s sweep came too late for it
document.addEventListener("load", e => {
    if (e.target && e.target.tagName === "LINK")
        sweep();
}, true);
let early = 0;
const fast = setInterval(() => {
    sweep();
    if (++early >= 20)
        clearInterval(fast);
}, 150);
setInterval(sweep, 4000);
setInterval(palette, 3000);
