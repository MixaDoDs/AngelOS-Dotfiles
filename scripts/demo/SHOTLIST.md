# Демо README: список кадров

Всё снимается в **стенде** (`scripts/demo/rig.sh`): headless labwc → вложенный niri → angelOS из этого
репозитория, поставленный `install.sh` в одноразовый HOME. На экранах ничего не появляется, а в кадр не
попадает ничего личного: пользователь `angel`, свой D-Bus без активации сервисов хоста, свой `XDG_RUNTIME_DIR`
(нет PipeWire — ни один звук не играет; нет `systemd --user` — живой сеанс ничего не замечает). Обои — релизные
из `Pictures/AngelOS/` (стенд их получает от `install.sh`). Обои пака Hell и сам ад не снимаются;
`angelos-hell.png` остаётся прежним и в README больше не показывается.

```bash
export LABWC=/path/to/labwc WLR_RANDR=/path/to/wlr-randr   # системные или локальная сборка (+ LABWC_LIB)
scripts/demo/shots.sh            # все автоматические кадры
scripts/demo/shots.sh macos-dock # один
scripts/demo/readme-art.py       # записка с установкой и полосы обоев релизов (docs/readme/)
```

Без labwc: `DEMO_START=/path/to/script scripts/demo/shots.sh …`, где скрипт поднимает стенд сам
(например `DEMO_VISIBLE=1 rig.sh start` и переносит окно вложенного niri на тестовый экран).

PNG — 1920×1080, GIF — 960 px (живые обои 720), 12 кадров/с, палитра 128 цветов, байеровский дизеринг
(`scripts/demo/gif.sh`); цель — до 3 МБ на GIF. Для этого стенд выключает живые обои (`liveWall off`) везде,
кроме кадров, которым они нужны (`alive`): мерцающие звёзды на каждом кадре не дают GIF сжаться.

## Что стенд делает со своим домом (rig.sh)

- `setup.complete`, `introSeen`, `wallpaper.releaseSeen`: ни мастера, ни подсказок, ни вопроса «обновление
  скачано — продолжить?», ни новости о новых обоях.
- `save.json`: все достижения уже получены, чтобы в кадр не всплывал тост «достижение получено» при первом
  клике по чему-нибудь.
- `SetupIntro.qml` стенда: `angelos intro` играет сразу, без вопроса (в стенде некому его кликнуть).
- `fastfetch_style.py` стенда: каждый конфиг, который пишет оболочка, проходит фильтр приватности
  (`angel@angelos`, без board / disk / localip / gear), а пометка «написано angelOS» остаётся. Иначе оболочка
  считает конфиг чужим, не рисует картинку, и fastfetch падает на логотип дистрибутива.
- `PolkitDialog.qml` стенда: агент polkit не регистрируется (он бы отвечал за живой сеанс).

## Скриншоты (`docs/screenshots/`)

| Файл | Образ | Обои | Что в кадре | Как |
|---|---|---|---|---|
| `pixel-dark.png` | Pixel, тёмная, `overdose` | Uriel ночь, живые | панель, виджеты clock/sysmon, kitty с fastfetch автора (`stream`) | авто |
| `pixel-light.png` | Pixel, светлая, `bubblegum` | Angel «Офаним» день | то же в светлой, открыт «Пуск» | авто |
| `macos-light.png` | macOS, светлая | Archangel «Life» день | строка меню, Dock, Nautilus, стеклянные виджеты | авто |
| `macos-dark.png` | macOS, тёмная | Archangel «Numb» ночь | то же в сумерках, открыт Пункт управления | авто |
| `updates.png` | Pixel, тёмная | Uriel ночь | Настройки → Обновления | авто |
| `report.png` | Pixel, тёмная | Uriel ночь | Настройки → О системе (сообщить о проблеме) | авто |
| `intro.png` | Pixel, тёмная | Uriel ночь | один кадр минуты первого запуска: офаним поднимается снизу | авто пишет `intro.mp4` и кадры 46–60 с в `$DEMO_RAW`; выбрать один **руками**, не больше |
| `sddm-login.png` | — | — | `sddm-greeter-qt6 --test-mode` в стенде, пользователь `angel` | авто |
| `angelos-hell.png` | — | — | **не переснимается**, в README не показывается | — |

## GIF (`docs/demo/`)

| Файл | Образ | Сцена | Как |
|---|---|---|---|
| `live-wall.gif` | Pixel | Uriel ночь, живые обои: звёзды, вода, `liveWall glint`, `liveWall rings` | авто |
| `menu-styles.gif` | Pixel | меню стола в шести обликах (`desktop.menuStyle`: list radial y2k tiles wings harp; pentagram не снимается) | авто |
| `pixel-desktop.gif` | Pixel | столы 1→2→3 (`angelos ws`), светлая ⇄ тёмная, вкусы `bubblegum → cyberangel → overdose` | авто |
| `wallpaper.gif` | Pixel | пиксельный переход между обоями трёх релизов | авто |
| `menu.gif` | Pixel | меню рабочего стола (`ipc desktopMenu`), «Вид ▸», добавление виджета | авто |
| `launcher.gif` | Pixel | лаунчер: `kit` → kitty, `web niri`, `> uname -a` (`ipc launcherText`) | авто |
| `settings.gif` | Pixel | Оформление → Панель → Виджеты → Окна → Программы по умолчанию (`ipc settings …`) | авто |
| `tips.gif` | Pixel | подсказки (`ipc tour`, `ipc tourNext` ×5) | авто |
| `tiling.gif` | Pixel | три kitty: фокус, ширины `Mod+R`, вкладки, плавающее (`niri msg action`) | авто |
| `overview.gif` | Pixel | обзор столов (`niri msg action toggle-overview`) | авто |
| `hotkeys.gif` | Pixel | подсказка niri (`show-hotkey-overlay`) | авто |
| `macos-menubar.gif` | macOS | меню Nautilus по очереди (`ipc macMenu 1..4`), Пункт управления, Центр уведомлений | авто |
| `macos-dock.gif` | macOS | меню Dock (`ipc macDockMenu`), свернуть (`ipc macMinimize`) и вернуть (`ipc macRestore`) | авто; **увеличение под указателем — руками** (см. ниже) |
| `macos-spotlight.gif` | macOS, тёмная | Spotlight: `term` → kitty (`ipc startMenu`, `ipc startText`) | авто |
| `plugins.gif` | Pixel | Настройки → Плагины, каталог Community (`ipc settings plugins`, нужна сеть) | авто; **установка плагина кликом — руками** |
| `installer.gif` | — | `install.sh` в kitty внутри стенда: баннер, тема macOS, раскладки, сердечки | авто (pty-драйвер, `SKIP_PACKAGES=1`); нужен `gum` (системный или `DEMO_GUM_DIR`) |

## Что руками

Стенд невидим, поэтому для кадров, где нужен настоящий указатель, его выводят на тестовый экран:

1. `DEMO_VISIBLE=1 scripts/demo/rig.sh start macos light` — niri стенда открывается окном в твоём сеансе;
   перенеси его на тестовый экран (не стримовый) и сделай плавающим 1920×1080. HOME всё так же одноразовый,
   запись берёт только вывод стенда.
2. `scripts/demo/rig.sh rec /tmp/dock.mp4 20 &`, затем мышью: провести вдоль Dock слева направо и обратно
   (увеличение), правый клик по Nautilus → меню, жёлтый свет у окна → свернуть, клик по снимку в Dock →
   вернуть.
3. `scripts/demo/gif.sh /tmp/dock.mp4 docs/demo/macos-dock.gif`.
4. Плагины: Настройки → Плагины → вкладка каталога, установить `cat`, показать его на панели; так же
   записать и сжать в `plugins.gif`.

## Перед съёмкой (приватность)

- Только стенд: живой сеанс не снимается вообще, поэтому чужих окон, уведомлений и переписок в кадре нет.
  Для ручных кадров окно стенда — единственное, что пишется (`rig.sh rec` пишет вывод niri стенда, а не
  твой экран).
- `niri-cast-privacy on` всё равно включается в живом сеансе на время ручных кадров — на случай, если
  запись по ошибке возьмёт не тот вывод.
- В стенде пользователь `angel`, `USER=angel`, имя в «Пуске» — `angel`; fastfetch показывает `angel@angelos`
  (фильтр в `fastfetch_style.py` стенда: без платы, диска, IP и списка «гира»).
- После съёмки: просмотреть каждый кадр (`scripts/demo/check-frames.sh` ищет в OCR кадров твой логин и имя машины, почту,
  `/home/`, `sk-`, `token`).
