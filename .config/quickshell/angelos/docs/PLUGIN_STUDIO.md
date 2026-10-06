# Мастер плагинов / Plugin Studio

## Как пользоваться

1. **Настройки → System → Разработка → Режим разработчика.**
   В настройках и меню «Пуск» появится **Мастер плагинов**.
2. Выбери, как подключаться:
   - **Claude · вход через браузер** или **Codex · вход через ChatGPT** — без
     API-ключа. Мастер использует установленные `claude` (Claude Code) или
     `codex` и твою подписку. Кнопка **Войти через браузер** открывает терминал с
     `claude auth login` / `codex login`, они сами открывают браузер; затем
     **Проверить вход**. angelOS не видит токены входа.
     Claude запускается без инструментов, MCP и пользовательских настроек/хуков
     (`--tools "" --strict-mcp-config --setting-sources ""`), API-ключ из окружения
     убирается, чтобы шла именно подписка. Codex — без shell, веб-поиска, MCP,
     computer use и приложений, песочница только на чтение, в пустой временной папке.
     Запросы расходуют лимиты подписки. Модель можно оставить пустой.
   - **OpenAI API** или **Anthropic API** — вставь API-ключ и нажми
     **Сохранить ключ**; запросы оплачиваются отдельно через API. Нужна модель с
     поддержкой structured outputs.
3. Опиши идею. Мастер объяснит, что будет делать плагин, предложит размеры,
   настройки, источники данных и зависимости. Если нужны уточнения, ответь
   в поле запроса; кнопки вариантов ответа добавляют текст в это поле.
4. Нажми **План подходит — создать плагин**. Получишь полные файлы плагина,
   описание и результаты проверки. Можно уточнить план, пересоздать плагин
   или открыть файлы и отредактировать их в своём редакторе.
5. Просмотри код, затем нажми **Установить**. Плагин включится и появится в
   **Настройки → Плагины**. Для виджета можно сразу добавить экземпляр на
   текущий экран; позднее его можно добавить через настройки виджетов или ПКМ.

ИИ получает [контракт генерации](STUDIO_CONTRACT.md), [API плагинов](PLUGINS.md)
и исходники основных компонентов angelOS. Виджеты используют текущую тему,
`Theme.u`, стандартные элементы управления и переключатель языка. Рамку,
перетаскивание и размещение на мониторе обеспечивает оболочка.

Диалог, план и последний результат сохраняются между перезапусками.
Закрытие окна настроек не прерывает запрос. Набранный, но ещё не отправленный
текст сохраняется при переходе между страницами до перезапуска оболочки.
**Новый плагин** начинает отдельный диалог; уже установленные плагины остаются.
Выключение режима разработчика скрывает мастер и отменяет запрос к ИИ,
но установленные плагины продолжают работать.

## Доработка готового плагина

Свой плагин (из `~/.config/angelos/plugins`) можно менять прямо в системе:
**Настройки → Плагины → «Доработать»** или блок **«Доработать готовый плагин»**
в мастере.

- **Сразу переделать** — пишешь, что поменять («добавь выбор цвета», «сделай
  меньше»), ИИ возвращает обновлённые файлы. **Сначала обсудить** — сперва план
  «что изменится», вопросы, потом «План подходит — переделать».
- **Изменения**: список изменённых файлов (`+` добавлен, `~` изменён, `−` удалён)
  и разница построчно (зелёное — добавлено, красное — убрано).
- **Править вручную** — встроенный редактор: любой файл черновика, новый файл,
  удаление; «Сохранить и проверить» сразу прогоняет проверки и песочницу.
  Работает и для черновика нового плагина до установки.
- **Обновить плагин** — прошлая версия уходит в
  `~/.local/state/angelos/plugin-backups/<id>/` (последние 10), новая
  ставится атомарно и **перезагружается без перезапуска оболочки** (QML грузит
  её по новому пути `~/.cache/angelos/plugin-load/<id>.<n>`, поэтому кэш
  компонентов не мешает). Можно дорабатывать дальше — следующая разница
  считается от новой версии.
- **Вернуть прошлую версию** — одной кнопкой; заменённая версия тоже
  сохраняется (второе нажатие возвращает её обратно).
- Картинки, звуки и другие файлы, которые мастер не редактирует, переносятся
  как есть. Если плагин изменили на диске после начала доработки, обновление
  остановится и попросит открыть его заново.
- Кнопка **↻** у своего плагина в «Плагинах» перезагружает его файлы после
  ручной правки во внешнем редакторе (режим разработчика не нужен).

### Рай и ад

Каждый новый виджет рабочего стола мастер делает в двух измерениях: обычный
и адский — для демоницы (`"realms": ["heaven", "hell"]`, вид по `Theme.hell`,
см. [PLUGINS.md](PLUGINS.md#два-измерения-рай-и-ад)). Проверка требует оба и
грузит виджет в раю и в аду. У старых своих плагинов, где ада нет, есть кнопка
**«Адская версия»** в «Плагинах» (и **«Сделать адскую версию»** в мастере при
доработке): ИИ дорисовывает только адский облик, остальное не трогает. Пока её
не нажали, angelOS в аду просто перекрашивает такой виджет шейдером.

### Пиксель и macOS

У angelOS две темы — исходная пиксельная (Win98 / NEEDY GIRL OVERDOSE) и macOS
(Golden Gate, Liquid Glass), — и пользователь переключает их на ходу. Каждый
новый плагин мастер делает для обеих: `"themes": ["pixel", "mac"]` в
manifest.json, а цвета, шрифты, размеры, скругления и отступы — только из
**Theme API** (`Skin`, см. [PLUGINS.md](PLUGINS.md#theme-api-пиксель-и-macos)).
Что это значит для сгенерированного кода — системный промт
(`docs/STUDIO_CONTRACT.md`, раздел «Two looks») требует:

- никаких `#rrggbb`, имён шрифтов и голых пикселей — `Skin.text`, `Skin.accent`,
  `Skin.px(n)`, `PxText { kind }`; светлое/тёмное, акцентный цвет и «Уменьшить
  прозрачность» токены учитывают сами;
- общие компоненты, которые меняют вид сами: `PxButton`, `PxToggle`,
  `PxSlider`, `PxField`, `PxText`…, карточка `SkinCard`, попап `BarPopup`;
- в macOS — ни «name.exe», ни пиксель-арта: заголовки через `Skin.title()`,
  значки `MacIcon`, виджет панели — одноцветный «menu bar extra» в
  `Skin.ink(screenName)`;
- память: ленивые `Loader`, ничего не работает, пока скрыто, опрос не чаще,
  чем меняются данные (сеть ≥ 60 с), у каждой картинки `sourceSize`.

Проверка это и смотрит: статически (поле `themes`, есть ли обращения к `Skin`,
нет ли захардкоженных цветов, шрифтов, `I18n.exe`, картинок без `sourceSize`) и
в песочнице — каждая видимая точка входа грузится в пиксельной теме и в macOS
(виджет рабочего стола ещё и в аду). Ошибка в одной из тем уходит модели с
пометкой, в какой.

## Модель, уровень, проверка

- **Модель** выбирается карточками: для Claude Code — Haiku / Sonnet / Opus / Fable,
  для Codex — модели из его каталога (`~/.codex/config.toml` → `model_catalog_json`),
  для API — актуальные ID. Своё имя можно ввести отдельно.
- **Уровень рассуждений** — low / medium / high / xhigh / max (у некоторых моделей
  Codex ещё ultra): для плагинов обычно хватает medium; выше — дольше и дороже.
  Передаётся как `--effort` (Claude Code), `model_reasoning_effort` (Codex),
  `output_config.effort` (Anthropic API), `reasoning.effort` (OpenAI API).
- **Проверка**: JSON/Python/shell и `qmlformat`, затем каждая точка входа
  загружается в Quickshell offscreen внутри bubblewrap (без сети, без домашней
  папки и сокетов) — в пиксельной теме и в macOS. Ошибки — неизвестные свойства
  и типы, импорты, ошибки в привязках, нулевой размер, нарушения Theme API —
  уходят модели на **автоисправление** (0–2 попытки).
- В контекст модели попадает справочник API, собранный из текущих исходников
  (виджеты, Theme, сервисы, имена иконок), исходники Theme API (`services/Skin.qml`,
  `widgets/SkinCard.qml`) и живые примеры: шаблон, работающий в обеих темах, и котик.

## Пример с лимитами Codex

«Хочу виджет с оставшимися токенами Codex» требует уточнения источника:
API-ключ сам по себе не даёт остаток лимита подписки ChatGPT/Codex.
Контракт запрещает выдумывать такой endpoint или выдавать rate limit за
баланс. Мастер должен уточнить метрику и предложить доступный источник,
пользовательский экспорт либо явно обозначенный собственный бюджет.
Учёт токенов последнего запроса в самом мастере — расход API-запроса,
а не остаток подписки.

## Файлы и проверка

- Ключи: `~/.config/angelos/studio/credentials.json`, права `0600`,
  каталог `0700`. Их можно удалить кнопкой в мастере. Это локальный файл,
  не системное зашифрованное хранилище.
- Диалог и черновики: `~/.local/state/angelos/studio/`.
- Установленные плагины: `~/.config/angelos/plugins/<id>/`.
- В обычном `settings.json` хранятся только режим разработчика, провайдер,
  модель и лимит ответа. Эти пользовательские каталоги не публикуются.

Ключ передаётся worker-процессу через stdin, а провайдеру — только в заголовке
авторизации. Модели отправляются диалог, документация angelOS и файлы черновика
при исправлении; пользовательские файлы автоматически не сканируются.
Ключи не передаются генерируемому плагину.

До установки сгенерированный код не запускается. Проверяются manifest,
точки встраивания, имена/размеры файлов, синтаксис QML через **Qt 6 qmlformat**,
Python, JSON и shell. Проверка синтаксиса не гарантирует правильную работу
импортов, внешних сервисов или поведения. После установки код работает с
правами текущего пользователя.

Установка не заменяет существующий ID и не запускает установочные скрипты.
После ручных правок во внешнем редакторе нужно нажать **Проверить ещё раз**:
установка сверяет файлы с просмотренным результатом. Установленный плагин
меняется через «Доработать» (см. выше) — с бэкапом и откатом.

При ошибке синтаксиса доступно **Исправить с ИИ**. При неполном ответе
увеличь лимит ответа или упрости задачу. Ошибка 401 означает отклонённый
ключ, 404 — недоступную модель, 429 — ограничение API. Автоматических платных
повторных запросов нет. Отмена останавливает локальное ожидание; уже
отправленный запрос провайдер мог учесть.

## English

Enable **Settings → System → Development → Developer mode**. Open
**Plugin Studio** in Settings or Start and pick a connection:

- **Claude · browser sign-in** / **Codex · ChatGPT sign-in** use the local
  `claude` or `codex` CLI and your subscription — no API key. **Sign in via
  browser** opens a terminal with `claude auth login` / `codex login`; then
  **Check sign-in**. angelOS never sees the tokens. Claude runs with no tools,
  MCP or user settings/hooks; Codex without shell, web search, MCP or computer
  use, read-only, in an empty temporary folder.
- **OpenAI API** / **Anthropic API** need an API key (separate API billing).
  The model must support structured outputs.

Describe the plugin, answer any questions, review its proposed behavior,
size, data sources and settings, then approve generation. Review the files
before clicking **Install**. Installation enables the plugin and optionally
adds its desktop widget to the current screen. Manage it in **Settings →
Plugins**. Turning off developer mode hides Studio without disabling plugins.

Studio sends the conversation and angelOS's plugin contract/component sources
to the selected provider. A repair request also includes the draft files.
Credentials are stored separately in a local `0600` file and passed via stdin,
never command-line arguments or generated plugin settings.

The conversation and draft survive restarts; unsent input survives navigating
between Settings pages during the current shell session. Closing Settings
does not cancel an active request.

Drafts are checked without executing them. The checks cover manifest structure,
file paths, required entry points and QML/Python/JSON/shell syntax. They do not
prove runtime correctness. Installed plugins run as your desktop user. Existing
plugin IDs are never overwritten. After editing files externally, use
**Recheck files** before installing.

**Improving an installed plugin**: Settings → Plugins → Improve (or the
"Improve an installed plugin" list in Studio). "Change it now" applies a
request directly; "Discuss first" plans the change. The Changes view lists
added/changed/removed files with a line diff; "Edit by hand" is a built-in
editor (save = recheck). "Update plugin" backs the old version up to
`~/.local/state/angelos/plugin-backups/<id>/` (last 10), swaps the new one in
atomically and hot-reloads it through a fresh load path (QML caches
components by URL). "Restore previous version" undoes it (and can redo).
Files Studio cannot edit ride along untouched.

**Heaven and hell**: every new desktop widget comes in both realms, the usual
one and a hell look for the demon (`"realms": ["heaven", "hell"]`, drawn by
`Theme.hell`); the check requires both and loads the widget in each. Your older
plugins without hell get **Hell version** in Settings → Plugins (and **Make the
hell version** while improving one): the AI adds only the hell look. Until then
angelOS re-inks such a widget with a shader in hell.

**Pixel and macOS**: angelOS has two themes, the original pixel one and macOS
(Golden Gate), switched while it runs. Every new plugin draws both
(`"themes": ["pixel", "mac"]`) and takes colours, fonts, sizes, radii and
spacing only from the **Theme API** (`Skin`, see PLUGINS.md): no hex colours,
font names or bare pixels; the shared controls, `SkinCard` and `BarPopup` change
by themselves; no ".exe" or pixel art in macOS (`Skin.title()`, `MacIcon`, a
monochrome menu bar extra in `Skin.ink(screenName)`); lazy loading, no polling
faster than the data, `sourceSize` on every image. The check verifies this
statically and loads every visual entry point in both looks.

For “remaining Codex tokens,” Studio must clarify the actual metric and data
source instead of inventing a subscription-balance API. Its own token counter
shows the last API request's usage, not a subscription's remaining allowance.

## Development

`scripts/plugin-studio.py` uses the Python standard library. The providers use
OpenAI Responses (`text.format`, JSON Schema, `store: false`) and Anthropic
Messages (`output_config.format`, JSON Schema). Provider endpoints are fixed;
redirects never forward credentials.

Run `python3 scripts/test-plugin-studio.py` from the repository root for offline
provider/validation/installation tests, or `./scripts/check.sh` for all checks.
