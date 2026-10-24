.pragma library

// What the figure of the P5 settings window says, in a plate at the bottom (P5View's speech): the
// angel in the light theme, the sisters of the circles in the dark one (a section each). Their
// voices are the phone's (her brackets and ^_^, Sola's «later», Vera's doubt, Lisa's «darling»,
// Lucky's coins), but no story: the lore stays the phone's (the owner, 23.10). Every text is [ru, en].
//   react    by event: poke (clicked), drag (carried off), drop (let go), flap (a value
//            changed), back (opened again), idle (a long quiet)
//   first    the first visit of a section (Achievements' kinds remember it while the game is on)
//   all      every section seen: the reward line
//   seen     the angel remembering a sister she saw in the dark ({name}), a couple of times

const angel = {
    "react": {
        "poke": [
            ["Ай! Это не кнопка))", "Ow! I'm not a button))"],
            ["Щекотно же!", "That tickles!"],
            ["Я тут для красоты, а не для тыканья ^_^", "I'm here to look pretty, not to be poked ^_^"],
            ["Ещё раз — и я обижусь. Ну, на секундочку))", "Once more and I'll sulk. For a second))"],
            ["Ты проверяешь, настоящая ли я? Ну и как?", "Checking if I'm real? Well?"]
        ],
        "drag": [
            ["Куда ты меня несёшь?!", "Where are you taking me?!"],
            ["Эй! Я сама умею летать!", "Hey! I can fly on my own!"],
            ["Ой-ой-ой, у меня крылья помнутся))", "Oh no, you'll crease my wings))"]
        ],
        "drop": [
            ["Фух. Обратно на место))", "Phew. Back where I belong))"],
            ["Спасибо, что вернул. Тут уютно ^_^", "Thanks for putting me back. It's cosy here ^_^"]
        ],
        "flap": [
            ["О, так лучше!", "Oh, that's better!"],
            ["Записала))", "Noted))"],
            ["Мне нравится, как ты всё настраиваешь ^_^", "I like how you set things up ^_^"]
        ],
        "back": [
            ["Снова ты! Я скучала))", "You again! I missed you))"],
            ["Что будем менять сегодня?", "What are we changing today?"]
        ],
        "idle": [
            ["Ты тут? Я никуда не тороплюсь))", "Still there? I'm in no hurry))"],
            ["Можно я пока посижу на карточке?", "Can I sit on the card meanwhile?"]
        ]
    },
    "first": {
        "main": ["Это главная. Отсюда всё видно ^_^", "This is the main page. You can see everything from here ^_^"],
        "system": ["Тут экран, звук и всё такое. Только громкость сразу не выкручивай))", "Screen, sound, all that. Don't crank the volume right away))"],
        "devices": ["Мышки, клавиатуры, геймпады… У тебя их правда столько?", "Mice, keyboards, gamepads… You really have that many?"],
        "network": ["Сеть! Модем пищать не будет, обещаю))", "The network! No modem screeching, I promise))"],
        "personal": ["Мой любимый раздел! Тут можно сделать красиво ^_^", "My favourite section! You can make it pretty here ^_^"],
        "windows": ["Окна и столы. Я люблю, когда всё по полочкам))", "Windows and desks. I like everything in its place))"],
        "apps": ["Программы. Их тут много, я не все знаю по именам", "Programs. There are lots, I don't know all their names"],
        "stream": ["Стрим? Мне надо причесаться!", "A stream? I need to do my hair!"],
        "a11y": ["Чтобы всем было удобно. Это важно", "So it's comfy for everyone. That matters"],
        "game": ["А это про меня! Только не читай всё сразу))", "This one's about me! Don't read it all at once))"],
        "angelos": ["Тут про саму систему. Скучно, но нужно ^_^", "About the system itself. Boring, but needed ^_^"]
    },
    "all": [["Ты заглянул везде! Даже я так не умею))", "You looked everywhere! Even I can't do that))"]],
    "seen": [
        ["Я видела, кто тут сидел, пока было темно. {name}. Брр. Не говори ей, что я так сказала", "I saw who sat here while it was dark. {name}. Brr. Don't tell her I said that"],
        ["Опять пахнет серой… Это {name} тут была? Я проветрю))", "Smells of sulphur again… Was {name} here? I'll air the place))"],
        ["{name} трогала мои настройки? Ну ладно. Я всё равно лучше рисую", "{name} touched my settings? Fine. I still draw better"]
    ]
};

const names = {
    "limbo": ["Сола", "Sola"],
    "heresy": ["Вера", "Vera"],
    "fraud": ["Лиса", "Lisa"],
    "greed": ["Лаки", "Lucky"]
};

// the sisters, in their voices
const sisters = {
    "limbo": {
        "back": [["А, это ты. Я тут лежу. Можно дальше лежать?", "Oh, it's you. I'm lying here. Can I go on lying?"]],
        "idle": [["Хорошо сидим. Тихо. Ничего не меняем.", "Nice sitting here. Quiet. Changing nothing."], ["Можешь не торопиться. Я никуда не денусь.", "No hurry. I'm not going anywhere."]],
        "poke": [["Не надо. Давай потом.", "Don't. Later."], ["Тык. Ну и что теперь. Ничего.", "Poke. So what now. Nothing."]],
        "drag": [["Неси куда хочешь. Мне всё равно где сидеть.", "Carry me wherever. I don't mind where I sit."]],
        "drop": [["Тут тоже серо. Хорошо.", "It's grey here too. Good."]],
        "flap": [["Поменял? Завтра можно было.", "Changed it? Could've waited till tomorrow."]]
    },
    "heresy": {
        "back": [["Вернулся. Проверим, что ты поменял в прошлый раз.", "Back. Let's check what you changed last time."]],
        "idle": [["Ты точно знаешь, что делает эта настройка? Я — проверю.", "Sure you know what that setting does? I'll check."]],
        "poke": [["Проверяешь, есть ли я? Правильно.", "Checking if I exist? Right."], ["Я тебе не верю. Ещё раз.", "I don't believe you. Again."]],
        "drag": [["Куда? Обоснуй.", "Where to? Explain."]],
        "drop": [["Поставил. Проверю, ровно ли.", "Put me down. I'll check it's straight."]],
        "flap": [["Уверен в этой настройке? Я — нет.", "Sure of that setting? I'm not."]]
    },
    "fraud": {
        "back": [["Золотце, снова ты. Я ничего не трогала. Честно.", "Darling, you again. I didn't touch a thing. Honest."]],
        "idle": [["Нажми что-нибудь. Я подскажу. Может, даже правильно.", "Press something. I'll help. Maybe even right."]],
        "poke": [["Золотце, за это берут деньги. Шучу. Наверное.", "Darling, people pay for that. Kidding. Probably."], ["Ты нажал меня, а настройка поменялась. Шучу. Или нет?", "You poked me and a setting changed. Kidding. Or not?"]],
        "drag": [["Уносишь меня? Как мило. Я тоже кое-что унесу.", "Carrying me off? Sweet. I'll carry something off too."]],
        "drop": [["Вернул на место. Всё на месте? Проверь карманы.", "Back in place. Is everything? Check your pockets."]],
        "flap": [["Хороший выбор. Я бы подсказала другой. Но этот тоже.", "Good choice. I'd have suggested another. This one'll do."]]
    },
    "greed": {
        "back": [["О, клиент вернулся. Сегодня скидок нет.", "Oh, a customer's back. No discounts today."]],
        "idle": [["Тишина тоже чего-то стоит. Записала.", "Silence costs too. On your tab."]],
        "poke": [["Тык стоит монетку. Записала на твой счёт.", "A poke costs a coin. On your tab."], ["Моё. Не трогай. Ладно, трогай, но плати.", "Mine. Don't touch. Fine, touch, but pay."]],
        "drag": [["Меня украли! Ничего, я дорого стою.", "I'm being stolen! Fine, I'm worth a lot."]],
        "drop": [["Положи, где взял. Я всё помню.", "Put me back where you found me. I remember everything."]],
        "flap": [["Сохранила твою настройку. Себе. На всякий случай.", "Saved your setting. For myself. Just in case."]]
    }
};

function lang(t, en) {
    return t ? (en ? t[1] : t[0]) : "";
}
function pick(list) {
    return list && list.length ? list[Math.floor(Math.random() * list.length)] : null;
}
function name(who, en) {
    return lang(names[who], en);
}
// a reaction of `who` to `event` ("" when she has none)
function react(who, event, en) {
    if (who === "angel")
        return lang(pick(angel.react[event]), en);
    const s = sisters[who];
    return s && s[event] ? lang(pick(s[event]), en) : "";
}
// the sisters' first words in the sections they sit in (P5Doll.seats)
const firstDark = {
    "main": ["Привет, золотце. Я тут встречаю. Вместо неё. Улыбайся.", "Hello, darling. I do the greeting here. Instead of her. Smile."],
    "system": ["Система. Ничему тут не верь, пока не проверишь. Мне — тоже.", "The system. Trust nothing here till you've checked. Me neither."],
    "devices": ["Мышки, клавиатуры… Всё моё. Ладно, твоё. Пока.", "Mice, keyboards… All mine. Fine, yours. For now."],
    "network": ["Сеть — мой дом. Тут столько всего можно перехватить. Шучу.", "The network's my home. So much to intercept. Kidding."],
    "personal": ["Красоту наводим? Я в этом лучшая. Фальшивую — тоже.", "Making it pretty? I'm the best at it. The fake kind too."],
    "windows": ["Окна… Можно их все закрыть и ничего не делать. Предлагаю.", "Windows… We could close them all and do nothing. Just saying."],
    "apps": ["Программы! Сколько их у тебя. Поделишься одной?", "Programs! You have so many. Share one?"],
    "stream": ["Эфир! Улыбнись в камеру, золотце. Я подержу текст.", "On air! Smile for the camera, darling. I'll hold the script."],
    "a11y": ["Чтобы было удобно. Удобно — это когда лежишь. Я за.", "So it's comfy. Comfy is lying down. I'm for it."],
    "game": ["Её раздел. Её тут нет. Проверю, всё ли тут правда.", "Her section. She isn't here. I'll check it's all true."],
    "angelos": ["Версии, обновления… Ты веришь, что новая лучше? Проверим.", "Versions, updates… You believe the new one's better? We'll see."]
};
function first(who, section, en) {
    return lang(who === "angel" ? angel.first[section] : firstDark[section], en);
}
function all(en) {
    return lang(pick(angel.all), en);
}
function seen(who, en) {
    return lang(pick(angel.seen), en).replace("{name}", name(who, en));
}
