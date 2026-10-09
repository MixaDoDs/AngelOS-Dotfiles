<div align="center">

<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/assets/logo-dark.svg" width="110" alt="Vantagraph Custom">

# Vantagraph Custom

**Vantagraph'ın lite sürümü. Hazır palet yok: temanın boyadığı her rengi, uygulamanın içindeki bir editörden sen belirliyorsun.**

[![Lisans: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-A78BFA?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/LICENSE)
[![Sürüm](https://img.shields.io/github/v/release/Miabeyefendi/Vantagraph-Custom?style=for-the-badge&color=F59E0B&label=version)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases/latest)
[![İndirme](https://img.shields.io/github/downloads/Miabeyefendi/Vantagraph-Custom/total?style=for-the-badge&color=22C55E&label=downloads)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases)
[![Spicetify](https://img.shields.io/badge/Spicetify_2.43%2B-1E293B?style=for-the-badge&logo=spotify&logoColor=white)](https://spicetify.app/)

[English](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Türkçe](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_TR.md) · [Español](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ES.md) · [简体中文](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ZH.md) · [Русский](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_RU.md)


<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/palettes-grid.png" width="94%" alt="Aynı Spotify ekranı, editörle yapılmış altı palette: VantagraphBlack, Plum, Ocean, Forest, Ember ve Paper">

</div>

---

## ✨ Ne alıyorsun

**Palet listesi değil, bir renk editörü.** Otuz altı renk, boyadıkları yere göre gruplanmış: yüzeyler, metin ve ikonlar, düğmeler, ilerleme çubukları, çizgiler ve gölgeler, arka plan resmi üzerindeki cam tonları ve Spotify'ın kendi çizdiği birkaç renk. Her biri HEX, RGB, RGBA ya da HSL kabul ediyor, kendi opaklığı var ve sen sürüklerken Spotify'ı değiştiriyor.

**İşin tamamını yapan bir seçici.** Doygunluk alanı, ton ve opaklık şeritleri, ekrandaki herhangi bir şeyden renk alan damlalık, R G B A kutuları, her formatta yazılabilen değer, paletindeki ve son seçtiğin renkler tek tıkla, geri al ve yinele, bir de arama kutusu.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-picker.png" width="82%" alt="Spotify içinde açık renk editörü: renk alanı, ton ve opaklık şeritleri, HEX, RGB ve HSL girişi, palet örnekleri">
</div>

**Sen aksini söyleyene kadar birbirini izleyen renkler.** Menü metni Text'i, ikonlar Subtext'i, play simgesi Panel'i izliyor. Kaynağı değiştirirsen onlar da onunla geliyor. Birine kendi değerini verirsen izlemeyi bırakıyor; tek tıkla yeniden bağlanıyor.

**Bir rengin nereyi boyadığını gör.** Herhangi bir rengin yanındaki hedef simgesine bas, renk Spotify'ın içinde yanıp sönsün. "Stroke" ya da "Glass Edge" artık tahmin işi değil.

**Paylaşılabilen paletler.** Paletin tamamını metin olarak kopyala, başkasınınkini yapıştır ya da başka bir temadan `color.ini` satırlarını doğrudan yapıştır.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-share.png" width="82%" alt="Tek tıkla kopyalanabilen ya da denenebilen hazır bir örnek paletle Share paneli">
</div>

**Vantagraph'ın geri kalanı, ikon seti hariç.** Font, yerleşim, arka plan ve snippet sekmeleri, resim içinde resim karaoke sözler, görev çubuğu oynatıcısı, tekerlekle ses ve parça bazlı döngü. Bu sürüm Spotify'ın kendi ikonlarına dokunmuyor, bu yüzden onları yeniden çizen bir Spotify güncellemesi temayı bozamıyor.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/background-glass.png" width="82%" alt="Arka plan resmi olarak albüm kapağı, önünde editörün cam renkleriyle tonlanmış paneller">
</div>

---

## 📦 Kurulum

[Spotify](https://www.spotify.com/download/) `1.2.86+` ve [Spicetify](https://spicetify.app/docs/getting-started) `2.43+` gerekiyor.

En kısa yol Spicetify Marketplace: **Vantagraph Custom** diye ara ve Install'a bas. Elle kurmak için:

Bu depoyu `…/spicetify/Themes/` içine `vantagraph-custom` adlı bir klasör olarak, `Extensions/` klasöründeki her `.js` dosyasını da `…/spicetify/Extensions/` içine kopyala. Sonra:

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify apply
```

Spotify VantagraphBlack paletiyle ve üst çubukta yeni bir düğmeyle yeniden başlıyor. Düğmeyi aç, **Colors** sekmesinde kal ve değiştirmeye başla. İsteğe bağlı eklentiler ve stok Spotify'a dönüş [kurulum rehberinde](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md).

> Zaten [Vantagraph](https://github.com/Miabeyefendi/Vantagraph) mı kullanıyorsun? Birini ya da diğerini çalıştır. İki eklenti seti birden açıkken iki ayar düğmesi ve iki ses tekerleği olur.

---

## 📖 Belgeler

| | |
|---|---|
| [**Kurulum**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md) | Tüm kurulum yolları, hangi eklenti ne yapıyor, nasıl temiz kaldırılır |
| [**Renk editörü**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/COLORS.md) | Otuz altı rengin tamamı, her birinin neyi boyadığı ve seçicideki her araç |
| [**Ayarlar**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/SETTINGS.md) | Diğer dört sekme, her kaydırıcı ve her snippet |
| [**Eklentiler**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md) | Eklentiler detaylı, ve üzerine inşa edildikleri atıflar |
| [**Teknik rehber**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/guides/TUTORIAL.md) | Bir rengin editörden ekrana nasıl ulaştığı |
| [**Değişiklikler**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/CHANGELOG.md) | Her sürümde ne değişti |

> Bunu Spotify içinden mi okuyorsun? Yukarıdaki linkler tarayıcında açılır. Temayı kurmak için gereken her şey zaten bu sayfada.

---

## 📜 Lisans ve atıflar

Vantagraph Custom **AGPL-3.0** altında, atıf şartları [NOTICE](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/NOTICE) dosyasında. Kaynak açık kaldığı ve atıf korunduğu sürece kullan, değiştir, dağıt. Aynı yazarın [Vantagraph](https://github.com/Miabeyefendi/Vantagraph) teması üzerine kurulu.

Eklentilerin üçü daha önceki işler üzerine yazılmış yeniden yazımlardır: [Aspecky](https://github.com/Aspecky), khanhas ve [Spicetify](https://github.com/spicetify) sürdürücüleri, ve [FO-SS](https://github.com/FO-SS). Her birinin neyi kattığı ve üzerine ne eklendiği [eklentiler rehberinde](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md#credits) yazılı.

Spotify bu projeyle bağlı değildir ve onu onaylamamıştır. Tema masaüstü istemcisini yerel olarak değiştirir; kendi riskinle çalıştırırsın.

<div align="center">
<br/>
<sub><b><a href="https://github.com/Miabeyefendi">Miabeyefendi</a></b> tarafından yapıldı</sub>
</div>
