// VANTAGRAPH SNIPPET DIAGNOSTIC v1
// Spotify UI'daki tüm stillenebilir bölgeleri tarıyor

void function(){
  const out = [];
  const hr = "─".repeat(50);
  out.push("=== VANTAGRAPH SNIPPET DIAGNOSTIC ===");
  out.push("Sayfa: " + location.pathname);
  out.push(hr);

  // 1. Tüm data-testid'ler
  out.push("\n📌 DATA-TESTID ELEMENTLER:");
  const testIds = new Set();
  document.querySelectorAll("[data-testid]").forEach(el => {
    testIds.add(el.getAttribute("data-testid"));
  });
  [...testIds].sort().forEach(id => out.push("  " + id));

  // 2. Tüm aria-label'lar (butonlar + interaktif)
  out.push("\n🏷️ ARIA-LABEL BUTONLAR:");
  const ariaSet = new Set();
  document.querySelectorAll("[aria-label]").forEach(el => {
    const tag = el.tagName.toLowerCase();
    const label = el.getAttribute("aria-label");
    if (tag === "button" || tag === "a" || el.getAttribute("role") === "button") {
      ariaSet.add(tag + " | " + label);
    }
  });
  [...ariaSet].sort().forEach(a => out.push("  " + a));

  // 3. Root__ sınıfları (Ana layout bölgeleri)
  out.push("\n🏗️ ROOT LAYOUT BÖLGELERİ:");
  document.querySelectorAll("[class*='Root__']").forEach(el => {
    const cls = [...el.classList].filter(c => c.startsWith("Root__")).join(", ");
    out.push("  " + cls + " → " + el.tagName + (el.id ? "#" + el.id : ""));
  });

  // 4. main- prefixli class'lar (Spotify component'leri)
  out.push("\n🧩 MAIN-* COMPONENT'LER (top 60):");
  const mainClasses = new Set();
  document.querySelectorAll("[class*='main-']").forEach(el => {
    [...el.classList].filter(c => c.startsWith("main-")).forEach(c => mainClasses.add(c));
  });
  [...mainClasses].sort().slice(0, 60).forEach(c => out.push("  " + c));

  // 5. Görünür section/shelf'ler
  out.push("\n📦 SECTION/SHELF ARIA-LABEL'LER:");
  document.querySelectorAll("section[aria-label]").forEach(s => {
    out.push("  " + s.getAttribute("aria-label"));
  });

  // 6. Gizlenebilir elementler (display != none olanlar)
  out.push("\n🔲 GİZLENEBİLİR BÖLGELER:");
  const hideable = [
    { sel: ".main-connectBar-connectBar", name: "Connect Bar" },
    { sel: ".main-buddyFeed-container", name: "Friend Activity" },
    { sel: "[aria-label='Friend Activity']", name: "Friend Activity Button" },
    { sel: "[aria-label=\"What's New\"]", name: "What's New Button" },
    { sel: ".main-userWidget-displayName", name: "Profile Username" },
    { sel: ".main-nowPlayingBar-lyricsButton", name: "Lyrics Button" },
    { sel: "[data-testid='fullscreen-mode-button']", name: "Fullscreen Button" },
    { sel: ".main-trackList-rowPlayCount, .main-trackList-playsHeader", name: "Play Count" },
    { sel: ".view-homeShortcutsGrid-shortcuts", name: "Home Shortcuts Grid" },
    { sel: ".main-entityHeader-imageContainer", name: "Playlist Album Cover" },
    { sel: ".main-topBar-background", name: "Topbar Background" },
    { sel: ".main-actionBarBackground-background", name: "Action Bar Gradient" },
    { sel: ".main-entityHeader-backgroundColor", name: "Entity Header Gradient" },
    { sel: ".x-downloadButton-DownloadButton", name: "Download Button" },
    { sel: ".main-nowPlayingView-section:not(.main-nowPlayingView-queue)", name: "NPV Sections (non-queue)" },
    { sel: ".main-nowPlayingView-aboutArtistV2", name: "About Artist" },
    { sel: ".main-trackList-trackListHeader", name: "Track List Header" },
    { sel: "#Desktop_LeftSidebar_Id", name: "Left Sidebar" },
    { sel: ".Root__right-sidebar", name: "Right Sidebar" },
    { sel: ".Root__now-playing-bar", name: "Now Playing Bar" },
    { sel: "[data-testid='now-playing-bar']", name: "NP Bar (testid)" },
    { sel: ".lyrics-lyrics-background", name: "Lyrics Background" },
    { sel: ".lyrics-lyrics-contentWrapper", name: "Lyrics Content" },
    { sel: ".main-coverSlotExpanded-container", name: "Expanded Cover Art" },
    { sel: ".main-coverSlotCollapsed-container", name: "Collapsed Cover Art" },
    { sel: ".progress-bar", name: "Progress Bar" },
    { sel: ".os-scrollbar", name: "Scrollbar" },
    { sel: ".main-yourLibraryX-entryPoints", name: "Library Entry Points" },
    { sel: ".main-yourLibraryX-listItem", name: "Library List Items" },
    { sel: ".main-globalNav-searchInputContainer", name: "Search Input" },
    { sel: "[data-testid='tracklist-row']", name: "Track List Rows" },
    { sel: ".main-card-card", name: "Cards" },
    { sel: ".main-cardImage-imageWrapper", name: "Card Images" },
  ];
  hideable.forEach(h => {
    const el = document.querySelector(h.sel);
    const count = document.querySelectorAll(h.sel).length;
    out.push("  " + (el ? "✅" : "❌") + " " + h.name + " (" + h.sel.substring(0,50) + ") → " + count + " adet");
  });

  // 7. CSS Custom Properties (Spicetify + Encore)
  out.push("\n🎨 CSS DEĞİŞKENLERİ (theme-related):");
  const cs = getComputedStyle(document.documentElement);
  const vars = ["--spice-main","--spice-sidebar","--spice-player","--spice-card","--spice-shadow",
    "--spice-text","--spice-subtext","--spice-button","--spice-button-active","--spice-accent",
    "--spice-highlight","--spice-notification","--spice-notification-error",
    "--encore-border-radius-rounded","--encore-graphic-size-decorative-smaller",
    "--encore-graphic-size-decorative-base","--encore-graphic-size-decorative-larger"];
  vars.forEach(v => {
    const val = cs.getPropertyValue(v).trim();
    if (val) out.push("  " + v + ": " + val);
  });

  // 8. Mevcut snippet style tag'ları
  out.push("\n🔧 AKTİF STYLE TAG'LER:");
  document.querySelectorAll("style[id]").forEach(s => {
    out.push("  #" + s.id + " (" + s.textContent.length + " chars)");
  });

  const result = out.join("\n");
  console.log(result);
  try { copy(result); console.log("\n✅ Panoya kopyalandı!"); } catch(e) { console.log("\n⚠️ copy() yok, manuel kopyala."); }
}();

