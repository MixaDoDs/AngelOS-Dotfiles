.pragma library

// Cava's ten raw ASCII bins, 0–100. Reject partial frames instead of animating junk.
function decodeSpectrum(line) {
    const bins = line.trim().split(";").filter(s => s !== "");
    if (bins.length !== 10)
        return [];
    const levels = bins.map(s => Number(s));
    if (levels.some(n => !Number.isFinite(n)))
        return [];
    return levels.map(n => Math.max(0, Math.min(1, n / 100)));
}

// One narrow sweep across ten strips; progress is 0–10.
function pulseStrength(progress, index) {
    const distance = progress - index;
    return distance >= 0 && distance < 1 ? Math.sin(distance * Math.PI) : 0;
}

// Display-only compression: quiet samples remain visible, zero input remains zero.
function displayLevel(level) {
    return Math.sqrt(Math.max(0, Math.min(1, level)));
}
