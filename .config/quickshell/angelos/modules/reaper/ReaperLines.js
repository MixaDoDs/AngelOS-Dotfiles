.pragma library

// What is said in «Смерть на смене» (ReaperWindow): the talk before each day (the Boss on the
// monitor, the colleagues coming in through the back door), the Boss after a shift, and what a
// soul says when it floats up — by what it carries. Each line {who, ru, en}.

// who: name, colour (ReaperArt.colors), sprite (ReaperArt.people; the Boss is the eye, Death is you)
const cast = {
    "boss": { "ru": "Шеф", "en": "The Boss", "c": "r" },
    "death": { "ru": "Смерть", "en": "Death", "c": "V" },
    "plague": { "ru": "Чума", "en": "Pestilence", "c": "B" },
    "famine": { "ru": "Голод", "en": "Famine", "c": "t" },
    "war": { "ru": "Война", "en": "War", "c": "r" }
};

function L(who, ru, en) {
    return { "who": who, "ru": ru, "en": en };
}

// day N's talk: it brings in the day's new rule (ReaperCore.rules)
const days = {
    1: [
        L("boss", "Смерть. Наконец-то. Души копятся в коридоре уже третье тысячелетие.", "Death. At last. The souls have been piling up in the hall for three millennia."),
        L("boss", "Работа простая: налево — Рай, направо — Ад.", "The job is simple: left is Heaven, right is Hell."),
        L("boss", "С ножом — в Ад. Все остальные — в Рай. Справится даже скелет.", "Knife — Hell. Everyone else — Heaven. Even a skeleton could do it."),
        L("death", "А премия будет?", "Is there a bonus?"),
        L("boss", "Премия — это вечность. Работай.", "The bonus is eternity. Get to work.")
    ],
    2: [
        L("plague", "Привет, новенькая! Я Чума. Не бойся, я больше не заразная.", "Hi, new girl! I'm Pestilence. Don't worry, I'm not contagious anymore."),
        L("plague", "Шеф велел передать: у кого нимб — в Рай. Даже если с ножом.", "The Boss says: a halo goes to Heaven. Even with a knife."),
        L("death", "Святой с ножом?", "A saint with a knife?"),
        L("plague", "Колбасу резал. Не задавай вопросов — их потом пишут в отчёт.", "Slicing sausage. Don't ask questions, they end up in a report.")
    ],
    3: [
        L("boss", "Пошли рогатые. Рога — в Ад.", "Here come the horned ones. Horns go to Hell."),
        L("boss", "Но нимб важнее рогов. Смотри в памятку: что выше, то и решает.", "But a halo beats horns. Check the memo: the higher rule decides."),
        L("death", "Кто вообще носит нимб и рога сразу?", "Who wears a halo and horns at once?"),
        L("boss", "Менеджеры среднего звена.", "Middle management.")
    ],
    4: [
        L("famine", "Привет... У тебя не найдётся чего-нибудь поесть?", "Hi... You wouldn't have anything to eat?"),
        L("death", "Я Смерть. У меня только коса.", "I'm Death. All I have is a scythe."),
        L("famine", "Жаль. Шеф сказал: с бутылкой — в Ад. Пить на том свете нельзя.", "Pity. The Boss says: a bottle goes to Hell. No drinking in the afterlife."),
        L("famine", "А есть можно? Нет? Так я и думал.", "And eating? No? I thought so.")
    ],
    5: [
        L("boss", "Появились безликие. Кто они — не знаем даже мы.", "The faceless have started coming. Not even we know who they are."),
        L("boss", "Таких — вниз, в Чистилище. Стрелка вниз. И это важнее всего остального.", "Send them down, to Limbo. The down arrow. And that beats every other rule."),
        L("death", "Им там не страшно?", "Aren't they scared down there?"),
        L("boss", "Там никак. В этом весь смысл.", "Down there is nothing. That's the whole point.")
    ],
    6: [
        L("war", "СМЕРТЬ! Почему в Аду кошки?! Они дерут мне плащ!", "DEATH! Why are there cats in Hell?! They're shredding my cloak!"),
        L("war", "Шеф решил: кто пришёл с котом — в Рай. Вместе с котом.", "The Boss decided: whoever comes with a cat goes to Heaven. Cat included."),
        L("death", "А если с котом и с бутылкой?", "And with a cat and a bottle?"),
        L("war", "Кот важнее. Кот всегда важнее.", "The cat wins. The cat always wins.")
    ],
    7: [
        L("boss", "Последнее правило недели. С крестом — в Рай.", "The last rule of the week. A cross goes to Heaven."),
        L("boss", "Но рога важнее креста. Не дай себя обмануть.", "But horns beat a cross. Don't let them fool you."),
        L("death", "А потом выходные?", "And then the weekend?"),
        L("boss", "...", "..."),
        L("boss", "Смешно. Работай.", "Funny. Get to work.")
    ]
};
// after the last rule: nothing new, only more souls
const later = [
    [L("boss", "Новых правил не будет. Будет больше душ.", "No more new rules. Just more souls."), L("death", "Как обычно.", "As usual.")],
    [L("plague", "Слышала? В Раю очередь на облака. Шеф доволен.", "Heard? There's a queue for clouds in Heaven. The Boss is pleased."), L("death", "А я?", "And me?"), L("plague", "А ты работаешь.", "You're working.")],
    [L("war", "Я тут подумал: а давай устроим войну? Будет больше работы!", "I've been thinking: how about a war? More work for you!"), L("death", "Нет.", "No.")],
    [L("famine", "Я принёс тебе обед. Шучу. Я его съел.", "I brought you lunch. Kidding. I ate it.")],
    [L("boss", "Ты всё ещё здесь. Это хорошо. Отсюда никто не уходит.", "You're still here. Good. No one leaves this place."), L("death", "...", "...")]
];
function talk(day) {
    return days[day] || later[day % later.length];
}

// the Boss after a shift
const after = {
    "won": [
        L("boss", "Норма есть. Не радуйся.", "Quota met. Don't celebrate."),
        L("boss", "Неплохо. Для скелета.", "Not bad. For a skeleton."),
        L("boss", "Сдано. Завтра будет хуже.", "Handed in. Tomorrow will be worse."),
        L("boss", "Чисто. Даже бухгалтерия не нашла, к чему придраться.", "Clean. Even accounting found nothing to pick on.")
    ],
    "time": [
        L("boss", "Очередь тянется до самого Чистилища. Позор.", "The queue reaches all the way to Limbo. Disgrace."),
        L("boss", "Ты слишком долго думаешь. Мёртвые ждать не любят.", "You think too long. The dead hate waiting."),
        L("boss", "Время вышло. У тебя, к счастью, его бесконечно много. Ещё раз.", "Time's up. Luckily you have an infinite amount of it. Again.")
    ],
    "mistakes": [
        L("boss", "Ты отправила праведника в Ад. Он уже пишет жалобу.", "You sent a saint to Hell. He's already writing a complaint."),
        L("boss", "Три ошибки. Бухгалтерия плачет.", "Three mistakes. Accounting is crying."),
        L("boss", "Ещё одна такая смена — и пойдёшь сортировать носки в Чистилище.", "One more shift like that and you'll sort socks in Limbo.")
    ]
};

// a soul's first words: about what it carries (most of the time), or anything
const soul = {
    "knife": [["Это не моё! Мне подбросили!", "It's not mine! It was planted!"], ["Я колбасу резал.", "I was slicing sausage."], ["Это для масла. Честно.", "It's a butter knife. Really."]],
    "bottle": [["Это лимонад.", "It's lemonade."], ["Ну, за встречу!", "Cheers to meeting you!"], ["Я просто подержать взял.", "I'm just holding it."]],
    "halo": [["Я всю жизнь был хорошим.", "I was good my whole life."], ["Оно само светится!", "It just glows on its own!"], ["Где тут вход для своих?", "Where's the VIP entrance?"]],
    "horns": [["Это шапка такая.", "It's a hat."], ["Не смотри на рога!", "Don't look at the horns!"], ["Я на маскарад шёл...", "I was going to a costume party..."]],
    "mask": [["...", "..."], ["Кто я?", "Who am I?"], ["Я не помню своего лица.", "I don't remember my face."], ["Ты видишь меня?", "Can you see me?"]],
    "cat": [["Мурзика не отдам!", "You're not taking my cat!"], ["Мяу. Это он сказал, не я.", "Meow. He said it, not me."], ["Он со мной. Он всегда со мной.", "He's with me. Always."]],
    "cross": [["Я молился. Иногда.", "I prayed. Sometimes."], ["Крест бабушкин.", "It was grandma's cross."], ["Я в церковь ходил! На Пасху.", "I went to church! At Easter."]],
    "any": [["Где я?", "Where am I?"], ["Я что, умер?", "Did I die?"], ["А тут есть вайфай?", "Is there wifi here?"], ["Можно жалобную книгу?", "Can I file a complaint?"], ["Я только за хлебом вышел...", "I only went out for bread..."], ["Мама?", "Mom?"], ["Это сон?", "Is this a dream?"], ["Я утюг не выключил!", "I left the iron on!"], ["А вы не подскажете, который час?", "Excuse me, what time is it?"], ["Красивая коса.", "Nice scythe."], ["Я тут постою, ладно?", "I'll just stand here, okay?"], ["Долго ещё ждать?", "How much longer?"]]
};
function soulLine(s, rnd) {
    rnd = rnd || Math.random;
    const has = Object.keys(soul).filter(k => k !== "any" && s[k]);
    // a faceless one never talks about anything else
    const pool = s.mask ? soul.mask : has.length && rnd() < 0.75 ? soul[has[Math.floor(rnd() * has.length)]] : soul.any;
    const l = pool[Math.floor(rnd() * pool.length)];
    return { "ru": l[0], "en": l[1] };
}
