pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// One game's note (services/GameTune): how it runs on Linux (ProtonDB), anti-cheat, the Proton
// and launch options we suggest and why, the in-game tips; both can be changed before
// "Apply", "Put back" undoes it. The pop-up note (GameNote) and Settings → Maintenance → Games
// show the same card.
Column {
    id: root

    required property var game
    readonly property var rec: game ? game.rec : ({})
    property string proton: rec.proton || ""
    property string options: rec.options || ""
    property bool guide: false
    spacing: Theme.u * 3

    // a fresh list keeps what is being edited; another game starts from its suggestion
    property string shown: ""
    onGameChanged: {
        if (!game || game.appid === shown)
            return;
        shown = game.appid;
        proton = rec.proton || "";
        options = rec.options || "";
    }

    function tierText(t) {
        return ({
                "platinum": I18n.t("Платина — работает идеально", "Platinum — runs perfectly"),
                "gold": I18n.t("Золото — работает, бывают мелочи", "Gold — runs, small things happen"),
                "silver": I18n.t("Серебро — играбельно, с огрехами", "Silver — playable, with flaws"),
                "bronze": I18n.t("Бронза — запускается с трудом", "Bronze — hard to get going"),
                "borked": I18n.t("Сломано — почти ни у кого не идёт", "Borked — runs for almost nobody"),
                "pending": I18n.t("Мало отчётов", "Too few reports")
            })[t] || I18n.t("Отчётов нет", "No reports");
    }
    function acText(a) {
        if (!a)
            return "";
        return ({
                "Supported": I18n.t("Античит (%1) работает на Linux", "Anti-cheat (%1) works on Linux"),
                "Running": I18n.t("Античит (%1): запускается, но официально не поддержан", "Anti-cheat (%1): runs, not officially supported"),
                "Planned": I18n.t("Античит (%1): поддержку обещали, пока онлайн может не пустить", "Anti-cheat (%1): support promised, online may refuse for now"),
                "Broken": I18n.t("Античит (%1) сейчас не пускает с Linux", "Anti-cheat (%1) refuses Linux now"),
                "Denied": I18n.t("Разработчик запретил Linux (%1): онлайн не запустится", "The developer bans Linux (%1): online won't start")
            })[a.status] || "";
    }
    function protonWhy(w) {
        return ({
                "native": I18n.t("У игры своя версия для Linux — Proton не нужен", "The game has a Linux build — no Proton needed"),
                "profile": I18n.t("проверено angelOS для этой игры", "checked by angelOS for this game"),
                "anticheat": I18n.t("с античитом надёжнее официальный Proton Experimental", "with anti-cheat Valve's Proton Experimental is the safe bet"),
                "default": I18n.t("быстрый, сам чинит сотни игр (protonfixes), дружит с Wayland", "fast, mends hundreds of games by itself (protonfixes), Wayland-friendly"),
                "ge": I18n.t("Proton-CachyOS не установлен — следующий по качеству GE-Proton", "Proton-CachyOS isn't installed — GE-Proton is the next best"),
                "steam": I18n.t("сторонних Proton нет — решает Steam", "no other Proton here — Steam decides")
            })[w] || "";
    }
    function optionsWhy(w) {
        if (w === "profile")
            return I18n.t("проверено angelOS для этой игры", "checked by angelOS for this game");
        if (w.startsWith("protondb:"))
            return I18n.t("так запускают %1 игроков с такой же видеокартой", "%1 players with the same kind of video card run it so").replace("%1", w.slice(9));
        return (root.options.indexOf("gamemoderun") >= 0) ? I18n.t("gamemoderun — режим производительности, пока идёт игра", "gamemoderun — performance mode while the game runs") : "";
    }
    readonly property var kinds: ({
            "cachyos": I18n.t("по умолчанию: оптимизирован, Wayland, автопочинки игр", "the default: optimised, Wayland, automatic game fixes"),
            "ge": I18n.t("если не идут ролики, лаунчер или звук", "when cutscenes, a launcher or sound fail"),
            "experimental": I18n.t("для игр с античитом (EAC, BattlEye) и самых новых", "for anti-cheat games (EAC, BattlEye) and the newest ones"),
            "official": I18n.t("стабильный: если новые версии ломают игру", "stable: when newer builds break the game"),
            "wineland": I18n.t("Wayland без XWayland: меньше задержка ввода, свежие патчи; мало отчётов — проверь замером", "Wayland without XWayland: less input lag, fresh patches; few reports — measure it"),
            "em": I18n.t("Proton-EM: свежий FSR 4 и патчи для новых игр", "Proton-EM: fresh FSR 4 and patches for new games"),
            "tkg": I18n.t("Proton-tkg: самосборный, для тонкой настройки", "Proton-tkg: self-built, for fine-tuning"),
            "gdk": I18n.t("GDK-Proton: для игр из Microsoft Store / Xbox", "GDK-Proton: for Microsoft Store / Xbox games"),
            "sarek": I18n.t("Proton-Sarek: для старых видеокарт без полного Vulkan", "Proton-Sarek: for old video cards without full Vulkan"),
            "luxtorpeda": I18n.t("Luxtorpeda: родной Linux-движок вместо Proton (старые игры)", "Luxtorpeda: a native Linux engine instead of Proton (old games)"),
            "boxtron": I18n.t("Boxtron: DOS-игры через DOSBox", "Boxtron: DOS games through DOSBox"),
            "roberta": I18n.t("Roberta: квесты через ScummVM", "Roberta: adventures through ScummVM"),
            "other": I18n.t("своя сборка", "a build of its own")
        })

    // ---- how it runs
    Row {
        spacing: Theme.u * 3
        PxPill {
            width: tierLabel.implicitWidth + Theme.u * 6
            height: tierLabel.implicitHeight + Theme.u * 2
            color: ({
                    "platinum": Theme.ok,
                    "gold": Theme.accent2,
                    "silver": Theme.faceAlt,
                    "bronze": Theme.accent3,
                    "borked": Theme.danger
                })[root.game.rating.tier] || Theme.sunken
            PxText {
                id: tierLabel
                anchors.centerIn: parent
                text: root.tierText(root.game.rating.tier)
                kind: "tiny"
                font.bold: true
            }
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.game.rating.n > 0
            text: I18n.t("работает у %1 из %2", "runs for %1 of %2").replace("%1", root.game.rating.ok).replace("%2", root.game.rating.n) + (root.game.rating.oob !== null && root.game.rating.oob !== undefined ? I18n.t(", сразу без настроек — %1 %", ", out of the box — %1 %").replace("%1", Math.round(root.game.rating.oob * 100)) : "")
            kind: "tiny"
            dim: true
        }
    }
    PxText {
        width: parent.width
        visible: text !== ""
        wrapMode: Text.Wrap
        text: root.acText(root.game.anticheat).replace("%1", ((root.game.anticheat || {}).anticheats || []).join(", "))
        color: root.game.anticheat && ["Denied", "Broken"].includes(root.game.anticheat.status) ? Theme.danger : Theme.text
    }

    // ---- Proton
    SettingRow {
        width: parent.width
        visible: !root.game.native && !root.bench
        label: "Proton"
        hint: (root.game.now.proton !== root.proton ? I18n.t("сейчас: ", "now: ") + GameTune.toolName(root.game.now.proton) + " · " : "") + (root.proton === root.rec.proton ? root.protonWhy(root.rec.protonWhy) : "")
        PxCombo {
            width: parent.width
            model: [
                {
                    "label": I18n.t("Как решит Steam", "Steam's own choice"),
                    "value": ""
                }
            ].concat(GameTune.tools.map(t => ({
                        "label": t.display + (t.name === root.rec.proton ? "  ★" : ""),
                        "value": t.name
                    })))
            currentValue: root.proton
            onActivated: v => root.proton = v
        }
    }
    PxText {
        width: parent.width
        visible: root.game.native
        wrapMode: Text.Wrap
        text: root.protonWhy("native")
        kind: "tiny"
        dim: true
    }
    PxButton {
        visible: !root.game.native && !root.bench
        compact: true
        flat: true
        icon: "info"
        text: root.guide ? I18n.t("Скрыть, какой Proton для чего", "Hide which Proton is for what") : I18n.t("Какой Proton для чего?", "Which Proton is for what?")
        onClicked: root.guide = !root.guide
    }
    Column {
        visible: root.guide && !root.game.native
        width: parent.width
        spacing: Theme.u
        Repeater {
            model: GameTune.tools
            PxText {
                required property var modelData
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                text: "• " + modelData.display + " — " + root.kinds[modelData.kind]
            }
        }
        PxButton {
            compact: true
            icon: "download"
            text: I18n.t("Поставить другие Proton (ProtonPlus)", "Install other Protons (ProtonPlus)")
            onClicked: GameTune.openProtonPlus()
        }
    }

    // ---- launch options
    SettingRow {
        width: parent.width
        visible: !root.bench
        label: I18n.t("Параметры запуска", "Launch options")
        hint: (root.game.now.options && root.game.now.options !== root.options ? I18n.t("сейчас: ", "now: ") + root.game.now.options + " · " : "") + (root.options === root.rec.options ? root.optionsWhy(root.rec.optionsWhy || "") : "")
        PxField {
            width: parent.width
            text: root.options
            placeholder: I18n.t("пусто — без параметров", "empty — none")
            onEdited: root.options = text
        }
    }
    // ---- mods: what hooks in through a DLL of its own needs Wine to take the game's copy
    Column {
        visible: (root.rec.mods || []).length > 0 && !root.bench
        width: parent.width
        spacing: Theme.u
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("Моды: их параметры и твои сохраняются, совет добавляется сверху.", "Mods: their settings and yours stay, the suggestion goes on top.")
        }
        Repeater {
            model: root.rec.mods || []
            Row {
                id: modRow
                required property var modelData
                spacing: Theme.u * 3
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.width - (modOn.visible ? modOn.width + Theme.u * 3 : 0)
                    wrapMode: Text.Wrap
                    text: "• " + (modRow.modelData.name === "mods" ? I18n.t("папка модов игры", "the game's mod folder") : modRow.modelData.name) + " — " + (modRow.modelData.on ? I18n.t("включён", "on") : I18n.t("найден, но не включён", "found, but not on")) + (modRow.modelData.dll ? I18n.t(" (Wine берёт %1.dll из игры)", " (Wine takes %1.dll from the game)").replace("%1", modRow.modelData.dll) : "") + (modRow.modelData.flag ? " " + modRow.modelData.flag : "")
                }
                PxButton {
                    id: modOn
                    visible: !modRow.modelData.on && !!modRow.modelData.enable && root.options.indexOf(modRow.modelData.dll ? modRow.modelData.dll + "=n,b" : modRow.modelData.flag) < 0
                    compact: true
                    icon: "check"
                    text: I18n.t("Включить", "Turn on")
                    onClicked: root.options = modRow.modelData.enable
                }
            }
        }
    }
    Column {
        visible: (root.rec.fallbacks || []).length > 0
        width: parent.width
        spacing: Theme.u
        PxText {
            text: I18n.t("Если не запускается (это дороже по FPS):", "If it doesn't start (costs FPS):")
            kind: "tiny"
            dim: true
        }
        Repeater {
            model: root.rec.fallbacks || []
            PxButton {
                required property var modelData
                compact: true
                flat: true
                text: modelData[0]
                onClicked: root.options = modelData[0]
            }
        }
    }

    // ---- in the game itself
    Repeater {
        model: root.rec.tips || []
        PxText {
            required property var modelData
            width: root.width
            wrapMode: Text.Wrap
            text: "★ " + I18n.t(modelData[0], modelData[1])
        }
    }

    PxText {
        width: parent.width
        visible: root.game.pending || GameTune.data.running
        wrapMode: Text.Wrap
        kind: "tiny"
        color: Theme.accent
        text: root.game.pending ? I18n.t("Ждёт, пока закроешь Steam — тогда запишу сам.", "Waiting for Steam to close — then it goes in by itself.") : I18n.t("Steam открыт: «Применить» запишет, когда он закроется.", "Steam is open: \"Apply\" writes it once Steam closes.")
    }
    Flow {
        width: parent.width
        visible: !root.bench
        spacing: Theme.u * 3
        PxButton {
            accent: true
            icon: "check"
            text: I18n.t("Применить", "Apply")
            enabled: !GameTune.busy && (root.proton !== root.game.now.proton || root.options !== root.game.now.options)
            onClicked: GameTune.apply(root.game.appid, root.game.native ? root.game.now.proton : root.proton, root.options)
        }
        PxButton {
            visible: root.game.undo
            icon: "refresh"
            text: I18n.t("Вернуть как было", "Put back")
            enabled: !GameTune.busy
            onClicked: GameTune.undo(root.game.appid)
        }
        PxButton {
            icon: "chat"
            text: I18n.t("Подобрать с агентом", "Tune with the agent")
            onClicked: GameTune.askAgent(root.game.appid)
        }
    }
    // ---- compare Protons here: FPS measured on this machine (GameTune.bench)
    readonly property var bench: GameTune.bench && GameTune.bench.appid === game.appid ? GameTune.bench : null
    readonly property var benchable: GameTune.tools.filter(t => t.switchable)
    property var picked: []
    function defaultPick() {
        const want = [game.now.proton, rec.proton].concat(benchable.filter(t => t.kind === "wineland").map(t => t.name).slice(0, 1));
        return benchable.map(t => t.name).filter(n => want.includes(n)).slice(0, 3);
    }
    function fmt(r) {
        return !r || r.error ? I18n.t("мало кадров — не засчитано", "too few frames — not counted") : I18n.t("%1 FPS · 1 % low %2 · 0,1 % low %3", "%1 FPS · 1 % low %2 · 0.1 % low %3").replace("%1", r.fps).replace("%2", r.low1).replace("%3", r.low01);
    }
    readonly property var ranked: bench ? Object.keys(bench.results).filter(n => bench.results[n] && !bench.results[n].error).sort((a, b) => bench.results[b].fps - bench.results[a].fps) : []
    Component.onCompleted: picked = defaultPick()

    PxText {
        visible: !root.game.native
        text: I18n.t("Сравнить у себя", "Compare here")
        font.bold: true
    }
    PxText {
        width: parent.width
        visible: !root.game.native && !root.bench
        wrapMode: Text.Wrap
        kind: "tiny"
        dim: true
        text: GameTune.hasMangoHud ? I18n.t("Выбери 2–3 Proton: по заходу на каждый, FPS меряет MangoHud на твоём железе. Стоять лучше в одном и том же месте или включить бенчмарк самой игры.", "Pick 2–3 Protons: one run each, MangoHud measures the FPS on this machine. Stand in the same spot each time, or run the game's own benchmark.") : I18n.t("Для замера нужен MangoHud (sudo pacman -S mangohud lib32-mangohud).", "Measuring needs MangoHud (sudo pacman -S mangohud lib32-mangohud).")
    }
    Flow {
        width: parent.width
        visible: !root.game.native && !root.bench && GameTune.hasMangoHud
        spacing: Theme.u * 3
        Repeater {
            model: root.benchable
            PxCheck {
                required property var modelData
                text: modelData.display
                checked: root.picked.includes(modelData.name)
                onToggled: on => root.picked = on ? root.picked.concat([modelData.name]) : root.picked.filter(n => n !== modelData.name)
            }
        }
    }
    PxButton {
        visible: !root.game.native && !root.bench && GameTune.hasMangoHud
        icon: "sparkle"
        text: I18n.t("Сравнить (%1 захода)", "Compare (%1 runs)").replace("%1", root.picked.length)
        enabled: root.picked.length >= 2 && !GameTune.bench && !GameTune.busy
        onClicked: GameTune.benchStart(root.game.appid, root.picked)
    }
    PxText {
        width: parent.width
        visible: !!root.bench && !root.bench.done
        wrapMode: Text.Wrap
        color: Theme.accent
        text: root.bench && !root.bench.done ? I18n.t("Заход %1 из %2: %3. Запусти игру, встань в одно место (или включи бенчмарк игры) и нажми Shift+F2 — 60 секунд записи. Потом выйди из игры: следующий Proton включится сам.", "Run %1 of %2: %3. Start the game, stand in one spot (or run its benchmark) and press Shift+F2 — 60 seconds of recording. Then quit: the next Proton comes by itself.").replace("%1", root.bench.i + 1).replace("%2", root.bench.tools.length).replace("%3", GameTune.toolName(root.bench.tools[root.bench.i])) + (GameTune.restartSteam ? I18n.t(" Сначала перезапусти Steam один раз — он должен увидеть переключатель «angelOS: Proton comparison».", " Restart Steam once first — it has to see the switch \"angelOS: Proton comparison\".") : "") : ""
    }
    Repeater {
        model: root.bench ? root.bench.tools : []
        PxText {
            required property string modelData
            width: root.width
            wrapMode: Text.Wrap
            readonly property var r: root.bench.results[modelData]
            visible: r !== undefined
            font.bold: root.ranked.length > 0 && root.ranked[0] === modelData
            text: (root.ranked[0] === modelData && root.bench.done ? "★ " : "• ") + GameTune.toolName(modelData) + " — " + root.fmt(r)
        }
    }
    Flow {
        width: parent.width
        visible: !!root.bench
        spacing: Theme.u * 3
        PxButton {
            visible: !!root.bench && root.bench.done && root.ranked.length > 0
            accent: true
            icon: "check"
            text: I18n.t("Оставить ", "Keep ") + (root.ranked.length ? GameTune.toolName(root.ranked[0]) : "")
            enabled: !GameTune.busy
            onClicked: GameTune.benchFinish(root.ranked[0])
        }
        PxButton {
            icon: "refresh"
            text: root.bench && root.bench.done ? I18n.t("Вернуть как было", "Put back") : I18n.t("Остановить", "Stop")
            enabled: !GameTune.busy
            onClicked: GameTune.benchFinish("")
        }
    }
    PxText {
        width: parent.width
        visible: GameTune.error !== ""
        wrapMode: Text.Wrap
        color: Theme.danger
        kind: "tiny"
        text: GameTune.error
    }
    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        kind: "tiny"
        dim: true
        text: I18n.t("Данные: ProtonDB (ODbL), AreWeAntiCheatYet. Steam перезаписывает настройки при выходе — поэтому запись ждёт, пока он закрыт.", "Data: ProtonDB (ODbL), AreWeAntiCheatYet. Steam rewrites its settings on exit, so writing waits until it is closed.")
    }
}
