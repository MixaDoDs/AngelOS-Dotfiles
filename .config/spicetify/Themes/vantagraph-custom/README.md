<div align="center">

<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/assets/logo-dark.svg" width="110" alt="Vantagraph Custom">

# Vantagraph Custom

**The lite edition of Vantagraph. No preset palettes: every colour the theme paints is yours to set, from an editor that lives inside the app.**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-A78BFA?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/LICENSE)
[![Version](https://img.shields.io/github/v/release/Miabeyefendi/Vantagraph-Custom?style=for-the-badge&color=F59E0B&label=version)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Miabeyefendi/Vantagraph-Custom/total?style=for-the-badge&color=22C55E&label=downloads)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases)
[![Spicetify](https://img.shields.io/badge/Spicetify_2.43%2B-1E293B?style=for-the-badge&logo=spotify&logoColor=white)](https://spicetify.app/)

[English](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Türkçe](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_TR.md) · [Español](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ES.md) · [简体中文](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ZH.md) · [Русский](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_RU.md)


<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/palettes-grid.png" width="94%" alt="The same Spotify screen in six palettes made with the editor: VantagraphBlack, Plum, Ocean, Forest, Ember and Paper">

</div>

---

## ✨ What you get

**A colour editor, not a palette list.** Thirty-six colours, grouped by where they paint: surfaces, text and icons, buttons, progress bars, lines and shadows, the glass tints used over a background image, and the few colours Spotify draws on its own. Each one takes HEX, RGB, RGBA or HSL, has its own opacity, and changes Spotify while you drag.

**A picker that does the whole job.** A saturation field, hue and opacity strips, an eyedropper that samples anything on screen, R G B A fields, typed values in any format, your palette and your recent picks as one-click swatches, undo and redo, and a search box.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-picker.png" width="82%" alt="The colour editor open inside Spotify: colour field, hue and opacity strips, HEX, RGB and HSL input, and palette swatches">
</div>

**Colours that follow each other until you say otherwise.** Menu text follows Text, the icons follow Subtext, the play symbol follows Panel. Change the parent and they come along. Give one a value of its own and it stops following; one click links it back.

**See where a colour paints.** Press the target icon next to any colour and it blinks inside Spotify, so "Stroke" or "Glass Edge" never has to be a guess.

**Palettes you can share.** Copy the whole palette as text, paste someone else's, or paste `color.ini` lines straight from another theme.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-share.png" width="82%" alt="The Share panel with a ready example palette that can be copied or tried in one click">
</div>

**The rest of Vantagraph, minus the icon set.** Font, layout, background and snippet tabs, lyric karaoke in picture-in-picture, a taskbar player, scroll-wheel volume and per-track looping. This edition leaves Spotify's own icons alone, so a Spotify update that redraws them cannot break it.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/background-glass.png" width="82%" alt="The album cover as a background image behind glass panels tinted by the editor's glass colours">
</div>

---

## 📦 Install

You need [Spotify](https://www.spotify.com/download/) `1.2.86+` and [Spicetify](https://spicetify.app/docs/getting-started) `2.43+`.

The quickest way is Spicetify Marketplace: search for **Vantagraph Custom** and press Install. To install by hand instead:

Copy this repository into `…/spicetify/Themes/` as a folder named `vantagraph-custom`, and every `.js` from its `Extensions/` folder into `…/spicetify/Extensions/`. Then:

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify apply
```

Spotify restarts in the VantagraphBlack palette with a new button in the topbar. Open it, stay on **Colors**, and start changing things. The optional extensions and the way back to stock Spotify are in the [installation guide](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md).

> Already using [Vantagraph](https://github.com/Miabeyefendi/Vantagraph)? Run one or the other. With both sets of extensions enabled you get two settings buttons and two volume wheels.

---

## 📖 Documentation

| | |
|---|---|
| [**Installation**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md) | Every install path, which extension does what, and how to uninstall cleanly |
| [**The colour editor**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/COLORS.md) | All thirty-six colours, what each one paints, and every tool in the picker |
| [**Settings**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/SETTINGS.md) | The other four tabs, every slider and every snippet |
| [**Extensions**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md) | The add-ons in detail, and the credits they are built on |
| [**Tutorial**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/guides/TUTORIAL.md) | How a colour gets from the editor to the screen |
| [**Changelog**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/CHANGELOG.md) | What changed in each release |

> Reading this inside Spotify? The links above open in your browser. Everything you need to install the theme is already on this page.

---

## 📜 License and credits

Vantagraph Custom is **AGPL-3.0**, with the attribution terms in [NOTICE](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/NOTICE). Use it, change it, ship it, as long as the source stays open and the attribution stays intact. It is built on [Vantagraph](https://github.com/Miabeyefendi/Vantagraph) by the same author.

Three of the extensions are rewrites built on earlier work by [Aspecky](https://github.com/Aspecky), khanhas and the [Spicetify](https://github.com/spicetify) maintainers, and [FO-SS](https://github.com/FO-SS). What each one contributed, and what was added on top, is set out in the [extensions guide](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md#credits).

Spotify is not affiliated with this project and does not endorse it. The theme modifies the desktop client locally; you run it at your own risk.

<div align="center">
<br/>
<sub>Built by <b><a href="https://github.com/Miabeyefendi">Miabeyefendi</a></b></sub>
</div>
