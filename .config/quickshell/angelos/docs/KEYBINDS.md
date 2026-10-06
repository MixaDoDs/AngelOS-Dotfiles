# Горячие клавиши по темам

Каждая тема angelOS — свой профиль биндов niri (`scripts/keyprofile.py`, `services/KeyProfile.qml`):
`~/.config/niri/cfg/keybinds.kdl` только выбирает профиль (два `include`), сам профиль — в
`keybinds-common.kdl` (обе темы), `keybinds-pixel.kdl` (пиксельная тема, исходные бинды angelOS),
`keybinds-macos.kdl` (Golden Gate, ⌘ = Super). Профиль читается после общего файла: его клавиша
заменяет общую только в этой теме. Переключение — вместе с темой, одной атомарной заменой
селектора после `niri validate`; Настройки → Горячие клавиши правят профиль текущей темы.
Переключение меняет в `keybinds.kdl` только строку `include` профиля: свой блок `binds { … }`,
дописанный туда руками, остаётся (для обеих тем, читается после профиля).
Обновление (`install.sh`) не затирает и не откладывает изменённый профиль, а сливает его в три
стороны (`keyprofile.py merge`): клавиши, которые пользователь не трогал, идут за репозиторием,
новые клавиши angelOS добавляются, если пользователь не занял эту клавишу и не удалял её, свои —
остаются. Публикация владельца (`owner/dotfiles-publish.sh`) отправляет живые профили владельца в
репозиторий и в `templates/keybinds`.
Вне тем: `angelos-windows.kdl` (Alt+Tab, лупа Super+Alt+= / − / 0, выход из игры).

## Общие (обе темы)

| Бинд | Действие | Подпись |
|---|---|---|
| `Mod+Shift+ESCAPE` | `show-hotkey-overlay` |  |
| `Mod+Shift+Return` | `angelos settings wallpaper` | angelOS: обои |
| `Mod+S` | `angelos settings appearance` | angelOS: настройки |
| `Mod+Alt+S` | `angelos settings appearance` | angelOS: настройки |
| `Mod+Shift+Q` | `angelos session` | angelOS: выключение |
| `Mod+E` | `nautilus` | File Manager: Nautilus |
| `XF86AudioRaiseVolume` | `angelos volumeUp` |  |
| `XF86AudioLowerVolume` | `angelos volumeDown` |  |
| `XF86AudioMute` | `angelos mute` |  |
| `XF86AudioMicMute` | `angelos micMute` |  |
| `XF86AudioNext` | `angelos media next` |  |
| `XF86AudioPrev` | `angelos media previous` |  |
| `XF86AudioPlay` | `angelos media toggle` |  |
| `XF86AudioPause` | `angelos media pause` |  |
| `XF86AudioStop` | `angelos media pause` |  |
| `Mod+Shift+Left` | `focus-monitor-left` |  |
| `Mod+Shift+Right` | `focus-monitor-right` |  |
| `Mod+Shift+UP` | `focus-monitor-up` |  |
| `Mod+Shift+Down` | `focus-monitor-down` |  |
| `Mod+Shift+CTRL+Left` | `move-column-to-monitor-left` |  |
| `Mod+Shift+CTRL+Right` | `move-column-to-monitor-right` |  |
| `Mod+Shift+CTRL+UP` | `move-column-to-monitor-up` |  |
| `Mod+Shift+CTRL+Down` | `move-column-to-monitor-down` |  |
| `Mod+Alt+V` | `switch-focus-between-floating-and-tiling` |  |
| `Mod+Shift+R` | `~/.local/bin/niri-record-region` | Record region → Videos (toggle) |
| `Mod+CTRL+WheelScrollDown` | `move-column-to-workspace-down` |  |
| `Mod+CTRL+WheelScrollUp` | `move-column-to-workspace-up` |  |
| `Mod+WheelScrollRight` | `focus-column-right` |  |
| `Mod+WheelScrollLeft` | `focus-column-left` |  |
| `Mod+CTRL+WheelScrollRight` | `move-column-right` |  |
| `Mod+CTRL+WheelScrollLeft` | `move-column-left` |  |
| `Mod+Shift+WheelScrollDown` | `focus-column-right` |  |
| `Mod+Shift+WheelScrollUp` | `focus-column-left` |  |
| `Mod+CTRL+Shift+WheelScrollDown` | `move-column-right` |  |
| `Mod+CTRL+Shift+WheelScrollUp` | `move-column-left` |  |
| `Mod+V` | `angelos clipboard` | angelOS: буфер обмена |
| `Mod+Shift+S` | `~/.local/bin/niri-screenshot-region` | Screenshot: region → Screenshots (ropes) |
| `Mod+Shift+V` | `~/.local/bin/voxtype record toggle` | Voice: toggle dictation |
| `CTRL+Shift+2` | `screenshot-screen` |  |
| `CTRL+Shift+3` | `screenshot-window` |  |
| `Mod+ESCAPE` | `toggle-keyboard-shortcuts-inhibit` |  |
| `CTRL+ALT+Delete` | `quit` |  |
| `Mod+Shift+P` | `power-off-monitors` |  |
| `Mod+Shift+X` | `~/.local/bin/niri-cast-privacy` | Privacy: block Telegram Bitwarden Helium Discord |
| `Mod+Alt+Y` | `angelos lyrics` | angelOS: лирика вкл/выкл |
| `Mod+Alt+T` | `angelos theme toggle` | angelOS: светлая/тёмная |

## Пиксельная тема

| Бинд | Действие | Подпись |
|---|---|---|
| `Mod+T` | `kitty` | Open Terminal: kitty |
| `Mod+B` | `xdg-open about:blank` | Open Browser: default |
| `Mod+Space` | `angelos launcher` | angelOS: программы |
| `Mod+ALT+L` | `angelos lock` | angelOS: блокировка |
| `Mod+Q` | `close-window` |  |
| `Mod+Left` | `focus-column-left` |  |
| `Mod+H` | `focus-column-left` |  |
| `Mod+Right` | `focus-column-right` |  |
| `Mod+L` | `focus-column-right` |  |
| `Mod+Up` | `focus-window-up` |  |
| `Mod+K` | `focus-window-up` |  |
| `Mod+Down` | `focus-window-down` |  |
| `Mod+J` | `focus-window-down` |  |
| `Mod+CTRL+Left` | `move-column-left` |  |
| `Mod+CTRL+H` | `move-column-left` |  |
| `Mod+CTRL+Right` | `move-column-right` |  |
| `Mod+CTRL+L` | `move-column-right` |  |
| `Mod+CTRL+UP` | `move-window-up` |  |
| `Mod+CTRL+K` | `move-window-up` |  |
| `Mod+CTRL+Down` | `move-window-down` |  |
| `Mod+CTRL+J` | `move-window-down` |  |
| `Mod+Home` | `focus-column-first` |  |
| `Mod+End` | `focus-column-last` |  |
| `Mod+CTRL+Home` | `move-column-to-first` |  |
| `Mod+CTRL+End` | `move-column-to-last` |  |
| `Mod+BracketLeft` | `consume-or-expel-window-left` |  |
| `Mod+BracketRight` | `consume-or-expel-window-right` |  |
| `Mod+Comma` | `consume-window-into-column` |  |
| `Mod+Period` | `expel-window-from-column` |  |
| `Mod+R` | `switch-preset-column-width` |  |
| `Mod+Alt+R` | `switch-preset-column-width-back` |  |
| `Mod+Ctrl+Shift+R` | `switch-preset-window-height` |  |
| `Mod+Ctrl+R` | `reset-window-height` |  |
| `Mod+WheelScrollDown` | `angelos ws down` |  |
| `Mod+WheelScrollUp` | `angelos ws up` |  |
| `Mod+1` | `angelos ws 1` |  |
| `Mod+2` | `angelos ws 2` |  |
| `Mod+3` | `angelos ws 3` |  |
| `Mod+4` | `angelos ws 4` |  |
| `Mod+5` | `angelos ws 5` |  |
| `Mod+6` | `angelos ws 6` |  |
| `Mod+7` | `angelos ws 7` |  |
| `Mod+8` | `angelos ws 8` |  |
| `Mod+9` | `angelos ws 9` |  |
| `Mod+CTRL+1` | `move-column-to-workspace 1` |  |
| `Mod+CTRL+2` | `move-column-to-workspace 2` |  |
| `Mod+CTRL+3` | `move-column-to-workspace 3` |  |
| `Mod+CTRL+4` | `move-column-to-workspace 4` |  |
| `Mod+CTRL+5` | `move-column-to-workspace 5` |  |
| `Mod+CTRL+6` | `move-column-to-workspace 6` |  |
| `Mod+CTRL+7` | `move-column-to-workspace 7` |  |
| `Mod+CTRL+8` | `move-column-to-workspace 8` |  |
| `Mod+CTRL+9` | `move-column-to-workspace 9` |  |
| `Mod+TAB` | `toggle-overview` | Overview |
| `Mod+CTRL+F` | `expand-column-to-available-width` |  |
| `Mod+C` | `center-column` |  |
| `Mod+CTRL+C` | `center-visible-columns` |  |
| `Mod+Minus` | `set-column-width "-10%"` |  |
| `Mod+Equal` | `set-column-width "+10%"` |  |
| `Mod+Shift+Minus` | `set-window-height "-10%"` |  |
| `Mod+Shift+Equal` | `set-window-height "+10%"` |  |
| `Mod+Shift+Space` | `toggle-window-floating` | Toggle floating |
| `Mod+F` | `fullscreen-window` |  |
| `Mod+Shift+F` | `maximize-column` |  |
| `Mod+W` | `toggle-column-tabbed-display` |  |
| `Mod+M` | `maximize-window-to-edges` |  |
| `Mod+Shift+T` | `~/.local/bin/niri-ocr` | OCR: region to clipboard |
| `Mod+O` | `angelos ws prev` | Previous workspace |

## macOS (Golden Gate)

| Бинд | Действие | Подпись |
|---|---|---|
| `Mod+T` | `~/.local/bin/kitty` | Open Terminal: kitty |
| `Mod+B` | `helium-browser` | Open Browser: Helium |
| `Mod+Alt+Space` | `angelos launcher` | angelOS: программы (лаунчер; ⌘Пробел — Spotlight) |
| `Mod+Alt+Left` | `focus-column-left` | Фокус: колонка слева |
| `Mod+Alt+H` | `focus-column-left` | Фокус: колонка слева |
| `Mod+Alt+Right` | `focus-column-right` | Фокус: колонка справа |
| `Mod+Alt+L` | `focus-column-right` | Фокус: колонка справа |
| `Mod+Alt+Up` | `focus-window-up` | Фокус: окно выше |
| `Mod+Alt+K` | `focus-window-up` | Фокус: окно выше |
| `Mod+Alt+Down` | `focus-window-down` | Фокус: окно ниже |
| `Mod+Alt+J` | `focus-window-down` | Фокус: окно ниже |
| `Mod+Alt+Ctrl+Left` | `move-column-left` | Колонку влево |
| `Mod+Alt+Ctrl+H` | `move-column-left` | Колонку влево |
| `Mod+Alt+Ctrl+Right` | `move-column-right` | Колонку вправо |
| `Mod+Alt+Ctrl+L` | `move-column-right` | Колонку вправо |
| `Mod+Alt+Ctrl+Up` | `move-window-up` | Окно выше |
| `Mod+Alt+Ctrl+K` | `move-window-up` | Окно выше |
| `Mod+Alt+Ctrl+Down` | `move-window-down` | Окно ниже |
| `Mod+Alt+Ctrl+J` | `move-window-down` | Окно ниже |
| `Mod+Alt+Home` | `focus-column-first` | Фокус: первая колонка |
| `Mod+Alt+End` | `focus-column-last` | Фокус: последняя колонка |
| `Mod+Alt+Ctrl+Home` | `move-column-to-first` | Колонку в начало |
| `Mod+Alt+Ctrl+End` | `move-column-to-last` | Колонку в конец |
| `Mod+Alt+BracketLeft` | `consume-or-expel-window-left` | Окно в колонку слева / из неё |
| `Mod+Alt+BracketRight` | `consume-or-expel-window-right` | Окно в колонку справа / из неё |
| `Mod+Alt+Comma` | `consume-window-into-column` | Забрать окно в колонку |
| `Mod+Alt+Period` | `expel-window-from-column` | Вынуть окно из колонки |
| `Mod+Alt+R` | `switch-preset-column-width` | Следующая ширина колонки |
| `Mod+Alt+Shift+R` | `switch-preset-column-width-back` | Предыдущая ширина колонки |
| `Mod+Alt+Ctrl+Shift+R` | `switch-preset-window-height` | Следующая высота окна |
| `Mod+Alt+Ctrl+R` | `reset-window-height` | Сбросить высоту окна |
| `Mod+WheelScrollDown` | `angelos ws down` | Стол ниже |
| `Mod+WheelScrollUp` | `angelos ws up` | Стол выше |
| `Mod+Alt+1` | `angelos ws 1` | Стол 1 |
| `Mod+Alt+2` | `angelos ws 2` | Стол 2 |
| `Mod+Alt+3` | `angelos ws 3` | Стол 3 |
| `Mod+Alt+4` | `angelos ws 4` | Стол 4 |
| `Mod+Alt+5` | `angelos ws 5` | Стол 5 |
| `Mod+Alt+6` | `angelos ws 6` | Стол 6 |
| `Mod+Alt+7` | `angelos ws 7` | Стол 7 |
| `Mod+Alt+8` | `angelos ws 8` | Стол 8 |
| `Mod+Alt+9` | `angelos ws 9` | Стол 9 |
| `Mod+Alt+Ctrl+1` | `move-column-to-workspace 1` | Колонку на стол 1 |
| `Mod+Alt+Ctrl+2` | `move-column-to-workspace 2` | Колонку на стол 2 |
| `Mod+Alt+Ctrl+3` | `move-column-to-workspace 3` | Колонку на стол 3 |
| `Mod+Alt+Ctrl+4` | `move-column-to-workspace 4` | Колонку на стол 4 |
| `Mod+Alt+Ctrl+5` | `move-column-to-workspace 5` | Колонку на стол 5 |
| `Mod+Alt+Ctrl+6` | `move-column-to-workspace 6` | Колонку на стол 6 |
| `Mod+Alt+Ctrl+7` | `move-column-to-workspace 7` | Колонку на стол 7 |
| `Mod+Alt+Ctrl+8` | `move-column-to-workspace 8` | Колонку на стол 8 |
| `Mod+Alt+Ctrl+9` | `move-column-to-workspace 9` | Колонку на стол 9 |
| `Mod+Alt+Tab` | `toggle-overview` | Обзор (niri overview) |
| `Mod+Alt+O` | `angelos ws prev` | Previous workspace |
| `Mod+Alt+Ctrl+F` | `expand-column-to-available-width` | Растянуть колонку на свободное место |
| `Mod+Alt+C` | `center-column` | Колонку в центр |
| `Mod+Alt+Ctrl+C` | `center-visible-columns` | Видимые колонки в центр |
| `Mod+Alt+Ctrl+Minus` | `set-column-width "-10%"` | Колонку уже (−10%) |
| `Mod+Alt+Ctrl+Equal` | `set-column-width "+10%"` | Колонку шире (+10%) |
| `Mod+Alt+Shift+Minus` | `set-window-height "-10%"` | Окно ниже ростом (−10%) |
| `Mod+Alt+Shift+Equal` | `set-window-height "+10%"` | Окно выше ростом (+10%) |
| `Mod+Alt+Shift+Space` | `toggle-window-floating` | Плавающее / в сетке |
| `Mod+Alt+F` | `fullscreen-window` | Окно во весь экран (niri) |
| `Mod+Alt+Shift+F` | `maximize-column` | Развернуть колонку |
| `Mod+Alt+W` | `toggle-column-tabbed-display` | Колонка вкладками |
| `Mod+Alt+M` | `maximize-window-to-edges` | Развернуть окно до краёв |
| `Mod+Shift+T` | `~/.local/bin/niri-ocr-region` | OCR: region to clipboard (stone) |
| `Mod+Z` | `qs -c angelos ipc call magnifier toggle` | Лупа (плагин) |
| `Mod+Q` | `angelos macQuit` | Mac: завершить программу |
| `Mod+W` | `close-window` | Mac: закрыть окно |
| `Mod+M` | `angelos macMinimize` | Mac: свернуть окно в Dock |
| `Mod+H` | `angelos macHide` | Mac: скрыть программу |
| `Mod+Tab` | `angelos alttab apps` | Mac: переключатель программ |
| `Mod+Shift+Tab` | `angelos alttab appsback` | Mac: переключатель программ, назад |
| `Mod+Grave` | `angelos alttab appwin` | Mac: следующее окно этой программы |
| `Mod+Shift+Grave` | `angelos alttab appwinback` | Mac: предыдущее окно этой программы |
| `Mod+Space` | `angelos startMenu ''` | Mac: Spotlight |
| `Mod+Comma` | `angelos settings ''` | Mac: Системные настройки angelOS |
| `Mod+Ctrl+F` | `fullscreen-window` | Mac: полноэкранный режим |
| `Mod+Shift+3` | `mac-screenshot.sh screen` | Mac: снимок экрана |
| `Mod+Shift+4` | `mac-screenshot.sh region` | Mac: снимок области |
| `Mod+Shift+5` | `angelos macShotMenu` | Mac: меню снимков экрана |
| `Ctrl+Left` | `angelos ws up` | Mac: рабочий стол слева |
| `Ctrl+Right` | `angelos ws down` | Mac: рабочий стол справа |
| `Ctrl+Up` | `toggle-overview` | Mac: Mission Control |
| `F3` | `toggle-overview` | Mac: Mission Control |
| `Mod+Ctrl+Q` | `angelos lock` | Mac: заблокировать экран |
| `Mod+Alt+Escape` | `angelos macMenu 0` | Mac: завершить принудительно |
| `Ctrl+F2` | `angelos macMenu -1` | Mac: строка меню с клавиатуры |
