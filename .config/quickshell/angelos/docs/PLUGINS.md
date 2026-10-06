# Плагины angelOS

Плагин — это папка с `manifest.json` и QML-файлами:

```
~/.config/angelos/plugins/<id>/     ← твои плагины
~/.config/quickshell/angelos/plugins/<id>/  ← встроенные примеры
```

Быстрый старт: **Настройки → Плагины → Новый плагин** создаёт заготовку из
`plugins/_template` со всеми точками встраивания. Правишь QML — оболочка
перезагружается сама. Включить/выключить плагин можно там же.

Создание с ИИ: включи **Настройки → System → Режим разработчика** и открой
**Мастер плагинов** в настройках или «Пуске». Он уточняет идею, предлагает
план, генерирует файлы и устанавливает их после просмотра. Поддерживаются
OpenAI и Claude, русский и английский интерфейс. [Руководство мастера](PLUGIN_STUDIO.md).

## manifest.json

```json
{
  "id": "my-widget",
  "name": "Мой виджет",
  "version": "1.0.0",
  "author": "я",
  "description": "что он делает",
  "icon": "heart",
  "enabledByDefault": true,
  "themes": ["pixel", "mac"],

  "menu": [
    { "label": "Терминал", "icon": "terminal", "exec": "kitty" },
    { "separator": true },
    { "label": "Обои…", "icon": "image", "settings": "wallpaper" },
    { "label": "Сайт", "icon": "info", "url": "https://example.com" }
  ],
  "menuComponent": "Menu.qml",
  "barWidget": "BarWidget.qml",
  "desktopWidget": "DesktopWidget.qml",
  "realms": ["heaven", "hell"],
  "settings": "Settings.qml",
  "main": "Main.qml",
  "launcher": "Launcher.qml"
}
```

Все поля кроме `id`/`name` необязательны. `themes` — в каких темах плагин выглядит
правильно: `"pixel"` (исходная пиксельная), `"mac"` (macOS / Golden Gate) или обе;
без поля плагин считается только пиксельным. «Плагины» и каталог Community
показывают бейдж «macOS» / «Pixel» / «обе темы» и предупреждают, если текущую тему
плагин не поддерживает (см. [Theme API](#theme-api-пиксель-и-macos)). Точки встраивания:

| поле | куда попадает | свойства, которые получает компонент |
|---|---|---|
| `menu` | ПКМ-меню рабочего стола (декларативно; в macOS — пункты меню рабочего стола без значков). `exec` — команда sh, `settings` — открыть страницу настроек, `url` — xdg-open | — |
| `menuComponent` | QML-элементы в ПКМ-меню (обычно `PxMenuItem`) | `plugin`, `menu` (вызови `menu.close()`) |
| `barWidget` | панель, рядом с треем (все стили); в macOS — строка меню, слева от значков трея («menu bar extra»), в том же порядке, что на панели | `plugin`, `screenName`, `barWindow` |
| `desktopWidget` | виджет на рабочем столе: angelOS сам рисует рамку — в пиксельной теме окно с заголовком `desktopTitle` (без окончания: `"my-widget"` — angelOS добавит выбранное в настройках `.exe`, `.sh` или `.bin`; в своём QML — `Skin.title("my-widget")`), в macOS — карточку Liquid Glass без заголовка; перетаскивание и удаление; добавляется через ПКМ → Вид | `plugin`, `screenName`, `widget` (`{uid, x, y, settings}`) |
| `settings` | страница в Настройки → Плагины → имя | `plugin` |
| `main` | фоновый сервис, живёт пока плагин включён (можно держать тут `IpcHandler`) | `plugin` |
| `launcher` | провайдер результатов лаунчера (Mod+Space; в macOS — Spotlight: свой раздел, префикс работает так же, пиксельные имена значков становятся линейными, `image` — картинкой) | `plugin`, `pluginId` |
| `sidebarWidget` | блок в экспериментальном сайдбаре (раздел «AI-лимиты»), ширина задаётся сайдбаром | `plugin`, `width` |

`name` и `description` могут быть строкой или объектом `{"ru": "…", "en": "…"}` —
тогда показывается вариант на языке интерфейса.

## Провайдер лаунчера

```qml
QtObject {
    property var plugin
    property string pluginId
    readonly property string prefix: "web"   // «web запрос» — только этот провайдер
    readonly property bool global: true      // участвовать в обычном поиске
    signal changed                           // дёрни, когда подгрузились асинхронные данные

    // text — запрос без префикса; prefixed — набран ли префикс
    function query(text, prefixed) {
        return [{ id: "open:1", title: "Заголовок", subtitle: "подпись",
                  icon: "heart",            // пиксельная иконка
                  image: "/путь/к/png",     // или картинка
                  score: 50 }];             // приложения: 20–130
    }
    function activate(id, row) { /* вернуть true, чтобы лаунчер не закрывался */ }
}
```

Готовые примеры: `plugins/web-search` (префикс `web`, фавиконки, MRU),
`plugins/claude-companion` (префикс `claude`), `plugins/codex-companion`
(префикс `codex`) и `plugins/osu-mini` (`osu`).

Имена файлов плагина не должны совпадать с синглтонами `qs.services`
(`Sidebar`, `Idle`, `Fonts`, `Capture`, `MetaTap`, …): QML путает типы.

Объяви в корне компонента те свойства, которые используешь, например
`property var plugin` и `property string screenName`.

Виджет рабочего стола — это только содержимое: размер берётся из `implicitWidth` /
`implicitHeight`, рамку «*.exe» рисует angelOS. Виджеты рисуются в поверхности
обоев (backdrop niri): она не принимает ввод, поэтому angelOS ловит мышь
невидимым прокси и передаёт виджету настоящие события Qt — нажатия, hover,
колесо работают как обычно; перетаскивание за заголовок делает хост. Необязательное
`property bool wantVisible` прячет рамку, когда показывать нечего (в режиме правки
виджет всё равно виден полупрозрачным, чтобы его можно было подвинуть).

## Theme API: пиксель и macOS

У angelOS две темы, и пользователь переключает их на ходу:

- **пиксельная** (исходная: Win98 / NEEDY GIRL OVERDOSE) — квадратные рамки с фаской,
  пиксельные шрифты, размеры по сетке арт-пикселя `Theme.u`, заголовки «name.exe»;
- **macOS** (Golden Gate, Liquid Glass) — скруглённое стекло, системный шрифт (Inter
  или SF Pro), размеры в пунктах, без «.exe».

Плагин, который выглядит правильно в обеих, объявляет `"themes": ["pixel", "mac"]`
и берёт всё оформление из **Theme API** — синглтона `Skin` (`import qs.services`,
`services/Skin.qml`). Значения не копируй — привязывайся: тема, светлое/тёмное,
акцентный цвет, масштаб шрифта и «Уменьшить прозрачность» меняются на ходу.

| что | токены |
|---|---|
| какая тема | `Skin.mac`, `Skin.pixel`, `Skin.name` (`"pixel"` / `"mac"` / `"hell"`), `Skin.macWidgets` — вид виджетов рабочего стола (у них свой стиль в Настройках → Виджеты; в `desktopWidget` проверяй его), `Skin.hell`, `Skin.dark` |
| цвета | `accent`, `accentText`, `text`, `textDim`, `textFaint`, `surface` (тело карточки; в macOS — стекло), `surfaceAlt`, `sunken`, `separator`, `hover`, `danger`, `ok`, `warn`, `shadow`; `Skin.mix(a, b, t)` |
| панель | `Skin.ink(screenName)` — цвет виджета панели: в macOS строка меню чёрная или белая по обоям под ней, виджет одноцветный, как «menu bar extra» |
| шрифт | `font`, `titleFont`, `mono`, `fontSize("small" / "body" / "title" / "big" / "huge")`, `smallSize`, `textSize`, `titleSize`, `bigSize`, `renderType` (проще — `PxText { kind }`) |
| размеры | `Skin.px(n)` — длина в пунктах (macOS: × масштаб шрифта; пиксель: по сетке, 2 пункта = арт-пиксель), `spacing`, `padding`, `radius` (у контролов; 0 в пикселе), `cardRadius`, `controlHeight`, `iconSize` |
| прозрачность | `Skin.reduceTransparency` (macOS → «Уменьшить прозрачность», размытие выключено или идёт полноэкранная игра) и `Skin.glass` (стекло можно) |
| слова, время | `Skin.title(name)` — «name.exe» в пикселе, «name» в macOS; `Skin.ms(ms)` — длительность с учётом «Движения» |

**Общие компоненты меняют вид сами.** Хосты плагинов (панель, строка меню, попап,
рабочий стол, настройки) ставят своему содержимому `settingsSkin`, и `PxButton`,
`PxToggle`, `PxSlider`, `PxField`, `PxCombo`, `PxSegmented`, `PxCheck`, `PxText`,
`PxScroll`, `PxGroup`, `SettingRow` рисуют себя в нужной теме. Карточка виджета,
попапа или группы — **`SkinCard`** (в пикселе — коробка с фаской, в macOS — Liquid
Glass, с «Уменьшить прозрачность» — плотная; `sunken` / `group` — тихая вложенная
группа). Попап у виджета панели — `BarPopup` (`import qs.modules.bar`): в пикселе
окошко, в macOS — стеклянный поповер со словами вместо «.exe».

Правила:

- ни `#rrggbb`, ни имён шрифтов, ни голых пикселей — только токены (`Theme.hell…` —
  внутри адского облика);
- свою рамку, фаску, заголовок и «name.exe» не рисуй — это делает хост;
- в macOS — без пиксель-арта: значки `MacIcon { name: "gauge" }` (Lucide, список в
  `widgets/MacIcons.js`, `MacIcons.fromPixel(имя)` переводит пиксельное имя),
  плавные формы вместо ступенчатых; `PxIcon`-битмапы — только в пиксельной теме;
- ветвись только там, где темы правда разные (спрайт ↔ линейный значок, блочный
  индикатор ↔ тонкая полоска): `Skin.mac ? … : …` в привязке или
  `Loader { active: Skin.mac }` для целой части — тогда ненужная тема ничего не стоит;
- светлое и тёмное, акцент, «Уменьшить прозрачность» — уже в токенах; если рисуешь
  полупрозрачное сам, проверяй `Skin.glass`;
- память: `Loader`/`LazyLoader` для того, что видно не всегда, таймеры только пока
  видно (`running: root.visible && …`), локальные данные не чаще раза в секунду,
  сеть — раз в минуту и реже, у каждой `Image` — `sourceSize` под показанный размер и
  `asynchronous: true`, без `layer.enabled` / `MultiEffect` без нужды, без
  покадровых JS-анимаций и растущих без предела списков.

### Пример: плагин, правильный в обеих темах

Это `plugins/_template` — с него начинается «Новый плагин», его же видит мастер.
`manifest.json`:

```json
{
  "id": "clicker", "name": "Кликер", "version": "0.1.0", "icon": "heart",
  "enabledByDefault": false,
  "themes": ["pixel", "mac"],
  "realms": ["heaven", "hell"],
  "barWidget": "BarWidget.qml",
  "desktopTitle": "clicker",
  "desktopWidget": "DesktopWidget.qml",
  "settings": "Settings.qml"
}
```

`DesktopWidget.qml` — одно содержимое на все облики: в пикселе хост обернёт его в окно
«clicker.exe», в macOS — в стеклянную карточку, в аду — в адскую рамку:

```qml
import QtQuick
import qs.config
import qs.services
import qs.widgets

Item {
    id: root
    property var plugin
    property string screenName
    property var widget

    readonly property int clicks: plugin ? plugin.get("clicks", 0) : 0
    readonly property string countText: (Theme.hell ? I18n.t("душ: ", "souls: ") : I18n.t("кликов: ", "clicks: ")) + clicks

    implicitWidth: Math.max(col.implicitWidth, Skin.px(150))
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Skin.spacing
        PxText {                                   // подпись карточки — только в macOS
            visible: Skin.macWidgets
            text: I18n.t("Кликер", "Clicker")
            kind: "tiny"
            color: Skin.textDim
        }
        PxText {                                   // шрифт и размер темы выберет сам
            text: root.countText
            kind: Skin.macWidgets ? "big" : "body"
            color: Theme.hell ? Theme.hellFlame : Skin.text
        }
        PxButton {                                 // фаска в пикселе, капсула в macOS
            text: "+1"
            accent: true
            hell: Theme.hell
            compact: true
            onClicked: if (root.plugin) root.plugin.set("clicks", root.clicks + 1)
        }
    }
}
```

`BarWidget.qml` — кнопка на пиксельной панели и одноцветный значок в строке меню macOS:

```qml
import QtQuick
import qs.config
import qs.services
import qs.widgets

Item {
    id: root
    property var plugin
    property string screenName
    property var barWindow
    readonly property int clicks: plugin ? plugin.get("clicks", 0) : 0

    implicitWidth: Skin.mac ? macRow.implicitWidth + Skin.px(4) : btn.implicitWidth
    implicitHeight: Skin.mac ? Skin.px(18) : btn.implicitHeight

    PxButton {
        id: btn
        visible: !Skin.mac
        anchors.fill: parent
        compact: true
        icon: "heart"
        text: String(root.clicks)
        onClicked: if (root.plugin) root.plugin.set("clicks", root.clicks + 1)
    }
    Row {
        id: macRow
        visible: Skin.mac
        anchors.centerIn: parent
        spacing: Skin.px(4)
        MacIcon { name: "heart"; size: Skin.px(15); stroke: 2; color: Skin.ink(root.screenName); anchors.verticalCenter: parent.verticalCenter }
        PxText { text: String(root.clicks); color: Skin.ink(root.screenName); anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        visible: Skin.mac
        anchors.fill: parent
        onClicked: if (root.plugin) root.plugin.set("clicks", root.clicks + 1)
    }
}
```

Встроенные плагины на Theme API — живые примеры: котик (пиксельный кот ↔ гладкий
одноцветный силуэт в строке меню), спидтест (блочный спидометр ↔ дуга), Claude
Companion, стрим-статы, веб-поиск (результаты и в Spotlight).

## Два измерения: рай и ад

Когда пользователь скидывает ангела в ад, правит демоница: обои становятся
пиксельным адом, а виджеты рабочего стола сгорают и встают адскими (Y2K →
Ангел или демон → «Виджеты в аду»). Виджет плагина должен уметь оба вида:

- в манифесте `"realms": ["heaven", "hell"]` — «я рисую ад сам». Без этого
  angelOS в аду перекрашивает виджет шейдером (запасной вариант);
- `Theme.realm` — `"heaven"` или `"hell"`, `Theme.hell` — `true` в аду. Просто
  привязывайся к ним: переключение идёт посреди сгорания, само сгорание и адскую
  рамку (обсидиан, пламя, капли) рисует хост — сам переход не анимируй;
- ад — не перекраска, а своя версия с теми же данными и кнопками на тех же
  местах: часы римскими цифрами (`Theme.roman(n)`), CPU — «Жар», обложка —
  горящая пластинка, счётчики — «души». Размер почти тот же (±20 %);
- палитра ада: `Theme.hellBody / hellFace / hellFaceAlt / hellSunken`
  (обсидиан), `hellEdge / hellHi / hellLo` (фаски), `hellBlood`, `hellEmber`,
  `hellFlame`, `hellGold`, `hellText` (кость), `hellTextDim`, а ещё `hellPlate` —
  спокойная подложка под текстом, `hellRim` — кромка рамок, `hellAccent` — единственный
  акцент. Цвета задаёт текущий вид ада (`story/circles.json`, `HellLook`), они могут
  меняться на ходу — привязывайся к токенам, не копируй значения. `hellText`,
  `hellTextDim` и `hellAccent` всегда читаются на `hellPlate` (контраст ≥ 4.5:1);
- шрифты ада: заголовки — `Theme.fontHell` (Jacquard 12 Hell, пиксельная готика с
  латиницей и кириллицей), чётко в `Theme.hellPx(n)` = 21·n px; символы и эмодзи она не
  пишет — проверяй `Theme.hellCovers(text)` (старое имя `Theme.latin(text)` работает так же);
  текст — `Theme.fontHellText` (Departure Mono), чётко в `Theme.hellTextPx(n)` = 11·n px;
  `Theme.roman(n)` — римские цифры;
- контролы: `PxBox { hell: Theme.hell }`, `PxButton { hell: Theme.hell }`;
  иконки `skull`, `pentagram`, `fire`.

Встроенные виджеты (часы, sysmon, cava, музыка) — живые примеры.

### Виджет панели в аду

Пока правит демоница (Y2K → Панель в аду), панель рисует себя в цветах круга: значки —
контуром одного цвета на одной сетке, у каждого квадратная ячейка, подложка — только под
курсором или у открытого, акцент — только для состояния. Виджет панели плагина может:

- объявить `property bool hellBar: false` — панель включит его в аду, и он рисует себя сам:
  ролевые токены `Theme.hellBarIcon` (значки), `Theme.hellText` / `hellTextDim` (текст),
  `Theme.hellAccent` (только состояние: открыто, включено, нужно внимание), `Theme.hellSprite`
  и `hellSpriteHi` (тело спрайта и его светлые части — читаются на подложке ≥ 3:1), тёмный
  контур — `Theme.hellEdge`. Подложку не рисуй: её даёт панель;
- объявить `readonly property bool barOpen` (например, `popup.visible`) — панель покажет под
  ним подложку открытого;
- ничего не объявлять — тогда в аду он проходит через `HellBarTint`: тёмное становится телом
  спрайта, среднее — его светлым тоном, светлое — текстом (форма и тени сохраняются).

Котик (цербер) и Claude Companion — живые примеры.

## Объект `plugin`

```js
plugin.id, plugin.dir, plugin.manifest
plugin.get("key", default)   // настройки плагина (хранятся в ~/.config/angelos/settings.json)
plugin.set("key", value)
plugin.settings()            // весь объект настроек
plugin.url("file.png")       // file:// URL внутри папки плагина
plugin.achieve("first-run")  // своё достижение — получено сразу (см. ниже)
plugin.progress("ten-runs")  // шаг к достижению с "goal" (можно plugin.progress(id, 3))
plugin.achieved("first-run") // уже получено?
```

## Свои достижения

Плагин может объявить достижения в `manifest.json` — они появятся в **Ангелочек →
Достижения** рядом со встроенными, с той же карточкой «Достижение получено»:

```json
"achievements": [
  { "id": "first-run", "name": {"ru": "Первый замер", "en": "First run"},
    "desc": {"ru": "Запустить замер скорости", "en": "Run a speed test"}, "icon": "gauge" },
  { "id": "ten-runs", "name": {"ru": "Метролог", "en": "Metrologist"},
    "desc": {"ru": "Десять замеров", "en": "Ten speed tests"}, "goal": 10, "tier": 3 }
]
```

`id` — латиница; `tier` — ступень (1–5, по умолчанию 2); `goal` — сколько раз нужно
`plugin.progress(id)` (без него хватает одного `plugin.achieve(id)`); `secret: true` —
«???» до получения; `icon` — пиксельный значок. Достижения плагина не открывают райские
вещи (это делают только встроенные) и считаются, пока плагин включён и игра включена:
в режиме «Просто рабочий стол» `achieve` и `progress` ничего не делают.

## Что можно импортировать

```qml
import qs.config    // Config (настройки), Theme (цвета, размеры, шрифты)
import qs.widgets   // SkinCard, PxButton, PxToggle, PxSlider, PxField, PxCombo, PxGroup,
                    // PxText, PxIcon, MacIcon, MacText, PxMenuItem, SettingRow, AppIcon…
import qs.services  // Skin (Theme API), Niri, Audio, Lyrics, Notifs, Wallpapers, Plugins, Shell, Clipboard…
import Quickshell   // и остальное из Quickshell
```

Свои синглтоны кладутся рядом с `qmldir` (см. `plugins/stream-stats`, `plugins/cat`).
Свою пиксельную картинку можно нарисовать прямо в плагине: `PxIcon { bitmap: ["..#..", ".#o#.", …] }`.
Попап у виджета панели — `import qs.modules.bar` и `BarPopup { anchorItem: … }` (см. `plugins/speedtest`).

### Полезное

- Размеры — `Skin.px(n)` (в пиксельной теме это кратные арт-пикселю `Theme.u`).
- Цвета — `Skin.accent / text / textDim / surface / danger …` (Theme API); `Theme.accent2 /
  accent3 / accent4` — дополнительные акценты палитры.
- Иконки: `PxIcon { name: "heart" }` — список в `widgets/Icons.js`, свои рисуются
  ASCII-битмапом (`#` контур, `o` розовый, `x` голубой, `y` жёлтый, `w` белый, `f` фон, `r` красный).
- `Shell.openSettings("wallpaper")`, `Shell.sh("команда")`, `Shell.terminal("команда")`.
- `Niri.action("FocusWorkspaceDown", {})`, `Niri.workspaces`, `Niri.windows`.

## Шаблоны тем

Помимо плагинов, темы для приложений тоже расширяемые: положи в
`~/.config/angelos/templates/` JSON вида

```json
[{ "id": "mytool", "name": "Mytool", "template": "mytool.conf",
   "target": "~/.config/mytool/colors.conf", "reload": "pkill -USR1 mytool" }]
```

и файл шаблона рядом. Плейсхолдеры: `{{accent}}` → `#ff5cad`, `{{accent.strip}}` →
`ff5cad`, `{{bg}} {{fg}} {{color0..15}} {{mode}} {{flavor}}` и все токены темы.

## Contributions to the shared Appearance theme picker

Enabled plugins can add optional `appearanceThemes` entries beside the built-in themes. Choices disappear when the plugin is disabled or removed. No scripts from the manifest are executed.

```json
"appearanceThemes": [
  {"id": "ice", "name": "Bibata · Ice", "kind": "cursor", "theme": "Bibata-Modern-Ice"},
  {"id": "wallpaper", "name": "Bibata · From Wallpaper", "kind": "cursor", "themeSetting": "wallpaperTheme"},
  {"id": "dark", "name": "Emoji Picker · Dark", "kind": "plugin-settings", "settings": {"theme": "dark"}},
  {"id": "custom", "name": "Emoji Picker · Custom…", "kind": "settings"}
]
```

IDs must contain lowercase letters, digits or hyphens and be unique within the plugin. `name` supports the usual localized labels. `cursor` applies an already installed theme using the native Cursors service, with the current cursor size. `themeSetting` resolves a dynamic theme name from that plugin's saved settings (for example a color-specific wallpaper cursor); it also selects the plugin's `theme=wallpaper` preference. Static cursor contributions select the matching `theme` preference. Missing themes or a busy cursor worker leave the choice unchanged.

`plugin-settings` updates primitive settings only in the contributing plugin's namespace. `settings` opens that plugin's own settings page. Choosing a built-in palette clears the last plugin selection; choosing a cursor or picker theme preserves the desktop color palette. Older AngelOS versions ignore the optional field, so plugins should retain their own settings controls.

### Assistant panel in the angel/demon menu

An enabled plugin service can register one optional helper panel:

```qml
Angel.registerAssistant(plugin.id, provider)
// provider is a QObject with helperTitle (string) and helperUrl (QML URL).
// On service destruction:
Angel.unregisterAssistant(plugin.id, provider)
```

Registration returns false if another provider already owns the slot. Unregistration checks both ID and object identity. The helper adds a menu button and loads the plugin's panel only while its assistant menu is open; keyboard focus is enabled on demand. The panel supplies its own input, model requests and confirmation controls. The built-in Ask/settings search and story dialogue remain separate. Older shells have no hook: feature-detect `typeof Angel.registerAssistant === "function"` before registering.

Optional provider properties `helperBusy` (bool) and `helperMood` (string: thinking/waiting/happy/concerned, empty at rest) enable short character gestures. New gestures respect calm motion, dragging and story transitions; the plugin should clear a temporary mood after its reaction. These properties never initiate model requests.
