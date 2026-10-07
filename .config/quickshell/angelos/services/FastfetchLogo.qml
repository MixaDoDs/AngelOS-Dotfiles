pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../widgets/Logos.js" as Logos

// fastfetch in angelOS's style (Settings → System → fastfetch): scripts/fastfetch_style.py
// writes ~/.config/fastfetch/config.jsonc and its picture in the theme's colours with the
// emblem of Settings → Bar → Logo. Horns while the demon rules, like everywhere else; hell's
// own fastfetch, one per circle, is scripts/terminal-hell.py's (ThemeExport.fastfetchHell).
// Style "own": the config is the user's; scripts/fastfetch-logo.py only draws the emblem
// into logo.txt, as before.
Singleton {
    id: root

    readonly property string emblem: ["heart", "pill", "star", "cd", "kitty"].includes(Config.bar.logoEmblem) ? Config.bar.logoEmblem : "heart"
    // the styles (Settings → System → fastfetch, the setup wizard's step): every one with a
    // picture shows the gear with its price — people giggle at the prices, never hide them
    readonly property var styles: [
        {
            "id": "compact",
            "name": I18n.t("Компакт", "Compact"),
            "hint": I18n.t("значок с «Пуска» покрупнее, короткие строки, сетап с ценами", "the Start emblem, bigger; short lines and your gear with its prices")
        },
        {
            "id": "angel",
            "name": I18n.t("Ангелочек", "Angel"),
            "hint": I18n.t("крылатое сердце с нимбом и таблеткой, все показания и сколько стоит сетап", "the winged heart with the halo and pill, every reading and what your gear cost")
        },
        {
            "id": "helper",
            "name": I18n.t("Ангел говорит", "The angel talks"),
            "hint": I18n.t("она сама: здоровается, показывает комп и комментирует цену сетапа (в аду — демоница)", "she does it herself: says hi, shows the computer and has a word on your gear's price (the demon in hell)")
        },
        {
            "id": "receipt",
            "name": I18n.t("Чек", "Receipt"),
            "hint": I18n.t("чек магазина angelOS: железо, сетап по ценам и ИТОГО (в аду — договор на душу)", "an angelOS store receipt: the hardware, the gear priced and the TOTAL (in hell, a contract for your soul)")
        },
        {
            "id": "stream",
            "name": I18n.t("Стрим", "Stream"),
            "hint": I18n.t("показания пишет чат, сетап приходит суперчатами", "the chat posts the readings, the gear comes in as superchats")
        },
        {
            "id": "window",
            "name": I18n.t("Окошко", "Window"),
            "hint": I18n.t("показания в рамке Y2K-окна ", "the readings in a Y2K window frame, ") + I18n.exe("AngelOS")
        },
        {
            "id": "mini",
            "name": I18n.t("Мини", "Mini"),
            "hint": I18n.t("без картинки: восемь строк и цена сетапа, для маленьких терминалов", "no picture: eight lines and the price of your gear, for small terminals")
        },
        {
            "id": "own",
            "name": I18n.t("Свой", "Your own"),
            "hint": I18n.t("angelOS не трогает config.jsonc (вернётся тот, что был до стилей)", "angelOS leaves config.jsonc alone (the one from before the styles comes back)")
        }
    ]
    readonly property string style: styles.some(s => s.id === Config.bar.fastfetchStyle) ? Config.bar.fastfetchStyle : "compact"
    // how long its picture moves in a new terminal (the same pixels, alive: wings, halo, glint,
    // sparkles; scripts/fastfetch_anim.py through ~/.config/fish/conf.d/angelos-fastfetch.fish)
    readonly property real animSeconds: Motion.still ? 0 : ({
            "off": 0,
            "short": 2.5,
            "long": 6
        })[Config.bar.fastfetchAnim] ?? 2.5
    // fastfetch is there at all (the setup wizard skips its step otherwise)
    property bool installed: false
    Process {
        running: true
        command: ["sh", "-c", "command -v fastfetch"]
        onExited: code => root.installed = code === 0
    }
    readonly property bool demon: Angel.demon
    readonly property var palette: ({
            "#": Theme.hex(Theme.dark ? Theme.mix(Theme.accent, Theme.edge, 0.55) : Theme.edge),
            "o": Theme.hex(Theme.accent),
            "x": Theme.hex(demon && emblem === "star" ? Qt.color("#7a0a1e") : Theme.accent2),
            "y": demon && emblem === "star" ? "#e0203a" : Theme.hex(Theme.mix(Theme.accent3, Qt.color("#ffd84a"), 0.6)),
            "w": "#ffffff",
            "f": Theme.hex(Theme.mix(Theme.accent2, "#ffffff", 0.55)),
            "r": "#e0203a",
            "p": Theme.hex(Theme.mix(Theme.accent, "#ffffff", 0.45))
        })
    // the words' colours: the keys, the title, the gold, the dim separators
    readonly property var colors: ({
            "accent": Theme.hex(Theme.accent),
            "accent2": Theme.hex(Theme.accent2),
            "accent3": Theme.hex(Theme.mix(Theme.accent3, Qt.color("#ffd84a"), 0.6)),
            "dim": Theme.hex(Theme.textDim),
            "pink": Theme.hex(Theme.mix(Theme.accent, "#ffffff", 0.35)),
            "lilac": Theme.hex(Theme.mix(Theme.accent2, "#ffffff", 0.35)),
            "windowTitle": I18n.exe("AngelOS"),     // the window style's title: AngelOS.exe / .sh / .bin
            "lang": I18n.english ? "en" : "ru"      // the words in the pictures (the receipt, her lines)
        })
    function args(cmd, style) {
        return ["python3", Quickshell.shellDir + "/scripts/fastfetch_style.py", cmd, "--style", style, "--emblem-rows", JSON.stringify(Logos.emblem(emblem, demon)), "--emblem-palette", JSON.stringify(palette), "--colors", JSON.stringify(colors), "--emblem", demon ? "" : emblem, "--anim", String(animSeconds)];
    }
    // what the files should show; empty = not ready yet
    readonly property string signature: !Config.ready ? "" : JSON.stringify([style, Config.bar.logoFastfetch, emblem, demon, palette, colors, animSeconds])
    onSignatureChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 2000
        onTriggered: {
            if (!root.signature)
                return;
            if (writer.running) {
                restart();
                return;
            }
            if (root.style !== "own")
                writer.command = root.args("apply", root.style);
            else
                writer.command = !Config.bar.logoFastfetch ? ["python3", Quickshell.shellDir + "/scripts/fastfetch-logo.py", "--restore"] : ["python3", Quickshell.shellDir + "/scripts/fastfetch-logo.py", "--emblem", root.emblem, "--rows", JSON.stringify(Logos.emblem(root.emblem, root.demon)), "--palette", JSON.stringify(root.palette)];
            writer.running = true;
        }
    }
    // to "own": the config the user had before the styles comes back
    onStyleChanged: if (Config.ready && style === "own")
        restorer.running = true
    Process {
        id: restorer
        command: ["python3", Quickshell.shellDir + "/scripts/fastfetch_style.py", "restore"]
    }
    Process {
        id: writer
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
