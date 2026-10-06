# Демо README: список кадров

Всё снимается в **стенде** (`scripts/demo/rig.sh`): headless labwc → вложенный niri → angelOS из этого
репозитория, поставленный `install.sh` в одноразовый HOME. На экранах ничего не появляется, а в кадр не
попадает ничего личного: пользователь `angel`, сгенерированные обои (`scripts/demo/wallpaper.py`), свой
D-Bus без активации сервисов хоста, свой `XDG_RUNTIME_DIR` (нет PipeWire — ни один звук не играет; нет
`systemd --user` — живой сеанс ничего не замечает). Обои пака Hell не снимаются; `angelos-hell.png`
остаётся прежним.

```bash
export LABWC=/path/to/labwc WLR_RANDR=/path/to/wlr-randr   # системные или локальная сборка (+ LABWC_LIB)
scripts/demo/shots.sh            # все автоматические кадры
scripts/demo/shots.sh macos-dock # один
```

PNG — 1920×1080 (в README показываются по 49 %), GIF — 960 px, 12 кадров/с, палитра 128 цветов,
байеровский дизеринг (`scripts/demo/gif.sh`); цель — до 3 МБ на GIF.

## Скриншоты (`docs/screenshots/`)

| Файл | Образ | Что в кадре | Как |
|---|---|---|---|
| `pixel-dark.png` | Pixel, тёмная, `overdose` | панель, сердечки-столы, виджеты clock/sysmon/cava, kitty с fastfetch | авто |
| `pixel-light.png` | Pixel, светлая, `bubblegum` | то же в светлой, открыт «Пуск» | авто |
| `macos-light.png` | macOS, светлая | строка меню, Dock, Nautilus, стеклянные виджеты | авто |
| `macos-dark.png` | macOS, тёмная | то же в сумерках, открыт Пункт управления | авто |
| `sddm-login.png` | — | `sddm-greeter-qt6 --test-mode` в стенде, пользователь `angel` | авто |
| `angelos-hell.png` | — | **не переснимается** (обои пака Hell) | — |

## GIF (`docs/demo/`)

| Файл | Образ | Сцена | Как |
|---|---|---|---|
| `pixel-desktop.gif` | Pixel | столы 1→2→3 (`angelos ws`), светлая ⇄ тёмная, вкусы `bubblegum → overdose → cyberangel` | авто |
| `wallpaper.gif` | Pixel | смена обоев: светлое небо ⇄ тёмное (пиксельный переход) | авто |
| `menu.gif` | Pixel | меню рабочего стола (`ipc desktopMenu`), «Вид ▸», добавление виджета | авто (без движения мыши) |
| `launcher.gif` | Pixel | лаунчер: `kit` → kitty, `web niri`, `> uname -a` (`ipc launcherText`) | авто |
| `settings.gif` | Pixel | Оформление → Панель → Виджеты → Окна → Программы по умолчанию (`ipc settings …`) | авто |
| `tips.gif` | Pixel | подсказки (`ipc tour`, `ipc tourNext` ×5) | авто |
| `tiling.gif` | Pixel | три kitty: фокус, ширины `Mod+R`, вкладки, плавающее (`niri msg action`) | авто |
| `overview.gif` | Pixel | обзор столов (`niri msg action toggle-overview`) | авто |
| `hotkeys.gif` | Pixel | подсказка niri (`show-hotkey-overlay`) | авто |
| `macos-menubar.gif` | macOS | меню Nautilus по очереди (`ipc macMenu 1..4`), Пункт управления, Центр уведомлений | авто |
| `macos-dock.gif` | macOS | меню Dock (`ipc macDockMenu`), свернуть (`ipc macMinimize`) и вернуть (`ipc macRestore`) | авто; **увеличение под указателем — руками** (см. ниже) |
| `macos-spotlight.gif` | macOS | Spotlight: `term` → kitty (`ipc startMenu`, `ipc startText`) | авто |
| `plugins.gif` | Pixel | Настройки → Плагины, каталог Community (`ipc settings plugins`, нужна сеть) | авто; **установка плагина кликом — руками** |
| `installer.gif` | — | `install.sh` в kitty внутри стенда: баннер, тема macOS, раскладки, сердечки | авто (pty-драйвер, `SKIP_PACKAGES=1`) |

## Что руками

Стенд невидим, поэтому для кадров, где нужен настоящий указатель, его выводят на экран HDMI-A-1
(тестовый, не стримовый DP-1):

1. `DEMO_VISIBLE=1 scripts/demo/rig.sh start macos light` — niri стенда открывается окном в твоём сеансе;
   перенеси его на HDMI-A-1 и разверни. HOME всё так же одноразовый, запись берёт только вывод стенда.
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
- В стенде пользователь `angel`, `USER=angel`, имя в «Пуске» — `angel`; fastfetch показывает `angel@…`
  (конфиг fastfetch стенда без платы, диска, IP и списка «гира»).
- После съёмки: просмотреть каждый кадр (`scripts/demo/check-frames.sh` ищет в OCR кадров твой логин и имя машины, почту,
  `/home/`, `sk-`, `token`).
