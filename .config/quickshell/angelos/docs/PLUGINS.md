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

Все поля кроме `id`/`name` необязательны. Точки встраивания:

| поле | куда попадает | свойства, которые получает компонент |
|---|---|---|
| `menu` | ПКМ-меню рабочего стола (декларативно). `exec` — команда sh, `settings` — открыть страницу настроек, `url` — xdg-open | — |
| `menuComponent` | QML-элементы в ПКМ-меню (обычно `PxMenuItem`) | `plugin`, `menu` (вызови `menu.close()`) |
| `barWidget` | панель, рядом с треем (все три стиля) | `plugin`, `screenName`, `barWindow` |
| `desktopWidget` | виджет на рабочем столе: angelOS сам рисует рамку с заголовком `desktopTitle` (без окончания: `"my-widget"` — angelOS добавит выбранное в настройках `.exe`, `.sh` или `.bin`; в своём QML — `I18n.exe("my-widget")`), перетаскивание и удаление; добавляется через ПКМ → Вид | `plugin`, `screenName`, `widget` (`{uid, x, y, settings}`) |
| `settings` | страница в Настройки → Плагины → имя | `plugin` |
| `main` | фоновый сервис, живёт пока плагин включён (можно держать тут `IpcHandler`) | `plugin` |
| `launcher` | провайдер результатов лаунчера (Mod+Space) | `plugin`, `pluginId` |
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
```

## Что можно импортировать

```qml
import qs.config    // Config (настройки), Theme (цвета, размеры, шрифты)
import qs.widgets   // PxWindow, PxBox, PxButton, PxToggle, PxSlider, PxField, PxCombo,
                    // PxGroup, PxText, PxIcon, PxHearts, PxMenuItem, SettingRow, AppIcon…
import qs.services  // Niri, Audio, Lyrics, Notifs, Wallpapers, Plugins, Shell, Clipboard…
import Quickshell   // и остальное из Quickshell
```

Свои синглтоны кладутся рядом с `qmldir` (см. `plugins/stream-stats`, `plugins/cat`).
Свою пиксельную картинку можно нарисовать прямо в плагине: `PxIcon { bitmap: ["..#..", ".#o#.", …] }`.
Попап у виджета панели — `import qs.modules.bar` и `BarPopup { anchorItem: … }` (см. `plugins/speedtest`).

### Полезное

- `Theme.u` — размер арт-пикселя; все отступы — кратные ему.
- `Theme.accent / accent2 / accent3 / face / text / edge …` — меняются вместе с темой.
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
