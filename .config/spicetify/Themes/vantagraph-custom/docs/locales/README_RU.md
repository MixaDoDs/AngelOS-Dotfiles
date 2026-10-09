<div align="center">

<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/assets/logo-dark.svg" width="110" alt="Vantagraph Custom">

# Vantagraph Custom

**Облегчённая версия Vantagraph. Готовых палитр нет: каждый цвет, который рисует тема, вы задаёте сами в редакторе прямо внутри приложения.**

[![Лицензия: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-A78BFA?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/LICENSE)
[![Версия](https://img.shields.io/github/v/release/Miabeyefendi/Vantagraph-Custom?style=for-the-badge&color=F59E0B&label=version)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases/latest)
[![Загрузки](https://img.shields.io/github/downloads/Miabeyefendi/Vantagraph-Custom/total?style=for-the-badge&color=22C55E&label=downloads)](https://github.com/Miabeyefendi/Vantagraph-Custom/releases)
[![Spicetify](https://img.shields.io/badge/Spicetify_2.43%2B-1E293B?style=for-the-badge&logo=spotify&logoColor=white)](https://spicetify.app/)

[English](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Türkçe](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_TR.md) · [Español](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ES.md) · [简体中文](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_ZH.md) · [Русский](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/locales/README_RU.md)


<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/palettes-grid.png" width="94%" alt="Один и тот же экран Spotify в шести палитрах, сделанных в редакторе: VantagraphBlack, Plum, Ocean, Forest, Ember и Paper">

</div>

---

## ✨ Что вы получаете

**Редактор цвета, а не список палитр.** Тридцать шесть цветов, сгруппированных по тому, что они окрашивают: поверхности, текст и значки, кнопки, полосы прогресса, линии и тени, стеклянные оттенки поверх фонового изображения и несколько цветов, которые Spotify рисует сам. Каждый принимает HEX, RGB, RGBA или HSL, имеет собственную прозрачность и меняет Spotify прямо во время перетаскивания.

**Пипетка и всё остальное.** Поле насыщенности, полосы оттенка и прозрачности, пипетка, которая берёт цвет с любого места экрана, поля R G B A, ввод значения в любом формате, цвета вашей палитры и последние выбранные цвета в один клик, отмена и повтор, а также поиск.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-picker.png" width="82%" alt="Редактор цвета внутри Spotify: поле цвета, полосы оттенка и прозрачности, ввод HEX, RGB и HSL, образцы палитры">
</div>

**Цвета, которые следуют за другими, пока вы не решите иначе.** Текст меню следует за Text, значки за Subtext, символ воспроизведения за Panel. Измените исходный цвет, и они изменятся вместе с ним. Задайте одному из них собственное значение, и он перестанет следовать; один клик снова связывает его.

**Видно, где рисует каждый цвет.** Нажмите значок мишени рядом с любым цветом, и он замигает внутри Spotify, так что «Stroke» или «Glass Edge» больше не приходится угадывать.

**Палитрами можно делиться.** Скопируйте всю палитру как текст, вставьте чужую или вставьте строки `color.ini` прямо из другой темы.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/editor-share.png" width="82%" alt="Панель Share с готовой палитрой-примером, которую можно скопировать или попробовать в один клик">
</div>

**Остальной Vantagraph, но без набора значков.** Вкладки шрифта, раскладки, фона и сниппетов, караоке-текст в отдельном окне, плеер поверх панели задач, громкость колесом мыши и повтор фрагмента в пределах трека. Эта версия не трогает собственные значки Spotify, поэтому обновление, которое их перерисует, не может её сломать.

<div align="center">
<img src="https://raw.githubusercontent.com/Miabeyefendi/Vantagraph-Custom/main/design/screenshots/background-glass.png" width="82%" alt="Обложка альбома как фоновое изображение за стеклянными панелями, окрашенными стеклянными цветами редактора">
</div>

---

## 📦 Установка

Нужны [Spotify](https://www.spotify.com/download/) `1.2.86+` и [Spicetify](https://spicetify.app/docs/getting-started) `2.43+`.

Быстрее всего через Spicetify Marketplace: найдите **Vantagraph Custom** и нажмите Install. Чтобы установить вручную:

Скопируйте этот репозиторий в `…/spicetify/Themes/` в папку с именем `vantagraph-custom`, а каждый `.js` из его папки `Extensions/` в `…/spicetify/Extensions/`. Затем:

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify apply
```

Spotify перезапускается с палитрой VantagraphBlack и новой кнопкой в верхней панели. Откройте её, оставайтесь на вкладке **Colors** и начинайте менять. Необязательные расширения и возврат к обычному Spotify описаны в [руководстве по установке](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md).

> Уже пользуетесь [Vantagraph](https://github.com/Miabeyefendi/Vantagraph)? Выберите что-то одно. Если включены оба набора расширений, появятся две кнопки настроек и два колеса громкости.

---

## 📖 Документация

| | |
|---|---|
| [**Установка**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/INSTALL.md) | Все способы установки, что делает каждое расширение и как удалить начисто |
| [**Редактор цвета**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/COLORS.md) | Все тридцать шесть цветов, что окрашивает каждый и все инструменты пипетки |
| [**Настройки**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/SETTINGS.md) | Остальные четыре вкладки, каждый ползунок и каждый сниппет |
| [**Расширения**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md) | Расширения подробно и благодарности тем, на чьей работе они построены |
| [**Техническое руководство**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/guides/TUTORIAL.md) | Как цвет попадает из редактора на экран |
| [**Изменения**](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/CHANGELOG.md) | Что поменялось в каждом релизе |

> Читаете это внутри Spotify? Ссылки выше открываются в браузере. Всё, что нужно для установки темы, уже есть на этой странице.

---

## 📜 Лицензия и благодарности

Vantagraph Custom распространяется под **AGPL-3.0**, условия атрибуции в файле [NOTICE](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/NOTICE). Пользуйтесь, изменяйте и распространяйте, пока исходный код остаётся открытым, а атрибуция нетронутой. Тема построена на [Vantagraph](https://github.com/Miabeyefendi/Vantagraph) того же автора.

Три расширения переписаны на основе более ранних работ [Aspecky](https://github.com/Aspecky), khanhas и сопровождающих [Spicetify](https://github.com/spicetify), а также [FO-SS](https://github.com/FO-SS). Что внёс каждый и что было добавлено сверху, изложено в [руководстве по расширениям](https://github.com/Miabeyefendi/Vantagraph-Custom/blob/main/docs/EXTENSIONS.md#credits).

Spotify не связан с этим проектом и не одобряет его. Тема изменяет настольный клиент локально; вы запускаете её на свой страх и риск.

<div align="center">
<br/>
<sub>Сделано <b><a href="https://github.com/Miabeyefendi">Miabeyefendi</a></b></sub>
</div>
