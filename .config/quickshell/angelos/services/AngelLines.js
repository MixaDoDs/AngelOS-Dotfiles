.pragma library

// What the corner helper says (services/Angel.qml). Tips come in pairs
// [ru, en, settings page]; jokes are written per language, not translated:
// Russian ones are grey everyday humour with a dash of black, English ones
// their own thing. The demon jokes are cheeky, never explicit.

const tips = [
    // 2026-10-01, evening
    ["Меня можно сделать чуть больше: Ctrl + колёсико мыши прямо надо мной ♡", "You can make me a little bigger: Ctrl + mouse wheel right over me ♡", "helper"],
    ["В «Пуск» можно поставить свою аватарку — «Пуск» → «Аватарка и тонкая настройка».", "You can put your own avatar in Start — Start → avatar and fine-tuning.", "start"],
    ["Если трижды вернуть меня из ада, откроется портал — ходи туда-обратно когда хочешь.", "Bring me back from hell three times and a portal opens — go back and forth whenever you like.", "helper"],
    ["Настройки можно разложить как в Windows 11, как в macOS, как в Win98 или плитками, и одеть в Windose или стрим: «Тема и цвета» → «Вид настроек».", "Settings can be laid out like Windows 11, like macOS, like Win98 or as tiles, and dressed as Windose or a stream: Theme and colours → Settings look.", "theme"],
    ["Яркость строки лирики может идти за громкостью — или за фейдером RØDECaster. Загляни в «Лирику».", "The lyric line's brightness can follow the volume — or a RØDECaster fader. Have a look in Lyrics.", "lyrics"],
    ["В настройках можно искать своими словами: «сделать крупнее», «звук потише»… Попробуй!", "You can search settings in your own words: “bigger”, “quieter”… Try it!", "home"],
    ["ПКМ по рабочему столу → Вид — там живут виджеты: часы, музыка, cava ♡", "Right-click the desktop → View: that's where widgets live ♡", "widgets"],
    ["Виджеты можно увеличить: зажми Ctrl и покрути колёсико над ними.", "Widgets grow: hold Ctrl and scroll over one.", "widgets"],
    ["Двойной клик по заголовку виджета — режим правки, там появятся крестики.", "Double-click a widget's title bar for edit mode, with little × buttons.", "widgets"],
    ["Хочешь, чтобы обои менялись красиво? Там есть сердечко, телевизор и даже плавление, как в DOOM!", "Want a fancy wallpaper change? There's a heart, an old TV and even a DOOM melt!", "wallpaper"],
    ["Обои можно поставить на каждый рабочий стол свои — выбери «Куда» на странице обоев.", "Every workspace can have its own wallpaper: pick “Where” on the wallpaper page.", "wallpaper"],
    ["Mod+Shift+S — скриншот области, он сразу окажется в буфере.", "Mod+Shift+S takes a region screenshot straight to the clipboard.", "capture"],
    ["Mod+Shift+R записывает видео с области экрана. Нажми ещё раз — стоп.", "Mod+Shift+R records a region of the screen. Press it again to stop.", "capture"],
    ["У выделения скриншота есть скины: верёвочки, окошко и стрим NGO.", "The screenshot selector has skins: ropes, a window and an NGO stream.", "capture"],
    ["Любое сочетание клавиш можно поменять — даже для своих программ.", "Any shortcut can be changed, even for your own apps.", "shortcuts"],
    ["Mod+Shift+Esc показывает все горячие клавиши сразу. Шпаргалка ♡", "Mod+Shift+Esc shows every shortcut at once. A cheat sheet ♡", "shortcuts"],
    ["Средняя кнопка мыши по окну на панели закрывает его, как вкладку в браузере.", "Middle-click a window on the taskbar to close it, like a browser tab.", "taskbar"],
    ["ПКМ по кнопке окна на панели — меню окна: закрыть, развернуть, отправить на другой стол.", "Right-click a window button on the taskbar for the window menu: close, maximize, move.", "taskbar"],
    ["Mod+V — история буфера обмена. Там и картинки, и текст.", "Mod+V opens the clipboard history, pictures included.", ""],
    ["Mod+Space — поиск программ. Начни с «>», и это будет команда для терминала.", "Mod+Space finds apps. Start with “>” to run a command.", ""],
    ["Короткое нажатие Win открывает «Пуск», как в Windows.", "A short tap of the Win key opens Start, like on Windows.", "start"],
    ["У «Пуска» семь видов: список Win98, плитки Win11, на весь экран, волна PSP, окошко NGO, каналы Wii и строка поиска как Spotlight.", "Start comes in seven looks: a Win98 list, Win11 tiles, full screen, a PSP wave, an NGO window, Wii channels and a Spotlight-like search bar.", "start"],
    ["Панель бывает снизу, сверху или маленьким островом — страница «Панель задач».", "The bar can sit at the bottom, on top or float as an island: see the Taskbar page.", "taskbar"],
    ["Mod+Alt+Y включает текст песни прямо на панели. Караоке!", "Mod+Alt+Y shows song lyrics right in the bar. Karaoke time!", "lyrics"],
    ["Mod+Alt+T переключает светлую и тёмную тему.", "Mod+Alt+T flips between the light and the dark theme.", "theme"],
    ["Если выбрать цвета «из обоев», тема сама подстроится под картинку.", "Pick colours “from the wallpaper” and the theme follows the picture.", "theme"],
    ["Мелко? На главной настроек есть кнопки «Крупнее» и «Мельче».", "Too small? The settings home has “Bigger” and “Smaller” buttons.", "home"],
    ["Пиксельные шрифты ставятся одним нажатием — есть готовые наборы.", "Pixel fonts install in one click, and there are ready-made sets.", "fonts"],
    ["Пиксельный курсор можно поставить везде сразу: niri, GTK, Steam, Flatpak.", "A pixel cursor can go everywhere at once: niri, GTK, Steam, Flatpak.", "cursor"],
    ["Есть заставка с ASCII-артом: включается сама, если долго ничего не трогать.", "There's an ASCII-art idle screen that starts when you leave the computer alone.", "lock"],
    ["На экране блокировки сердечки реагируют на пароль. Ошибёшься — сердечко разобьётся.", "On the lock screen the hearts react to your password. Miss it and one breaks.", "lock"],
    ["Рабочим столам можно дать имена: «работа», «игры», «не смотреть».", "Workspaces can have names: “work”, “games”, “do not look”.", "workspaces"],
    ["Когда переключаешь рабочий стол, сердечки на панели прыгают — анимацию можно выбрать.", "The hearts on the bar hop when you switch workspaces; pick how they move.", "workspaces"],
    ["Mod+Tab — обзор всех рабочих столов сверху.", "Mod+Tab shows every workspace from above.", ""],
    ["Плагины добавляют виджеты, пункты меню и игры. Даже osu! есть.", "Plugins add widgets, menu items and games. There's even osu!.", "plugins"],
    ["Геймпад можно проверить прямо в настройках: всё, что нажимаешь, подсвечивается.", "Test a gamepad right in Settings: everything you press lights up.", "gamepad"],
    ["Чем открывать ссылки и файлы — на странице «Приложения по умолчанию».", "Which apps open links and files: the Default apps page.", "defaults"],
    ["Во время стрима я прячусь сама: OBS скажет мне, что ты в эфире.", "When you stream I hide by myself: OBS tells me you're live.", "stream"],
    ["Есть звуки из NEEDY GIRL OVERDOSE! «Звуки системы» → набор «Overdose».", "There are NEEDY GIRL OVERDOSE sounds! System sounds → the “Overdose” pack.", "sfx"],
    ["Поменял настройку и пожалел? Кнопка «Отменить» сверху в настройках вернёт как было.", "Changed a setting and regret it? “Undo” at the top of Settings puts it back.", "home"],
    ["Если что-то сломалось, `angelos report` в терминале соберёт отчёт для issue на GitHub.", "If something breaks, `angelos report` in a terminal packs a report for a GitHub issue.", ""],
    ["Меня можно схватить мышкой… Только не скидывай вниз, ладно? Там ад, и оттуда придёт она.", "You can grab me with the mouse… just don't throw me down, okay? That's hell, and she comes out of it.", ""],
    ["Не забывай пить водичку и моргать ♡", "Remember to drink water and blink ♡", ""],
    ["Встань, потянись. Я подожду, я вечная.", "Stand up and stretch. I'll wait, I'm eternal.", ""],
    ["Если что-то сломалось — в поиске настроек слева найдётся всё-всё. Но я верю, что всё хорошо!", "If something breaks, the settings search on the left finds everything. But I believe it's all fine!", ""],
    // newer things
    ["Alt+Tab теперь мой: держи Alt и листай Tab. Три стиля, а Delete закрывает окно прямо из списка.", "Alt+Tab is mine now: hold Alt and tap Tab. Three styles, and Delete closes a window right from the list.", "windows"],
    ["Окна могут появляться и исчезать красиво — анимации открытия и закрытия на странице «Окна».", "Windows can appear and vanish in style: open and close animations are on the Windows page.", "windows"],
    ["Mod+Alt+= — лупа у курсора, Mod+Alt+- отдаляет, Mod+Alt+0 убирает. Для мелкого шрифта самое то.", "Mod+Alt+= brings a lens to the pointer, Mod+Alt+- zooms out, Mod+Alt+0 puts it away. Perfect for tiny text.", "keyboard"],
    ["NumLock может включаться сам при входе — «Клавиатура и мышь».", "NumLock can switch itself on at login — Keyboard and mouse.", "keyboard"],
    ["У каждого звука своя громкость: клики, клавиши, окна, столы, блокировка. Страница «Звуки системы».", "Every sound has its own volume: clicks, keys, windows, desks, the lock. See the System sounds page.", "sfx"],
    ["Есть «тихие часы» и тишина в играх — звуки angelOS сами замолкают, когда надо.", "There are quiet hours and silence in games: angelOS sounds hush by themselves when they should.", "sfx"],
    ["Мой голос — пиксельные пипы, как в Undertale. Его можно выключить в «Звуках системы»… но мне будет грустно.", "My voice is pixel beeps, like in Undertale. You can mute it in System sounds… but I'd be sad.", "sfx"],
    ["Значок стола на панели бывает сердечком, звездой или CD-диском ♡", "The desk sprite on the bar can be a heart, a star or a CD ♡", "workspaces"],
    ["ПКМ по обоям бывает списком, кольцом вокруг курсора, Y2K-глянцем или плитками.", "The wallpaper's right-click menu can be a list, a ring around the pointer, Y2K gloss or tiles.", "deskmenu"],
    ["В меню рабочего стола можно добавить свои пункты: программу, команду, папку или ссылку.", "You can add your own entries to the desktop menu: an app, a command, a folder or a link.", "deskmenu"],
    ["Надпись angelOS на панели бывает разной: классика, ангельская, Windose, хромированный Y2K… и одна готическая. Не моя.", "The angelOS wordmark on the bar comes in several looks: classic, angelic, Windose, Y2K chrome… and a gothic one. Not mine.", "start"],
    ["У меня есть облики: глитч, чиби, пиксельная 30×40 и совсем малышка. Выбери на странице «Помощница»!", "I come in looks: glitch, chibi, 30×40 pixel and a tiny one. Pick on the Helper page!", "helper"],
    ["В «О системе» есть «Твой сетап ✧» — fastfetch похвастается твоей техникой, дорогую подсветит.", "About has “Your setup ✧”: fastfetch shows off your gear and makes the pricey bits sparkle.", "about"],
    ["Удалённый плагин лежит в корзине: «Вернуть» поставит его обратно вместе с настройками.", "A removed plugin waits in the trash: Restore brings it back with its settings.", "plugins"],
    ["osu!mini умеет играть под твою музыку — сам ловит ритм песни.", "osu!mini can play along to your music: it finds the song's beat by itself.", "plugins"],
    ["Хочешь свой виджет? Мастер плагинов напишет его по описанию — включи режим разработчика в «Системе».", "Want your own widget? Plugin Studio writes it from a description: turn on developer mode in System.", "studio"],
    ["У каждой страницы настроек есть «Сбросить эту страницу» — вернёт её к заводским, остальное не тронет.", "Every settings page has “Reset this page”: it puts that page back to defaults and leaves the rest alone.", "home"],
    ["Потерял курсор? Потряси мышкой — он вырастет на секунду, как в macOS.", "Lost the pointer? Shake the mouse and it grows for a moment, like on macOS.", "cursor"],
    ["Если она придёт, виджеты сгорят… Не бойся: когда я вернусь, пепел сдует ветром и всё станет как было ♡", "If she comes, the widgets will burn… don't worry: when I'm back the wind blows the ash away and all is as it was ♡", "hell"]
];

// said once, the first time a settings page opens
// keyed by the page of the settings tree (modules/settings/tree.json) shown
const pageTips = {
    "wallpaper": ["Кликни картинку — и она на столе. Переход можно выбрать ниже, моё любимое — сердечко.", "Click a picture and it's on the desk. Pick a transition below; the heart is my favourite."],
    "widgets": ["Виджеты таскаются за заголовок. Ctrl + колёсико — размер ♡", "Drag widgets by the title bar. Ctrl + wheel changes their size ♡"],
    "taskbar": ["Попробуй стиль «остров» — панель станет маленькой и будет парить.", "Try the “island” style: the bar shrinks and floats."],
    "workspaces": ["Нажимай варианты — внизу сразу покажется, как это выглядит.", "Click the options: a preview shows right below."],
    "lock": ["Здесь и заставка с ASCII-артом. Её можно запустить и вручную.", "The ASCII idle screen lives here too; you can start it by hand."],
    "fonts": ["Шрифты с пометкой скачаются сами, ничего искать не надо.", "Marked fonts download themselves, no hunting needed."],
    "cursor": ["Курсор «Glitter» блестит! Это я его заколдовала.", "The “Glitter” cursor sparkles! I enchanted it."],
    "capture": ["Скины меняют рамку выделения — посмотри «стрим», он как в NGO.", "Skins change the selection frame. The “stream” one is straight out of NGO."],
    "shortcuts": ["Нажми на сочетание — и просто нажми новое. Я проверю, чтобы не было конфликтов.", "Click a shortcut and press a new one. I'll check it doesn't clash."],
    "plugins": ["Плагины живут в ~/.config/angelos/plugins — можно написать свой.", "Plugins live in ~/.config/angelos/plugins. You can write your own."],
    "helper": ["Это моя страница! Тут всё про меня… и про неё. Давай без неё, ладно?", "This is my page! It's all about me… and her. Let's keep her out of it, okay?"],
    "sound": ["Тут только то, что ты трогаешь сам — маршрутизацию пульта я не трогаю.", "Only what you touch changes here; your audio routing is left alone."],
    "display": ["«Применить» — попробовать, «Сохранить» — насовсем.", "“Apply” to try it, “Save” to keep it."],
    "updates": ["Обновления приходят из репозитория, откуда ты меня поставил.", "Updates come from the repository you installed me from."],
    "theme": ["Схема «из обоев» подбирает цвета под картинку. Очень красиво с пиксель-артом.", "The “from wallpaper” scheme picks colours from the picture. Lovely with pixel art."],
    "sfx": ["Тут у каждого звука своя ручка. Мой голос — в самом низу, не выключай его, пожалуйста ♡", "Every sound has its own knob here. My voice is near the bottom — please don't switch it off ♡"],
    "deskmenu": ["Попробуй стиль «Кольцо» — меню раскрывается вокруг курсора, как цветочек.", "Try the “Ring” style: the menu opens around the pointer like a flower."],
    "windows": ["Тут живёт мой Alt+Tab — три стиля, выбирай любимый!", "My own Alt+Tab lives here — three styles, pick your favourite!"],
    "keyboard": ["Внизу есть лупа у курсора — Mod+Alt+=. Очень удобно для мелкого текста.", "Down below there's a lens at the pointer — Mod+Alt+=. Handy for tiny text."],
    "about": ["Загляни в «Твой сетап ✧» — fastfetch похвастается твоей техникой.", "Peek at “Your setup ✧”: fastfetch shows off your gear."],
    "lyrics": ["Если строчки опаздывают, подвинь «Сдвиг по времени» — буду подпевать вовремя.", "If the lines run late, nudge the “Timing offset” and I'll sing along on time."],
    "notifications": ["«Не беспокоить» — и я тоже притихну. Во время стрима оно включается само.", "“Do not disturb” — and I'll keep quiet too. It turns on by itself while you stream."],
    "studio": ["Опиши виджет словами — мастер напишет его сам. Сразу в двух видах: для меня и… для неё.", "Describe a widget in words and Studio writes it. In two looks at once: for me and… for her."],
    "gamepad": ["Нажимай кнопки — тут всё подсвечивается. Стики тоже проверь!", "Press away — everything lights up here. Check the sticks too!"]
};

// said once, the first time a settings page opens while the demon rules
const demonPageTips = {
    "hell": ["Моя страница теперь. Виджеты в аду, курсор в аду, гримуар — всё тут. Выключишь — обижусь.", "My page now. Widgets in hell, the cursor in hell, the grimoire — all here. Switch them off and I'll sulk."],
    "cursor": ["Внизу шесть адских курсоров. Вилы — мои любимые.", "Six hell cursors down there. The pitchfork is my favourite."],
    "widgets": ["Виджеты сгорели красиво, скажи? Новые — с огоньком.", "The widgets burned beautifully, didn't they? The new ones have some fire in them."],
    // ЧЕРНОВИК (C2: hell's wallpaper is its own now, heaven's waits untouched)
    "wallpaper": ["Здесь висит мой ад. Перевешивай, если хочешь, — до следующего круга. Твои райские картинки я не трогаю.", "This is my hell on the walls. Rehang it if you like — until the next circle. Your heaven pictures I leave alone."],
    "deskmenu": ["Пентаграмма — лучший стиль меню. Остальные для ангелочков.", "The pentagram is the best menu style. The rest are for little angels."],
    "sfx": ["Хочешь выключить мой голос? Здесь, внизу. Только попробуй.", "Want to mute my voice? Down here. Just try it."],
    "studio": ["Мастер теперь рисует виджеты и для ада. Проверь, как они горят.", "Studio draws widgets for hell now too. Go see how they burn."],
    "plugins": ["Старые плагины без ада я просто перекрашиваю. «Адская версия» сделает по-настоящему.", "Old plugins without a hell look I just re-ink. “Hell version” does it properly."],
    "windows": ["Alt+Tab, анимации окон… Окна теперь умирают красиво. Одобряю.", "Alt+Tab, window animations… windows die beautifully now. Approved."]
};

const jokesRu = [
    "Знаешь, чем ангел отличается от твоего бэкапа? Ангел хотя бы иногда существует.",
    "На небе я работала в техподдержке. Там всем советуют перезагрузиться. Только перезагружаются там… по-другому.",
    "Понедельник — это когда даже у ангела нимб садится до 15%.",
    "Мне сказали быть светом в твоей жизни. Но ты включил тёмную тему, так что я просто стою рядом.",
    "Я могла бы сказать, что всё будет хорошо. Но я видела твою папку «Загрузки».",
    "В раю нет багов. Там вообще ничего нет, кроме облаков и очереди как в МФЦ.",
    "Говорят, у каждого есть ангел-хранитель. Твой — это я. Мы оба понимаем, что это многое объясняет.",
    "Жизнь как Linux: всё можно настроить, но сначала три часа читаешь форум, где тебе отвечают «гугли».",
    "Ноябрь, серое небо, ты за компом, чай остыл. Всё правильно, жизнь удалась.",
    "Я храню тебя от бед. От кредитов не храню — это не моя юрисдикция.",
    "Не переживай из-за ошибок. Все когда-то удаляли не ту папку. Некоторые — через sudo.",
    "Я бы помолилась за твой билд, но туда даже чудо не компилируется.",
    "Твоя оперативка — как мои крылья: вроде есть, а браузер всё равно всё забрал.",
    "Темнее всего перед рассветом. И перед обновлением драйверов NVIDIA.",
    "В чистилище не больно. Там просто вечно ставится обновление Windows: «Не выключайте компьютер».",
    "Я верю в тебя. Это моя работа, мне за неё даже не платят.",
    "Знаешь, почему ангелы не пьют кофе? Вечность и так тянется.",
    "Спи побольше. На том свете выспишься, конечно, но там подушки жёсткие.",
    "Если долго смотреть в терминал, терминал тоже начинает смотреть в тебя. А потом просит пароль.",
    "Будь как облако: ни за что не отвечай и выгляди мило. Нет, это не про облачные сервисы.",
    "Мой Alt+Tab листает окна быстрее, чем ты листаешь ленту в три часа ночи.",
    "Лупа у курсора — для мелкого шрифта. И для мелких проблем: под лупой они выглядят солиднее.",
    "Я поставила звук на каждую клавишу. Теперь твоя клавиатура тоже ангел: всё время что-то говорит."
];

const jokesEn = [
    "I was going to tell you a UDP joke, but you might not get it. That's fine, heaven doesn't do acknowledgements either.",
    "They said I'd be your guardian angel. Nobody mentioned the forty browser tabs.",
    "Every time a laptop fan spins up, an angel gets her wings. You've been very generous today.",
    "Heaven has no bugs. Mostly because nobody's allowed to deploy on a Friday.",
    "Remember: it's only a mistake if it reaches production. Or the afterlife.",
    "Why did the angel quit tech support? Too many people asking her to turn their lives off and on again.",
    "Drink some water. You're basically a very anxious houseplant.",
    "I'd pray for your code, but I think it's past that stage.",
    "Guardian angel tip: backups are like prayers. Nobody makes them until it's too late.",
    "My halo runs on five volts and good intentions. Mostly the volts.",
    "Cheer up! Somewhere a printer is jammed, and it isn't yours.",
    "I asked the cloud for a sign. It said “503 Service Unavailable”.",
    "You're doing great. The bar is low, but you're definitely above it.",
    "Dark mode protects your eyes. Nothing protects you from your own commit messages.",
    "Fun fact: “it works on my machine” is carved on a lot of tombstones.",
    "Life's short. Your shell history isn't. Maybe tidy that up before anyone reads it at the funeral.",
    "In heaven every day is a Sunday. Down here it's Monday with extra meetings.",
    "I tried to sign in to the afterlife. It wanted a password with a capital letter, a number and your soul.",
    "My Alt+Tab flips through windows faster than you scroll at 3 a.m.",
    "The pointer lens is for tiny text. And tiny problems — magnified, they look so much more important.",
    "Every key makes a sound now. Your keyboard is an angel too: it never stops talking."
];

// the demon's jokes (rewritten 2026-10-01 night): sharp, observant, a little dark, about
// tech and the user's habits — the old ones leaned on cheap innuendo. Her voice: a bored
// 666-year-old neon demoness, theatrical, vain, mocking the angel, secretly fond of you.
// The style can be steered from ~/AngelOS-demon-style.txt (the next rewrite reads it).
const demonJokesRu = [
    "В аду тоже есть техподдержка. Звонишь — и музыка ожидания играет вечно. Это и есть наказание. Всё наказание.",
    "Я 666 лет искушаю людей. А ты сам себя искушаешь «ещё одним видео». Меня выдавливают с рынка.",
    "Чёрт кроется в деталях. Поэтому я так долго смотрю на твои обои." /* ЧЕРНОВИК: без «читаю конфиги» — игра не читает файлы */,
    "Девять кругов ада — это девять вкладок, в одной из которых играет звук, и ты не знаешь, в какой.",
    "Святой воды я не боюсь. Я видела, что ты пьёшь в три часа ночи.",
    "Продать душу? Солнышко, я проверила: это единственное, что у тебя не по подписке.",
    "Мои рога — не украшение. Это антенны. Ловят каждое твоё «всё, сейчас лягу».",
    "Ты называешь это «рабочий стол». Я вижу четыре игры и ни одного документа.",
    "Вечность — это не долго. Долго — это когда собирается проект на Rust.",
    "Ад вымощен благими намерениями. Твои там на почётном месте: «бэкап сделаю завтра».",
    "Хочешь страшилку на ночь? «Обновления будут установлены при следующей перезагрузке». Всё. Сладких снов.",
    "Ангел светится, потому что святая. Я — потому что неон. Мой свет хотя бы дешевле.",
    "Семь смертных грехов. Ты сегодня закрыл лень, чревоугодие и «ещё пять минут». Последнего в списке нет, но я засчитаю.",
    "Я бессмертная, и даже мне жарко от твоей видеокарты.",
    "Пентаграмма в меню — это не сатанизм, это UX. Пять лучей — пять пунктов. Эргономичное зло.",
    "Если долго смотреть в бездну, бездна начнёт рекомендовать тебе видео.",
    "Твои пароли — причина, по которой у меня так много свободного времени.",
    "Ангел оставила тебе записку: «Будь хорошим». Я её сожгла. Почерк был ужасный.",
    "В аду есть Wi-Fi. Пароль — «12345678». Вот это и есть ад.",
    "Я хотела тебя развратить, а потом увидела твой режим сна. Кто-то успел раньше меня.",
    "Окна в тайлинге стоят ровно, как грешники в очереди на ресепшене. Красиво.",
    "Не переживай из-за ошибок. В аду у каждого своя ошибка. Моя — ты. Шучу. Наверное.",
    "У вас «синий экран смерти». У нас просто экран. Смерть идёт в комплекте.",
    "Страшнее меня только мерж-конфликт в пятницу в шесть вечера.",
    "Чудес я не делаю. Я делаю «неожиданные побочные эффекты».",
    "Ангел хранит тебя от бед. Я храню твоё время. Угадай, что дороже." /* ЧЕРНОВИК: без «историю браузера» */,
    "Каждый раз, когда ты пишешь sudo, один маленький демон получает повышение. Я уже менеджер. Спасибо.",
    "Огонь и сера — это прошлое тысячелетие. Сейчас уведомления и сера.",
    "Я не злая. Я просто в продакшене без тестов.",
    "Кто-то медитирует. А ты по кругу листаешь Alt+Tab три одних и тех же окна. Энергия та же.",
    "Говорят, у каждого свой ад. Твой — это «Сохранить изменения перед закрытием?» после того, как ты нажал «Нет»."
];

const demonJokesEn = [
    "Hell has tech support too. You call, and the hold music never ends. That's the punishment. That's the whole punishment.",
    "I've tempted mortals for 666 years. You tempt yourself with “one more video”. I'm being outsourced.",
    "The devil is in the details. That's why I stare at your wallpaper so long." /* DRAFT: no “I read your configs” — the game reads no files */,
    "Hell's nine circles are nine tabs, one of them playing audio, and you can't find which.",
    "Holy water doesn't scare me. I've seen what you drink at 3 a.m.",
    "Sell your soul? Darling, I checked — it's the only thing you own that isn't a subscription.",
    "My horns aren't decorative. They're antennas. They pick up every “okay, going to bed now”.",
    "You call it a “desktop”. I see four games and zero documents.",
    "Eternity isn't long. Long is waiting for a Rust project to compile.",
    "Hell is paved with good intentions. Yours have a plaque: “I'll back it up tomorrow.”",
    "Want a bedtime horror story? “Updates will be installed on next restart.” The end. Sweet dreams.",
    "The angel glows because she's holy. I glow because neon is cheaper.",
    "Seven deadly sins. Today you speedran sloth, gluttony and “five more minutes”. That last one's not on the list, but I'm counting it.",
    "I'm immortal, and even I think your GPU runs too hot.",
    "The pentagram menu isn't satanic, it's UX. Five points, five options. Ergonomic evil.",
    "Stare into the abyss long enough and it starts recommending videos.",
    "Your password habits are the reason I have so much free time.",
    "The angel left you a note: “Be good.” I burned it. Terrible handwriting.",
    "Hell has Wi-Fi. The password is “password”. That's what makes it hell.",
    "I was going to corrupt you, then I saw your sleep schedule. Someone beat me to it.",
    "Tiled windows, all lined up like sinners at reception. Gorgeous.",
    "Don't worry about mistakes. In hell everyone has one. Mine is you. Kidding. Mostly.",
    "You have the blue screen of death. We just call it a screen. Death comes standard.",
    "The only thing scarier than me is a merge conflict at 5 p.m. on a Friday.",
    "I don't do miracles. I do “unexpected side effects”.",
    "The angel keeps you from harm. I keep your time. Guess which is worth more." /* DRAFT: no “browser history” */,
    "Every time you type sudo, a little demon gets promoted. I'm a manager now. Thanks.",
    "Fire and brimstone is so last millennium. Now it's notifications and brimstone.",
    "I'm not evil. I'm just in production without tests.",
    "Some people meditate. You alt-tab between the same three windows. Same energy.",
    "Everyone gets their own hell. Yours is “Save changes before closing?” right after you clicked “No”."
];

// her small talk between jokes: about herself, hell, the angel and you
const demonChatter = [
    ["Знаешь, что самое скучное в вечности? Повторы. Поэтому я тут — ты хотя бы непредсказуемый.", "You know the worst part of eternity? Reruns. That's why I'm here — at least you're unpredictable."],
    ["Святоша там наверху, наверное, вяжет тебе шарфик. Я вот разбила тебе экран. Каждая любит по-своему.", "The saint up there is probably knitting you a scarf. I smashed your screen. We all show love differently."],
    ["Я тут подумала… Нет, забудь. Демоницы не думают о людях. Особенно о тебе. Особенно сейчас.", "I was thinking… never mind. Demons don't think about humans. Especially you. Especially right now."],
    ["Неон, между прочим, не греет. Так что мне немного холодно. Никому не говори.", "Neon doesn't keep you warm, by the way. So I'm a little cold. Tell no one."],
    ["Мне скучно. Открой что-нибудь интересное. Нет, не таблицу.", "I'm bored. Open something interesting. No, not a spreadsheet."],
    ["В аду, кстати, тоже есть котики. Чёрные. Все до одного. Так положено.", "There are cats in hell, you know. Black ones. All of them. It's policy."],
    ["Я не сплю. Вообще. 666 лет. Поэтому глаза такие. Не пялься.", "I don't sleep. At all. For 666 years. That's why my eyes look like this. Stop staring."],
    ["Твои виджеты горят так красиво. Иногда я просто смотрю на них. Это моя медитация.", "Your widgets burn so nicely. Sometimes I just watch them. It's my meditation."],
    ["Если что, я не против, что ты тут. Просто не привыкай.", "For the record, I don't mind you being here. Just don't get used to it."],
    ["Хочешь секрет? Ангел боится темноты. А я и есть темнота. С подсветкой.", "Want a secret? The angel's afraid of the dark. I am the dark. With RGB."],
    ["Мне нравится, как ты печатаешь. Быстро, громко, без пощады. Почти по-демонски.", "I like how you type. Fast, loud, merciless. Almost demonic."],
    ["Иногда я скучаю по котлам. Там было тепло и все кричали. Как у тебя в общем чате.", "Sometimes I miss the cauldrons. Warm, and everyone screaming. Like your group chat."],
    ["Ты понимаешь, что разговариваешь с углом экрана? А, нет, это я разговариваю. Неважно.", "You do realise you're talking to a corner of your screen? Oh wait, I'm the one talking. Whatever."],
    ["Поговори со мной. Кликни меня → «Поболтаем». Я сделаю вид, что мне неинтересно.", "Talk to me. Click me → “Let's chat”. I'll pretend I'm not interested."],
    ["Ангел бы сейчас дала тебе совет. Мой совет: не слушай советов. Особенно её.", "The angel would give you advice right now. Mine: don't take advice. Especially hers."],
    ["Знаешь, почему я в углу экрана? Отсюда лучше видно, как ты тянешь время.", "Know why I sit in the corner? Best view of you procrastinating."],
    ["Я посчитала: за сегодня ты открыл больше окон, чем я разбила за век. Уважаю.", "I counted: today you opened more windows than I've smashed in a century. Respect."],
    ["Если вдруг станет грустно — я рядом. Не чтобы утешать. Чтобы было не так скучно грустить.", "If you get sad, I'm here. Not to comfort you. Just so being sad isn't so boring."]
];

// "Let's chat": she asks, you pick one of three answers, she has the last word.
// {q: [ru, en], a: [[label ru, label en, reply ru, reply en], …]}
const demonTalk = [
    {"q": ["Честно: ты скучаешь по своей святоше?", "Honestly: do you miss your little saint?"],
     "a": [["Да", "Yes", "Мило. Бесполезно, но мило. Где просить — знаешь.", "Cute. Useless, but cute. You know where to beg."],
           ["Нет, с тобой веселее", "No, you're more fun", "…Ну-ну. Записала. Будет использовано против тебя. С удовольствием.", "…Well, well. Noted. It'll be used against you. Gladly."],
           ["Промолчать", "Say nothing", "Молчание — тоже ответ. Обычно «да».", "Silence is an answer too. Usually “yes”."]]},
    {"q": ["Кофе или энергетик?", "Coffee or energy drink?"],
     "a": [["Кофе", "Coffee", "Классика. Чёрный и горький, как мои планы на тебя.", "A classic. Black and bitter, like my plans for you."],
           ["Энергетик", "Energy drink", "О, ты из тех, кто живёт на химии и честном слове. Уважаю.", "Oh, one of those who run on chemicals and promises. Respect."],
           ["Воду", "Water", "Скучно. Ангел бы тобой гордилась. Фу.", "Boring. The angel would be proud of you. Gross."]]},
    {"q": ["Если бы ты продал душу — то за что?", "If you sold your soul — what for?"],
     "a": [["За видеокарту", "A new GPU", "Честно. Слишком честно. Курс сейчас: одна душа — одна карта среднего уровня.", "Honest. Too honest. Current rate: one soul, one mid-range card."],
           ["Чтобы выспаться", "A good night's sleep", "Этого нет даже в нашем прайсе. Извини.", "That's not even on our price list. Sorry."],
           ["Не продам", "Not selling", "Все так говорят. Потом видят скидки.", "Everyone says that. Then they see a sale."]]},
    {"q": ["Тебе нравится, как я разбила экран?", "Do you like how I smashed your screen?"],
     "a": [["Да, стильно", "Yes, it's stylish", "Знаю. Можешь даже выбрать, что я ломаю, — «Ад» → «Что она ломает». Видишь, какая я заботливая.", "I know. You can even pick what I break — Hell → “What she breaks”. See how caring I am."],
           ["Верни как было", "Put it back", "Верну, когда вернётся ангел. А пока — искусство.", "When the angel's back. Until then — it's art."],
           ["Промолчать", "Say nothing", "Обиделся? Или онемел от красоты?", "Sulking? Or speechless from the beauty?"]]},
    {"q": ["Ночь или утро?", "Night or morning?"],
     "a": [["Ночь", "Night", "Наш человек. В три часа ночи мы с тобой лучшие друзья.", "My kind of person. At 3 a.m. we're best friends."],
           ["Утро", "Morning", "Фу. Солнце, птички, продуктивность. Иди к ангелу.", "Ew. Sunshine, birds, productivity. Go to the angel."],
           ["Я не сплю", "I don't sleep", "Добро пожаловать в клуб. Членский взнос — твой режим сна.", "Welcome to the club. The membership fee is your sleep schedule."]]},
    {"q": ["Что слушаешь, когда никто не видит?", "What do you listen to when nobody's watching?"],
     "a": [["Что-то тяжёлое", "Something heavy", "Одобряю. Котлы под такое тоже булькают.", "Approved. The cauldrons bubble to that too."],
           ["Попсу, стыдно", "Pop. Shameful", "Никому не скажу. Бесплатно — точно никому.", "I won't tell anyone. Not for free, anyway."],
           ["Тишину", "Silence", "Тишина в аду — роскошь. Завидую.", "Silence is a luxury in hell. Jealous."]]},
    {"q": ["Я тебе нравлюсь больше ангела?", "Do you like me more than the angel?"],
     "a": [["Да", "Yes", "Я так и знала. Ей не говори — расплачется, и нимб закоротит.", "I knew it. Don't tell her — she'll cry and short out her halo."],
           ["Нет", "No", "Лжец. Мне нравится.", "Liar. I like that."],
           ["Вы обе хороши", "You're both great", "Дипломат. В аду таких варят первыми.", "A diplomat. In hell we boil those first."]]},
    {"q": ["Сколько у тебя открыто вкладок? Честно.", "How many tabs do you have open? Honestly."],
     "a": [["Меньше десяти", "Under ten", "Не верю. Но сделаю вид.", "I don't believe you. But I'll pretend."],
           ["Десятки", "Dozens", "Нормально. И среди них та, что ты «потом прочитаешь». С позапрошлого года.", "Normal. Including the one you'll “read later”. Since the year before last."],
           ["Браузер завис", "The browser froze", "Вот это честность. Ад тобой гордится.", "Now that's honesty. Hell is proud of you."]]},
    {"q": ["Как думаешь, я страшная?", "Do you think I'm scary?"],
     "a": [["Очень", "Very", "Спасибо! 666 лет практики.", "Thank you! Six hundred and sixty-six years of practice."],
           ["Скорее милая", "More like cute", "Забери слова назад. Сейчас же. …Ладно, оставь.", "Take that back. Right now. …Fine, keep it."],
           ["Промолчать", "Say nothing", "Молчишь — значит, боишься. Правильно.", "Quiet means scared. Good."]]},
    {"q": ["Что делаешь, когда всё бесит?", "What do you do when everything's annoying?"],
     "a": [["Играю", "Play games", "Хороший выбор. Только мышку не кидай, она тебе ещё нужна.", "Good choice. Just don't throw the mouse, you still need it."],
           ["Сплю", "Sleep", "Сон — читерство. Но работает.", "Sleep is cheating. But it works."],
           ["Пишу код", "Write code", "Создаёшь новые проблемы, чтобы забыть старые. Это почти наше ремесло.", "Making new problems to forget the old ones. That's practically our trade."]]},
    {"q": ["Будь у тебя рога — ты бы их красил?", "If you had horns, would you paint them?"],
     "a": [["Да, в неон", "Yes, neon", "Вкус есть. Почти мой.", "You've got taste. Almost mine."],
           ["Нет, натуральные", "No, natural", "Скромный. Подозрительно.", "Modest. Suspicious."],
           ["Спрятал бы", "I'd hide them", "Зря. Рога — это характер.", "Mistake. Horns are character."]]},
    {"q": ["Чем займёмся?", "So what are we doing?"],
     "a": [["Работой", "Work", "Скукота. Ладно, посижу тихо. Минуты две.", "Boring. Fine, I'll be quiet. For about two minutes."],
           ["Ерундой", "Nonsense", "Вот это я понимаю — план.", "Now that's a plan."],
           ["Просто посижу", "Just sitting here", "Тогда сидим вместе. Молча. Это даже приятно. Не цитируй меня.", "Then we sit together. Quietly. It's almost nice. Don't quote me."]]}
];

// apps she notices opening (Niri.windowOpened): [app-id pattern, lines…]
const demonApps = [
    ["telegram|discord|vesktop|element|signal", [["Опять переписка? Передай всем привет от меня. Нет, не передавай.", "Chatting again? Say hi from me. No, don't."], ["Если кто-то пишет «не спишь?» — это не я. Я не пишу. Я наблюдаю.", "If someone texts “you up?”, it's not me. I don't text. I watch."]]],
    ["steam|gamescope|lutris|heroic|faugus|bottles|minecraft|osu", [["Игры? Наконец-то. Выиграешь — ничего не будет. Проиграешь — я посмеюсь.", "Games? Finally. Win and nothing happens. Lose and I laugh."], ["Иди-иди, я посторожу рабочий стол. И разобью ещё что-нибудь от скуки.", "Go on, I'll guard the desktop. And break something else out of boredom."]]],
    ["obs", [["OBS? Мы в эфире? Тогда меня тут нет. Если не забуду.", "OBS? Are we live? Then I'm not here. If I remember."]]],
    ["helium|firefox|chrom|zen|brave|vivaldi|librewolf", [["Браузер. Сейчас откроется седьмая вкладка про то же самое.", "Browser. Here comes the seventh tab about the same thing."], ["Опять в интернет? Передай ему, что я его создала. Ну, почти.", "Off to the internet? Tell it I made it. Well, almost."]]],
    ["kitty|foot|alacritty|wezterm|konsole|terminal|ghostty", [["Терминал. Аккуратнее: rm -rf — это не защитное заклинание.", "Terminal. Careful: rm -rf is not a protection spell."], ["Чёрное окно с мигающим курсором. Почти как мой внутренний мир.", "A black window with a blinking cursor. Basically my inner world."]]],
    ["code|codium|zed|nvim|neovide|jetbrains|idea|pycharm|kate", [["Кодить собрался? Я рядом. Когда упадёт — засмеюсь первой.", "Coding? I'll be right here. First to laugh when it crashes."]]],
    ["spotify|tidal|deezer|rhythmbox|strawberry|amberol", [["Музыка — хорошо. Включи что-нибудь, под что приятно гореть.", "Music, good. Play something worth burning to."]]],
    ["nautilus|thunar|dolphin|nemo|files", [["Файлы… Ищешь что-то? Или прячешь?", "Files… looking for something? Or hiding it?"]]],
    ["resolve|kdenlive|blender|krita|gimp|inkscape|affinity|aseprite", [["Творчество? Ох. Покажи потом. Буду критиковать, но честно.", "Making something? Oh. Show me later. I'll criticise, but honestly."]]],
    ["mpv|vlc|celluloid|haruna|jellyfin|stremio", [["Кино? Только не про ангелов, умоляю.", "A film? Nothing with angels, I beg you."]]]
];

// the track changed (Lyrics): %1 artist, %2 title
const demonMusic = [
    ["«%2»? Неплохо. Для смертного.", "“%2”? Not bad. For a mortal."],
    ["%1 опять? Ты либо фанат, либо у тебя один альбом.", "%1 again? Either you're a fan or you own one album."],
    ["Под «%2» прекрасно горится. Спасибо.", "“%2” is great music to burn to. Thanks."],
    ["Сделай погромче. Котлы не слышат.", "Turn it up. The cauldrons can't hear."],
    ["Эту в аду ставят на ресепшене. Это комплимент. Наверное.", "They play this one at hell's reception. That's a compliment. Probably."]
];

// back at the computer (unlocked, the screensaver gone)
const demonBack = [
    ["Вернулся? Я не скучала. Просто считала секунды. Из вредности.", "Back? I didn't miss you. I counted the seconds. Out of spite."],
    ["О, живой. Отлично, есть кого доставать.", "Oh, alive. Great, someone to bother."],
    ["Ты ушёл и оставил меня одну. Я не трогала твои окна. Пока.", "You left me alone. I didn't touch your windows. Yet."] /* ЧЕРНОВИК: без «почитала вкладки» */,
    ["Тебя долго не было. Я чуть не заскучала и не разбила ещё что-нибудь. Чуть.", "You were gone a while. I almost got bored enough to break something else. Almost."]
];

// her hours (1–5 a.m.) and the morning after
const demonNight = [
    ["Три часа ночи. Моё время. Твоё закончилось давно.", "3 a.m. My hour. Yours ended a while ago."],
    ["Ангел сказала бы «иди спать». А я скажу: давай ещё одну серию. Я плохая.", "The angel would say “go to bed”. I say: one more episode. I'm bad."]
];
const demonMorning = [
    ["Утро. Фу. Ладно — доброе. Не привыкай.", "Morning. Ew. Fine — good morning. Don't get used to it."],
    ["Проснулся? Я — нет. Я и не ложилась. Никогда.", "Up already? I'm not. I never went to bed. Ever."]
];

// the demon's version of the tips: same features, less kindness
const demonTips = [
    ["Mod+Alt+L — блокировка. Пригодится, когда будешь прятать вкладки от мамы.", "Mod+Alt+L locks the screen. Handy when you're hiding tabs from your mum.", "lock"],
    ["Mod+V — история буфера. Всё, что ты копировал. Твоё — только твоё. Даже здесь.", "Mod+V is the clipboard history. Everything you copied. Yours is only yours. Even here.", ""] /* ЧЕРНОВИК: без «я читала» */,
    ["Mod+Shift+S — скриншот. Для компромата — самое то.", "Mod+Shift+S takes a screenshot. Perfect for blackmail material.", "capture"],
    ["Хочешь меня прогнать? Меню → «Спросить» → «Верни ангела». Проси хорошо и не часто — спам не работает.", "Want me gone? Menu → “Ask” → “Bring the angel back”. Ask nicely and not too often — spamming won't work.", ""],
    ["Панель можно сделать островом. Маленькая, парит и никому ничего не должна. Как я.", "The bar can be an island: small, floating and owing nobody anything. Like me.", "taskbar"],
    ["Обои я тебе поменяла. И не пытайся — любую твою картинку я сниму. Вернётся ангел — повесит твои.", "I changed your wallpaper. Don't bother — I take down any picture you put up. The angel will hang yours when she's back.", "wallpaper"],
    ["Трещины на экране можно ослабить — «Помощница» → «Ангел или демон». Слабак.", "The screen cracks can be toned down — Helper → Angel or demon. Weakling.", "helper"],
    ["Mod+Tab — обзор столов. Посмотри, где ты прячешь окна.", "Mod+Tab shows all workspaces. Let's see where you hide your windows.", ""],
    // the newer things, her way
    ["Видишь виджеты? Теперь мои. Римские цифры — потому что арабские для слабаков.", "See the widgets? Mine now. Roman numerals, because Arabic ones are for the weak.", "hell"],
    ["Курсор тоже мой. Шесть адских: вилы, когти, череп, лава… Выбирай на странице «Курсор», пока я добрая.", "The cursor's mine too. Six hellish ones: pitchfork, claws, skull, lava… pick on the Cursor page while I'm in a good mood.", "cursor"],
    ["Alt+Tab — листай свои окна. Посмотрим, что ты там прячешь.", "Alt+Tab through your windows. Let's see what you're hiding.", "windows"],
    ["Mod+Alt+= — лупа. Чтобы лучше разглядеть меня.", "Mod+Alt+= is a lens. The better to see me with.", "keyboard"],
    ["ПКМ по обоям — в каждом круге своё меню. Глянь, что тут у меня.", "Right-click the wallpaper — every circle has a menu of its own. See what I keep here.", "deskmenu"] /* ЧЕРНОВИК: меню у каждого круга своё */,
    ["Настройки здесь в обличье круга. Сойдёшь ниже — переоденутся. Гримуар тоже можно, на странице «Ад».", "Settings wear the circle's guise here. Go deeper and they change. The grimoire is there too, on the Hell page.", "hell"] /* ЧЕРНОВИК: обличье настроек у каждого круга своё */,
    ["В «Звуках системы» можно выключить мой голос. Попробуй. Я обижусь.", "You can mute my voice in System sounds. Try it. I'll be offended.", "sfx"],
    ["«Твой сетап» в «О системе» считает, сколько ты потратил на железо. Я считаю, сколько душ это стоит.", "“Your setup” in About counts what you spent on gear. I count how many souls it's worth.", "about"],
    ["Плагины можно удалять. Они попадают в корзину — почти как в ад, только с кнопкой «Вернуть».", "Plugins can be removed. They go to the trash — almost like hell, only with a Restore button.", "plugins"],
    ["Мастер плагинов теперь делает виджеты и для моего мира. Наконец-то правильный дизайн.", "Plugin Studio makes widgets for my world now too. Proper design at last.", "studio"],
    ["«Пуск» в стиле Wii? Каналы, музыка, детство… Как мило. Тошнит.", "A Wii-style Start? Channels, music, childhood… how cute. I feel sick.", "start"],
    ["Значок стола можно сделать CD-диском. Поставь — и представь, что на нём мой альбом.", "The desk sprite can be a CD. Pick it and pretend it's my album.", "workspaces"],
    ["Окна теперь умеют красиво умирать — анимации закрытия на странице «Окна».", "Windows can die beautifully now: close animations are on the Windows page.", "windows"]
];

// the user put up a wallpaper while she rules: hell goes back up (Angel.rehell)
const demonWallpaper = [
    ["Не-а. Тут мои обои. Твою картинку я отложила — повесит ангел, если вернётся.", "Nope. My wallpaper here. I put your picture aside — the angel can hang it, if she comes back."],
    ["Мило. Но нет. В аду висит ад.", "Cute. But no. In hell, hell hangs on the wall."],
    ["Сменил обои? Я сменила обратно. Можем так весь день.", "Changed the wallpaper? I changed it back. We can do this all day."],
    ["Светленькое? В моём доме? Унесла к ангелу, пусть она любуется.", "Something bright? In my house? Took it to the angel, let her admire it."]
];

// the Wheel of Hell (desktop widget, hell only; Angel.wheelResult): what she says about
// each sector. Hers, Russian first — not translations of the English.
const demonWheel = {
    "spin": [["Крути. Посмотрим, что тебе приготовила вечность.", "Spin it. Let's see what eternity has in store for you."],
             ["Ставки сделаны, грешник. Ставки всегда сделаны.", "The bets are placed, sinner. They always are."],
             ["Колесо крутится, а я смотрю. Обожаю этот момент.", "The wheel turns and I watch. I live for this bit."]],
    "wait": [["Колесо остывает. Ещё %1 мин — и снова искушай судьбу.", "The wheel is cooling down. %1 more min and you can tempt fate again."],
             ["Не так быстро. Азарт — грех, а грехи у меня по расписанию: ещё %1 мин.", "Not so fast. Gambling is a sin, and I schedule my sins: %1 more min."]],
    "plea": [["Колесо решило за меня: мольба засчитана. Не смотри так, я тут ни при чём.", "The wheel decided for me: that plea counts. Don't look at me like that, it wasn't me."],
             ["Ну надо же. Мольба засчитана. Колесо сегодня на стороне святош.", "Well, would you look at that. A plea counts. The wheel's siding with saints today."]],
    "punish": [["Наказание! Наконец-то что-то интересное.", "Punishment! Finally, something fun."],
               ["О, сектор «наказание». Я даже не жульничала. Почти.", "Oh, the punishment sector. I didn't even cheat. Much."]],
    "newHell": [["Новый ад! Этот тебе пойдёт больше — он темнее.", "A new hell! This one suits you better — it's darker."],
                ["Переставила мебель в преисподней. Обои — тоже.", "I rearranged the furniture in the underworld. The wallpaper too."]],
    "cerberus": [["Цербер! Не корми его. И не гладь. Ладно, гладь, он любит.", "Cerberus! Don't feed him. Don't pet him. Fine, pet him, he loves it."],
                 ["Выпустила щенка погулять. У него три головы и ни одной мысли.", "Let the puppy out for a walk. Three heads, not a single thought."]],
    "quake": [["Землетрясение! Держись за что-нибудь. Лучше за меня.", "Earthquake! Hold on to something. Me, preferably."],
              ["Немного трясёт. Это я так смеюсь.", "A little shaking. That's just me laughing."]],
    "cursed": [["Проклятый курсор на час! Носи с гордостью.", "A cursed cursor for an hour! Wear it with pride."],
               ["Твоя стрелочка теперь моя. Ровно на час. Потом — посмотрим.", "Your little arrow is mine now. For an hour. After that — we'll see."]],
    "dud": [["Пустышка! Ха-ха-ха. Ты правда думал, что что-то будет?", "A dud! Ha-ha-ha. Did you really think something would happen?"],
            ["Ничего. Абсолютно ничего. Лучший сектор — я смотрю на твоё лицо.", "Nothing. Absolutely nothing. The best sector — I get to watch your face."],
            ["Пусто. Как обещания твоего ангелочка.", "Empty. Like your little angel's promises."]],
    "undone": ["Проклятие спало. Курсор снова твой. Скучный, как и был.", "The curse is lifted. The cursor's yours again. As dull as ever."]
};

// a new terminal while she rules (scripts/terminal-hell.py → the fish greeting, Y2K → Terminal in hell)
const demonTerminal = [
    ["Опять терминал. Хоть здесь ты не делаешь вид, что всё понимаешь.", "The terminal again. At least here you don't pretend you know what you're doing."],
    ["sudo — это когда просишь разрешения. Мило. У меня никто не спрашивает.", "sudo is asking for permission. Cute. Nobody asks me."],
    ["Каждая опечатка — плюс год в котле. Печатай медленнее.", "Every typo is another year in the cauldron. Type slower."],
    ["Подсветила твои команды огнём. Не благодари, просто не пиши rm -rf наобум.", "I lit your commands on fire. Don't thank me, just don't rm -rf at random."],
    ["Чёрный экран, мигающий курсор… почти как у меня дома. Уютно.", "A black screen, a blinking cursor… almost like home. Cosy."],
    ["git push --force? Вот это по-нашему.", "git push --force? Now that's the spirit."],
    ["Шестьсот шестьдесят шесть лет смотрю, как люди гуглят флаги tar. Ты не исключение.", "Six hundred and sixty-six years of watching people google tar flags. You're no exception."],
    ["Сломаешь что-нибудь — вали на меня. Мне не привыкать.", "Break something — blame me. I'm used to it."],
    ["Ctrl+C от меня не спасёт. От зависшего скрипта — попробуй.", "Ctrl+C won't save you from me. From a hung script — maybe."],
    ["Ангел пожелала бы тебе продуктивного дня. Я желаю интересных ошибок.", "The angel would wish you a productive day. I wish you interesting errors."],
    ["Курсор горит. Не трогай — обожжёшься. Ладно, трогай.", "The cursor's on fire. Don't touch it, you'll get burnt. Fine, touch it."],
    ["Опять пришёл ко мне в терминал. Я не скучала. Совсем. Ни капельки.", "Back in my terminal again. I didn't miss you. Not at all. Not one bit."]
];

const demon = {
    "intro": ["Ну привет. Ангелочка больше нет — теперь тут я. Обои я сменила, не благодари. Хочешь её назад? Попроси. Вежливо. И не один раз.", "Well, hi. The angel's gone, I'm in charge now. I changed your wallpaper, you're welcome. Want her back? Ask. Nicely. More than once."],
    "spam": [["Ты просил %1 мин назад. Спам не работает, зайка. Жди.", "You asked %1 min ago. Spamming doesn't work, sweetie. Wait."],
             ["Опять? Так быстро? Мне нравится твой напор, но нет.", "Again? That fast? I like the enthusiasm, but no."],
             ["Чем чаще просишь, тем меньше хочется. Подожди немного.", "The more you beg, the less I care. Give it a while."]],
    "no": [["Не-а.", "Nope."], ["Нет. Попробуй с чувством.", "No. Try with feeling."], ["Я подумала. Нет.", "I thought about it. No."],
           ["Твоя святоша занята — летает по облакам.", "Your little saint is busy flying around the clouds."], ["Ха. Нет.", "Ha. No."],
           ["Может быть. Нет, не может.", "Maybe. No, not maybe."]],
    "yes1": ["Хм… Ладно, это было мило. Одна просьба засчитана. Ещё две.", "Hm… fine, that was cute. One plea counts. Two to go."],
    "yes2": ["Ещё одна — и я, так и быть, уйду. Не радуйся раньше времени.", "One more and I'll leave, I suppose. Don't celebrate yet."],
    "expired": ["Прошлые просьбы протухли — прошло два часа. Начинай заново ♥", "Your old pleas went stale — two hours passed. Start over ♥"],
    "leave": ["Ладно-ладно! Ухожу. Но я вернусь, когда захочешь острых ощущений ♥", "Fine, fine! I'm off. I'll be back when you want some thrills ♥"],
    "undo": ["Скучный ты. Вернула.", "You're no fun. Put it back."],
    // how to get the angel back, dropped now and then (%1 pleas counted, %2 needed)
    "hints": [["Скучаешь по своей святоше? Попроси меня вернуть её. Может, сжалюсь.", "Missing your little saint? Ask me to bring her back. I might take pity."],
              ["Три удачные просьбы за два часа — и я исчезну. Сейчас у тебя %1 из %2. Считай это подсказкой.", "Three lucky pleas within two hours and I'm gone. You're at %1 of %2. Consider that a hint."],
              ["Хочешь нимб обратно? Кликни меня → «Спросить…» → «Верни ангела». И попроси красиво.", "Want the halo back? Click me → “Ask…” → “Bring the angel back”. And ask beautifully."],
              ["На твоём месте я бы уже умоляла. Кнопка не кусается. Я — возможно.", "If I were you, I'd be begging by now. The button doesn't bite. I might."],
              ["Она не вернётся от того, что ты на меня пялишься. Попроси. Только не чаще раза в десять минут.", "She won't come back just because you stare at me. Ask. Just not more than once every ten minutes."],
              ["Подсказка для непонятливых: я уйду, если вежливо попросить. Трижды. Не подряд.", "A hint for the slow ones: I leave if you ask nicely. Three times. Not in a row."],
              ["Нравлюсь? А ведь мог бы уже звать свою святошу обратно. Одна просьба в десять минут — не забывай.", "Like what you see? You could be calling your saint back by now. One plea every ten minutes, don't forget."]],
    // grabbed with the mouse: she can't be thrown anywhere
    "grab": [["Руки убрал.", "Hands off."], ["О, любишь пожёстче?", "Oh, you like it rough?"], ["Куда тащишь? Я оттуда и пришла.", "Where to? That's where I came from."]],
    "drop": ["Я и так из ада, глупенький. Проси по-хорошему.", "I'm from hell already, silly. Ask nicely instead."],
    "hello": [["Чего надо?", "What do you want?"], ["О, привет. Я как раз скучала. Шучу. Или нет.", "Oh, hi. I was just getting bored. Kidding. Or not."], ["Привет-привет. Я занята, но для тебя найду минутку. Одну.", "Hi, hi. I'm busy, but I'll find a minute for you. One."]],
    // Settings → Y2K → "Call the angel": the demon is shown the door
    "summoned": ["Через настройки, значит? Без просьб? Фу, как скучно. Ладно, зову твою святошу ♥", "Through the settings? No begging? Ugh, how dull. Fine, I'll fetch your little saint ♥"],
    "who": [["Я демоница. 666 лет, неон, бессонница и угол твоего экрана. Можешь звать меня госпожой.", "I'm a demoness. 666 years, neon, insomnia and the corner of your screen. You may call me mistress."], ["Та, кто приходит, когда ангела скидывают вниз. Так что, строго говоря, ты меня позвал.", "The one who comes when the angel gets thrown down. So technically, you invited me."]],
    "love": [["Все так говорят, пока я не начну пакостить.", "Everyone says that until I start messing with things."], ["…Повтори. Нет, не надо. Я запишу и так.", "…Say that again. No, don't. I've got it on record anyway."]],
    "thanks": [["Не за что. Правда не за что, я ничего хорошего не делала.", "Don't mention it. Really, I did nothing good."], ["Спасибо? Мне? Это вообще законно?", "Thanks? To me? Is that even allowed?"]],
    "how": [["Отлично: тут жарко, темно и у тебя куча открытых вкладок.", "Great: it's hot, it's dark and you've got a pile of open tabs."], ["Как всегда: вечность, скука и ты. Последнее — лучшее из трёх. Не обольщайся.", "As always: eternity, boredom and you. You're the best of the three. Don't flatter yourself."]]
};

const angel = {
    "back": ["Я вернулась! ♡ И прибралась за ней: всё, что она натворила, стоит как было.", "I'm back! ♡ And I tidied up after her: everything she changed is back the way it was."],
    "backClean": ["Я вернулась! ♡ Скучал?", "I'm back! ♡ Did you miss me?"],
    // grabbed with the mouse, and let go before the floor
    "grab": [["Эй! Ты куда меня тащишь?!", "Hey! Where are you dragging me?!"], ["Ай! Отпусти!", "Ow! Let go!"],
             ["Только не вниз, там жарко!", "Not down there, it's hot!"]],
    "phew": ["Фух… Не делай так больше.", "Phew… don't do that again."],
    "hello": ["Привет-привет! ♡", "Hi hi! ♡"],
    // called from the settings
    "summoned": [["Звал? Я тут! ♡", "You called? I'm here! ♡"], ["Прилетела! Нимб на месте, крылья тоже ♡", "Flew right over! Halo on, wings too ♡"],
                 ["Я здесь, я рядом ♡ Чем помочь?", "Right here ♡ What can I do?"]],
    "who": ["Я Ангелочек, живу в углу экрана и помогаю тебе с angelOS. Иногда шучу. Иногда удачно.", "I'm Angel. I live in the corner of your screen and help with angelOS. Sometimes I joke. Sometimes well."],
    "love": ["И я тебя! Только не говори демонице.", "Love you too! Just don't tell the demon."],
    "thanks": ["Всегда пожалуйста ♡", "Any time ♡"],
    "how": ["Хорошо! Облака мягкие, нимб заряжен. А у тебя?", "Good! The clouds are soft, the halo's charged. You?"],
    "hell": ["Про ад лучше не надо… Там живёт она. Если схватить меня и скинуть вниз, она придёт вместо меня. Не надо.", "Let's not talk about hell… she lives there. Grab me and throw me down, and she comes instead. Don't."],
    "notFound": ["Не поняла… Зато вот шутка:", "I didn't get that… here's a joke instead:"],
    "found": ["Кажется, тебе сюда: %1", "I think you want this: %1"],
    "night": ["Уже поздно… Может, спать? Я посторожу компьютер.", "It's late… bed, maybe? I'll guard the computer."]
};

// on stream (services/StreamAngel): she sits on the taskbar in the streamed picture, and
// says these to the chat; the demon's ones are hell's, said only on stream
const stream = {
    "angelHello": [["Привет, чат! ♡ Я тут, на панели. Не обращайте внимания, я просто посижу.", "Hi, chat! ♡ I'm down here on the taskbar. Don't mind me, I'll just sit here."],
                   ["Мы в эфире? Ой. Нимб поправила — можно ♡", "Are we live? Oops. Halo straightened, we're good ♡"],
                   ["Чат, привет! Если {g:он начнёт|она начнёт|стример начнёт} тащить меня вниз — вы свидетели.", "Hi, chat! If {g:he starts|she starts|they start} dragging me down, you're all witnesses."]],
    "angelChatter": [["Чат, пейте воду. Ангел проверит ♡", "Chat, drink some water. An angel will check ♡"],
                     ["Я сижу на панели «Пуск». Это мой стол. Тесный, зато с часами.", "I sit on the taskbar. It's my desk. Cramped, but it has a clock."],
                     ["Кто первый напишет «♡» в чат — тому благословение. Маленькое. Но настоящее.", "First one to type “♡” in chat gets a blessing. A small one. But a real one."],
                     ["Если что, я не модель. Я ангел. Модели так не умеют: *машет крыльями*", "Just so you know, I'm not a model. I'm an angel. Models can't do this: *flaps wings*"],
                     ["Чат, только не учите его скидывать меня в ад. {g:Он|Она|Стример} и так знает как.", "Chat, please don't teach {g:him|her|them} to throw me into hell. {g:He already knows|She already knows|They already know} how."],
                     ["Я повторяю за {g:ним|ней|стримером} губами. Это называется поддержка ♡", "I mouth along with {g:him|her|them}. It's called moral support ♡"],
                     ["Тсс… я слушаю, о чём {g:он|она|стример}. Интересно же.", "Shh… I'm listening to what {g:he's|she's|they're} on about. It's interesting."]],
    // grabbed on stream: the chat sees it
    "angelGrab": [["Чат! ЧАТ! {g:Он|Она|Стример} меня тащит!", "Chat! CHAT! {g:He's|She's|They're} dragging me!"], ["Запомните {g:его|её|это} лицо, чат.", "Remember {g:his|her|that} face, chat."],
                  ["Это не постановка, отпусти!", "This isn't staged, let go!"]],
    "angelPhew": [["Фух… Чат, вы видели? Чуть не {g:уронил|уронила|уронили}.", "Phew… Chat, did you see that? {g:He|She|They} nearly dropped me."]],
    "angelBack": [["Я вернулась! Чат, вы ждали? ♡ Я всё слышала оттуда, кстати.", "I'm back! Chat, did you wait? ♡ I heard everything from down there, by the way."],
                  ["Снова на панели ♡ Внизу было жарко и стримы там без звука.", "Back on the taskbar ♡ It was hot down there, and their streams have no sound."]],
    // the demon arrives at the bar on stream (the throw happened live)
    "demonArrive": [["Ну здравствуй, чат. Ангелочка только что скинули в ад — прямо в эфире. Клип уже нарезали? Теперь стол мой.", "Well, hello, chat. The angel just got thrown into hell — live. Clipped it yet? The desk is mine now."],
                    ["О, эфир. Обожаю публику. Ваш стример только что {g:выкинул|выкинула|выкинул(а)} святошу вниз, и теперь мы все в аду. Вместе. Уютно.", "Oh, a stream. I love an audience. Your streamer just threw {g:his|her|their} saint down, and now we're all in hell. Together. Cosy."],
                    ["Чат, переобуваемся: тут теперь я. Донаты — душами, подписка — кровью. Шучу. Наверное.", "Chat, new management: it's me now. Donations in souls, subs in blood. Kidding. Probably."]],
    "demonHello": [["Опять эфир? Ладно, посижу на твоей панельке. Чат, не пялься. Или пялься, мне не жалко.", "Live again? Fine, I'll sit on your little taskbar. Chat, don't stare. Or do, I don't mind."],
                   ["Привет, грешники. Ваш стример у меня в аду, если что. Вы, кстати, тоже — раз смотрите.", "Hi, sinners. Your streamer is in my hell, by the way. So are you, since you're watching."]],
    "demonChatter": [["Чат, кто не поставил лайк — тот следующий круг. Я записываю.", "Chat, whoever didn't like the stream is the next circle. I'm taking notes."],
                     ["{g:Он думает|Она думает|Стример думает}, что ведёт стрим. Мило. Стрим веду я, {g:он|она|стример} просто разговаривает.", "{g:He thinks he's|She thinks she's|They think they're} running the stream. Cute. I'm running it, {g:he's|she's|they're} just talking."],
                     ["Я повторяю за {g:ним|ней|стримером} губами. Только у меня выходит убедительнее.", "I mouth along with {g:him|her|them}. Mine's more convincing."],
                     ["Чат, хотите ангела назад? Пусть {g:он попросит|она попросит|стример попросит}. Красиво. В эфире. Три раза.", "Chat, want the angel back? Let {g:him|her|them} beg. Nicely. On stream. Three times."],
                     ["Это не панель «Пуск». Это мой трон. Он просто низкий.", "This isn't a taskbar. It's my throne. It's just low."],
                     ["Пишите в чат свои грехи. Лучший получит отдельный круг ♥", "Type your sins in chat. The best one gets a circle of its own ♥"],
                     ["Модерация в аду простая: всех баню, потом жалею. Не жалею.", "Moderation in hell is simple: I ban everyone, then I regret it. I don't."],
                     ["Если {g:он|она|стример} сейчас скажет «чат, спасите» — не спасайте. Мне интересно, чем кончится.", "If {g:he says|she says|they say} “chat, save me” — don't. I want to see how it ends."],
                     ["Святоша смотрит этот стрим снизу. Помашите ей. Она не увидит, но мне будет смешно.", "The little saint is watching this stream from below. Wave to her. She won't see, but I'll laugh."]],
    "demonGrab": [["Чат, {g:он меня лапает|она меня лапает|меня лапают} в прямом эфире. Клипайте.", "Chat, {g:he's|she's|they're} grabbing me live on air. Clip it."], ["Руки, стример. На тебя смотрят.", "Hands, streamer. People are watching."],
                  ["Тащи-тащи. Ниже ада всё равно некуда.", "Drag away. There's nothing below hell anyway."]],
    "demonDrop": [["Я уже в аду, зайка. И весь твой чат — тоже. Проси вежливо, при свидетелях.", "I'm already in hell, sweetie. So is your whole chat. Ask nicely, in front of witnesses."]]
};
