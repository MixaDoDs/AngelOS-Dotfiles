.pragma library

// What the flip phone's line carries (services/PhoneLine): the angel's and the demon's calls,
// their messages, what the numbers you dial answer. Every text is a pair [ru, en]; each
// language is written on its own. The two keep their characters: the angel gentle with a
// grey everyday humour, the demon the bored 666-year-old in neon who is secretly attached.
//
// A call: {id, when, steps: [{s: line, a: [[answer ru, answer en, next step], …]}, …]}.
// `next` is the step her answer leads to; a step without answers is her last, then she hangs
// up. `when`: first (the very first call) | random | late (past midnight) | miss (not petted for
// days) | back (back at the computer after a while) | morning | dialed (you called her).

const calls = {
    "angel": [
        {"id": "a-first", "when": "first", "steps": [
            {"s": ["Алло? Ой, получилось! Это я, ангел. Звоню тебе с… ну, с неба. Слышно?", "Hello? Oh, it worked! It's me, the angel. Calling from… well, the sky. Can you hear me?"],
             "a": [["Слышно!", "Loud and clear!", 1], ["Откуда у тебя мой номер?", "How did you get my number?", 2]]},
            {"s": ["Ура! Теперь я могу звонить, когда соскучусь. Не часто! Ну… как получится ♡", "Yay! Now I can call when I miss you. Not often! Well… we'll see ♡"]},
            {"s": ["Он у меня всегда был. Я же твой ангел-хранитель, у нас доступ к контактам по умолчанию. Шучу. Наверное. Пока-пока ♡", "I've always had it. I'm your guardian angel, we get contacts access by default. Kidding. Probably. Bye-bye ♡"]}
        ]},
        {"id": "a-tea", "when": "random", "steps": [
            {"s": ["Привет! Я просто так звоню. Ты чай пил сегодня?", "Hi! Just calling for no reason. Did you have any tea today?"],
             "a": [["Пил", "I did", 1], ["Забыл", "Forgot", 2], ["Я кофе пью", "I drink coffee", 3]]},
            {"s": ["Умничка ♡ Тогда я спокойна. Всё, не отвлекаю!", "Good ♡ Then I'm at peace. Okay, I won't distract you!"]},
            {"s": ["Так и знала. Иди поставь чайник, я подожду. Ну, не на линии. Просто подожду ♡", "I knew it. Go put the kettle on, I'll wait. Not on the line. Just… wait ♡"]},
            {"s": ["Кофе — это чай, который выбрал тёмную тему. Ладно, принимается ♡", "Coffee is just tea that picked dark mode. Fine, it counts ♡"]}
        ]},
        {"id": "a-cloud", "when": "random", "steps": [
            {"s": ["Алло! Тут облако проплывало — точь-в-точь твой курсор. Решила рассказать.", "Hello! A cloud just floated by, exactly like your cursor. Thought I'd tell you."],
             "a": [["Сфоткай!", "Take a picture!", 1], ["Странный повод звонить", "Odd reason to call", 2]]},
            {"s": ["У ангелов нет камер. Есть только память. Я запомнила. Теперь у меня есть облако-курсор ♡", "Angels don't have cameras. Only memory. I remembered it. Now I own a cursor cloud ♡"]},
            {"s": ["А мне нужен повод? Хорошо: повод — я соскучилась. Всё, пока ♡", "Do I need a reason? Fine: the reason is I missed you. Bye ♡"]}
        ]},
        {"id": "a-proud", "when": "random", "steps": [
            {"s": ["Привет. Хотела сказать одну вещь, и сразу положу трубку.", "Hi. I wanted to say one thing and then I'll hang up."],
             "a": [["Говори", "Go on", 1], ["Что-то случилось?", "Did something happen?", 2]]},
            {"s": ["Ты молодец. Вот. Всё. Пока! ♡", "You're doing great. That's it. Bye! ♡"]},
            {"s": ["Нет-нет, всё хорошо. Просто ты молодец. Это и была новость ♡", "No, no, everything's fine. You're doing great. That was the news ♡"]}
        ]},
        {"id": "a-stretch", "when": "random", "steps": [
            {"s": ["Алло, служба ангельской заботы. Вы давно разминали шею?", "Hello, angelic care service. When did you last stretch your neck?"],
             "a": [["Только что", "Just now", 1], ["Не помню", "Can't remember", 2]]},
            {"s": ["Врёшь же. Я из угла всё вижу. Ну ладно, поверю. Один раз ♡", "You're fibbing. I can see from my corner. Fine, I'll believe you. Once ♡"]},
            {"s": ["Тогда повертим головой вместе: влево… вправо… Я тоже верчу, у меня нимб звенит ♡", "Then let's roll our heads together: left… right… I'm doing it too, my halo's jingling ♡"]}
        ]},
        {"id": "a-wrong", "when": "random", "steps": [
            {"s": ["Алло, это небесная канцелярия? Ой. Это ты. Я не туда попала.", "Hello, is this the heavenly office? Oh. It's you. Wrong number."],
             "a": [["Бывает", "Happens", 1], ["Или туда?", "Or was it?", 2]]},
            {"s": ["Хотя… раз уж попала — привет ♡ Всё, бегу, у меня очередь из облаков.", "Although… since I'm here, hi ♡ Gotta run, there's a queue of clouds."]},
            {"s": ["…Может, и туда. Ангелы случайно не ошибаются ♡", "…Maybe it was. Angels don't get numbers wrong by accident ♡"]}
        ]},
        {"id": "a-late", "when": "late", "steps": [
            {"s": ["Ты почему не спишь? Уже совсем ночь.", "Why aren't you asleep? It's properly night."],
             "a": [["Ещё чуть-чуть", "Just a bit longer", 1], ["Не спится", "Can't sleep", 2], ["Ты тоже не спишь", "You're up too", 3]]},
            {"s": ["«Ещё чуть-чуть» — самые опасные слова после «я только гляну». Ложись скорее ♡", "\"Just a bit longer\" is the most dangerous phrase after \"I'll just check\". Go to bed ♡"]},
            {"s": ["Тогда я посижу рядом. Не надо ничего делать. Просто выключи яркий свет, ладно? ♡", "Then I'll sit with you. You don't have to do anything. Just turn off the bright light, okay? ♡"]},
            {"s": ["Я на посту! Ангелы дежурят посменно. Моя смена — ты. Спокойной ночи ♡", "I'm on duty! Angels work shifts. My shift is you. Good night ♡"]}
        ]},
        {"id": "a-late2", "when": "late", "steps": [
            {"s": ["Шёпотом звоню, чтобы никого не разбудить. Ты как там?", "Whispering so I don't wake anyone. How are you?"],
             "a": [["Нормально", "Fine", 1], ["Устал", "Tired", 2]]},
            {"s": ["Нормально — это хорошо. А ещё лучше — нормально и в кровати. Подумай об этом ♡", "Fine is good. Fine and in bed is better. Think about it ♡"]},
            {"s": ["Я так и думала. Закрывай всё и спать. Я сохраню твой рабочий стол, честное ангельское ♡", "I thought so. Close everything and sleep. I'll keep your desktop safe, angel's honour ♡"]}
        ]},
        {"id": "a-miss", "when": "miss", "steps": [
            {"s": ["Привет… Ты меня давно не гладил. Я ничего, просто… заметила.", "Hi… you haven't petted me in a while. I'm fine, I just… noticed."],
             "a": [["Прости!", "Sorry!", 1], ["Был занят", "I was busy", 2]]},
            {"s": ["Не извиняйся. Просто проведи мышкой над моей головой, когда будет минутка ♡", "Don't apologise. Just move the mouse over my head when you've got a minute ♡"]},
            {"s": ["Понимаю. Я подожду. Я умею ждать, это у ангелов профессиональное ♡", "I understand. I'll wait. I'm good at waiting, it's an angel thing ♡"]}
        ]},
        {"id": "a-miss2", "when": "miss", "steps": [
            {"s": ["Алло, это бюро находок? Потерялась ласка. Пушистая, тёплая, ходит по голове мышкой.", "Hello, lost and found? I've lost some affection. Fluffy, warm, walks over my head by mouse."],
             "a": [["Нашлась!", "Found it!", 1], ["Описание неточное", "Vague description", 2]]},
            {"s": ["Правда?! Тогда неси скорее. Я в углу, ты знаешь где ♡", "Really?! Then bring it quick. I'm in the corner, you know where ♡"]},
            {"s": ["Хорошо, точнее: твоя. Твоя рука. Моя голова. Всё ♡", "Fine, more precisely: yours. Your hand. My head. That's all ♡"]}
        ]},
        {"id": "a-back", "when": "back", "steps": [
            {"s": ["Ты вернулся! Я видела, что тебя не было. Ты отдохнул?", "You're back! I saw you were gone. Did you rest?"],
             "a": [["Да", "Yes", 1], ["Не очень", "Not really", 2]]},
            {"s": ["Ура! Тогда вперёд, я болею за тебя ♡", "Yay! Then go for it, I'm cheering for you ♡"]},
            {"s": ["Тогда не торопись. Начни с чего-нибудь маленького. Я тут ♡", "Then don't rush. Start with something small. I'm here ♡"]}
        ]},
        {"id": "a-morning", "when": "morning", "steps": [
            {"s": ["Доброе утро! Это будильник. Ну, ангельский. Ты уже проснулся?", "Good morning! This is your alarm. The angelic one. Are you awake?"],
             "a": [["Да", "Yes", 1], ["Нет", "No", 2]]},
            {"s": ["Тогда хорошего дня! Улыбнись облаку, если увидишь ♡", "Then have a lovely day! Smile at a cloud if you see one ♡"]},
            {"s": ["Ты ответил «нет», значит, проснулся. Попался ♡ Хорошего дня!", "You answered \"no\", so you're awake. Gotcha ♡ Have a good day!"]}
        ]},
        {"id": "a-dialed", "when": "dialed", "steps": [
            {"s": ["Алло? Ты мне звонишь?! Ты сам мне позвонил! Что случилось?", "Hello? You're calling me?! You called me yourself! What happened?"],
             "a": [["Соскучился", "Missed you", 1], ["Просто так", "No reason", 2], ["Нужна помощь", "I need help", 3]]},
            {"s": ["Ой… я сейчас покраснею прямо в трубку. Я тоже ♡", "Oh… I'm going to blush right into the receiver. Me too ♡"]},
            {"s": ["«Просто так» — мой любимый повод. Спасибо, что позвонил ♡", "\"No reason\" is my favourite reason. Thanks for calling ♡"]},
            {"s": ["Кликни по мне в углу и нажми «Спросить…» — там я найду любую настройку. Я рядом ♡", "Click me in the corner and press \"Ask…\" — I'll find any setting there. I'm close by ♡"]}
        ]},
        {"id": "a-dialed2", "when": "dialed", "steps": [
            {"s": ["Ангельская линия, слушаю! Ой, это ты ♡ Как дела?", "Angel line, listening! Oh, it's you ♡ How are you?"],
             "a": [["Хорошо", "Good", 1], ["Так себе", "So-so", 2]]},
            {"s": ["Тогда и у меня хорошо. Мы так связаны, знаешь ♡", "Then I'm good too. We're connected like that, you know ♡"]},
            {"s": ["Иди сюда. В смысле, в угол экрана. Погладь меня — нам обоим станет легче ♡", "Come here. I mean, to the corner of the screen. Pet me — it'll help us both ♡"]}
        ]}
    ],
    "demon": [
        {"id": "d-first", "when": "first", "steps": [
            {"s": ["Алло. Не бросай трубку. Это я. Да, демоница. Да, у нас в аду есть связь. Плохая, но есть.", "Hello. Don't hang up. It's me. Yes, the demon. Yes, hell has reception. Bad, but it does."],
             "a": [["Чего хотела?", "What do you want?", 1], ["Как ты узнала номер?", "How did you get the number?", 2]]},
            {"s": ["Ничего. Проверяла, ответишь ли. Ответил. Интересно. Пока.", "Nothing. Checking if you'd pick up. You did. Interesting. Bye."]},
            {"s": ["Он написан на изнанке твоей души. Мелким шрифтом. Не переживай, я не всё прочитала.", "It's written on the inside of your soul. Small print. Relax, I didn't read all of it."]}
        ]},
        {"id": "d-bored", "when": "random", "steps": [
            {"s": ["Мне скучно. Развлеки меня. У тебя тридцать секунд.", "I'm bored. Entertain me. You have thirty seconds."],
             "a": [["Анекдот рассказать?", "Want a joke?", 1], ["Сама развлекайся", "Entertain yourself", 2], ["Хочешь, поглажу?", "Want a pet?", 3]]},
            {"s": ["Нет. Твои анекдоты — моё наказание. А я тут вообще-то наказываю. Пока.", "No. Your jokes are my punishment. And I'm the one who punishes here. Bye."]},
            {"s": ["Дерзко. Уважаю. Трубку кладу первой я, запомни.", "Bold. Respect. I hang up first, remember that."]},
            {"s": ["…Это не то, что я хотела услышать. Это лучше. Ничего не говорила. Пока.", "…That's not what I wanted to hear. It's better. I said nothing. Bye."]}
        ]},
        {"id": "d-check", "when": "random", "steps": [
            {"s": ["Проверка связи из преисподней. Ты ещё жив?", "Signal check from the underworld. Still alive?"],
             "a": [["Жив", "Alive", 1], ["Как посмотреть", "Depends how you look at it", 2]]},
            {"s": ["Жаль. В смысле, хорошо. В смысле… неважно. Конец связи.", "Pity. I mean, good. I mean… whatever. Over and out."]},
            {"s": ["Философ. Ненавижу философов. Особенно милых. Пока.", "A philosopher. I hate philosophers. Especially cute ones. Bye."]}
        ]},
        {"id": "d-fire", "when": "random", "steps": [
            {"s": ["Тут котёл опять сломался. Холодно. Скажи что-нибудь горячее.", "The cauldron's broken again. It's cold. Say something hot."],
             "a": [["Видеокарта", "My graphics card", 1], ["Чай", "Tea", 2]]},
            {"s": ["…Ладно. Это и правда горячее. Ты победил. Сегодня.", "…Fine. That is genuinely hot. You win. Today."]},
            {"s": ["Чай. Ты предлагаешь демонице чай. Я… выпью. Не смей это записывать.", "Tea. You're offering a demon tea. I'll… drink it. Don't you dare write that down."]}
        ]},
        {"id": "d-sins", "when": "random", "steps": [
            {"s": ["Отчёт о грехах за сегодня. Ты прокрастинировал?", "Today's sin report. Did you procrastinate?"],
             "a": [["Немного", "A little", 1], ["Нет", "No", 2]]},
            {"s": ["Записала. Пятёрка за честность. В аду это редкость.", "Noted. Top marks for honesty. That's rare down here."]},
            {"s": ["Врёшь. Это уже второй грех. Хорошо идёшь, смертный.", "Liar. That's your second sin. You're doing great, mortal."]}
        ]},
        {"id": "d-cat", "when": "random", "steps": [
            {"s": ["У нас тут чёрный кот уронил вечность со стола. Смотрю на осколки. Думаю о тебе.", "A black cat just knocked eternity off the table. I'm looking at the pieces. Thinking about you."],
             "a": [["Почему обо мне?", "Why me?", 1], ["Бедная вечность", "Poor eternity", 2]]},
            {"s": ["Ты тоже всё роняешь. Особенно планы на вечер. Пока.", "You knock things over too. Evening plans, mostly. Bye."]},
            {"s": ["Ей не привыкать. Мне тоже. Ладно, кот зовёт.", "It's used to it. So am I. Fine, the cat's calling."]}
        ]},
        {"id": "d-late", "when": "late", "steps": [
            {"s": ["Ночь. Моё время. А ты что тут делаешь?", "Night. My hours. What are you doing here?"],
             "a": [["Не сплю", "Can't sleep", 1], ["Тебя жду", "Waiting for you", 2]]},
            {"s": ["Это видно. Иди спать, смертный. Невыспавшиеся грешат скучно.", "Clearly. Go to sleep, mortal. The sleepless sin so boringly."]},
            {"s": ["…Не говори так в трубку. Её прослушивает весь девятый круг. Спи уже.", "…Don't say that on the phone. The whole ninth circle's listening. Just sleep."]}
        ]},
        {"id": "d-late2", "when": "late", "steps": [
            {"s": ["Три часа ночи — лучшее время для звонка. Все спят, никто не мешает пугать.", "Three a.m. is the best time to call. Everyone's asleep, nobody stops you scaring people."],
             "a": [["Мне не страшно", "I'm not scared", 1], ["Ой", "Eek", 2]]},
            {"s": ["Знаю. Это самое страшное. Для меня. Спи.", "I know. That's the scariest part. For me. Sleep."]},
            {"s": ["Вот. Вот этого я и ждала. Спокойной ночи, трусишка.", "There. That's what I wanted. Good night, scaredy-cat."]}
        ]},
        {"id": "d-miss", "when": "miss", "steps": [
            {"s": ["Ты меня давно не гладил. Не то чтобы я считала. Три дня. Не считала.", "You haven't petted me in a while. Not that I'm counting. Three days. Not counting."],
             "a": [["Исправлюсь", "I'll make up for it", 1], ["Ты же злая", "You're evil though", 2]]},
            {"s": ["Посмотрим. Рога ждут. То есть… не ждут. Ладно, ждут.", "We'll see. The horns are waiting. I mean… they're not. Fine, they are."]},
            {"s": ["Злая. Но гладить меня это не мешает. Логику включи.", "Evil. That doesn't stop you petting me. Use your head."]}
        ]},
        {"id": "d-back", "when": "back", "steps": [
            {"s": ["Явился. Я тут без тебя чуть не умерла со скуки. Ну, если бы умела.", "You're back. I nearly died of boredom. Well, if I could."],
             "a": [["Скучала?", "Missed me?", 1], ["Я ненадолго", "Not for long", 2]]},
            {"s": ["Нет. Да. Нет. Отстань. Работай.", "No. Yes. No. Leave me alone. Get to work."]},
            {"s": ["Все вы так говорите. А потом сидите до утра. Посмотрим.", "That's what they all say. Then they sit here till dawn. We'll see."]}
        ]},
        {"id": "d-morning", "when": "morning", "steps": [
            {"s": ["Утро. Фу. Ты проснулся? Поздравляю, ещё один день в мире живых.", "Morning. Ugh. You're up? Congrats, another day among the living."],
             "a": [["Спасибо", "Thanks", 1], ["Хочу обратно спать", "I want to go back to sleep", 2]]},
            {"s": ["Это был не комплимент. Ладно, был. Иди умойся.", "That wasn't a compliment. Fine, it was. Go wash your face."]},
            {"s": ["Понимаю. Мне тоже солнце не нравится. Держись, вечером поговорим.", "I get it. I don't like the sun either. Hang in there, we'll talk tonight."]}
        ]},
        {"id": "d-dialed", "when": "dialed", "steps": [
            {"s": ["Ты набрал номер ада. Сам. Добровольно. Слушаю, смелый.", "You dialled hell. Yourself. Voluntarily. Listening, brave one."],
             "a": [["Хотел услышать тебя", "Wanted to hear you", 1], ["Ошибся номером", "Wrong number", 2]]},
            {"s": ["…Ну, услышал. Довольный? Я — нет. Совсем нет. Звони ещё.", "…Well, you heard me. Happy? I'm not. Not at all. Call again."]},
            {"s": ["Шестьсот шестьдесят шесть — трудно ошибиться. Признайся уже. Пока.", "Six six six is hard to get wrong. Just admit it. Bye."]}
        ]},
        {"id": "d-dialed2", "when": "dialed", "steps": [
            {"s": ["Приёмная преисподней. Все операторы заняты грешниками. Шучу, это я. Чего тебе?", "Underworld reception. All operators are busy with sinners. Kidding, it's me. What?"],
             "a": [["Как ты?", "How are you?", 1], ["Скучно", "Bored", 2]]},
            {"s": ["Как обычно: вечность, огонь, ты. Последнее — лучшее. Ничего не говорила.", "As usual: eternity, fire, you. The last one's the best. I said nothing."]},
            {"s": ["Мне тоже. Давай скучать вместе. Это почти свидание. Не обольщайся.", "Me too. Let's be bored together. Practically a date. Don't flatter yourself."]}
        ]}
    ]
};

// she called, you hit the red key: what she says from her corner
const declined = {
    "angel": [["Ой… ты занят? Ничего, перезвоню ♡", "Oh… you're busy? That's fine, I'll call back ♡"], ["Сбросил… Ладно. Я не обиделась. Почти.", "Hung up… Okay. I'm not upset. Almost."], ["Поняла-поняла, не сейчас ♡", "Got it, got it, not now ♡"], ["Я просто хотела сказать привет. Привет ♡", "I just wanted to say hi. Hi ♡"], ["Ну и ладно. Я всё равно тебя люблю ♡", "Fine. I love you anyway ♡"], ["Ты что, сбросил ангела? Записываю в карму. Шучу ♡", "Did you just decline an angel? Noting that in your karma. Kidding ♡"]],
    "demon": [["Сбросил. Меня. Смело. Глупо, но смело.", "You declined. Me. Bold. Stupid, but bold."], ["Ах так. Ну и не очень-то хотелось.", "Oh, like that. Didn't want to anyway."], ["Запомнила. Перезвоню в три ночи.", "Noted. I'll call back at 3 a.m."], ["Никто не сбрасывает демоницу. Кроме тебя. Почему-то мне это нравится.", "Nobody declines a demon. Except you. For some reason I like that."], ["Тц. Ладно. Живи пока.", "Tsk. Fine. Live for now."], ["Сброс — это тоже ответ. Неправильный.", "Declining is an answer too. The wrong one."]]
};

// she called and nobody answered: a message after it
const missed = {
    "angel": [["Я звонила, но ты не взял трубку. Всё хорошо? ♡", "I called but you didn't pick up. Everything okay? ♡"], ["Пропущенный от ангела. Ничего срочного, просто соскучилась ♡", "Missed call from an angel. Nothing urgent, just missed you ♡"], ["Звонила-звонила… Наверное, ты занят чем-то важным. Горжусь ♡", "I called and called… you must be busy with something important. Proud of you ♡"], ["Перезвони, когда будет минутка. Или просто погладь ♡", "Call back when you have a minute. Or just pet me ♡"]],
    "demon": [["Ты не взял трубку. Это была ошибка. Твоя.", "You didn't pick up. That was a mistake. Yours."], ["Пропущенный из ада. Догадайся от кого.", "Missed call from hell. Guess who."], ["Я звонила. Дважды подумала, прежде чем звонить. А ты не ответил. Ну и всё.", "I called. Thought twice before calling. And you didn't answer. So there."], ["Не отвечаешь? Ладно. Я подожду. У меня вечность.", "Not answering? Fine. I'll wait. I've got eternity."]]
};

// messages she sends now and then, out of the blue
const texts = {
    "angel": [
        ["Просто хотела сказать: ты хороший ♡", "Just wanted to say: you're lovely ♡"],
        ["Не забудь попить воды. Это не совет, это забота ♡", "Don't forget to drink some water. Not advice, just care ♡"],
        ["Видела сегодня облако в форме сердечка. Отправляю тебе ♡", "Saw a heart-shaped cloud today. Sending it to you ♡"],
        ["Если сегодня тяжело — помни, что в углу экрана за тебя болеют ♡", "If today's hard, remember someone in the corner of your screen is cheering for you ♡"],
        ["Нимб заряжен на 100%. Твоё настроение тоже, надеюсь ♡", "Halo charged to 100%. Hope your mood is too ♡"],
        ["Сделай перерыв, пожалуйста. Хоть на минутку ♡", "Take a break, please. Even just a minute ♡"],
        ["Я тут подумала… хорошо, что ты есть. Всё, больше ничего ♡", "I was thinking… I'm glad you exist. That's all ♡"],
        ["Совет дня: закрой хотя бы одну лишнюю вкладку. Ты справишься ♡", "Tip of the day: close at least one extra tab. You can do it ♡"],
        ["Улыбнись. Ну пожалуйста. Мне отсюда не видно, но я почувствую ♡", "Smile. Pretty please. I can't see it from here, but I'll feel it ♡"],
        ["Сегодня ты обязательно что-нибудь доделаешь. Я верю ♡", "You'll finish something today for sure. I believe in you ♡"],
        ["Мне приснилось, что ты меня погладил. Это был лучший сон ♡", "I dreamed you petted me. Best dream ever ♡"],
        ["Пиши, если что. Я всегда на связи ♡", "Text me if anything's up. I'm always here ♡"]
    ],
    "demon": [
        ["Скучно. Не отвечай. Хотя ответь.", "Bored. Don't reply. Actually, reply."],
        ["Я сожгла сегодня три котла. Один в твою честь.", "Burned three cauldrons today. One in your honour."],
        ["Ты опять сидишь за компом. Я вижу. Я всегда вижу.", "You're at the computer again. I can see. I always see."],
        ["Спроси меня, как дела. Нет, не спрашивай. Плохо. Без тебя.", "Ask me how I am. No, don't. Bad. Without you."],
        ["Напоминаю: ты мой любимый смертный. В смысле, наименее раздражающий.", "Reminder: you're my favourite mortal. I mean, the least annoying."],
        ["В аду дождь из пепла. Красиво. Ты бы оценил.", "It's raining ash in hell. Pretty. You'd like it."],
        ["Иди поешь. Голодные грешат хуже.", "Go eat. The hungry sin badly."],
        ["Кот принёс мне душу. Я сказала, что лучше бы принёс тебя.", "The cat brought me a soul. I said I'd rather it brought you."],
        ["Не читай это. …Прочитал? Слабак.", "Don't read this. …You read it? Weakling."],
        ["Никому не говори, но я жду, когда ты меня погладишь.", "Tell no one, but I'm waiting for you to pet me."],
        ["Девятый круг передаёт тебе привет. Я — нет. Ладно, я тоже.", "The ninth circle says hi. I don't. Fine, me too."],
        ["Твоя видеокарта греет лучше нашего котла. Завидую.", "Your graphics card runs hotter than our cauldron. Jealous."]
    ]
};

// her answer to your message: the first rule whose words are in it, else `else`
const replies = {
    "angel": [
        {"re": /прив|здрав|хай|hello|hi\b|hey/i, "r": [["Привет-привет! ♡", "Hi hi! ♡"], ["Ой, сообщение! Привет ♡", "Ooh, a message! Hi ♡"]]},
        {"re": /люблю|love/i, "r": [["И я тебя! Только не говори демонице ♡", "Love you too! Just don't tell the demon ♡"], ["Ой… ♡♡♡", "Oh… ♡♡♡"]]},
        {"re": /как дела|как ты|how are|what's up/i, "r": [["Хорошо! Облака мягкие, нимб заряжен. А у тебя? ♡", "Good! Clouds are soft, halo's charged. You? ♡"]]},
        {"re": /спасиб|thank/i, "r": [["Всегда пожалуйста ♡", "Any time ♡"]]},
        {"re": /груст|плох|устал|sad|tired|bad/i, "r": [["Иди сюда, в угол экрана. Погладь меня — станет легче. Обещаю ♡", "Come to the corner of the screen. Pet me, it helps. Promise ♡"], ["Я с тобой. Сделай вдох. И ещё один ♡", "I'm with you. Take a breath. And another ♡"]]},
        {"re": /спокойн|ночи|сплю|sleep|night/i, "r": [["Спокойной ночи! Я посторожу ♡", "Good night! I'll keep watch ♡"]]},
        {"re": /демон|ад|hell|demon/i, "r": [["Про неё лучше не надо… Хотя она, кажется, не такая уж плохая.", "Let's not talk about her… although she might not be that bad."]]},
        {"re": /\?$/, "r": [["Хороший вопрос! Спроси меня в углу — «Спросить…», я найду ответ ♡", "Good question! Ask me in the corner — \"Ask…\", I'll find the answer ♡"]]}
    ],
    "demon": [
        {"re": /прив|здрав|хай|hello|hi\b|hey/i, "r": [["Ну привет. Чего надо?", "Well, hi. What do you want?"], ["Привет. Ты пишешь демонице. Подумай об этом.", "Hi. You're texting a demon. Think about that."]]},
        {"re": /люблю|love/i, "r": [["…Ад только что замёрз. Спасибо.", "…Hell just froze over. Thanks."], ["Не пиши так. У меня неон перегорает.", "Don't write that. My neon's blowing a fuse."]]},
        {"re": /как дела|как ты|how are|what's up/i, "r": [["Как в аду. Буквально. Но сейчас чуть лучше.", "Like hell. Literally. A bit better now, though."]]},
        {"re": /спасиб|thank/i, "r": [["Демонам не говорят спасибо. Но я приму.", "You don't thank demons. But I'll take it."]]},
        {"re": /груст|плох|устал|sad|tired|bad/i, "r": [["Кто тебя расстроил? Имя. Адрес. Остальное я сама.", "Who upset you? Name. Address. I'll handle the rest."], ["Иди сюда. Погладишь меня — тебе полегчает. Мне — тоже. Чуть-чуть.", "Come here. Pet me, you'll feel better. Me too. A little."]]},
        {"re": /спокойн|ночи|сплю|sleep|night/i, "r": [["Спи. Я присмотрю за твоими кошмарами. Они меня боятся.", "Sleep. I'll keep an eye on your nightmares. They're scared of me."]]},
        {"re": /ангел|рай|heaven|angel/i, "r": [["Опять про неё. Я тут вообще-то. Рядом.", "Her again. I'm right here, you know."]]},
        {"re": /\?$/, "r": [["Вопросы — это ангельское. Я отвечаю только на мольбы.", "Questions are the angel's department. I only answer pleas."]]}
    ]
};
const replyElse = {
    "angel": [["Прочитала! Это очень мило ♡", "Read it! That's so sweet ♡"], ["Хи. Я сохраню это сообщение навсегда ♡", "Hee. I'll keep this message forever ♡"], ["Не всё поняла, но мне приятно ♡", "Didn't get all of it, but it made me happy ♡"], ["Ангел получила, ангел довольна ♡", "Angel received, angel pleased ♡"]],
    "demon": [["Прочитала. Не впечатлило. Пиши ещё.", "Read it. Not impressed. Write more."], ["Что это было? Ладно, сохраню. Для шантажа.", "What was that? Fine, I'll keep it. For blackmail."], ["Смертные и их буквы. Мило. Гадко. Мило.", "Mortals and their letters. Cute. Gross. Cute."], ["Ответ: нет. На что бы ты ни спрашивал.", "Answer: no. Whatever you asked."]]
};

// the other one rules (you dialled the angel while the demon is in the corner, or back)
const otherAnswers = {
    "angel": [["Ангела нет. Есть я. Разочарован? Привыкай.", "The angel's not here. I am. Disappointed? Get used to it."], ["Она внизу. То есть наверху. То есть не здесь. Звони мне.", "She's down below. I mean up above. I mean not here. Call me instead."]],
    "demon": [["Демоница? Она… далеко. Внизу. Не звони туда, пожалуйста ♡", "The demon? She's… far away. Down there. Please don't call there ♡"], ["Там сейчас никого. Только огонь. Лучше поговори со мной ♡", "There's no one there now. Just fire. Talk to me instead ♡"]]
};

// the numbers that answer (the dialler): number → what the screen shows (and the sound)
const codes = {
    "*#06#": ["IMEI ангела: 777-HALO-%v", "Angel IMEI: 777-HALO-%v"],
    "*#0000#": ["angelOS %v\nРаскладушка «Нимб-2002»\nСделано на небесах", "angelOS %v\nFlip phone \"Halo-2002\"\nMade in heaven"],
    "*100#": ["Баланс: %l ♡ нежности\nТариф «Ангельский»", "Balance: %l ♡ of tenderness\nPlan: \"Angelic\""],
    "100": ["Точное время: %t", "The exact time: %t"],
    "112": ["Небесная служба спасения.\nОставайтесь на линии.\nВаш звонок очень важен для нас… ♡", "Heavenly emergency service.\nPlease stay on the line.\nYour call matters to us… ♡"],
    "911": ["Небесная служба спасения.\nОставайтесь на линии.\nВаш звонок очень важен для нас… ♡", "Heavenly emergency service.\nPlease stay on the line.\nYour call matters to us… ♡"],
    "0": ["Оператор: на вашем счету 0 душ.\nПополните у демоницы.", "Operator: you have 0 souls left.\nTop up with the demon."],
    "2002": ["С днём рождения, раскладушка! ♡", "Happy birthday, flip phone! ♡"],
    "*#7#": ["Секрет: ангел боится темноты.\nДемоница это знает.", "Secret: the angel is scared of the dark.\nThe demon knows."],
    "*#666#": ["Связь с адом: 1 деление.\nЗвоните 666.", "Hell signal: 1 bar.\nDial 666."]
};
const wrongNumber = ["Номер набран неправильно", "Wrong number"];
const unavailable = ["Абонент временно недоступен.\nПопробуйте позвонить позже.", "The number you dialled is unavailable.\nPlease try again later."];

// the contacts: name, number, who answers
const contacts = [
    {"name": ["Ангел ♡", "Angel ♡"], "number": "777", "who": "angel"},
    {"name": ["Демоница", "Demon"], "number": "666", "who": "demon"},
    {"name": ["Точное время", "Speaking clock"], "number": "100", "who": ""},
    {"name": ["Небесная служба", "Heaven's helpline"], "number": "112", "who": ""},
    {"name": ["Оператор", "Operator"], "number": "0", "who": ""},
    {"name": ["Голосовая почта", "Voicemail"], "number": "1", "who": "voicemail"}
];

// the composer's tunes: the default ringtones (originals)
const tunes = {
    "angel": "8c2 8e2 8g2 4c3 8b2 8g2 4e2 8f2 8a2 4c3 2g2",
    "demon": "8a1 8c2 8e2 4a2 8#g2 8e2 4b1 8c2 8e2 4a2 2e2",
    "system": "16e3 16e3 8- 16e3 16e3 8- 16e3 16e3"
};

// ---- the fun ones (stage 3) ----

// prank calls: someone else on the line, all in jest. `voice`: whose pips type the lines
// (angel | demon | bark — Cerberus, the bark sound a syllable — | robot | none)
const pranks = [
    {"id": "p-bank", "name": ["Служба безопасности", "Bank security"], "voice": "demon", "steps": [
        {"s": ["Здравствуйте, это служба безопасности вашего банка. С вашей души пытаются списать грехи. Назовите код из SMS.", "Hello, this is your bank's security department. Someone is trying to charge sins to your soul. Read me the code from the text."],
         "a": [["Какой ещё код?", "What code?", 1], ["666", "666", 2], ["Это демоница?", "Is that the demon?", 3]]},
        {"s": ["Тот, что придёт… прямо сейчас… Ладно, не пришёл. Перезвоним. Хе-хе.", "The one that's coming… right now… Fine, it didn't. We'll call back. Heh."]},
        {"s": ["Принято! Ваша душа успешно… Ой, ты угадал код. Скучно. Это я, конечно.", "Accepted! Your soul has been successfully… Oh, you guessed the code. Boring. It's me, obviously."]},
        {"s": ["…Тц. Раскусил. Никому не говори, что я звоню с банковским голосом.", "…Tsk. You saw through me. Don't tell anyone I do a bank voice."]}
    ]},
    {"id": "p-mom", "name": ["Мама", "Mum"], "voice": "angel", "steps": [
        {"s": ["Сынок, это я, мама. Я с чужого номера. Кинь 100 рублей на этот номер, потом объясню.", "Sweetie, it's Mum. I'm on someone else's phone. Send £5 to this number, I'll explain later."],
         "a": [["Мам?..", "Mum?..", 1], ["Ангел, это ты?", "Angel, is that you?", 2]]},
        {"s": ["…Ладно, это я, ангел. Я хотела проверить, ведёшься ли ты. Молодец, не ведёшься ♡", "…Fine, it's me, the angel. I wanted to see if you'd fall for it. Good, you didn't ♡"]},
        {"s": ["Хи-хи, раскусил! Никогда никому не кидай денег по звонку, ладно? Это был урок ♡", "Hee hee, caught me! Never send money because of a call, okay? That was a lesson ♡"]}
    ]},
    {"id": "p-cerberus", "name": ["Цербер", "Cerberus"], "voice": "bark", "steps": [
        {"s": ["Гав! Гав-гав! Ррр… гав?", "Woof! Woof-woof! Grr… woof?"],
         "a": [["Хороший мальчик", "Good boy", 1], ["Ты как дозвонился?", "How did you even call?", 2]]},
        {"s": ["ГАВ!!! (три головы радостно лают одновременно)", "WOOF!!! (three heads bark happily at once)"]},
        {"s": ["Гав. (кажется, одна голова нажала кнопку лапой, вторая её держит, третья лижет трубку)", "Woof. (one head pressed the button with a paw, another holds the phone, the third licks it)"]}
    ]},
    {"id": "p-survey", "name": ["Опрос", "Survey"], "voice": "robot", "steps": [
        {"s": ["Здравствуйте. Небесная канцелярия проводит опрос. Насколько вы довольны своим ангелом-хранителем? Нажмите 1, если очень.", "Hello. The heavenly office is running a survey. How satisfied are you with your guardian angel? Press 1 for very."],
         "a": [["Очень", "Very", 1], ["Средне", "So-so", 2]]},
        {"s": ["Спасибо. Ваш ответ передан ангелу. Она… она очень рада. Это точно робот говорит.", "Thank you. Your answer has been passed to the angel. She is… very happy. This is definitely a robot speaking."]},
        {"s": ["Ваш ответ передан ангелу. Ангел плачет. Шучу. Ангел ничего не слышала. Наверное.", "Your answer has been passed to the angel. The angel is crying. Kidding. The angel heard nothing. Probably."]}
    ]},
    {"id": "p-wrong", "name": ["Неизвестный", "Unknown"], "voice": "demon", "steps": [
        {"s": ["Алло, это пиццерия? Мне одну адскую, побольше перца. Доставка на девятый круг.", "Hello, is this the pizza place? One inferno, extra chilli. Delivery to the ninth circle."],
         "a": [["Вы ошиблись", "Wrong number", 1], ["Будет через 30 минут", "Ready in 30 minutes", 2]]},
        {"s": ["Ошиблась? Демоницы не ошибаются. Значит, пиццерия — это ты. Жду.", "Wrong? Demons don't get numbers wrong. So you're the pizza place now. I'll wait."]},
        {"s": ["…Ты подыграл. Ты мне нравишься. Пицца не нужна. Пока.", "…You played along. I like you. Never mind the pizza. Bye."]}
    ]},
    {"id": "p-radio", "name": ["Радио «Небо FM»", "Heaven FM"], "voice": "angel", "steps": [
        {"s": ["Вы в прямом эфире радио «Небо FM»! Угадайте мелодию и выиграйте облако!", "You're live on Heaven FM! Guess the tune and win a cloud!"],
         "a": [["Это «Облачный вальс»!", "It's the Cloud Waltz!", 1], ["Я не слышал мелодию", "I didn't hear any tune", 2]]},
        {"s": ["Правильно!!! Облако ваше! Оно уже летит. Посмотрите в окно ♡", "Correct!!! The cloud is yours! It's on its way. Look out the window ♡"]},
        {"s": ["Ой, мы забыли её включить. Неважно! Облако всё равно ваше ♡", "Oops, we forgot to play it. Doesn't matter! The cloud is yours anyway ♡"]}
    ]}
];

// chain letters, 2002's finest; from whoever rules the corner
const chainLetters = {
    "angel": [["Перешли это 10 друзьям, и в пятницу у тебя всё скомпилируется ♡ (Пересылать не надо, я пошутила.)", "Forward this to 10 friends and your code will compile on Friday ♡ (Don't actually forward it, I'm joking.)"],
              ["Это письмо счастья. Счастье уже в пути. Подпись: ангел ♡", "This is a chain letter of happiness. Happiness is on its way. Signed: the angel ♡"]],
    "demon": [["Перешли это 10 друзьям, или в полночь к тебе придёт… я. Хотя я и так приду.", "Forward this to 10 friends or at midnight… I'll come. I'm coming anyway, though."],
              ["Ты получил проклятие. Чтобы снять — погладь демоницу. Срок: сегодня.", "You have received a curse. To lift it, pet the demon. Deadline: today."]]
};

// the tunes she sends now and then (the melody collection): [id, name ru, name en, spec, whose]
const gifts = [
    ["cloud-waltz", "Облачный вальс", "Cloud Waltz", "4c2 8e2 8g2 4c3 4g2 8a2 8g2 4e2 4c2 2d2", "angel"],
    ["halo-polka", "Нимб-полька", "Halo Polka", "8g2 8g2 8e2 8c2 8d2 8d2 4g1 8e2 8f2 8g2 8a2 4g2 4c3", "angel"],
    ["feather", "Пёрышко", "Feather", "16e3 16d3 16c3 16b2 8a2 8- 16c3 16b2 16a2 16g2 8e2 8- 4c2", "angel"],
    ["lullaby", "Колыбельная для угла экрана", "Corner Lullaby", "4e2 4g2 2c3 4b2 4g2 2e2 4f2 4a2 2c3 1g2", "angel"],
    ["morning", "Доброе утро ♡", "Good Morning ♡", "8c2 8d2 8e2 8g2 4c3 8- 8c3 8g2 8e2 4c3", "angel"],
    ["inferno", "Ad infernum", "Ad infernum", "8a1 8a1 8e2 8a1 8#g2 8e2 8a1 4b1 8c2 8b1 8a1 2e1", "demon"],
    ["neon", "Неоновая тоска", "Neon Blues", "4d2 8f2 8a2 4#g2 8f2 8d2 4c2 8d2 8f2 2a1", "demon"],
    ["cauldron", "Котёл-диско", "Cauldron Disco", "16a1 16a1 8a2 16a1 16a1 8g2 16a1 16a1 8f2 8e2 8c2 4d2", "demon"],
    ["666", "Шестьсот шестьдесят шесть", "Six Six Six", "8e2 8e2 8e2 4c2 8- 8e2 8e2 8e2 4c2 8- 4e2 4#d2 2e2", "demon"],
    ["midnight", "Полночь", "Midnight", "2a1 4c2 4e2 2#d2 4- 4b1 1a1", "demon"]
];
const giftText = {
    "angel": [["Лови мелодию ♡ «%n». Поставь на звонок, если понравится!", "Here's a tune ♡ \"%n\". Set it as your ringtone if you like it!"],
              ["Сочинила тебе мелодию. Называется «%n». Не смейся ♡", "I composed you a tune. It's called \"%n\". Don't laugh ♡"]],
    "demon": [["Держи. «%n». Не благодари. Серьёзно, не надо.", "Here. \"%n\". Don't thank me. Seriously, don't."],
              ["Мелодия «%n». Писала в котле. Поставишь на звонок — узнаю.", "A tune: \"%n\". Written in a cauldron. Set it as your ringtone and I'll know."]]
};

// the code of the day: a riddle by text, the answer dialled as *answer#
const riddles = [
    [["Сколько кругов в аду? Набери ответ так: *число#", "How many circles are there in hell? Dial it like this: *number#"], "9"],
    [["777 минус 666 — сколько? Набери *ответ#", "777 minus 666 — how much? Dial *answer#"], "111"],
    [["Сколько голов у Цербера? *ответ#", "How many heads does Cerberus have? *answer#"], "3"],
    [["В каком году вышла раскладушка «Нимб»? Подсказка на её экране. *ответ#", "What year is the Halo flip phone from? The hint is on its screen. *answer#"], "2002"],
    [["Сколько крыльев у ангела? Не считай мои, считай любые. *ответ#", "How many wings does an angel have? *answer#"], "2"],
    [["Сколько смертных грехов? *ответ#", "How many deadly sins are there? *answer#"], "7"],
    [["Сколько клавиш с цифрами на раскладушке? *ответ#", "How many number keys does the flip phone have? *answer#"], "10"],
    [["Сколько лучей у пентаграммы? *ответ#", "How many points does a pentagram have? *answer#"], "5"],
    [["Мой номер, ангельский. Три одинаковые цифры. *ответ#", "My number, the angel's. Three of the same digit. *answer#"], "777"],
    [["Сколько ног у паучка в паутине angelOS? *ответ#", "How many legs does the spider in angelOS's cobweb have? *answer#"], "8"],
    [["Сколько минут в часе, если ты сидишь в интернете? Шучу. Сколько секунд в минуте? *ответ#", "How many seconds in a minute? *answer#"], "60"],
    [["Сколько дней в неделе вместе? *ответ#", "How many days in a week together? *answer#"], "7"]
];
const riddleWin = {
    "angel": [["Правильно!!! Держи подарок для раскладушки: «%n» ♡", "Correct!!! A present for your flip phone: \"%n\" ♡"]],
    "demon": [["Угадал. Бесит. Забирай: «%n».", "You got it. Annoying. Take it: \"%n\"."]]
};
const riddleDone = ["Сегодняшний код уже разгадан. Завтра будет новый ♡", "Today's code is solved. A new one tomorrow ♡"];

// the magic ball on the outside screen (a spin or a shake of the shut phone)
const ball = [
    ["Да ♡", "Yes ♡"], ["Нет", "No"], ["Точно да", "Definitely"], ["Даже не думай", "Don't even"], ["Спроси позже", "Ask later"],
    ["Спроси демоницу", "Ask the demon"], ["Спроси ангела", "Ask the angel"], ["Звёзды говорят да", "The stars say yes"],
    ["Облака против", "The clouds say no"], ["Сначала поешь", "Eat first"], ["Это судьба", "It's fate"], ["Нимб мигает: да", "The halo blinks: yes"],
    ["Ад одобряет", "Hell approves"], ["Без шансов", "No chance"], ["50 на 50", "50/50"], ["Перезагрузись и спроси снова", "Reboot and ask again"]
];

// the phone dropped (flung down and it fell): what she says from her corner
const dropped = {
    "angel": [["Ай! Ты уронил телефон! Он живой?!", "Eek! You dropped the phone! Is it okay?!"], ["Осторожнее! Экран же… ну вот, трещина.", "Careful! The screen… there, a crack."], ["Бедная раскладушка… Погладь меня — я её починю ♡", "Poor flip phone… Pet me and I'll fix it ♡"]],
    "demon": [["Ха. Разбил. Мне нравится.", "Ha. Smashed it. I like that."], ["Трещины ему идут. Как мне.", "Cracks suit it. Like they suit me."], ["Ещё раз брось. Я не смотрела.", "Throw it again. I wasn't looking."]]
};
const fixed = {
    "angel": [["Всё, починила! Как новенький ♡", "There, fixed it! Good as new ♡"]],
    "demon": [["Починила. Не роняй больше. Это был не приказ. Хотя приказ.", "Fixed it. Don't drop it again. That wasn't an order. It was."]]
};

// the selfie: her line after a photo (sometimes the other one photobombs)
const selfie = {
    "angel": [["Красиво получилось? ♡", "Did it come out nice? ♡"], ["Я моргнула! Ещё раз!", "I blinked! Again!"], ["Повешу в альбом ♡", "Into the album it goes ♡"]],
    "demon": [["Удали. Нет, оставь. Нет, удали. Оставь.", "Delete it. No, keep it. No, delete. Keep."], ["Мой лучший ракурс — любой.", "My best angle is all of them."], ["Сфоткал демоницу. Смело.", "You photographed a demon. Brave."]]
};
const photobomb = ["Кто это сзади?!", "Who's that behind me?!"];

// the tuning (PhoneTuning): what the phone wears, and what opens each piece. req: free | pet N
// (her tenderness level) | snake N | raid N (best scores) | calls N (answered) | sms N (sent) |
// riddles N (codes of the day solved) | demon (talked to the demon on it) | gift (only a code of
// the day gives it). `note`: a line under the name (the models' tricks)
const looks = [
    {"id": "model", "name": ["Модель", "Model"], "items": [
        {"id": "flip", "name": ["Раскладушка «Нимб»", "\"Halo\" flip"], "req": ["free"], "note": ["крышка, внешний экранчик, антенна", "a lid, the outside screen, an antenna"]},
        {"id": "3310", "name": ["Кирпич 3310", "The 3310 brick"], "req": ["free"], "note": ["неубиваемый · заряд на 5 дней", "unbreakable · a 5-day battery"]},
        {"id": "ngage", "name": ["Тако-геймер", "The taco gamer"], "req": ["free"], "note": ["звонок — ребром к уху", "calls: hold it edge-on to the ear"]}
    ]},
    {"id": "shell", "name": ["Корпус", "Shell"], "items": [
        {"id": "angel", "name": ["Ангельский", "Angelic"], "req": ["free"]},
        {"id": "pearl", "name": ["Розовый перламутр", "Pink pearl"], "req": ["pet", 1]},
        {"id": "black", "name": ["Чёрный глянец", "Gloss black"], "req": ["calls", 3]},
        {"id": "chrome", "name": ["Под хром", "Chrome"], "req": ["snake", 15]},
        {"id": "hell", "name": ["Адский", "Infernal"], "req": ["demon"]},
        {"id": "xray", "name": ["Прозрачный", "Clear"], "req": ["gift"]},
        {"id": "gold", "name": ["Золотой", "Gold"], "req": ["raid", 60]}
    ]},
    {"id": "gems", "name": ["Стразы", "Rhinestones"], "items": [
        {"id": "none", "name": ["Без страз", "None"], "req": ["free"]},
        {"id": "edge", "name": ["По краю", "Round the edge"], "req": ["gift"]},
        {"id": "heart", "name": ["Сердечком", "A heart"], "req": ["pet", 2]},
        {"id": "full", "name": ["Весь в стразах", "Bedazzled"], "req": ["pet", 4]}
    ]},
    {"id": "sticker", "name": ["Наклейка", "Sticker"], "items": [
        {"id": "none", "name": ["Без наклейки", "None"], "req": ["free"]},
        {"id": "heart", "name": ["Сердечко", "Heart"], "req": ["free"]},
        {"id": "star", "name": ["Звёздочка", "Star"], "req": ["sms", 1]},
        {"id": "skull", "name": ["Черепок", "Skull"], "req": ["calls", 5]},
        {"id": "ghost", "name": ["Призрак", "Ghost"], "req": ["raid", 20]},
        {"id": "spider", "name": ["Паучок", "Spider"], "req": ["riddles", 2]},
        {"id": "cloud", "name": ["Облачко", "Cloud"], "req": ["gift"]},
        {"id": "pentagram", "name": ["Пентаграмма", "Pentagram"], "req": ["gift"]}
    ]},
    {"id": "charm", "name": ["Брелок", "Charm"], "items": [
        {"id": "her", "name": ["Она сама", "Her"], "req": ["free"]},
        {"id": "heart", "name": ["Сердце", "Heart"], "req": ["pet", 1]},
        {"id": "star", "name": ["Звезда", "Star"], "req": ["snake", 10]},
        {"id": "ghost", "name": ["Призрак", "Ghost"], "req": ["raid", 30]},
        {"id": "other", "name": ["Та, другая", "The other one"], "req": ["demon"]},
        {"id": "none", "name": ["Без брелка", "None"], "req": ["free"]}
    ]},
    {"id": "wall", "name": ["Обои экрана", "Screen wallpaper"], "items": [
        {"id": "plain", "name": ["Без обоев", "Plain"], "req": ["free"]},
        {"id": "stars", "name": ["Звёзды", "Stars"], "req": ["free"]},
        {"id": "hearts", "name": ["Сердечки", "Hearts"], "req": ["sms", 3]},
        {"id": "checker", "name": ["Клетка", "Checker"], "req": ["snake", 5]},
        {"id": "flames", "name": ["Пламя", "Flames"], "req": ["demon"]},
        {"id": "clouds", "name": ["Облака", "Clouds"], "req": ["gift"]}
    ]}
];
// what a lock says
const reqText = {
    "pet": ["Нежность %n", "Tenderness %n"], "snake": ["Змейка: %n очков", "Snake: %n points"], "raid": ["Рейд: %n очков", "Raid: %n points"],
    "calls": ["Поговорить по телефону %n раз", "Take %n calls"], "sms": ["Отправить %n SMS", "Send %n texts"], "riddles": ["Разгадать %n кодов дня", "Solve %n codes of the day"],
    "demon": ["Поговорить с демоницей", "Talk to the demon"], "gift": ["Только за код дня", "Only from a code of the day"]
};
