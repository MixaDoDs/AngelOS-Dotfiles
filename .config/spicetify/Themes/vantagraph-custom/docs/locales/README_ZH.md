<div align="center">

<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/assets/logo-dark.svg" width="110" alt="Vantagraph Custom">

# Vantagraph Custom

**Vantagraph 的轻量版。没有预设配色：主题绘制的每一种颜色，都由你在应用内部的编辑器里自己决定。**

[![许可证: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-A78BFA?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/LICENSE)
[![版本](https://img.shields.io/github/v/release/Miabeyefendi/Vantagraph-Custom?style=for-the-badge&color=F59E0B&label=version)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases/latest)
[![下载量](https://img.shields.io/github/downloads/Miabeyefendi/Vantagraph-Custom/total?style=for-the-badge&color=22C55E&label=downloads)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases)
[![Spicetify](https://img.shields.io/badge/Spicetify_2.43%2B-1E293B?style=for-the-badge&logo=spotify&logoColor=white)](https://spicetify.app/)

[English](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Türkçe](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_TR.md) · [Español](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ES.md) · [简体中文](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ZH.md) · [Русский](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_RU.md)


<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/palettes-grid.png" width="94%" alt="同一个 Spotify 界面，用编辑器做出的六套配色：VantagraphBlack、Plum、Ocean、Forest、Ember 和 Paper">

</div>

---

## ✨ 你会得到什么

**是颜色编辑器，不是配色列表。** 三十六种颜色，按它们绘制的位置分组：界面表面、文字与图标、按钮、进度条、线条与阴影、背景图片上的玻璃色调，以及 Spotify 自己绘制的少数几种颜色。每一种都支持 HEX、RGB、RGBA 或 HSL，都有独立的不透明度，拖动时 Spotify 立刻跟着变化。

**一个功能完整的取色器。** 饱和度区域、色相条和不透明度条，能吸取屏幕上任何颜色的吸管，R G B A 输入框，任意格式的数值输入，当前配色和最近使用的颜色一键复用，撤销与重做，还有搜索框。

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-picker.png" width="82%" alt="在 Spotify 中打开的颜色编辑器：取色区域、色相与不透明度条、HEX、RGB 和 HSL 输入，以及配色色块">
</div>

**会互相跟随的颜色，直到你另作决定。** 菜单文字跟随 Text，图标跟随 Subtext，播放符号跟随 Panel。改动源颜色，它们会一起变化。给其中一个设置自己的值，它就不再跟随；点一下又能重新关联。

**看清每种颜色画在哪里。** 点击任意颜色旁的靶心图标，它会在 Spotify 里闪烁，"Stroke" 或 "Glass Edge" 指的是什么，一看便知。

**可以分享的配色。** 把整套配色复制为文本，粘贴别人的配色，或者直接粘贴其他主题的 `color.ini` 行。

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-share.png" width="82%" alt="Share 面板，附带一套可一键复制或试用的示例配色">
</div>

**保留 Vantagraph 的其余部分，只去掉了图标集。** 字体、布局、背景和片段开关标签页，画中画歌词卡拉OK，任务栏播放器，滚轮调音量，以及单曲循环片段。这个版本不改动 Spotify 自带的图标，所以 Spotify 重绘图标的更新不会把它弄坏。

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/background-glass.png" width="82%" alt="专辑封面作为背景图片，前面是由编辑器玻璃色调着色的面板">
</div>

---

## 📦 安装

需要 [Spotify](https://www.spotify.com/download/) `1.2.86+` 和 [Spicetify](https://spicetify.app/docs/getting-started) `2.43+`。

最快的方式是 Spicetify Marketplace：搜索 **Vantagraph Custom** 并点击 Install。若要手动安装：

把本仓库复制到 `…/spicetify/Themes/`，目录名必须是 `vantagraph-custom`；再把其中 `Extensions/` 目录里的每个 `.js` 复制到 `…/spicetify/Extensions/`。然后：

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify apply
```

Spotify 会以 VantagraphBlack 配色重启，顶栏多出一个新按钮。点开它，停在 **Colors** 标签页，就可以开始修改。可选扩展以及如何退回原版 Spotify，请看[安装指南](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md)。

> 已经在用 [Vantagraph](https://github.com/Miabeyefendi/Vantagraph)？两者选其一。两套扩展同时开启，会出现两个设置按钮和两个音量滚轮。

---

## 📖 文档

| | |
|---|---|
| [**安装**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md) | 所有安装方式、每个扩展做什么，以及如何干净卸载 |
| [**颜色编辑器**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/COLORS.md) | 全部三十六种颜色、每种颜色绘制的位置，以及取色器里的每个工具 |
| [**设置**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/SETTINGS.md) | 其余四个标签页、每个滑块和每一个片段开关 |
| [**扩展**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md) | 各个扩展的细节，以及它们所基于的致谢 |
| [**技术指南**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/guides/TUTORIAL.md) | 一种颜色是如何从编辑器到达屏幕的 |
| [**更新日志**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/CHANGELOG.md) | 每个版本改了什么 |

> 你是在 Spotify 里看这段吗？上面的链接会在浏览器中打开。安装主题所需的一切，这一页上已经有了。

---

## 📜 许可证与致谢

Vantagraph Custom 采用 **AGPL-3.0**，署名条款见 [NOTICE](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/NOTICE)。只要源码保持开放、署名保持完整，你可以使用、修改和再分发。它基于同一作者的 [Vantagraph](https://github.com/Miabeyefendi/Vantagraph) 构建。

其中三个扩展是在前人工作之上的重写，分别来自 [Aspecky](https://github.com/Aspecky)、khanhas 与 [Spicetify](https://github.com/spicetify) 维护者，以及 [FO-SS](https://github.com/FO-SS)。各自贡献了什么、在此之上又加了什么，都写在[扩展指南](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md#credits)里。

Spotify 与本项目没有关联，也未为其背书。本主题在本地修改桌面客户端；你自担风险运行它。

<div align="center">
<br/>
<sub>由 <b><a href="https://github.com/Miabeyefendi">Miabeyefendi</a></b> 制作</sub>
</div>
