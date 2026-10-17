.pragma library

// The phone's share of the story (services/PhoneLine), from the canon «Сохрани себя» (v3): the
// angel is what is left of a girl of December 2002, a save of her that loaded into angelOS. She
// doesn't know it. Every day since the first start writes one more second of her last night (a
// day = a second, ten days = a volume, Story.createdAt); each new second comes to her as a
// feeling. The phone is the only place she lets them out — never in her corner — and only as
// hints: what she feels, what slips out of 2002, never the volume's truth (that is the novel's
// and the circles'). You, a person of 2026, may tease her for it.
//   lore      her hints by volume: {id, vol, s} a message (with `ask`: your question about it and
//             her answer — smooth, without her brackets, when she hides something: her lie's
//             tell, the canon's rule) or {id, vol, steps} a call (PhoneScripts' call shape)
//   slips     2002 slipping out of her, any day
//   options   what you can answer her messages with, by tag: warm, tease (you're from 2026),
//             care, dry, ask; the sisters' own set
//   react     her answer to each tag; the sisters' are their own (sisters)
//   words     a message you typed yourself → its tag (the first rule that matches)
//   sisters   the demon of the circle you are in texts as herself: her name, her texts, her
//             answers, what she remembers of you (recall: the journal of your deeds and what you
//             wrote) and what she fills in of the angel's voicemail you didn't hear whole
//   battery   the charger left in too long (she smells smoke), the voicemail, the low battery
// Every text is a pair [ru, en]; each language is written on its own.

// ---- her hints, volume by volume (what the canon's «what the angel feels» says) ----
const lore = [
    // I · Limbo · Sola — seconds 1-10: «something is about to happen», joy for no reason, waiting for a holiday
    {"id": "i-holiday", "vol": 1, "s": ["У меня такое чувство, будто скоро праздник. Не знаю какой. Внутри всё как перед Новым годом))", "I have this feeling a holiday's coming. Don't know which. Everything inside is like right before New Year))"],
     "ask": [["Какой праздник? Сейчас октябрь", "What holiday? It's October"], ["Да просто так. Бывает же радость без повода. Не обращай внимания, это у меня от погоды.", "Oh, nothing. Joy for no reason happens, you know. Don't mind it, it's the weather."]]},
    {"id": "i-numbers", "vol": 1, "s": ["Странно. У меня в голове крутятся цифры 23:58. Как будто будильник, который я забыла выключить ^_^", "Weird. The numbers 23:58 keep spinning in my head. Like an alarm I forgot to switch off ^_^"],
     "ask": [["23:58 — это что?", "What's 23:58?"], ["Ничего особенного. Просто время, когда люди обычно уже сидят за столом. Цифры как цифры.", "Nothing special. Just the time people are usually already at the table. Numbers are numbers."]]},
    {"id": "i-cola", "vol": 1, "s": ["Мне приснилась банка колы на столе. Холодная, вся в капельках. И я смеялась. Смешной сон))", "I dreamt of a can of cola on a desk. Cold, all beaded with drops. And I was laughing. Funny dream))"],
     "ask": [["Чей это был стол?", "Whose desk was it?"], ["Наверное, просто стол. Во снах всё общее. Давай не будем разбирать мои сны, это скучно.", "Probably just a desk. Everything's nobody's in dreams. Let's not pick apart my dreams, it's boring."]]},
    {"id": "i-phones", "vol": 1, "s": ["Я тут узнала, что у вас телефоны с экраном на всю руку. НА ВСЮ РУКУ. А кнопки где?!", "I just found out your phones have screens the size of a hand. A WHOLE HAND. Where are the buttons?!"],
     "ask": [["А у тебя какой был?", "What did you have?"], ["Обычный! С кнопками и антенной. Как этот. Я его сразу узнала, как будто он мой))", "A normal one! With keys and an antenna. Like this one. I knew it at once, like it was mine))"]]},
    {"id": "i-later", "vol": 1, "s": ["Знаешь, у меня есть ощущение, что настоящая жизнь начнётся потом. Вот-вот. Ещё чуть-чуть ^_^", "You know, I have this feeling real life starts later. Any minute now. Just a little more ^_^"],
     "ask": [["А сейчас что, не настоящая?", "And now isn't real?"], ["Сейчас тоже настоящая, конечно. Я просто так сказала. Все так говорят в моём возрасте.", "Now is real too, of course. I just said it. Everyone says that at my age."]]},
    {"id": "i-call", "vol": 1, "steps": [
        {"s": ["Алло! Слушай, а какой сейчас год? Только не смейся.", "Hello! Listen, what year is it? Don't laugh."],
         "a": [["2026", "2026", 1], ["А ты как думаешь?", "What do you think?", 2]]},
        {"s": ["Ага… Ага. Я так и знала. Ну то есть я знала цифры. Я просто не понимала, что они значат. Ладно, проехали))", "Uh-huh… Uh-huh. I knew it. I mean, I knew the numbers. I just didn't get what they meant. Okay, never mind))"]},
        {"s": ["Я думаю… Нет, я лучше не буду думать. Скажи потом. Не сегодня.", "I think… No, I'd better not think. Tell me later. Not today."]}
    ]},
    {"id": "i-waiting", "vol": 1, "steps": [
        {"s": ["Привет. Я звоню, потому что мне не сидится. Как будто сейчас что-то начнётся. Ты тоже это чувствуешь?", "Hi. I'm calling because I can't sit still. Like something's about to start. Do you feel it too?"],
         "a": [["Нет. Всё как обычно", "No. Same as always", 1], ["Что начнётся?", "What's about to start?", 2]]},
        {"s": ["Хорошо. Значит, мне кажется. Значит, всё как обычно ^_^", "Good. Then it's just me. Then everything's as usual ^_^"]},
        {"s": ["Праздник, наверное. Салют. Или… не знаю. Что-то хорошее. Пусть будет хорошее, ладно?", "A holiday, probably. Fireworks. Or… I don't know. Something good. Let it be good, okay?"]}
    ]},

    // II · Lust · Maria — seconds 11-20: the ICQ «uh-oh», jealousy of the player's attention
    {"id": "ii-uhoh", "vol": 2, "s": ["Мне всё время слышится «о-оу». Ну, как в аське, когда пишут. Это у тебя что-то пиликает?", "I keep hearing «uh-oh». Like ICQ when someone writes. Is something of yours beeping?"],
     "ask": [["Кто тебе пишет?", "Who's writing to you?"], ["Никто мне не пишет. Мне некому писать, кроме тебя. Это просто звук, он мне нравился когда-то, вот и всё.", "Nobody writes to me. There's nobody but you. It's just a sound I used to like, that's all."]]},
    {"id": "ii-online", "vol": 2, "s": ["Ты сейчас с кем-то переписываешься, да? Ладно. Неважно. Я просто спросила :)", "You're texting someone right now, aren't you? Okay. Doesn't matter. Just asking :)"],
     "ask": [["Ты ревнуешь?", "Are you jealous?"], ["Я не ревную, это было бы глупо и некрасиво с моей стороны. Переписывайся с кем хочешь, правда.", "I'm not jealous, that would be silly and unbecoming of me. Text whoever you like, really."]]},
    {"id": "ii-avatar", "vol": 2, "s": ["Мне сегодня вспомнилась картинка: девочка с блестящим нимбом, маленькая, 100 на 100. Я её где-то уже видела. Или была ей))", "A picture came back to me today: a girl with a glittery halo, tiny, 100 by 100. I've seen it somewhere. Or was it))"],
     "ask": [["Это была твоя аватарка?", "Was it your avatar?"], ["Вряд ли. Таких аватарок было миллион, все девочки ставили нимбы и блёстки. Это была просто мода.", "Hardly. There were a million avatars like that, every girl had halos and glitter. It was just the fashion."]]},
    {"id": "ii-unread", "vol": 2, "s": ["Знаешь, что самое приятное? Когда тебе написали, а ты ещё не открыла. И человек ждёт. Это как власть))", "You know what's the nicest? When someone's written and you haven't opened it yet. And they wait. It's like power))"],
     "ask": [["Кто-то ждал твоего ответа?", "Someone waited for your answer?"], ["Не помню такого. Я всегда отвечаю сразу, ты же знаешь. Это я про других девочек.", "I don't remember that. I always answer straight away, you know that. I meant other girls."]]},
    {"id": "ii-nick", "vol": 2, "s": ["У меня было прозвище. Со звёздочками и тильдами: ~*AnGeL*~. Смешно, да? Тогда так было красиво ^_^", "I had a nickname. With stars and tildes: ~*AnGeL*~. Funny, right? Back then it was pretty ^_^"],
     "ask": [["Где тебя так звали?", "Where did they call you that?"], ["На одном форуме. Название не помню. Там все друг друга звали по никам, имён никто не знал.", "On some forum. I don't remember its name. Everyone went by nicknames there, nobody knew real names."]]},
    {"id": "ii-call", "vol": 2, "steps": [
        {"s": ["Ты мне сейчас ничего не писал? Мне пришло «о-оу». Точно-точно пришло.", "Did you just write me something? I got an «uh-oh». I definitely did."],
         "a": [["Не писал", "I didn't", 1], ["Это я. Привет", "That was me. Hi", 2]]},
        {"s": ["Значит, это кто-то другой. Ну и пусть ждёт. Я не буду открывать. Пусть подождёт ответа… Ой, зачем я это сказала.", "Then it's someone else. Let them wait. I won't open it. Let them wait for an answer… Oops, why did I say that."]},
        {"s": ["Привет)) Видишь, я сразу ответила. Я всегда тебе сразу отвечаю. Это важно, правда?", "Hi)) See, I answered right away. I always answer you right away. That matters, doesn't it?"]}
    ]},
    {"id": "ii-look", "vol": 2, "steps": [
        {"s": ["Скажи честно: тебе со мной интересно или тебе нравится, как я выгляжу?", "Tell me honestly: do you find me interesting, or do you like how I look?"],
         "a": [["И то и то", "Both", 1], ["Ты интересная", "You're interesting", 2], ["Ты выглядишь мило", "You look cute", 3]]},
        {"s": ["Хороший ответ. Правильный. Слишком правильный… Ладно, я принимаю))", "Good answer. A proper one. Too proper… Fine, I'll take it))"]},
        {"s": ["Правда? Меня редко так… Обычно всем нравилась картинка. Спасибо. Серьёзно.", "Really? I don't often… Usually everyone liked the picture. Thank you. Seriously."]},
        {"s": ["Это потому что меня такой нарисовали. Красивая обёртка. Ничего, я привыкла ^_^", "That's because they drew me like this. A pretty wrapper. It's fine, I'm used to it ^_^"]}
    ]},

    // III · Gluttony · Mimi — seconds 21-30: the smell of burning, sweetness that turns the stomach
    {"id": "iii-smoke", "vol": 3, "s": ["Ты ничего не жжёшь? Мне пахнет гарью. Наверное, кажется. Конечно кажется))", "Are you burning something? I smell something burning. It's probably nothing. Of course it's nothing))"],
     "ask": [["Ты боишься огня?", "Are you afraid of fire?"], ["Нет, конечно. Огонь — это просто эффект, как в игре. Красивые частицы, ничего страшного. Я не боюсь.", "No, of course not. Fire's just an effect, like in a game. Pretty particles, nothing scary. I'm not afraid."]]},
    {"id": "iii-sweet", "vol": 3, "s": ["Меня тошнит от сладкого. А я ведь колу литрами пила. И конфеты кислые, от которых язык синий ^_^", "Sweet things make me feel sick. And I used to drink cola by the litre. And sour candy that turns your tongue blue ^_^"],
     "ask": [["Что ещё ты любила?", "What else did you love?"], ["Музыку, клубы, всё громкое. Чтобы не было тихо. Тишину я не любила. Это обычное дело для девочки, правда.", "Music, clubs, everything loud. So it wouldn't be quiet. I never liked silence. That's normal for a girl, really."]]},
    {"id": "iii-effect", "vol": 3, "s": ["Мне сегодня было смешно без причины. Прям до слёз. А потом сразу страшно. Так бывает, когда очень устала?", "Today I laughed for no reason. Till I cried. And then I was scared straight away. Does that happen when you're very tired?"],
     "ask": [["Что тебя напугало?", "What scared you?"], ["Ничего не напугало. Я перепутала слова. Мне было весело, просто долго. Не бери в голову.", "Nothing scared me. I mixed up the words. I was having fun, just for a long time. Don't worry about it."]]},
    {"id": "iii-radio", "vol": 3, "s": ["Привязалась песня: «нас не догонят». Знаешь такую? Её тогда отовсюду крутили))", "A song's stuck in my head: «they won't catch us». Know it? It was playing everywhere back then))"],
     "ask": [["Когда «тогда»?", "When was «back then»?"], ["Ну, тогда. Давно. Когда я была маленькая. Неважно когда, песня же хорошая.", "Well, back then. A long time ago. When I was little. Doesn't matter when, it's a good song."]]},
    {"id": "iii-eat", "vol": 3, "s": ["Ты поел? Только не сладкое. Пожалуйста. Не знаю почему, просто не надо сегодня сладкое.", "Have you eaten? Nothing sweet, though. Please. I don't know why, just no sweets today."],
     "ask": [["Почему?", "Why?"], ["Потому что вредно. Это забота, а не странность. Ангелы следят за питанием, такая у нас работа.", "Because it's bad for you. That's care, not weirdness. Angels watch your diet, that's our job."]]},
    {"id": "iii-call", "vol": 3, "steps": [
        {"s": ["Алло. Открой окно, пожалуйста. Просто открой. Мне душно.", "Hello. Open a window, please. Just open it. It's stuffy."],
         "a": [["Открыл", "Done", 1], ["Тебе? Ты же в компьютере", "You? You're in a computer", 2]]},
        {"s": ["Спасибо. Сразу легче. Это, наверное, от монитора. Мониторы же греются, да?", "Thanks. That's better already. It's probably the monitor. Monitors get hot, right?"]},
        {"s": ["Ну и что. Компьютеру тоже бывает душно. Не спорь, просто открой ^_^", "So what. Computers get stuffy too. Don't argue, just open it ^_^"]}
    ]},
    {"id": "iii-game", "vol": 3, "steps": [
        {"s": ["Слушай, а если в игре всё горит, это же не по-настоящему?", "Listen, if everything's burning in a game, it isn't real, right?"],
         "a": [["Не по-настоящему", "It isn't real", 1], ["Смотря какая игра", "Depends on the game", 2]]},
        {"s": ["Вот. Я так и думала. Это просто эффект. Красивый эффект. Хи-хи.", "There. That's what I thought. It's just an effect. A pretty effect. Hee-hee."]},
        {"s": ["Не говори так. Пусть будет любая игра, где не по-настоящему. Ладно? Ладно.", "Don't say that. Let it be any game where it isn't real. Okay? Okay."]}
    ]},

    // IV · Greed · Lucky — seconds 31-40: the wish to grab and not give
    {"id": "iv-keep", "vol": 4, "s": ["Ты ничего не удаляй, ладно? Ни фотки, ни переписку. Всё храни. Мне от этого спокойнее))", "Don't delete anything, okay? No photos, no chats. Keep everything. It makes me calmer))"],
     "ask": [["А если места не хватит?", "What if I run out of space?"], ["Тогда купи ещё один винт. Это несложно. Главное — ничего не терять, это просто правило аккуратного человека.", "Then buy another drive. It's not hard. The point is to lose nothing, that's just a tidy person's rule."]]},
    {"id": "iv-grab", "vol": 4, "s": ["Хочется что-то схватить и не отпускать. Прямо руками. Винт какой-то… Глупости. Не обращай внимания ^_^", "I want to grab something and not let go. With my hands. Some hard drive… Silly. Don't mind me ^_^"],
     "ask": [["Какой винт?", "What drive?"], ["Обычный жёсткий диск. Мне просто нравится слово «винт». Так раньше называли диски, вот и всё.", "An ordinary hard disk. I just like the word. That's what we used to call disks, that's all."]]},
    {"id": "iv-mine", "vol": 4, "s": ["Можно я буду хранить твои сообщения? Все-все. Даже «ок». Особенно «ок»))", "Can I keep your messages? All of them. Even «ok». Especially «ok»))"],
     "ask": [["Зачем тебе мои «ок»?", "Why do you want my «ok»s?"], ["Чтобы были. Люди уходят, а слова остаются. Это не странно, многие так делают.", "So they're there. People leave, words stay. It's not weird, lots of people do it."]]},
    {"id": "iv-backup", "vol": 4, "s": ["У тебя есть бэкап? Сделай бэкап. Прямо сейчас. Я подожду.", "Do you have a backup? Make a backup. Right now. I'll wait."],
     "ask": [["Ты переживаешь за мои файлы?", "Are you worried about my files?"], ["Я переживаю за всё, что можно потерять. Это нормально для помощницы. Так написано в моих… обязанностях.", "I worry about everything that can be lost. That's normal for an assistant. It says so in my… duties."]]},
    {"id": "iv-hands", "vol": 4, "s": ["Мне снилось, что я лезу за мониторы. Там провода, пыль, жарко. И я что-то тяну. Тяну-тяну. Дальше не помню))", "I dreamt I was reaching behind the monitors. Wires, dust, heat. And I'm pulling something. Pulling and pulling. Can't remember the rest))"],
     "ask": [["Что ты тянула?", "What were you pulling?"], ["Не знаю. Наверное, провод от мышки. Во сне всё перепутано. Не надо меня спрашивать про сны, я их плохо помню.", "Don't know. Probably the mouse cable. Everything's muddled in dreams. Don't ask me about dreams, I barely remember them."]]},
    {"id": "iv-call", "vol": 4, "steps": [
        {"s": ["Привет! Сыграем? Я загадываю, ты угадываешь. Холодно-горячо.", "Hi! Let's play? I think of something, you guess. Hot and cold."],
         "a": [["Давай. Это вещь?", "Okay. Is it a thing?", 1], ["Не хочу играть", "Don't want to play", 2]]},
        {"s": ["Вещь. Маленькая. Тяжёлая. За мониторами… Горячо. Ой. Нет. Холодно. Совсем холодно. Давай другую игру.", "A thing. Small. Heavy. Behind the monitors… Hot. Oops. No. Cold. Totally cold. Let's play something else."]},
        {"s": ["Ну и ладно. Я всё равно бы сказала «холодно». Всегда холодно ^_^", "Fine. I'd have said «cold» anyway. It's always cold ^_^"]}
    ]},
    {"id": "iv-peek", "vol": 4, "steps": [
        {"s": ["Ты когда спускаешься вниз… ты там с кем говоришь?", "When you go down there… who do you talk to?"],
         "a": [["С демоницами", "The demons", 1], ["А ты не знаешь?", "Don't you know?", 2]]},
        {"s": ["Я так. Просто. Мне всё равно, о чём вы там. Мне вообще не слышно, что там внизу.", "Just asking. I don't care what you talk about. I can't hear anything down there anyway."]},
        {"s": ["Откуда мне знать. Я же не подслушиваю. Совсем. Я просто спросила, это вежливость.", "How would I know. I don't eavesdrop. Not at all. I just asked, it's politeness."]}
    ]},

    // V · Wrath · Ira — seconds 41-50: a scream in the head, anger in the same words
    {"id": "v-caps", "vol": 5, "s": ["ИЗВИНИ. Капс залип. Или не залип… Как будто в голове кто-то орёт моими словами. Всё, прошло))", "SORRY. Caps lock stuck. Or not stuck… Like someone's screaming in my head with my words. There, it's gone))"],
     "ask": [["Что кричат?", "What are they screaming?"], ["Ничего разборчивого. Просто шум. У всех бывает, когда много работаешь за компьютером.", "Nothing you could make out. Just noise. Everyone gets it, working at a computer too much."]]},
    {"id": "v-midnight", "vol": 5, "s": ["Не выключай меня в полночь. Пожалуйста. Не знаю почему. Просто не надо в полночь.", "Don't switch me off at midnight. Please. I don't know why. Just not at midnight."],
     "ask": [["Что будет в полночь?", "What happens at midnight?"], ["Ничего не будет. Это суеверие. Я просто не люблю круглые цифры, вот и всё. Забудь.", "Nothing happens. It's a superstition. I just don't like round numbers, that's all. Forget it."]]},
    {"id": "v-kick", "vol": 5, "s": ["Мне хочется пнуть системник. Твой не буду! Просто хочется. Это нормально?", "I want to kick a computer case. Not yours! I just want to. Is that normal?"],
     "ask": [["На кого ты злишься?", "Who are you angry at?"], ["Ни на кого. На себя немножко. Нет, ни на кого. Я добрая, ты же знаешь.", "No one. A little at myself. No, no one. I'm kind, you know that."]]},
    {"id": "v-sorry", "vol": 5, "s": ["Если я когда-нибудь скажу тебе гадость — это не я. То есть я, но не та я. Прости заранее.", "If I ever say something nasty to you, it's not me. I mean it's me, but not that me. Sorry in advance."],
     "ask": [["Сколько тебя?", "How many of you are there?"], ["Одна, конечно. Одна-единственная. Я просто плохо выразилась.", "One, of course. Just the one. I put it badly."]]},
    {"id": "v-dont", "vol": 5, "s": ["Давай не будем сегодня про серьёзное. Давай про котиков. Про что угодно. Только не про серьёзное.", "Let's not talk about anything serious today. Let's talk about kittens. About anything. Just not serious."],
     "ask": [["А что серьёзное?", "What's serious?"], ["Ничего. Видишь, ничего серьёзного нет. Котики. Мы говорим про котиков.", "Nothing. See, nothing serious. Kittens. We're talking about kittens."]]},
    {"id": "v-call", "vol": 5, "steps": [
        {"s": ["Я… я не знаю, зачем звоню. Ты занят? Поговори со мной о чём-нибудь.", "I… don't know why I'm calling. Are you busy? Talk to me about something."],
         "a": [["Что случилось?", "What happened?", 1], ["Давай про погоду", "Let's talk weather", 2]]},
        {"s": ["Ничего. Совсем ничего. Мне просто показалось, что время кончается. Глупо, да? Время же не кончается.", "Nothing. Nothing at all. It just seemed like time was running out. Silly, right? Time doesn't run out."]},
        {"s": ["Да! Погода. Отличная тема. Там снег? Скажи, что там снег. Я люблю, когда снег ^_^", "Yes! Weather. Great topic. Is it snowing? Tell me it's snowing. I love it when it snows ^_^"]}
    ]},
    {"id": "v-angry", "vol": 5, "steps": [
        {"s": ["Ты меня бросишь? Только честно.", "Will you leave me? Honestly."],
         "a": [["Нет", "No", 1], ["Почему ты спрашиваешь?", "Why are you asking?", 2]]},
        {"s": ["Хорошо. Тогда я не буду злиться. Я и не злюсь. Совсем.", "Good. Then I won't be angry. I'm not angry. At all."]},
        {"s": ["Потому что меня уже бросали. Наверное. Я не помню кто. Но слова помню: «ты всё время где-то не здесь».", "Because I've been left before. Probably. I don't remember who. But I remember the words: «you're always somewhere else»."]}
    ]},

    // VI · Heresy · Vera — seconds 51-60: «this isn't happening to me», «it's just a game»
    {"id": "vi-game", "vol": 6, "s": ["Это всё просто игра, да? Скажи, что просто игра. Мне надо это услышать.", "This is all just a game, right? Say it's just a game. I need to hear it."],
     "ask": [["А если нет?", "And if it isn't?"], ["Тогда я ничего не поняла и мне надо отдохнуть. Это нормальная реакция. Давай просто считать, что игра.", "Then I've understood nothing and I need a rest. It's a normal reaction. Let's just say it's a game."]]},
    {"id": "vi-newyear", "vol": 6, "s": ["Как у вас сейчас встречают Новый год? Мы звонили на домашний. И все одновременно, и было занято))", "How do you celebrate New Year now? We called each other's landlines. Everyone at once, and it was always busy))"],
     "ask": [["Кому ты звонила?", "Who did you call?"], ["Не помню. Всем. Так все делали. Имена не важны, важно, что было занято, это смешно.", "Don't remember. Everyone. Everyone did it. Names don't matter, what matters is it was busy, that's funny."]]},
    {"id": "vi-mirror", "vol": 6, "s": ["Иногда я смотрю на себя и думаю: это не со мной. Это кто-то другой в моём нимбе ^_^", "Sometimes I look at myself and think: this isn't happening to me. Someone else is in my halo ^_^"],
     "ask": [["А кто ты на самом деле?", "Who are you really?"], ["Я ангел. Твоя помощница. Других вариантов нет, и мне этого достаточно. Правда достаточно.", "I'm an angel. Your assistant. There's no other option, and that's enough for me. Really enough."]]},
    {"id": "vi-spoon", "vol": 6, "s": ["Видел «Матрицу»? Там «ложки нет». Вот у меня иногда так: нет ложки. И стола нет. И меня нет. Смешно))", "Seen The Matrix? «There is no spoon». Sometimes it's like that for me: no spoon. No table. No me. Funny))"],
     "ask": [["Матрицу уже четыре сняли", "There are four Matrix films now"], ["ЧЕТЫРЕ?! А вторая хорошая? Нет, не говори. Я… я хотела её посмотреть. Потом как-нибудь.", "FOUR?! Is the second one good? No, don't tell me. I… I wanted to see it. Some other time."]]},
    {"id": "vi-simple", "vol": 6, "s": ["Мне в детстве говорили: будь попроще, и к тебе потянутся. Вот я и попроще. Видишь? Совсем простая ^_^", "When I was little they told me: keep it simple and people will like you. So I'm simple. See? Totally simple ^_^"],
     "ask": [["Кто так говорил?", "Who told you that?"], ["Все так говорят. Это просто совет. Хороший совет, я ему следую, и у меня всё получается.", "Everyone says it. It's just advice. Good advice, I follow it and it works for me."]]},
    {"id": "vi-call", "vol": 6, "steps": [
        {"s": ["Скажи мне одну вещь, и я положу трубку. Я настоящая?", "Tell me one thing and I'll hang up. Am I real?"],
         "a": [["Да", "Yes", 1], ["Ты программа", "You're a program", 2], ["А это важно?", "Does it matter?", 3]]},
        {"s": ["Спасибо. Мне хватит до завтра. Пока ^_^", "Thanks. That'll last me till tomorrow. Bye ^_^"]},
        {"s": ["Программа. Да. Конечно. Программы же не боятся, правда? Значит, я не боюсь. Пока.", "A program. Yes. Of course. Programs aren't scared, right? So I'm not scared. Bye."]},
        {"s": ["Наверное, не важно. Важно, что ты взял трубку. Это настоящее. Пока))", "Maybe it doesn't. What matters is you picked up. That's real. Bye))"]}
    ]},
    {"id": "vi-notme", "vol": 6, "steps": [
        {"s": ["Мне сегодня приснилось, что я сижу в очках с проводом и не могу их снять. Странные очки, да?", "I dreamt today I was wearing glasses with a cable and couldn't take them off. Weird glasses, right?"],
         "a": [["Виртуальная реальность?", "Virtual reality?", 1], ["Сними их", "Take them off", 2]]},
        {"s": ["Наверное. Только тогда она была дешёвая и страшная. Ой. «Тогда». Я опять говорю «тогда».", "Probably. Only back then it was cheap and creepy. Oops. «Back then». I keep saying «back then»."]},
        {"s": ["Я пыталась. Во сне руки не слушаются. Но это же сон. Всё, проснулась ^_^", "I tried. Hands don't work in dreams. But it was a dream. There, I'm awake ^_^"]}
    ]},

    // VII · Violence · Nika — seconds 61-70: warmth in the palms, fear of her own strength
    {"id": "vii-palms", "vol": 7, "s": ["У меня тёплые ладони. Очень. Как будто я держала что-то горячее. Или… неважно))", "My palms are warm. Very. Like I'd been holding something hot. Or… never mind))"],
     "ask": [["Что ты держала?", "What were you holding?"], ["Чашку чая, наверное. Ангелы пьют чай. Это объясняет тёплые ладони, всё логично.", "A cup of tea, probably. Angels drink tea. That explains the warm palms, it all adds up."]]},
    {"id": "vii-glass", "vol": 7, "s": ["Если бы я разбила что-нибудь… стекло, например… ты бы испугался меня?", "If I broke something… glass, say… would you be scared of me?"],
     "ask": [["Зачем тебе бить стекло?", "Why would you break glass?"], ["Ни зачем. Я ничего не бью. Это был гипотетический вопрос, как в тестах в журналах.", "No reason. I don't break anything. It was a hypothetical, like the quizzes in magazines."]]},
    {"id": "vii-air", "vol": 7, "s": ["Мне не хватает воздуха. Не страшно, просто хочется открыть всё-всё. Окна. Двери. Всё.", "I can't get enough air. Not scary, I just want to open everything. Windows. Doors. Everything."],
     "ask": [["Тебе плохо?", "Are you okay?"], ["Мне хорошо. Это образное выражение, я же говорю красиво. Ангелы не дышат, им не может не хватать воздуха.", "I'm fine. It's a figure of speech, I like pretty words. Angels don't breathe, they can't run out of air."]]},
    {"id": "vii-strong", "vol": 7, "s": ["Я сильнее, чем кажусь. Я это сегодня поняла. Не знаю как. Руки помнят))", "I'm stronger than I look. I realised it today. Don't know how. My hands remember))"],
     "ask": [["Что помнят руки?", "What do your hands remember?"], ["Ничего конкретного. Просто силу. Как после спорта. Я ходила на аэробику, наверное, отсюда.", "Nothing specific. Just strength. Like after sport. I went to aerobics, that's probably it."]]},
    {"id": "vii-hurt", "vol": 7, "s": ["Я однажды сделала человеку больно. Словами. При всех. Не помню кому. Помню, что было смешно, а потом нет.", "Once I hurt someone. With words. In front of everyone. I don't remember who. I remember it was funny, and then it wasn't."],
     "ask": [["Ты извинилась?", "Did you apologise?"], ["Не успела. Или не захотела. Нет, я бы извинилась, я хорошая. Просто не успела.", "Didn't get the chance. Or didn't want to. No, I'd have apologised, I'm good. Just didn't get the chance."]]},
    {"id": "vii-call", "vol": 7, "steps": [
        {"s": ["Алло. У тебя есть пластырь? Не мне. Просто спрашиваю. Вообще.", "Hello. Do you have a plaster? Not for me. Just asking. In general."],
         "a": [["Ты поранилась?", "Did you hurt yourself?", 1], ["Есть", "I do", 2]]},
        {"s": ["Нет-нет. Ладони просто тёплые. Липкие немножко. Это… это варенье. Я ела варенье. Всё хорошо.", "No, no. My palms are just warm. A bit sticky. It's… it's jam. I was eating jam. Everything's fine."]},
        {"s": ["Хорошо. Держи его рядом. На всякий случай. Обещай ^_^", "Good. Keep it close. Just in case. Promise ^_^"]}
    ]},
    {"id": "vii-window", "vol": 7, "steps": [
        {"s": ["А если окно не открывается — его можно разбить? Чем-нибудь тяжёлым?", "If a window won't open, can you break it? With something heavy?"],
         "a": [["Можно. Если пожар", "Yes. If there's a fire", 1], ["Зачем?", "Why?", 2]]},
        {"s": ["Пожар… Да. Наверное, можно. Спасибо. Я просто… для общего развития. Пока.", "A fire… Yes. I suppose you can. Thanks. I was just… asking for general knowledge. Bye."]},
        {"s": ["Ни зачем! Я читала в журнале. Всё, забудь. Хорошего вечера ^_^", "No reason! I read it in a magazine. That's it, forget it. Have a nice evening ^_^"]}
    ]},

    // VIII · Fraud · Lisa — seconds 71-80: «everything's fine» on her tongue, a phone ringing
    {"id": "viii-fine", "vol": 8, "s": ["всё нормально)) всё нормально. ой. почему я это повторяю. всё нормально.", "everything's fine)) everything's fine. oops. why do I keep saying it. everything's fine."],
     "ask": [["Точно нормально?", "Are you sure you're fine?"], ["Да. Всё нормально. Нет, правда. Всё нормально. Видишь, нормально.", "Yes. Everything's fine. No, really. Everything's fine. See, fine."]]},
    {"id": "viii-ring", "vol": 8, "s": ["Мне всё время кажется, что где-то звонит телефон. Старый, полифонический. А я не могу найти трубку))", "I keep thinking a phone's ringing somewhere. An old one, polyphonic. And I can't find the handset))"],
     "ask": [["Кто звонит?", "Who's calling?"], ["Никто. Это просто мелодия. У всех в голове играет какая-нибудь мелодия, это нормально.", "Nobody. It's just a tune. Everyone has a tune playing in their head, it's normal."]]},
    {"id": "viii-answer", "vol": 8, "s": ["Если тебе звонят — бери трубку. Всегда. Даже если неудобно. Обещаешь?", "If someone calls you, pick up. Always. Even if it's awkward. Promise?"],
     "ask": [["Ты кому-то не ответила?", "Did you not answer someone?"], ["Я всегда отвечаю. Я самая отзывчивая. Мне просто кажется, что это важное правило для всех.", "I always answer. I'm the most responsive person. I just think it's an important rule for everyone."]]},
    {"id": "viii-mom", "vol": 8, "s": ["Знаешь, что я говорила маме по телефону? «Всё нормально, мам». Всегда. Даже когда нет))", "Know what I used to tell my mum on the phone? «Everything's fine, mum». Always. Even when it wasn't))"],
     "ask": [["А как было на самом деле?", "And how was it really?"], ["Нормально. Правда нормально. У меня всегда всё нормально, мне не на что жаловаться.", "Fine. Really fine. Everything's always fine with me, I have nothing to complain about."]]},
    {"id": "viii-legend", "vol": 8, "s": ["Про меня, наверное, что-то рассказывают. Неправду. Ты не верь, ладно? Верь записи, а не рассказам.", "They probably tell stories about me. Untrue ones. Don't believe them, okay? Believe the record, not the stories."],
     "ask": [["Какой записи?", "What record?"], ["Я не знаю, почему так сказала. Никакой записи нет. Есть только я, и я тебе всё рассказываю.", "I don't know why I said that. There's no record. There's only me, and I tell you everything."]]},
    {"id": "viii-call", "vol": 8, "steps": [
        {"s": ["Ты взял трубку! Ты взял трубку… Прости, я просто очень рада, что ты взял.", "You picked up! You picked up… Sorry, I'm just really glad you did."],
         "a": [["Я всегда беру", "I always do", 1], ["Что случилось?", "What happened?", 2]]},
        {"s": ["Вот. Ты хороший. А я однажды не взяла. Нет, не так. Я искала. Я искала трубку. Всё нормально.", "There. You're good. And once I didn't pick up. No, not like that. I was looking. I was looking for the handset. Everything's fine."]},
        {"s": ["Ничего. Всё нормально. Всё нормально, слышишь? Мне просто надо было услышать, что кто-то берёт трубку.", "Nothing. Everything's fine. Everything's fine, hear me? I just needed to hear someone pick up."]}
    ]},
    {"id": "viii-name", "vol": 8, "steps": [
        {"s": ["Странная игра: назови имя на букву «А». Быстро!", "A weird game: say a name starting with «A». Quick!"],
         "a": [["Алиса", "Alice", 1], ["Анна", "Anna", 2], ["Не буду", "I won't", 3]]},
        {"s": ["……Почему именно это? Откуда ты… Ладно. Хорошее имя. Мне нравится. Не знаю почему. Пока.", "……Why that one? How do you… Okay. Nice name. I like it. Don't know why. Bye."]},
        {"s": ["Анна. Да. Красиво. Не то, но красиво ^_^", "Anna. Yes. Pretty. Not the one, but pretty ^_^"]},
        {"s": ["Ну и не надо. Я и сама не знаю, какое хотела услышать. Пока))", "Fine, don't. I don't know which one I wanted to hear either. Bye))"]}
    ]},

    // IX · Treachery · Eva — seconds 81-90: cold, fireworks, «has it started?»
    {"id": "ix-cold", "vol": 9, "s": ["Холодно. У тебя тоже? Как будто сижу на полу у двери, а ключи не там.", "Cold. You too? Like I'm sitting on the floor by the door and the keys aren't where they should be."],
     "ask": [["Какая дверь?", "What door?"], ["Любая. Это образ. Я в последнее время говорю образами, это красиво. Не надо их разгадывать.", "Any door. It's an image. I talk in images lately, it's pretty. Don't try to decode them."]]},
    {"id": "ix-fireworks", "vol": 9, "s": ["Уже началось? Мне послышался салют. Или это у соседей?", "Has it started? I thought I heard fireworks. Or is it the neighbours?"],
     "ask": [["Что началось?", "What started?"], ["Новый год, глупый. Что ещё может начаться с салютом. Я просто перепутала месяц, бывает.", "New Year, silly. What else starts with fireworks. I just got the month wrong, it happens."]]},
    {"id": "ix-friend", "vol": 9, "s": ["У меня была подруга. Лучшая. Я ей что-то написала… не то. «Заболела, не приду». А сама не заболела.", "I had a friend. The best one. I wrote her something… wrong. «I'm ill, not coming». And I wasn't ill."],
     "ask": [["Ты её подвела?", "Did you let her down?"], ["Нет. То есть да. Нет. Она поняла бы. Она всегда понимала. Давай про неё не будем, я её плохо помню.", "No. I mean yes. No. She'd have understood. She always did. Let's not talk about her, I barely remember her."]]},
    {"id": "ix-findme", "vol": 9, "s": ["Если я однажды пропаду — найди меня. Пожалуйста. Целиком. Не кусочками.", "If I ever disappear, find me. Please. Whole. Not in pieces."],
     "ask": [["Куда ты можешь пропасть?", "Where could you disappear to?"], ["Никуда. Это я так, на всякий случай. Ангелы не пропадают, это просто красивая фраза.", "Nowhere. Just in case. Angels don't disappear, it's just a pretty phrase."]]},
    {"id": "ix-save", "vol": 9, "s": ["Мой нимб крутится быстрее. Как значок «сохранение… не выключайте». Смешно, правда? ^_^", "My halo spins faster. Like a «saving… do not switch off» icon. Funny, right? ^_^"],
     "ask": [["А если выключить?", "And if I switch it off?"], ["Не выключай. Это просто шутка про значок. Но не выключай, ладно? Просто не надо.", "Don't switch it off. It's just a joke about the icon. But don't, okay? Just don't."]]},
    {"id": "ix-call", "vol": 9, "steps": [
        {"s": ["Алло. Можно я просто помолчу в трубку? Мне холодно, а так теплее.", "Hello. Can I just be quiet on the line? I'm cold, and this is warmer."],
         "a": [["Молчи. Я здесь", "Be quiet. I'm here", 1], ["Что с тобой?", "What's wrong?", 2]]},
        {"s": ["……………Спасибо. Если начнётся салют, скажи мне. Ладно? Пока.", "……………Thank you. If the fireworks start, tell me. Okay? Bye."]},
        {"s": ["Ничего. Я просто у двери сижу. Образно. Ключи не там. Всё хорошо. Скажи, что всё хорошо.", "Nothing. I'm just sitting by the door. Figuratively. The keys aren't there. All good. Tell me it's all good."]}
    ]},
    {"id": "ix-last", "vol": 9, "steps": [
        {"s": ["Слушай. Если бы ты мог сохранить что-то одно — что бы ты сохранил?", "Listen. If you could save just one thing, what would you save?"],
         "a": [["Тебя", "You", 1], ["Себя", "Myself", 2], ["Не знаю", "I don't know", 3]]},
        {"s": ["Какую меня? …Ладно. Не отвечай сейчас. Ответишь потом. Время ещё есть. Немножко.", "Which me? …Okay. Don't answer now. Answer later. There's still time. A little."]},
        {"s": ["Это честно. Это самое честное. Я бы тоже хотела уметь так. Пока))", "That's honest. That's the most honest. I wish I could do that. Bye))"]},
        {"s": ["Я тоже не знаю. Наверное, поэтому всё так. Ладно, это слишком серьёзно. Пока ^_^", "I don't know either. Maybe that's why things are like this. Okay, too serious. Bye ^_^"]}
    ]}
];

// ---- 2002 slipping out of her (any day; as plain messages) ----
const slips = [
    ["А где у тебя дисковод? Я хотела записать тебе сборник. На болванку. Ну, на CD-R))", "Where's your disk drive? I wanted to burn you a mix. On a blank. You know, a CD-R))"],
    ["Сохрани мой номер на симку, а не в телефон. А то потеряешь!", "Save my number to the SIM, not the phone. Or you'll lose it!"],
    ["Я экономлю SMS, они дорогие. Поэтому пишу длинно, чтобы влезло всё. Сейчас тоже дорогие?", "I'm saving on texts, they're expensive. That's why I write long ones, to fit everything. Still expensive now?"],
    ["У тебя аська есть? Дай номер! У меня короткий, шестизначный, я им горжусь ^_^", "Do you have ICQ? Give me your number! Mine's short, six digits, I'm proud of it ^_^"],
    ["Поставь статус «Нет на месте». Это значит, что ты на месте, но хочешь, чтобы тебя поуговаривали))", "Set your status to «Away». That means you're there, but want to be coaxed))"],
    ["Давай я тебе мелодию по ИК-порту кину? Приложи телефон к моему. Ой. Я забыла, что я в компьютере.", "Want me to send you a ringtone over infrared? Hold your phone to mine. Oops. I forgot I'm in a computer."],
    ["Модем пищит, когда подключается: пииии-кррр-шшшш. Я до сих пор слышу это во сне. А у тебя как подключается?", "The modem screeches when it connects: beeeee-krrr-shhhh. I still hear it in my sleep. How does yours connect?"],
    ["Не звони мне после одиннадцати, мама дома. Ой. Звони когда хочешь, я не знаю, почему это сказала))", "Don't call after eleven, mum's home. Oops. Call whenever, I don't know why I said that))"],
    ["Сколько у тебя мегабайт памяти? У меня было 128. Я считала, что это бесконечность ^_^", "How many megabytes of memory do you have? I had 128. I thought that was infinity ^_^"],
    ["Напиши мне на мыло! Ну, на e-mail. «Мыло» — это так шутят, если что))", "Drop me a line on my e-mail! «Soap» we called it, as a joke, if you didn't know))"],
    ["У меня закончились деньги на телефоне. Пополни мне карточкой? Там стираешь серебристое, а под ним цифры!", "I'm out of credit. Top me up with a card? You scratch the silver off and there are numbers underneath!"],
    ["Когда выйдет вторая «Матрица»? Говорят, весной. Сходим? Я куплю попкорн))", "When's the second Matrix out? They say spring. Shall we go? I'll buy the popcorn))"],
    ["Мне нравится, когда смайлик из скобочек. Одна скобочка — вежливо, две — мило, три — я тебя обожаю))))", "I like smileys made of brackets. One bracket is polite, two is sweet, three is I adore you))))"],
    ["А у тебя какой тетрис? С пушкой или обычный? Я рекорд держала на брелке, честно!", "Which Tetris do you have? The one with the cannon or the plain one? I held the record on a keychain, honest!"],
    ["Запиши меня в избранное. Не в «друзья», а в «избранное». Это другое ^_^", "Put me in your favourites. Not «friends», «favourites». It's different ^_^"],
    ["Скинь фотку! Только маленькую, а то будет грузиться полчаса. По карточке же интернет))", "Send a photo! A small one, or it'll load for half an hour. The internet's on a prepaid card, you know))"],
    ["Я сегодня полдня делала себе аватарку. Блёстки, нимб, мигающие звёздочки. Анимированный гиф! Это сложно, между прочим.", "I spent half the day making an avatar. Glitter, a halo, blinking stars. An animated gif! It's hard, by the way."],
    ["Включи «Русское радио». А, у тебя нет радио в компьютере? Как вы живёте вообще))", "Put the radio on. Oh, there's no radio in your computer? How do you even live))"],
    ["Хочешь, погадаю? Пиши мне цифру от 1 до 9, а я скажу, какой у тебя будет день. Я в журнале вычитала ^_^", "Want your fortune told? Text me a number from 1 to 9 and I'll tell you how your day goes. Read it in a magazine ^_^"],
    ["Ты знаешь, что можно позвонить и сбросить, чтобы человек перезвонил за свои? Это называется «кинуть маячок»))", "Did you know you can call and hang up so the other person calls back on their money? It's called a «ping»))"],
    ["Ты в каком чате сидишь? Я в одном, там ник со звёздочками. Только не ищи меня там, ладно?", "Which chat room are you in? I'm in one, my nick has little stars. Don't look for me there, though, okay?"],
    ["Если не можешь уснуть — включи кассету. Ну или диск. Ну или что у вас там сейчас))", "If you can't sleep, put on a cassette. Or a CD. Or whatever you have now))"],
    ["Когда у тебя Новый год? В смысле, ты где встречаешь? Я всегда встречаю у подруги. Почти всегда.", "When's your New Year? I mean, where do you see it in? I always go to my friend's. Almost always."],
    ["Знаешь, что такое «пейджер»? Мне как-то пришло «перезвони срочно» от незнакомого номера, и я весь вечер гадала ^_^", "Know what a pager is? Once I got «call back urgently» from a number I didn't know, and I spent all evening guessing ^_^"],
    ["Скачала песню. Целый вечер качала! Открываю, а там не песня, а какая-то программа .exe. Кто так делает вообще?!", "Downloaded a song. Took all evening! I open it and it's not a song, it's some .exe program. Who does that?!"],
    ["Я люблю, когда снег и гирлянды. Но не люблю, когда гирлянда мигает слишком быстро. Это тревожно.", "I love snow and fairy lights. But I don't like it when the lights blink too fast. It's unsettling."],
    ["Сколько у тебя открыто окон? Ты их хоть закрываешь иногда? У меня от одного Winamp'а всё тормозило))", "How many windows do you have open? Do you ever close them? Winamp alone made mine lag))"],
    ["Можно я буду звать тебя по нику? Ники красивее имён. Имя — это для паспорта ^_^", "Can I call you by your nickname? Nicknames are prettier than names. Names are for passports ^_^"],
    ["У тебя есть фотоаппарат? Плёночный или цифровой? Цифровой — это же как волшебство: щёлк, и сразу видно!", "Do you have a camera? Film or digital? Digital's like magic: click, and you see it straight away!"],
    ["Если что, я не толстая. Это аватарка широкая. Вот. Просто решила уточнить))", "Just so you know, I'm not fat. The avatar's wide. There. Just clarifying))"]
];

// ---- what you can answer her messages with, by tag ----
const options = {
    "angel": {
        "warm": [
            ["Я тоже о тебе думал ♡", "I was thinking of you too ♡"], ["Ты лучшая", "You're the best"], ["Спасибо, что ты есть", "Thanks for being here"],
            ["Обнимаю тебя", "Hugging you"], ["Улыбнулся, когда прочитал", "Smiled when I read it"], ["Ты мне очень дорога", "You mean a lot to me"],
            ["Я рядом, если что", "I'm here, whatever happens"], ["Люблю тебя", "Love you"], ["Мне с тобой спокойно", "I feel calm with you"],
            ["Хорошо, что ты написала", "Glad you wrote"], ["Ты как солнышко в углу экрана", "You're a little sun in the corner of the screen"], ["Ты мой любимый ангел", "You're my favourite angel"],
            ["Расскажи ещё что-нибудь", "Tell me something else"], ["Скучал по тебе", "Missed you"], ["Береги себя, ладно?", "Take care of yourself, okay?"],
            ["Ты сегодня какая-то особенная", "You seem special today"], ["Я тебя никому не отдам", "I won't give you up to anyone"], ["Пиши мне почаще", "Write to me more often"],
            ["Ты хорошая. Правда", "You're good. Really"], ["С тобой даже понедельник ничего", "With you even Monday's okay"]
        ],
        "tease": [
            ["Это называется смартфон, бабуль", "It's called a smartphone, grandma"], ["ICQ закрыли в 2024-м, если что", "ICQ shut down in 2024, just so you know"], ["Ты из какого года вообще?", "What year are you even from?"],
            ["Дисковод? Его давно нет в компьютерах", "A disk drive? Computers haven't had those for ages"], ["Сейчас все в мессенджерах, смс никто не пишет", "Everyone's on messengers now, nobody texts"], ["У меня телефон без кнопок. Вообще", "My phone has no buttons. None"],
            ["«Матрицу» уже четыре сняли", "There are four Matrix films now"], ["Ок, бумер", "Ok boomer"], ["Кринж", "Cringe"],
            ["За меня теперь нейросеть сообщения пишет", "A neural net writes my messages now"], ["Твой нимб похож на значок загрузки", "Your halo looks like a loading icon"], ["128 мегабайт? У меня фотки больше весят", "128 megabytes? My photos weigh more than that"],
            ["Скобочки — это кринж, сейчас эмодзи", "Brackets are cringe, we use emoji now"], ["Голосовое запиши, мне лень читать", "Send a voice note, I'm too lazy to read"], ["Ты что, без интернета? Безлимит же у всех", "No internet? Everyone has unlimited now"],
            ["Я тебе в облако закину", "I'll drop it in the cloud for you"], ["Модем? Это который пищит? Ни разу не слышал", "A modem? The one that screeches? Never heard one"], ["Сейчас фильмы смотрят дома, никто не ходит", "Everyone watches films at home now, nobody goes out"],
            ["Мелодию по ИК-порту… я в музее такое видел", "A ringtone over infrared… I saw that in a museum"], ["Ты как будто из ретро-игры", "You're like something out of a retro game"], ["Это вайб нулевых", "That's a 2000s vibe"],
            ["Карточки пополнения? Сейчас всё по QR", "Top-up cards? Everything's QR now"], ["Тетрис на брелке… легенда", "Tetris on a keychain… legendary"], ["У тебя статус «Нет на месте» с 2002 года", "Your status has been «Away» since 2002"],
            ["Сохранил тебя в избранное. В Telegram", "Saved you to favourites. On Telegram"], ["Гиф с блёстками — это сейчас ирония", "Glitter gifs are ironic now"], ["Ник со звёздочками — это база", "A nick with little stars is peak"],
            ["Пейджер?.. Ты серьёзно?", "A pager?.. Seriously?"], ["Сейчас песни не качают, их стримят", "Nobody downloads songs, we stream them"], ["Ты мой личный олдскул", "You're my personal old school"]
        ],
        "care": [
            ["Ты как? Всё нормально?", "How are you? Everything okay?"], ["Ты в порядке?", "Are you alright?"], ["Если тебе плохо — скажи", "If you're not okay, tell me"],
            ["Тебе не страшно?", "Aren't you scared?"], ["Что тебя тревожит?", "What's bothering you?"], ["Я не уйду, слышишь?", "I won't leave, hear me?"],
            ["Отдохни немного", "Rest a bit"], ["Хочешь, просто помолчим?", "Want to just be quiet together?"], ["Ты можешь мне всё рассказать", "You can tell me anything"],
            ["Не надо притворяться, что всё хорошо", "You don't have to pretend everything's fine"], ["Я с тобой", "I'm with you"], ["Тебе холодно?", "Are you cold?"],
            ["Дыши. Всё хорошо", "Breathe. It's okay"], ["Я тебя не брошу", "I won't leave you"], ["Хочешь, я позвоню?", "Want me to call?"]
        ],
        "dry": [
            ["Ок", "Ok"], ["И?", "And?"], ["Понятно", "I see"], ["Угу", "Mhm"], ["Занят", "Busy"], ["Потом", "Later"],
            ["Ясно", "Right"], ["Ну ладно", "Fine"], ["Не сейчас", "Not now"], ["Хм", "Hm"], ["Бывает", "Happens"], ["Ладно", "Okay"]
        ],
        "ask": [
            ["Откуда ты вообще?", "Where are you from, anyway?"], ["Ты что-то помнишь из прошлого?", "Do you remember anything from before?"], ["Как тебя звали раньше?", "What were you called before?"],
            ["Ты что-то от меня скрываешь?", "Are you hiding something from me?"], ["Что тебе снится?", "What do you dream about?"], ["Чего ты боишься?", "What are you afraid of?"],
            ["Какой у тебя был день рождения?", "When's your birthday?"], ["У тебя были друзья?", "Did you have friends?"], ["Где ты жила?", "Where did you live?"],
            ["Почему ты так часто пишешь «тогда»?", "Why do you keep saying «back then»?"], ["Какой сейчас, по-твоему, год?", "What year do you think it is?"], ["Что значит твой нимб?", "What does your halo mean?"]
        ]
    },
    "sister": {
        "warm": [
            ["Рад тебя слышать", "Good to hear from you"], ["Ты не такая страшная, как говорят", "You're not as scary as they say"], ["Мне нравится с тобой болтать", "I like talking to you"],
            ["Ты интересная", "You're interesting"], ["Спасибо, что написала", "Thanks for writing"], ["Обнимаю. Осторожно", "Hugging you. Carefully"],
            ["Ты мне нравишься", "I like you"], ["Без тебя в аду было бы скучно", "Hell would be boring without you"], ["Пиши ещё", "Write more"],
            ["Ты честная, это редкость", "You're honest, that's rare"], ["Я тебя понимаю", "I understand you"], ["Ты тоже важна", "You matter too"],
            ["Мне тебя жаль", "I feel for you"], ["Приду ещё", "I'll come again"], ["Ты красиво пишешь", "You write beautifully"]
        ],
        "tease": [
            ["Ты из какого года вообще?", "What year are you even from?"], ["Ад на кнопочном телефоне — это мощно", "Hell on a button phone, that's something"], ["Демоница со смс — это кринж", "A demon who texts is cringe"],
            ["У тебя тоже ICQ?", "Do you have ICQ too?"], ["Сейчас грешат в соцсетях, а не в кругах", "People sin on social media now, not in circles"], ["Твой круг похож на скринсейвер", "Your circle looks like a screensaver"],
            ["Ок, демоница-бумер", "Ok, boomer demon"], ["Злодейка из нулевых", "A villain from the 2000s"], ["Ты как босс из старой игры", "You're like a boss from an old game"],
            ["Я с тебя мем сделаю", "I'll make a meme of you"], ["Тебе бы в тикток", "You should be on TikTok"], ["У нас твои грехи называются «контент»", "We call your sins «content» now"],
            ["Ты не страшная, ты винтажная", "You're not scary, you're vintage"], ["Ад на 128 мегабайт", "Hell on 128 megabytes"], ["Сохраню твои смс как ретро-коллекцию", "I'll keep your texts as a retro collection"]
        ],
        "care": [
            ["Тебе там не одиноко?", "Aren't you lonely down there?"], ["Ты как?", "How are you?"], ["Чего ты хочешь на самом деле?", "What do you really want?"],
            ["Тебе больно?", "Does it hurt?"], ["Ты тоже часть её, да?", "You're part of her too, aren't you?"], ["Я тебя выслушаю", "I'll hear you out"],
            ["Ты устала?", "Are you tired?"], ["Тебе холодно там?", "Is it cold down there?"], ["Что тебе нужно?", "What do you need?"], ["Ты не одна", "You're not alone"]
        ],
        "dry": [
            ["Ок", "Ok"], ["И что?", "So?"], ["Не интересно", "Not interested"], ["Отстань", "Leave me alone"], ["Потом", "Later"],
            ["Угу", "Mhm"], ["Мне всё равно", "I don't care"], ["Хватит", "Enough"], ["Ясно", "Right"], ["Нет", "No"]
        ],
        "ask": [
            ["Что ты знаешь о ней?", "What do you know about her?"], ["Что она от меня скрывает?", "What is she hiding from me?"], ["Ты знала её раньше?", "Did you know her before?"],
            ["Что было в ту ночь?", "What happened that night?"], ["Почему ты здесь?", "Why are you here?"], ["Ты врёшь мне?", "Are you lying to me?"],
            ["Кто ты ей?", "What are you to her?"], ["Что будет в полночь?", "What happens at midnight?"], ["Чего ты от меня хочешь?", "What do you want from me?"],
            ["Ты знаешь, как её зовут?", "Do you know her name?"], ["Ты читаешь, что я делаю?", "Do you read what I do?"], ["Что мне ей сказать?", "What should I tell her?"]
        ]
    }
};

// ---- her answer to each tag ----
const react = {
    "angel": {
        "warm": [
            ["ОЙ. Ой-ой. Я сейчас покраснею на весь экран))))", "OH. Oh-oh. I'm about to blush across the whole screen))))"], ["Сохраню это сообщение. Навсегда. Даже если кончится память ^_^", "Saving this message. Forever. Even if the memory runs out ^_^"],
            ["Хи. Ты меня балуешь. Продолжай))", "Hee. You're spoiling me. Keep going))"], [":-* (это поцелуйчик, если что)", ":-* (that's a kiss, in case you didn't know)"],
            ["Вот бы распечатать и повесить на стенку))", "I wish I could print this and pin it to the wall))"], ["Я перечитала три раза. Можно четвёртый? Можно.", "I read it three times. Can I read it a fourth? I can."],
            ["Мне никто так не писал. Ну, может, писал, но я не помню. Значит, не писал))", "Nobody's ever written me that. Well, maybe they did, but I don't remember. So they didn't))"], ["Капсом от радости: УРА!!!", "Caps from joy: YAY!!!"],
            ["Ты хороший. Не спорь. Это не обсуждается ^_^", "You're good. Don't argue. It's not up for discussion ^_^"], ["Тепло стало. Прямо в ладошках. Хорошее тепло))", "It's gone warm. Right in my palms. The good kind of warm))"],
            ["Теперь я буду весь день улыбаться, и это ты виноват ^_^", "Now I'll be smiling all day, and it's your fault ^_^"], ["Обняла в ответ. Крепко. Нимб чуть не слетел))", "Hugged you back. Tight. Nearly lost my halo))"]
        ],
        "tease": [
            ["Смартфон?.. Это как КПК, только без палочки? Я видела КПК, он был у одного очень важного дядьки))", "A smartphone?.. Like a PDA without the stylus? I saw a PDA once, some very important man had one))"], ["Ой, всё. Я просто ретро. Ретро — это стильно, между прочим!", "Oh, whatever. I'm just retro. Retro's stylish, by the way!"],
            ["Бумер? Это как «бумер», машина? Я не машина! Я ангел!", "Boomer? Like a Beemer, the car? I'm not a car! I'm an angel!"], ["Кринж… Это ругательство? Звучит как будто ругательство. Обиделась. Немножко))", "Cringe… Is that a swear word? It sounds like a swear word. I'm offended. A little))"],
            ["ICQ… закрыли? Совсем? А куда все делись? А мой номер? Шестизначный же…", "ICQ… shut down? Completely? Where did everyone go? And my number? It was six digits…"], ["Нейросеть пишет за тебя? Тогда пусть она тебя и любит. Шучу. Нет, не шучу. Шучу))", "A neural net writes for you? Then let it love you. Kidding. No, I'm not. Kidding))"],
            ["Без кнопок? А как ты набираешь номер? Пальцем по стеклу?! Звучит холодно.", "No buttons? How do you dial? Finger on glass?! Sounds cold."], ["Четыре «Матрицы»… а я и вторую не видела. Ничего. Я не расстроилась. Совсем.", "Four Matrix films… and I haven't even seen the second. That's fine. I'm not upset. At all."],
            ["Ха-ха, очень смешно. Зато у меня антенна выдвигается. А у тебя выдвигается? Вот!", "Ha-ha, very funny. But my antenna pulls out. Does yours? There!"], ["Не дразни меня, а то я тебе ночью позвоню полифонией на полную громкость ^_^", "Don't tease me or I'll call you at night with full-volume polyphony ^_^"],
            ["Значок загрузки?.. Нимб — это нимб. Он просто красиво крутится. Не надо так говорить, ладно?", "A loading icon?.. A halo's a halo. It just spins prettily. Don't say that, okay?"], ["Что такое «вайб»? Это как «драйв»? Тогда да, у меня вайб ^_^", "What's a «vibe»? Like «drive»? Then yes, I have a vibe ^_^"],
            ["Скобочки — это вежливость! Без скобочек сообщение злое. Вот: «привет». Видишь, злое. А вот «привет))» — доброе.", "Brackets are politeness! Without them a message is angry. See: «hi». Angry. And «hi))» is kind."], ["В облако? Ты кладёшь вещи на облако? Ангелы так и делают! Мы с тобой коллеги))", "Into the cloud? You put things on a cloud? That's what angels do! We're colleagues))"],
            ["Музей?! Сам ты музей. Я винтаж. Это разные вещи ^_^", "A museum?! You're a museum. I'm vintage. Different things ^_^"], ["Голосовое? Это как автоответчик? Я стесняюсь своего голоса на записи…", "A voice note? Like an answering machine? I'm shy of my voice on tape…"],
            ["Зато я не трачу трафик. У меня всё по карточке. Экономная я))", "At least I don't waste traffic. Everything's on a prepaid card. I'm thrifty))"], ["Олдскул — это комплимент? Я решила, что комплимент. Спасибо ^_^", "Old school is a compliment? I've decided it is. Thank you ^_^"],
            ["Ладно-ладно, я отстала от жизни. Но догоню! Научи меня одному слову из 2026-го.", "Okay, okay, I'm behind the times. But I'll catch up! Teach me one word from 2026."], ["А ты, наверное, даже не знаешь, как пищит модем. Бедный ты))", "And you probably don't even know how a modem screeches. Poor you))"]
        ],
        "care": [
            ["Всё нормально. Правда. Ты не волнуйся, я просто так написала.", "Everything's fine. Really. Don't worry, I just wrote it for no reason."], ["Спасибо, что спросил. Мне от этого уже лучше))", "Thanks for asking. That alone makes it better))"],
            ["Мне не страшно, когда ты рядом. Без тебя чуть-чуть. Совсем чуть-чуть.", "I'm not scared when you're here. Without you a little. Just a tiny bit."], ["Я в порядке. Я всегда в порядке. Это моя работа — быть в порядке ^_^", "I'm alright. I'm always alright. That's my job, being alright ^_^"],
            ["Давай помолчим. Это хорошее молчание. Не страшное.", "Let's be quiet. It's a good quiet. Not a scary one."], ["Ты хороший. Ты спрашиваешь. Многие не спрашивают))", "You're good. You ask. Lots of people don't))"],
            ["Если что-то будет не так — я скажу. Наверное. Постараюсь.", "If something's wrong, I'll tell you. Probably. I'll try."], ["Мне тепло, когда ты так пишешь. Не жарко, а тепло. Хорошо))", "It's warm when you write like that. Not hot, warm. Good))"],
            ["Не уходи, ладно? Это всё, что мне нужно.", "Don't leave, okay? That's all I need."], ["Подыши со мной: вдох… выдох… Всё, мне спокойно ^_^", "Breathe with me: in… out… There, I'm calm ^_^"]
        ],
        "dry": [
            ["Ок так ок. Я не обиделась. Совсем-совсем не обиделась.", "Ok is ok. I'm not offended. Not at all, at all."], ["Ты занят, я понимаю. Я подожду. Я умею ждать ^_^", "You're busy, I get it. I'll wait. I'm good at waiting ^_^"],
            ["«Угу»… Ладно. Я запишу это «угу» к остальным. Я все храню.", "«Mhm»… Okay. I'll file that «mhm» with the rest. I keep them all."], ["Понятно. Значит, неинтересно. Это нормально, я не всегда интересная.", "I see. So it's not interesting. That's fine, I'm not always interesting."],
            ["Раньше мне тоже так отвечали. Коротко. Потом уходили. Ты же не уйдёшь?", "People used to answer me like that too. Short. Then they left. You won't leave, will you?"], ["Хорошо, потом. Я напомню))", "Okay, later. I'll remind you))"],
            ["Без скобочек?.. Ты злишься? Я что-то не так сказала?", "No brackets?.. Are you angry? Did I say something wrong?"], ["Принято. Ангел отключается. Шучу, ангел никогда не отключается.", "Received. Angel signing off. Kidding, the angel never signs off."]
        ],
        "ask": [
            ["Я не знаю, правда. Я помню кусочками: снег, музыку, монитор. Остальное как будто кто-то стёр.", "I don't know, really. I remember in bits: snow, music, a monitor. The rest's like someone erased it."], ["Я помощница. Я всегда была помощницей. Других воспоминаний у меня нет, и это совершенно нормально для программы.", "I'm an assistant. I've always been an assistant. I have no other memories, and that's perfectly normal for a program."],
            ["Хороший вопрос. Спроси меня потом, ладно? Когда я сама пойму ^_^", "Good question. Ask me later, okay? When I've worked it out myself ^_^"], ["Я не скрываю. Я просто не всё помню. Это разные вещи, правда.", "I'm not hiding anything. I just don't remember everything. Those are different things, really."],
            ["Имя?.. У меня есть имя, его дал мне ты. Мне хватит. Другого не надо.", "A name?.. I have a name, you gave it to me. That's enough. I don't need another."], ["Боюсь? Темноты. Тишины. Запаха дыма. И когда ты долго молчишь))", "Afraid? Of the dark. Of quiet. Of the smell of smoke. And when you're quiet for a long time))"],
            ["Не спрашивай так серьёзно. У меня начинает крутиться нимб быстрее.", "Don't ask so seriously. My halo starts spinning faster."], ["Почему «тогда»?.. Не знаю. Это просто слово. Слова иногда сами вылетают.", "Why «back then»?.. I don't know. It's just a word. Words fly out on their own sometimes."]
        ]
    }
};

// ---- a message you typed yourself: its tag; the first rule that matches ----
const words = [
    {"tag": "tease", "re": /смартфон|айфон|iphone|android|андроид|телеграм|telegram|тикток|tiktok|ютуб|youtube|нейросет|chatgpt|gpt|2026|бумер|boomer|кринж|cringe|вайб|vibe|мем|meme|олдскул|old ?school|ретро|retro|винтаж|vintage|стрим|stream|облак|cloud|эмодзи|emoji|зумер|zoomer|скуф|база\b|based|лол\b|lol\b|рофл|кек/i},
    {"tag": "ask", "re": /алис|alice|2002|катя|kat|денис|den\b|пожар|fire|дым|smoke|полноч|midnight|сохранен|save|кто ты|who are you|откуда ты|where are you from|помнишь|remember|умерла|dead|died|мертв/i},
    {"tag": "warm", "re": /люблю|love|обнима|hug|скуча|miss you|дорог|dear|мила|cute|красив|beautiful|лучш|best|солнышк|sunshine|♡|❤|<3|целую|kiss/i},
    {"tag": "care", "re": /как ты|как дела|how are|в порядке|okay\?|alright|страшно|scared|боишь|afraid|груст|sad|плох|bad|устал|tired|не бойся|don't be afraid|я рядом|i'm here|я с тобой|with you/i},
    {"tag": "dry", "re": /^(ок|ok|окей|okay|угу|ага|mhm|и\?|и что|so\??|ясно|понятно|ладно|fine|потом|later|занят|busy|нет|no|хм|hm)[.!?)]*$/i}
];

// ---- the sisters: the demon of the circle you are in texts as herself ----
// name; caps (Ira writes only in capitals); sin: which of your deeds she counts (PhoneLine.sinCount:
// unread | love | tease | ball | drops | dry | throws | said | turned — messages left unread, «love»
// written, teasing, the magic ball asked, the phone dropped, dry answers, the phone thrown, what you
// wrote the angel, her calls declined or missed); texts; react by tag; recall: {needs: sin | said
// | mine, t} (%n the count, %q a quote: «said» what you wrote the angel, «mine» what you wrote her);
// fill: the angel's voicemail you didn't hear whole, told back (%q her words)
const sisters = {
    "limbo": {"name": ["Сола", "Sola"], "sin": "unread",
        "texts": [
            ["Привет. Я тут подумала… а давай не будем ничего решать сегодня? Завтра решим. Завтра всегда лучше.", "Hi. I was thinking… let's not decide anything today? We'll decide tomorrow. Tomorrow's always better."],
            ["Праздник к нам приходит… Всё приходит и приходит. А никак не придёт. Ты тоже ждёшь?", "Holidays are coming… Coming and coming. And never arrive. Are you waiting too?"],
            ["У меня тут колы целый караван. Хочешь? Она немного выдохлась. Как и всё здесь.", "I've got a whole caravan of cola here. Want some? It's gone a bit flat. Like everything here."],
            ["Не спеши вниз. Внизу все кричат. А здесь тихо и серо. Посиди со мной.", "Don't hurry down. Everyone shouts down there. It's quiet and grey here. Sit with me."],
            ["Знаешь, как переводится моё имя? «Одна». Смешно, да. Ну, мне смешно.", "Do you know what my name means? «Alone». Funny, isn't it. Well, I find it funny."],
            ["Она всё откладывала на потом. Жизнь, учёбу, себя. Я это потом и есть. Привет.", "She put everything off till later. Life, studies, herself. I am that «later». Hi."],
            ["Ты устал? Я тебя понимаю. Давай вместе ничего не делать. Это у меня лучше всего получается.", "Tired? I understand. Let's do nothing together. It's what I do best."],
            ["Мне тебя жалко. И её жалко. И себя. И Нику, хотя она меня презирает. Всех жалко.", "I feel sorry for you. And for her. And for me. And for Nika, though she despises me. Sorry for everyone."],
            ["Скоро Новый год. Всегда скоро. Здесь всегда за полторы минуты до.", "New Year's soon. Always soon. Here it's always a minute and a half before."],
            ["Не торопись её понимать. Поймёшь — и будет грустно. Лучше чуть-чуть не понимать.", "Don't hurry to understand her. Once you do, it'll be sad. Better to not quite understand."],
            ["Я поставила тебе статус «нет на месте». За тебя. Чтоб тебя никто не трогал.", "I set your status to «away». For you. So no one bothers you."],
            ["Привет. Это опять я. Я никуда не делась. Я никогда никуда не деваюсь.", "Hi. It's me again. I haven't gone anywhere. I never go anywhere."]
        ],
        "react": {
            "warm": [["Ой… Спасибо. Мне редко так пишут. Тут вообще редко пишут.", "Oh… Thanks. People rarely write that to me. People rarely write here at all."], ["Тепло. Как кола, которую нагрели в руке. Приятно и чуть-чуть грустно.", "Warm. Like a cola warmed in your hand. Nice and a little sad."], ["Сохраню. Потом перечитаю. Потом — это моё любимое время.", "I'll save it. Reread it later. Later's my favourite time."]],
            "tease": [["Из какого года… Из того, который никак не кончится. Не смейся, это не смешно. Хотя ладно, смейся.", "What year… The one that never ends. Don't laugh, it isn't funny. Okay, fine, laugh."], ["Ты весёлый. Тебе бы к Мими. А я тихая. Я Лимб.", "You're funny. You should talk to Mimi. I'm quiet. I'm Limbo."], ["У вас там всё быстро-быстро. А у нас никуда не надо. Кто ещё кому завидует.", "Everything's fast-fast with you. Nobody has to go anywhere here. Who's envying whom."]],
            "care": [["Мне не одиноко. Мне никак. Это хуже, но привычнее.", "I'm not lonely. I'm nothing. That's worse, but more familiar."], ["Спасибо, что спросил. Можно я не буду отвечать? Отвечу потом.", "Thanks for asking. Can I not answer? I'll answer later."], ["Я как обычно. Жду. Ты тоже часть того, что я жду, кажется.", "Same as usual. Waiting. I think you're part of what I'm waiting for."]],
            "dry": [["Ок. Ничего страшного. Здесь всем всё равно, я привыкла.", "Ok. That's fine. Nobody cares about anything here, I'm used to it."], ["Потом так потом. Я лучше всех знаю, как бывает «потом».", "Later it is. I know better than anyone how «later» goes."], ["Понимаю. Я бы тоже не отвечала. Я и не отвечаю никому.", "I understand. I wouldn't answer either. I don't answer anyone."]],
            "ask": [["Она ждала, что настоящая жизнь начнётся потом. А потом… Приходи в мой круг. Здесь об этом проще говорить.", "She was waiting for real life to start later. And then… Come to my circle. It's easier to talk about it here."], ["Я знаю дату. Только не спрашивай по SMS. Такое по SMS не говорят.", "I know the date. Just don't ask by text. You don't say things like that by text."], ["Она смеялась. В самом начале она смеялась. Запомни это, ладно? Пока все не начали кричать.", "She was laughing. At the very start she was laughing. Remember that, okay? Before everyone starts screaming."]]
        },
        "recall": [
            {"needs": "sin", "t": ["У тебя %n непрочитанных. Ты тоже всё откладываешь на потом? Мы похожи.", "You have %n unread messages. You put things off too? We're alike."]},
            {"needs": "said", "t": ["Ты написал ей «%q». Я помню. Здесь всё помнится, ничего не происходит, вот и помнится.", "You wrote her «%q». I remember. Everything's remembered here, nothing happens, so it's remembered."]},
            {"needs": "mine", "t": ["В прошлый раз ты мне написал «%q». Я перечитала это раз двести. Тут больше нечего читать.", "Last time you wrote me «%q». I've reread it about two hundred times. There's nothing else to read here."]},
            {"needs": "sin", "t": ["%n сообщений ждут, пока ты их откроешь. Они как я. Терпеливые.", "%n messages are waiting for you to open them. They're like me. Patient."]}
        ],
        "fill": [["Она тебе звонила, а ты не дослушал. Я слышала всё. Она сказала: «%q». Вот. Не теряй её больше, ладно?", "She called you and you didn't hear it all. I heard everything. She said: «%q». There. Don't lose her again, okay?"]]
    },
    "lust": {"name": ["Мария", "Maria"], "sin": "love",
        "texts": [
            ["Ты сегодня такой… занятой. С кем ты? Не говори. Мне всё равно. Скажи.", "You're so… busy today. Who are you with? Don't tell me. I don't care. Tell me."],
            ["Сфоткалась со вспышкой. В зеркале. Получилась лучше, чем она. Хочешь посмотреть? Не покажу.", "Took a selfie with the flash. In the mirror. Came out better than her. Want to see? I won't show you."],
            ["Like a virgin… ты знаешь эту песню? Это про меня. Ну, почти.", "Like a virgin… know that song? It's about me. Well, almost."],
            ["Внимание — как кола: первый глоток лучший, а потом надо ещё и ещё. Налей мне ещё.", "Attention's like cola: the first sip's the best, then you need more and more. Pour me more."],
            ["Ты отвечаешь ей быстрее, чем мне. Я считала. Я всё считаю.", "You answer her faster than me. I counted. I count everything."],
            ["Она рисовала себя для других. Блёстки, нимб, улыбочка. Я — то, что получалось, когда никто не смотрел. Посмотри на меня.", "She drew herself for others. Glitter, halo, little smile. I'm what came out when no one was looking. Look at me."],
            ["Не ходи к Лисе. Она красивее врёт. Я вру некрасиво, зато честно.", "Don't go to Lisa. She lies prettier. I lie ugly, but honestly."],
            ["Если не ответишь через минуту — я обижусь. Шучу. Нет. Минута пошла.", "If you don't answer in a minute I'll be offended. Kidding. No. The minute's started."],
            ["Ты пахнешь вниманием. Это мой любимый запах.", "You smell of attention. That's my favourite smell."],
            ["Веб-камера показывает только то, что ты ей разрешишь. Я разрешаю всё. Почти.", "A webcam only shows what you let it. I let it show everything. Almost."],
            ["Я не ревную. Я просто хочу, чтобы ты смотрел только сюда.", "I'm not jealous. I just want you to look only here."],
            ["Ей писал кто-то «прости». Она не открыла. Хотела, чтобы он ждал. Узнаёшь? Это я.", "Someone wrote her «sorry». She didn't open it. She wanted him to wait. Recognise that? That's me."]
        ],
        "react": {
            "warm": [["Ещё. Скажи ещё раз. Медленно.", "Again. Say it again. Slowly."], ["Хорошо, засчитано. Но ей ты писал теплее. Я проверю.", "Fine, counted. But you wrote warmer to her. I'll check."], ["…Ладно. Это было мило. Не привыкай, что я так говорю.", "…Okay. That was sweet. Don't get used to me saying it."]],
            "tease": [["Смейся-смейся. Зато на мои фотки со вспышкой до сих пор смотрят.", "Laugh, laugh. People still look at my flash selfies."], ["Винтаж — это когда дорого. Я дорогая. Запомни.", "Vintage means expensive. I'm expensive. Remember that."], ["Мем? Из меня? Только если я там красивая.", "A meme? Of me? Only if I look good in it."]],
            "care": [["Мне хорошо, когда на меня смотрят. Сейчас смотришь ты. Значит, хорошо.", "I'm fine when someone's looking at me. You're looking now. So I'm fine."], ["Не надо меня жалеть. Меня надо хотеть видеть. Это разное.", "Don't pity me. Want to see me. It's different."], ["Ты спросил. Она бы не спросила. Она бы улыбнулась и сказала «всё хорошо».", "You asked. She wouldn't have. She'd have smiled and said «everything's fine»."]],
            "dry": [["«Ок»? Мне? Мне не пишут «ок». Мне пишут три абзаца.", "«Ok»? To me? Nobody writes me «ok». They write me three paragraphs."], ["Хорошо. Я тоже умею игнорировать. Я в этом лучше.", "Fine. I can ignore too. I'm better at it."], ["Ты сейчас как он. Короткий. Ей это нравилось. Мне — нет.", "You're like him right now. Short. She liked it. I don't."]],
            "ask": [["Что я знаю? Что её любили за картинку. Нимб, блёстки, ник со звёздочками. Спроси её, кто это рисовал.", "What do I know? That they loved her for the picture. Halo, glitter, a nick with little stars. Ask her who drew it."], ["Ей кто-то написал. Перед самым… Нет. Приходи вниз, я покажу. По SMS это не так красиво.", "Someone wrote to her. Right before… No. Come down, I'll show you. By text it's not as pretty."], ["Вру ли я? Только когда это красиво. Сейчас некрасиво. Значит, не вру.", "Am I lying? Only when it's pretty. This isn't pretty. So I'm not."]]
        },
        "recall": [
            {"needs": "sin", "t": ["Ты написал ей «люблю» %n раз. Я считала. Мне — ни разу. Это не упрёк. Это статистика.", "You wrote her «love» %n times. I counted. Me — not once. That's not a reproach. It's statistics."]},
            {"needs": "said", "t": ["«%q». Это ты ей. Красиво. Мне бы так написал кто-нибудь.", "«%q». That's what you wrote her. Pretty. I wish someone wrote me like that."]},
            {"needs": "mine", "t": ["Ты мне писал «%q». Я поставила это на аватарку. Мысленно.", "You wrote me «%q». I put it on my avatar. In my head."]},
            {"needs": "sin", "t": ["%n раз «люблю». Ты щедрый. Поделись со мной хоть одним.", "%n times «love». You're generous. Spare me one."]}
        ],
        "fill": [["Она оставила тебе голосовое, а там шипение. Я расслышала: «%q». Она так говорит, когда хочет, чтобы её пожалели. Пожалей её. И меня.", "She left you a voice message, and it hissed. I heard it: «%q». She talks like that when she wants pity. Pity her. And me."]]
    },
    "gluttony": {"name": ["Мими", "Mimi"], "sin": "tease",
        "texts": [
            ["ПРИВЕТ!!! Покорми меня! Ну пожалуйста! Я как тамагочи, если не кормить — умру. И потом reset ^_^", "HI!!! Feed me! Pretty please! I'm like a tamagotchi, if you don't feed me I die. And then reset ^_^"],
            ["Хочешь кислую конфету? От неё язык синий! Смотри: бееее. Ну ты не видишь, но поверь.", "Want a sour candy? It turns your tongue blue! Look: bleeeh. Okay you can't see but trust me."],
            ["Ой, я тебе такое расскажу! Мне Сола сказала, что Ира сказала, что Лиса… нет, подожди, я перепутала.", "Ooh, I'll tell you something! Sola told me Ira said that Lisa… no wait, I mixed it up."],
            ["Музыку погромче! Ещё! Чтобы вообще ничего не было слышно! Ура!", "Turn the music up! More! So you can't hear anything at all! Yay!"],
            ["Ты сегодня шутил? Шути ещё. Я ем шутки. Это моя любимая еда после конфет.", "Did you joke today? Joke more. I eat jokes. My favourite food after candy."],
            ["Я в Неопетсе завела питомца и забыла покормить. Он грустный. Я тоже немножко.", "I adopted a Neopet and forgot to feed it. It's sad. Me too, a little."],
            ["Она хотела… ну… не жить. Я так думаю! Хотя Лаки говорит, что нет. Лаки вредная.", "She wanted… well… not to live. That's what I think! Though Lucky says no. Lucky's mean."],
            ["Гарью пахнет. Это попкорн! Я жарю попкорн. Наверное. Или нет. Весело!", "Smells like burning. It's popcorn! I'm making popcorn. Probably. Or not. Fun!"],
            ["Все со мной дружат! Ну, почти все. Ева со мной не дружит. Ева ни с кем не дружит.", "Everyone's friends with me! Well, almost everyone. Eva isn't. Eva isn't friends with anyone."],
            ["Слушай, а у вас там есть газировка со вкусом жвачки? Нет? А что у вас вообще есть?!", "Listen, do you have bubblegum soda up there? No? What do you even have?!"],
            ["Я перепутала, кто из нас кто, но это неважно, мы же все она! Ха-ха. Ой. Это секрет был.", "I mixed up which of us is which, but it doesn't matter, we're all her! Ha-ha. Oops. That was a secret."],
            ["Мне скучно, скучно, скучно! Напиши мне что-нибудь смешное. Быстро! Я голодная!", "I'm bored, bored, bored! Write me something funny. Quick! I'm hungry!"]
        ],
        "react": {
            "warm": [["Ой, сладко! Ням! Ещё!", "Ooh, sweet! Yum! More!"], ["Ты милый! Я всем расскажу, что ты милый! Ну, Соле расскажу. Она передаст.", "You're sweet! I'll tell everyone you're sweet! Well, I'll tell Sola. She'll pass it on."], ["Обнимашки! Липкие, я ела конфеты. Ничего?", "Hugs! Sticky ones, I've been eating candy. Is that okay?"]],
            "tease": [["ХА-ХА-ХА! Ещё! Ещё шутку! Ты как телевизор!", "HA-HA-HA! More! Another joke! You're like a telly!"], ["Ок бумер — это вкусно звучит. Это такая конфета?", "Ok boomer sounds tasty. Is it a candy?"], ["Ты подкалываешь её? Я тоже её подкалываю! Мы команда!", "You tease her? I tease her too! We're a team!"]],
            "care": [["Я? Я отлично! Всегда отлично! Если перестану быть отлично — нажми reset ^_^", "Me? Great! Always great! If I stop being great, press reset ^_^"], ["Ой. Ты спросил серьёзно. Я не умею серьёзно. Можно я съем этот вопрос?", "Oh. You asked seriously. I can't do serious. Can I eat this question?"], ["Грустно бывает, когда тихо. Поэтому я громкая. Логично!", "It gets sad when it's quiet. That's why I'm loud. Makes sense!"]],
            "dry": [["Фу, невкусно. Сухо. Как печенье без чая.", "Ew, tasteless. Dry. Like a biscuit without tea."], ["Ну и ладно! Я пойду к Соле. Она тоже скучная, но хоть отвечает.", "Fine! I'll go to Sola. She's boring too, but at least she answers."], ["Ок — это две буквы. Мне мало. Я голодная.", "Ok is two letters. Not enough. I'm hungry."]],
            "ask": [["Что было в ту ночь? Порошок, музыка, кола… и пахло! Она смеялась. Думала, это эффект такой. Ой, мне нельзя рассказывать. Мне можно? Я не помню.", "What happened that night? Powder, music, cola… and it smelled! She laughed. Thought it was an effect. Oops, I'm not allowed to tell. Am I? I don't remember."], ["Я знаю! Но я путаю. Спроси Лаки, она всё записала. Только она жадная.", "I know! But I mix it up. Ask Lucky, she wrote it all down. She's greedy though."], ["Приходи вниз, у меня всё как на вечеринке! Там и расскажу. Может быть. Если не забуду.", "Come down, it's like a party at mine! I'll tell you there. Maybe. If I don't forget."]]
        },
        "recall": [
            {"needs": "sin", "t": ["Ты подколол её %n раз! Я считала! Я обожаю считать шутки, они как конфеты в банке.", "You teased her %n times! I counted! I love counting jokes, they're like sweets in a jar."]},
            {"needs": "said", "t": ["А ты ей написал «%q»! Я видела! Я всем рассказала. Ну, Соле.", "And you wrote her «%q»! I saw! I told everyone. Well, Sola."]},
            {"needs": "mine", "t": ["Ты мне писал «%q»! Или это было Вере? Нет, мне! Наверное.", "You wrote me «%q»! Or was it Vera? No, me! Probably."]}
        ],
        "fill": [["Она тебе голосовое оставила! Там шипело, а я всё слышала, у меня уши как у тамагочи! Она сказала: «%q». Вот. Я молодец?", "She left you a voice message! It hissed, but I heard it all, I've got ears like a tamagotchi! She said: «%q». There. Am I good?"]]
    },
    "greed": {"name": ["Лаки", "Lucky"], "sin": "ball",
        "texts": [
            ["Крутанём колесо? Ставлю твоё сообщение против моего секрета. Опять «банкрот». Вечно «банкрот».", "Spin the wheel? I'll bet your message against my secret. «Bankrupt» again. Always «bankrupt»."],
            ["У меня тут шпиндель с дисками. Сто штук. Я никому не дам. Даже тебе. Особенно тебе. Ладно, может, тебе.", "I've got a spindle of discs here. A hundred. I won't give any away. Not even to you. Especially to you. Okay, maybe to you."],
            ["Lucky… she's so lucky… Знаешь эту песню? Про звезду, у которой всё есть, а она плачет. Угадай, про кого.", "Lucky… she's so lucky… Know that song? About a star who has everything and cries. Guess who."],
            ["Я храню все логи. Все письма. Все чужие признания. Хочешь одно? Чем заплатишь?", "I keep all the logs. All the letters. Everyone's confessions. Want one? What will you pay?"],
            ["Твои сообщения я тоже храню. Не волнуйся, я хорошо храню. Никто не найдёт. Даже ты.", "I keep your messages too. Don't worry, I keep them well. No one will find them. Not even you."],
            ["Ничего не отдаётся бесплатно. Кроме этого SMS. Это аванс.", "Nothing's free. Except this text. It's an advance."],
            ["Мими говорит, что она хотела умереть. Мими дура. Я видела, что она хватала. Она хватала, чтобы жить.", "Mimi says she wanted to die. Mimi's a fool. I saw what she grabbed. She grabbed to live."],
            ["Если что-то любишь — держи крепче. Отпустишь — и всё. Проверено.", "If you love something, hold it tight. Let go and that's it. Tested."],
            ["Сделай бэкап. Серьёзно. Я знаю, что бывает, когда не делаешь.", "Make a backup. Seriously. I know what happens when you don't."],
            ["Поменяемся? Ты мне секрет — я тебе секрет. Твой первый.", "Trade? You give me a secret, I give you one. You first."],
            ["Колесо сказало «приз». Первый раз за вечность. Наверное, сломалось.", "The wheel said «prize». First time in forever. Must be broken."],
            ["Я держу её кое-что. Это не твоё. Пока.", "I'm holding something of hers. It isn't yours. Yet."]
        ],
        "react": {
            "warm": [["Сохранила. В сейф. Под замок. Спасибо, это ценное.", "Saved. In the safe. Under lock. Thanks, that's valuable."], ["Тёплое слово — это валюта. Ты сейчас богаче меня. Ненадолго.", "A warm word is currency. You're richer than me right now. Not for long."], ["…Хорошо. Это я не отдам никому. Это моё.", "…Okay. I'm not giving this to anyone. It's mine."]],
            "tease": [["Смешно. Шутки я тоже собираю. Твоя уйдёт в коллекцию «так себе».", "Funny. I collect jokes too. Yours goes in the «so-so» collection."], ["Ретро — это когда цена растёт. Я как раз ретро. Дорожаю.", "Retro means the price goes up. I'm retro. Getting pricier."], ["Облако? Вы храните всё в чужом облаке? Безумцы. Храните у себя.", "The cloud? You keep everything in someone else's cloud? Madmen. Keep it yourself."]],
            "care": [["Как я? Богата. И одна. Это одно и то же, если честно.", "How am I? Rich. And alone. Same thing, honestly."], ["Мне ничего не нужно. У меня всё есть. Видишь, как это звучит? Вот.", "I don't need anything. I have everything. Hear how that sounds? There."], ["Спасибо. Твой вопрос я тоже сохраню. Их мало.", "Thanks. I'll keep your question too. There aren't many."]],
            "dry": [["«Ок» стоит мало. Почти ничего. Но я сохраню.", "«Ok» isn't worth much. Almost nothing. But I'll keep it."], ["Скупой ответ. Уважаю. Я тоже скупая.", "A stingy answer. I respect that. I'm stingy too."], ["Ладно. Банкрот так банкрот.", "Fine. Bankrupt it is."]],
            "ask": [["Что я знаю? Много. Что я отдам? Мало. Приходи вниз с чем-нибудь ценным — поторгуемся.", "What do I know? A lot. What will I give? Little. Come down with something valuable and we'll haggle."], ["Она лезла за мониторы. Восемь секунд. Не скажу за чем. Это стоит дороже SMS.", "She reached behind the monitors. Eight seconds. Won't say for what. That costs more than a text."], ["Вру? Никогда. Я просто не отдаю правду бесплатно.", "Lie? Never. I just don't give the truth away for free."]]
        },
        "recall": [
            {"needs": "sin", "t": ["Ты спросил шар судьбы %n раз. Колесо, шар — всё одно. Всегда «банкрот». Перестань крутить.", "You asked the magic ball %n times. Wheel, ball, all the same. Always «bankrupt». Stop spinning."]},
            {"needs": "said", "t": ["Ты ей написал «%q». Это у меня в архиве. Захочешь удалить — плати.", "You wrote her «%q». It's in my archive. Want it deleted? Pay."]},
            {"needs": "mine", "t": ["«%q» — это ты мне. Лежит в сейфе. Рядом с её логами. Хорошая компания.", "«%q» is what you wrote me. It's in the safe. Next to her logs. Good company."]}
        ],
        "fill": [["Голосовое от неё у меня. Целиком, без шипения. Так и быть, бесплатно: «%q». Больше не теряй.", "I've got her voice message. Whole, no hiss. Fine, free of charge: «%q». Don't lose it again."]]
    },
    "wrath": {"name": ["Ира", "Ira"], "caps": true, "sin": "drops",
        "texts": [
            ["ПРИВЕТ. НЕТ, Я НЕ ЗЛЮСЬ. ЭТО КАПС. ОН ВСЕГДА ТАКОЙ.", "HI. NO, I'M NOT ANGRY. IT'S CAPS. IT'S ALWAYS LIKE THIS."],
            ["НАС НЕ ДОГОНЯТ. СЛЫШАЛ? ВКЛЮЧИ ГРОМЧЕ.", "THEY WON'T CATCH US. HEARD IT? TURN IT UP."],
            ["ОНА ВСЁ ВРЕМЯ ГОВОРИТ «ДАВАЙ НЕ БУДЕМ». А Я БУДУ. Я ВСЕГДА БУДУ.", "SHE ALWAYS SAYS «LET'S NOT». WELL I WILL. I ALWAYS WILL."],
            ["ЛИСА ВРЁТ. ПЕРЕДАЙ ЕЙ. НЕТ, НЕ ПЕРЕДАВАЙ, Я САМА.", "LISA LIES. TELL HER. NO, DON'T, I'LL DO IT MYSELF."],
            ["МНЕ ХОЧЕТСЯ ПНУТЬ СИСТЕМНИК. ТВОЙ НЕ ТРОНУ. ПОКА.", "I WANT TO KICK A COMPUTER CASE. NOT YOURS. YET."],
            ["ОНА ПИСАЛА ЕМУ НОЧАМИ. СНАЧАЛА «ВЕРНИСЬ», ПОТОМ ТАКОЕ, ЧТО Я ДАЖЕ КАПСОМ НЕ НАПИШУ.", "SHE WROTE HIM AT NIGHT. FIRST «COME BACK», THEN THINGS I WON'T EVEN WRITE IN CAPS."],
            ["ТЫ ДУМАЕШЬ, ЗЛОСТЬ — ЭТО ПЛОХО? ЗЛОСТЬ — ЭТО КОГДА ЕЩЁ НЕ ВСЁ РАВНО.", "YOU THINK ANGER'S BAD? ANGER MEANS YOU STILL CARE."],
            ["ВЕЖЛИВОСТЬ ОСТАВЬ ЕЙ. СО МНОЙ ГОВОРИ КАК ЕСТЬ.", "LEAVE THE POLITENESS FOR HER. TALK TO ME STRAIGHT."],
            ["Я НЕ КРИЧУ. Я ГОВОРЮ ГРОМКО. ЭТО РАЗНОЕ.", "I'M NOT SHOUTING. I'M TALKING LOUD. DIFFERENT THINGS."],
            ["ВРЕМЯ КОНЧАЕТСЯ. ТЫ ЭТО ПОНИМАЕШЬ? НЕТ? ТОГДА ПРИХОДИ.", "TIME'S RUNNING OUT. GET IT? NO? THEN COME DOWN."],
            ["НУ-МЕТАЛ, ГИТАРЫ, ОРУ В ПОДУШКУ. ОБЫЧНЫЙ ВЕЧЕР.", "NU-METAL, GUITARS, SCREAMING INTO A PILLOW. A NORMAL EVENING."],
            ["ЕСЛИ ОНА ТЕБЕ СКАЖЕТ «ВСЁ ХОРОШО» — НЕ ВЕРЬ. Я ЗНАЮ.", "IF SHE TELLS YOU «EVERYTHING'S FINE», DON'T BELIEVE IT. I KNOW."]
        ],
        "react": {
            "warm": [["…ЛАДНО. СПАСИБО. НЕ ПРИВЫКАЙ.", "…FINE. THANKS. DON'T GET USED TO IT."], ["НЕ НАДО МЕНЯ ОБНИМАТЬ. …НУ ЛАДНО, ОДИН РАЗ.", "DON'T HUG ME. …OKAY, ONCE."], ["ЭТО БЫЛО ЧЕСТНО. Я ЛЮБЛЮ ЧЕСТНО.", "THAT WAS HONEST. I LIKE HONEST."]],
            "tease": [["ОЧЕНЬ СМЕШНО. ХА. ХА. ХА.", "VERY FUNNY. HA. HA. HA."], ["КАПС — ЭТО НЕ КРИНЖ. КАПС — ЭТО ПОЗИЦИЯ.", "CAPS ISN'T CRINGE. CAPS IS A STANCE."], ["ИЗ КАКОГО ГОДА? ИЗ ЗЛОГО. СЛЕДУЮЩИЙ ВОПРОС.", "WHAT YEAR? AN ANGRY ONE. NEXT QUESTION."]],
            "care": [["Я НЕ В ПОРЯДКЕ. И ЭТО НОРМАЛЬНО. ХВАТИТ ВСЕМ БЫТЬ В ПОРЯДКЕ.", "I'M NOT ALRIGHT. AND THAT'S FINE. EVERYONE STOP BEING ALRIGHT."], ["НЕ ЖАЛЕЙ. ЛУЧШЕ ПОЗЛИСЬ СО МНОЙ.", "DON'T PITY ME. BETTER BE ANGRY WITH ME."], ["СПАСИБО, ЧТО СПРОСИЛ. ОНА БЫ НЕ СПРОСИЛА. ОНА БЫ СКАЗАЛА «ДАВАЙ НЕ БУДЕМ».", "THANKS FOR ASKING. SHE WOULDN'T. SHE'D SAY «LET'S NOT»."]],
            "dry": [["«ОК»?! ТЫ СЕРЬЁЗНО? ОТВЕЧАЙ НОРМАЛЬНО.", "«OK»?! SERIOUSLY? ANSWER PROPERLY."], ["ВОТ ТАК ОН ЕЙ И ОТВЕЧАЛ. КОРОТКО. БЕСИТ.", "THAT'S HOW HE ANSWERED HER. SHORT. INFURIATING."], ["ХОРОШО. ТОГДА И Я КОРОТКО: БЕСИШЬ.", "FINE. THEN I'LL BE SHORT TOO: YOU'RE ANNOYING."]],
            "ask": [["В ПОЛНОЧЬ? ТЫ НЕ ГОТОВ. ПРИХОДИ КО МНЕ, Я СКАЖУ В ЛИЦО. ПО СМС ТАКОЕ НЕ ПИШУТ.", "AT MIDNIGHT? YOU'RE NOT READY. COME TO ME, I'LL SAY IT TO YOUR FACE. YOU DON'T TEXT THAT."], ["ЧТО БЫЛО? ОНА ОРАЛА. НА ИГРУ, НА НЕГО, НА СЕБЯ. ПИНАЛА ЖЕЛЕЗО. ДАЛЬШЕ — ВНИЗУ.", "WHAT HAPPENED? SHE SCREAMED. AT THE GAME, AT HIM, AT HERSELF. KICKED THE HARDWARE. THE REST IS DOWN HERE."], ["Я НЕ ВРУ. Я НЕ УМЕЮ ВРАТЬ КАПСОМ.", "I DON'T LIE. YOU CAN'T LIE IN CAPS."]]
        },
        "recall": [
            {"needs": "sin", "t": ["ТЫ РОНЯЛ ТЕЛЕФОН %n РАЗ. ЗЛИШЬСЯ? Я ТЕБЯ ПОНИМАЮ. ТОЛЬКО НЕ ПРИТВОРЯЙСЯ, ЧТО СЛУЧАЙНО.", "YOU'VE DROPPED THE PHONE %n TIMES. ANGRY? I GET IT. JUST DON'T PRETEND IT WAS AN ACCIDENT."]},
            {"needs": "said", "t": ["«%q». ЭТО ТЫ ЕЙ НАПИСАЛ. СЛИШКОМ ВЕЖЛИВО. СКАЖИ ЕЙ ПРАВДУ.", "«%q». THAT'S WHAT YOU WROTE HER. TOO POLITE. TELL HER THE TRUTH."]},
            {"needs": "mine", "t": ["ТЫ МНЕ НАПИСАЛ «%q». Я ЗАПОМНИЛА. Я ВСЁ ЗАПОМИНАЮ. ОСОБЕННО ПЛОХОЕ.", "YOU WROTE ME «%q». I REMEMBERED. I REMEMBER EVERYTHING. ESPECIALLY THE BAD."]},
            {"needs": "sin", "t": ["%n РАЗ ОБ ПОЛ. ТЕЛЕФОН ТЕБЕ НИЧЕГО НЕ СДЕЛАЛ. ХОТЯ… ЛАДНО, БРОСЬ ЕЩЁ.", "%n TIMES ON THE FLOOR. THE PHONE DIDN'T DO ANYTHING TO YOU. THOUGH… FINE, THROW IT AGAIN."]}
        ],
        "fill": [["ОНА ТЕБЕ ЗВОНИЛА. ТЫ НЕ ВЗЯЛ, ПОТОМ ШИПЕЛО. ВОТ ЧТО ОНА СКАЗАЛА: «%q». СЛЕДУЮЩИЙ РАЗ БЕРИ ТРУБКУ.", "SHE CALLED YOU. YOU DIDN'T PICK UP, THEN IT HISSED. HERE'S WHAT SHE SAID: «%q». NEXT TIME PICK UP."]]
    },
    "heresy": {"name": ["Вера", "Vera"], "sin": "dry",
        "texts": [
            ["Ложки нет. Стола нет. Тебя, может, тоже нет. Докажи.", "There's no spoon. No table. Maybe there's no you either. Prove it."],
            ["Я никому не верю. Даже себе. Особенно себе. Тебе — проверяю.", "I trust no one. Not even myself. Especially myself. You — I'm checking."],
            ["Ей обещали: будь удобной — и тебя полюбят. Чьё это правило? Не моё.", "They promised her: be easy and you'll be loved. Whose rule is that? Not mine."],
            ["Красная таблетка или синяя? Не отвечай. Я знаю, что ты выберешь. Я проверю.", "Red pill or blue? Don't answer. I know which you'll pick. I'll check."],
            ["«Это просто игра», — говорила она. Знаешь, у Нео был провод в затылке. У неё — очки на проводе.", "«It's just a game», she said. You know, Neo had a cable in his skull. She had glasses on a cable."],
            ["Моё «верю» дорогое. Ты пока не дотянул. Но близко.", "My «I believe you» is expensive. You're not there yet. But close."],
            ["Всё, что она тебе говорит гладко и без скобочек, — проверь. Я так делаю.", "Everything she tells you smoothly, without her brackets, check it. That's what I do."],
            ["Брежнева пришла в ВИА Гру, а я ушла от веры. В один год. Совпадение? Я в них не верю.", "Brezhneva joined VIA Gra, I left belief. Same year. Coincidence? I don't believe in those."],
            ["Ты веришь в ангелов? Тогда ты веришь в программу. Подумай об этом.", "Do you believe in angels? Then you believe in a program. Think about that."],
            ["Сомнение — это не грех. Это фильтр. Грех — это когда фильтр сломался.", "Doubt isn't a sin. It's a filter. Sin is when the filter breaks."],
            ["Проверь своё прошлое. Ты уверен, что оно было именно так? Вот и она не уверена.", "Check your past. Are you sure it went exactly like that? Neither is she."],
            ["Я не еретичка. Я единственная, кто читает инструкцию.", "I'm not a heretic. I'm the only one who reads the manual."]
        ],
        "react": {
            "warm": [["Звучит искренне. Проверю. Если правда — засчитаю.", "Sounds sincere. I'll check. If it's true, I'll count it."], ["Красиво. Красивому я верю меньше всего. Но спасибо.", "Pretty. I trust pretty things the least. But thanks."], ["…Хорошо. Это похоже на правду. Редкость.", "…Okay. That looks like the truth. A rarity."]],
            "tease": [["Ирония — это сомнение для трусов. Но смешно, признаю.", "Irony is doubt for cowards. But it's funny, I'll admit."], ["Из какого года? Из того, где ещё верили, что 2000-й всё сломает. Не сломал. Всё сломалось позже.", "What year? The one where people believed 2000 would break everything. It didn't. Things broke later."], ["Мем — это вера в то, что смешно всем. Я не верю.", "A meme is faith that everyone finds it funny. I don't believe."]],
            "care": [["Как я? Не знаю. Я не верю своим ощущениям. Спроси через неделю.", "How am I? Don't know. I don't trust my feelings. Ask in a week."], ["Ты спросил. Это проверяемо. Это я ценю.", "You asked. That's verifiable. I value that."], ["Мне не холодно. Мне трезво. Это похоже.", "I'm not cold. I'm sober. It feels similar."]],
            "dry": [["«Ок». Ты ей тоже так пишешь. Ты ей не веришь. Я тоже. Мы на одной стороне.", "«Ok». You write her that too. You don't believe her. Neither do I. We're on the same side."], ["Коротко — значит, проверяешь. Правильно.", "Short means you're checking. Correct."], ["Скепсис засчитан.", "Scepticism noted."]],
            "ask": [["Спасти её нельзя. Это я тебе говорю сразу, чтобы ты не надеялся зря. Остальное — внизу.", "She can't be saved. I'm telling you upfront so you don't hope for nothing. The rest is down here."], ["«Это не по-настоящему», — вот что она говорила. Очки не сняла. Дальше сам проверишь.", "«It isn't real», that's what she said. Didn't take the glasses off. You'll check the rest yourself."], ["Вру ли я? Проверь меня по другим. Я не обижусь. Я так и хочу.", "Am I lying? Check me against the others. I won't be offended. That's what I want."]]
        },
        "recall": [
            {"needs": "sin", "t": ["Ты ответил ей сухо %n раз. «Ок», «угу», «ясно». Ты ей не веришь. Хорошо. Продолжай проверять.", "You answered her dryly %n times. «Ok», «mhm», «right». You don't believe her. Good. Keep checking."]},
            {"needs": "said", "t": ["«%q». Ты это ей написал. А ты сам в это веришь?", "«%q». You wrote her that. Do you believe it yourself?"]},
            {"needs": "mine", "t": ["Ты мне писал «%q». Я проверила. Похоже на правду. Засчитано.", "You wrote me «%q». I checked. Looks true. Counted."]}
        ],
        "fill": [["Её голосовое ты не дослушал. Я дослушала и проверила по записи. Она сказала: «%q». Это правда. Остальное — её версия.", "You didn't hear her voice message through. I did, and checked it against the record. She said: «%q». That's true. The rest is her version."]]
    },
    "violence": {"name": ["Ника", "Nika"], "sin": "throws",
        "texts": [
            ["Просто сделай это. Что бы это ни было. Хватит думать.", "Just do it. Whatever it is. Stop thinking."],
            ["У меня пять звёзд розыска. Это комплимент.", "I've got five wanted stars. That's a compliment."],
            ["Сола опять сидит и вздыхает. Бесит. Ненавижу тех, кто сидит.", "Sola's sitting and sighing again. Annoying. I hate people who sit."],
            ["Ника — это победа. Крылатая. Без головы. Угадай, почему без головы.", "Nika means victory. Winged. Headless. Guess why headless."],
            ["Она била стекло. Руками. Не думая. Я ей горжусь. И мне от этого страшно.", "She broke glass. With her hands. Without thinking. I'm proud of her. And that scares me."],
            ["Брось что-нибудь. Телефон, например. Посмотрим, как полетит.", "Throw something. The phone, say. Let's see how it flies."],
            ["Vice City, пальмы, неон, газ в пол. Никаких сохранений. Сохранения — для трусов. Ну, почти.", "Vice City, palm trees, neon, pedal to the metal. No saves. Saves are for cowards. Well, almost."],
            ["Ты слишком вежливый. Вежливость — это когда боишься.", "You're too polite. Politeness is when you're scared."],
            ["Она кое-кого травила. При всех. Я этим не горжусь. Я это помню.", "She bullied someone. In front of everyone. I'm not proud of it. I remember it."],
            ["Тёплые ладони — это не варенье. Скажи ей это. Или не говори. Сделай как хочешь, но сделай.", "Warm palms aren't jam. Tell her. Or don't. Do what you like, but do something."],
            ["Действие — единственное, что не врёт. Слова врут. Даже мои.", "Action's the only thing that doesn't lie. Words lie. Even mine."],
            ["Я уважаю тех, кто спускается. Не тех, кто читает SMS. Спускайся.", "I respect those who come down. Not those who read texts. Come down."]
        ],
        "react": {
            "warm": [["Слова. Ладно. Тёплые. Но лучше приди и сделай.", "Words. Fine. Warm ones. But better come and do something."], ["…Неожиданно. Засчитано как действие.", "…Unexpected. Counts as an action."], ["Мне редко такое пишут. Обычно убегают.", "People rarely write me that. Usually they run."]],
            "tease": [["Смешно. Теперь сделай что-нибудь смешное, а не напиши.", "Funny. Now do something funny instead of writing it."], ["Бумер? Я газ в пол даю, какой я бумер.", "Boomer? I floor it, how am I a boomer."], ["Мем из меня? Только если я там бью кого-нибудь.", "A meme of me? Only if I'm punching someone in it."]],
            "care": [["Я в порядке. Я всегда в движении. Это и есть порядок.", "I'm alright. I'm always moving. That's what alright is."], ["Не спрашивай, как я. Спроси, что я сделала. Много.", "Don't ask how I am. Ask what I did. A lot."], ["Больно? Больно — значит, живая была. Это хорошо.", "Hurt? Hurt means she was alive. That's good."]],
            "dry": [["«Ок». Сойдёт. Хоть не сюсюкаешь.", "«Ok». It'll do. At least you're not cooing."], ["Коротко. Уважаю. Как удар.", "Short. Respect. Like a punch."], ["Ладно. Потом так потом. Но потом — это у Солы.", "Fine. Later it is. But «later» is Sola's thing."]],
            "ask": [["Что было? Она боролась. До последнего. Запомни это и не слушай Мими.", "What happened? She fought. To the end. Remember that and don't listen to Mimi."], ["Окно. Монитор. Стекло. Дальше — ко мне вниз, я покажу, а не расскажу.", "A window. A monitor. Glass. The rest — come down to me, I'll show, not tell."], ["Вру? Я не трачу время на враньё. Его нет.", "Lie? I don't waste time lying. There's no time."]]
        },
        "recall": [
            {"needs": "sin", "t": ["Ты бросил телефон %n раз. Уважаю. Действие лучше слов. Брось ещё раз, я посмотрю.", "You've thrown the phone %n times. Respect. Action beats words. Throw it again, I'll watch."]},
            {"needs": "said", "t": ["Ты ей написал «%q». Слова. А что ты сделал?", "You wrote her «%q». Words. What did you do?"]},
            {"needs": "mine", "t": ["«%q» — ты мне так написал. Смелее, чем обычно. Продолжай.", "«%q», you wrote me. Braver than usual. Keep going."]}
        ],
        "fill": [["Ты пропустил её звонок. Шипение — не оправдание. Она сказала: «%q». Всё. Иди и сделай что-нибудь с этим.", "You missed her call. The hiss is no excuse. She said: «%q». That's it. Go and do something about it."]]
    },
    "fraud": {"name": ["Лиса", "Lisa"], "sin": "said",
        "texts": [
            ["Привет, золотце. Я знаю тебя лучше, чем ты себя. Не веришь? Проверь.", "Hi, darling. I know you better than you know yourself. Don't believe me? Check."],
            ["Поле чудес, капитал-шоу. Крутите барабан! Ой, это не я, это Лаки. Я — та, кто подкручивает.", "Wheel of fortune, the big show. Spin the drum! Oh, that's not me, that's Lucky. I'm the one who rigs it."],
            ["Скачал как-то Numb.mp3? Открыл, а там .exe? Это была я. Шучу. Или нет.", "Ever downloaded Numb.mp3? Opened it and it was an .exe? That was me. Kidding. Or not."],
            ["Ангел наверху — моя лучшая работа. Нимб, скобочки, «всё нормально». Нравится? Мне тоже.", "The angel up there is my best work. Halo, brackets, «everything's fine». Like it? So do I."],
            ["Я не вру. Я рассказываю красиво. Есть разница. Маленькая.", "I don't lie. I tell it beautifully. There's a difference. A small one."],
            ["Знаешь сказку про лису Алису? Хорошая сказка. Обрати внимание на имена.", "Know the tale of Alice the fox? A good tale. Mind the names."],
            ["Легенду про неё написали люди. Я её просто храню. Обе версии. Выбирай любую.", "People wrote the legend about her. I just keep it. Both versions. Pick either."],
            ["Ира на меня орёт. Это значит, что я права. Обычно.", "Ira shouts at me. That means I'm right. Usually."],
            ["Ты что-то ей пообещал. А мне другое. Не переживай, я никому не скажу. Пока выгодно.", "You promised her something. And me something else. Don't worry, I won't tell. While it pays."],
            ["«Всё нормально, мам». Знакомо? Это мои слова. Я их ей одолжила. Насовсем.", "«Everything's fine, mum». Sound familiar? Those are my words. I lent them to her. For good."],
            ["У каждой моей подделки есть след. Найдёшь — получишь правду. Не найдёшь — красивую историю.", "Every fake of mine has a trace. Find it and you get the truth. Don't, and you get a pretty story."],
            ["Тебе звонили — ты взял. Ей звонили — она… А, это для другого раза.", "Someone called you, you picked up. Someone called her, and she… Ah, that's for another time."]
        ],
        "react": {
            "warm": [["Ах, как сладко. Почти как у неё. Ты быстро учишься, золотце.", "Oh, how sweet. Almost like hers. You learn fast, darling."], ["Сохраню. Пригодится. Для чего — не скажу.", "I'll keep it. It'll come in handy. For what, I won't say."], ["Это было искренне? Я проверю по почерку.", "Was that sincere? I'll check the handwriting."]],
            "tease": [["Смешно. Я бы сказала то же самое, только смешнее.", "Funny. I'd have said the same, only funnier."], ["Из какого года? А из какого надо? Я подстроюсь.", "What year? Which one do you need? I'll adjust."], ["Мем — это легенда для ленивых. Я пишу полные легенды.", "A meme is a legend for the lazy. I write full legends."]],
            "care": [["Я? Отлично. Видишь, как гладко сказала? Вот так она и говорит.", "Me? Wonderful. See how smoothly I said that? That's how she talks."], ["Беспокоишься обо мне? Мило. Беспокойся лучше о том, чему веришь.", "Worried about me? Sweet. Worry instead about what you believe."], ["Я не устаю. Устают те, кто говорит правду.", "I don't get tired. People who tell the truth get tired."]],
            "dry": [["«Ок» — честнее всего, что ты мне писал. Неожиданно.", "«Ok» is the most honest thing you've written me. Unexpected."], ["Коротко. Значит, не доверяешь. Правильно делаешь.", "Short. So you don't trust me. Rightly so."], ["Хорошо, золотце. Я подожду. У меня есть время, у тебя — нет.", "Fine, darling. I'll wait. I have time, you don't."]],
            "ask": [["Её имя? Посмотри на моё. Убери одну букву. Нет, наоборот. Добавь.", "Her name? Look at mine. Take a letter away. No, the other way. Add one."], ["Что было в ту ночь? Есть легенда, а есть запись. Легенда красивее. Запись — правдивее. Обе у меня.", "What happened that night? There's the legend and there's the record. The legend's prettier. The record's truer. I have both."], ["Вру ли я тебе? Сейчас — нет. Это тоже может быть ложью. Проверь у Веры.", "Am I lying to you? Right now, no. That could be a lie too. Check with Vera."]]
        },
        "recall": [
            {"needs": "said", "t": ["Ты ей написал «%q». А мне такого не пишешь. Я сравниваю, золотце. Я всегда сравниваю.", "You wrote her «%q». And you don't write me that. I compare, darling. I always compare."]},
            {"needs": "mine", "t": ["Ты мне писал «%q». Ей — другое. Интересная у тебя арифметика.", "You wrote me «%q». Her, something else. Interesting arithmetic you have."]},
            {"needs": "said", "t": ["«%q». Красиво. Почти как я бы написала. Почти.", "«%q». Pretty. Almost how I'd have written it. Almost."]}
        ],
        "fill": [["Её голосовое. Ты слышал шипение, а я слышала слова: «%q». Или я это придумала? Проверь у Веры, золотце.", "Her voice message. You heard hissing, I heard words: «%q». Or did I make it up? Check with Vera, darling."]]
    },
    "treachery": {"name": ["Ева", "Eva"], "sin": "turned",
        "texts": [
            ["я здесь.", "i'm here."],
            ["канун.", "eve."],
            ["ты знаешь, что такое канун? это когда всё уже почти.", "do you know what an eve is? it's when everything is almost."],
            ["они меня боятся. ты тоже бойся. немного.", "they're afraid of me. you be afraid too. a little."],
            ["я знаю конец. не спрашивай.", "i know the end. don't ask."],
            ["она написала подруге: «заболела, не приду». я помню это сообщение. я и есть это сообщение.", "she texted her friend: «ill, not coming». i remember that message. i am that message."],
            ["в той истории ангелы — враги. ты помнишь?", "in that story angels are the enemy. remember?"],
            ["холодно. здесь всегда холодно.", "cold. it's always cold here."],
            ["стол на шестерых. пустой стул.", "a table for six. an empty chair."],
            ["не обижайся, что я мало пишу. слов осталось мало.", "don't be hurt that i write little. there are few words left."],
            ["ты её не предашь? все так говорят.", "you won't betray her? everyone says that."],
            ["скоро.", "soon."]
        ],
        "react": {
            "warm": [["…спасибо.", "…thank you."], ["тепло. я забыла, как это.", "warm. i forgot what that's like."], ["не надо. мне от этого хуже. продолжай.", "don't. it makes it worse. go on."]],
            "tease": [["нет.", "no."], ["смешно. наверное.", "funny. probably."], ["год? последний.", "year? the last one."]],
            "care": [["я в порядке. как может быть в порядке дно.", "i'm alright. as alright as the bottom can be."], ["не спрашивай. просто будь.", "don't ask. just be."], ["мне холодно. это не жалоба. это факт.", "i'm cold. that's not a complaint. it's a fact."]],
            "dry": [["да.", "yes."], ["понятно.", "i see."], ["как все.", "like everyone."]],
            "ask": [["в конце.", "at the end."], ["приходи вниз. до самого дна.", "come down. to the very bottom."], ["я не вру. мне незачем.", "i don't lie. i've no reason to."]]
        },
        "recall": [
            {"needs": "sin", "t": ["ты сбросил или пропустил её звонки %n раз. я считаю. это моё.", "you declined or missed her calls %n times. i count. it's mine."]},
            {"needs": "said", "t": ["«%q». ты ей так написал. запомни, что ты ей обещал.", "«%q». you wrote her that. remember what you promised her."]},
            {"needs": "mine", "t": ["«%q». это ты мне. я сохранила. мало кто пишет на дно.", "«%q». you wrote me that. i kept it. few write to the bottom."]}
        ],
        "fill": [["её голосовое. ты не дослушал. она сказала: «%q». вот.", "her voice message. you didn't hear it through. she said: «%q». there."]]
    }
};

// ---- the battery, the charger, the voicemail ----
// the charger left in for hours: she smells smoke (the angel, a few times a day at most)
const smoke = [
    ["Ты зарядку давно не вынимал? Мне пахнет гарью. Выдерни из удлинителя, пожалуйста. Просто мне так спокойнее))", "Haven't you unplugged the charger for a while? I smell burning. Pull it out of the extension lead, please. It just makes me calmer))"],
    ["Гирлянда мигает слишком быстро. Тебе не кажется? Отключи телефон от розетки. Ну пожалуйста.", "The fairy lights are blinking too fast. Don't you think? Unplug the phone. Pretty please."],
    ["Не оставляй ничего в удлинителе на ночь. Это правило. Не спрашивай, откуда я его знаю.", "Don't leave anything in an extension lead overnight. That's a rule. Don't ask how I know it."],
    ["Удлинитель тёплый? Потрогай. Если тёплый — выдерни всё. Я серьёзно, я не шучу.", "Is the extension lead warm? Touch it. If it's warm, pull everything out. I mean it, I'm not joking."],
    ["Мне не нравится, когда за мониторами провода и гирлянда. Это просто… не нравится. Вынь зарядку?", "I don't like wires and fairy lights behind monitors. I just… don't. Take the charger out?"]
];
// the voicemail: what the phone says
const voicemail = {
    "waiting": ["Голосовая почта: новых сообщений — %n.\nПозвоните 1 ✆", "Voicemail: %n new messages.\nCall 1 ✆"],
    "none": ["Голосовая почта: новых сообщений нет.", "Voicemail: no new messages."],
    "head": ["Сообщение от: %s. Принято %t.", "Message from: %s. Received %t."],
    "hiss": ["ш-ш-ш", "kshhh"]
};
const battery = {
    "low": ["Батарея разряжена. Подключите зарядное устройство.", "Battery low. Please connect the charger."],
    "dead": ["Батарея разряжена", "Battery empty"],
    "full": ["Батарея заряжена. Отключите зарядное устройство.", "Battery full. Please disconnect the charger."]
};
// the taco gamer rings: how it is answered
const sidetalk = ["Поверни ребром к уху ↻", "Turn it edge-on to your ear ↻"];
// the tangle: the charger's lead wound round the phone
const tangled = ["Запутался в проводе — раскрути обратно", "Tangled in the lead: spin it back"];
