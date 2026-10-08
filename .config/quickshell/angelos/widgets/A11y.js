.pragma library

// Names for screen readers (AT-SPI, e.g. Orca): Quickshell 0.3.2 gives its windows an
// accessibility tree, and the Px widgets put roles and names in it. A control with no words
// of its own (a toggle, a slider, a dropdown in Settings) takes the label of the SettingRow
// it sits in.
function rowLabel(item) {
    for (let p = item ? item.parent : null, i = 0; p && i < 10; p = p.parent, i++)
        if (typeof p.label === "string" && p.label !== "" && p.control !== undefined)
            return p.label;
    return "";
}

function name(text, item, fallback) {
    return text || rowLabel(item) || fallback || "";
}
