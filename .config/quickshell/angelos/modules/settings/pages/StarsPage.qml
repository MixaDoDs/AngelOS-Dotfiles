pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.y2k

// Heaven's stars (services/HeavenStars): the prayers and what they give — the angel's
// skins and the album of cards — the day's tasks and the heavenly pass. The stars come from
// the time at the computer, the daily login reward on the heaven lock, the tasks and the pass.
PxPage {
    id: page

    heading: I18n.t("Небеса: звёзды", "Heaven: stars")
    subtitle: I18n.t("Звёзды ✦ капают за время за компьютером (1 ✦ за 10 минут), за награду за вход на небесном экране блокировки, задания дня и небесный пропуск. Молитва стоит %1 ✦ (первый вход за день молится бесплатно) и даёт карточку в альбом или скин ангела.", "Stars ✦ come from the time at the computer (1 ✦ per 10 minutes), the login reward on the heaven lock, the day's tasks and the heavenly pass. A prayer costs %1 ✦ (the first unlock of a day prays for free) and gives a card for the album or one of the angel's skins.").arg(HeavenStars.wishCost)

    readonly property var rarityColor: ({
            "3": "#7fb2ff",
            "4": "#c48bff",
            "5": "#ffd25a"
        })

    // ---- the stars and the prayers ----
    PxGroup {
        id: wishGroup
        name: "stars-wish"
        width: parent.width
        title: I18n.t("Звёзды и молитвы", "Stars and prayers")
        icon: "sparkleStar"

        property var results: []
        property int shown: 0
        Row {
            spacing: Theme.u * 8
            PxText {
                text: "✦ " + HeavenStars.stars
                kind: "big"
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.u
                PxText {
                    text: I18n.t("всего получено: %1 ✦ · молитв: %2 · 5★: %3", "earned in all: %1 ✦ · prayers: %2 · 5★: %3").arg(HeavenStars.earned).arg(LockStream.wishes).arg(LockStream.fives)
                    dim: true
                }
                PxText {
                    text: I18n.t("гарант 4★ через %1 · 5★ через %2 (мягкий гарант с 74-й)", "4★ sure in %1 · 5★ sure in %2 (soft pity from the 74th)").arg(10 - LockStream.pity4).arg(90 - LockStream.pity5)
                    dim: true
                }
            }
        }
        Row {
            spacing: Theme.u * 4
            // the prayers open as chests (services/Chests, modules/chest/ChestOverlay)
            PxButton {
                text: Chests.freeReady ? I18n.t("Сундук дня · бесплатно", "The day's chest · free") : I18n.t("Сундук ×1 · %1 ✦", "Chest ×1 · %1 ✦").arg(HeavenStars.wishCost)
                icon: "sparkle"
                accent: true
                enabled: Chests.freeReady || HeavenStars.stars >= HeavenStars.wishCost
                onClicked: Chests.openOne()
            }
            PxButton {
                text: I18n.t("Сундуки ×10 · %1 ✦", "Chests ×10 · %1 ✦").arg(HeavenStars.wishCost * 10)
                icon: "sparkleStar"
                enabled: HeavenStars.stars >= HeavenStars.wishCost * 10
                onClicked: Chests.openTen()
            }
        }
        function pray(n) {
            const out = [];
            for (let i = 0; i < n; i++) {
                if (!HeavenStars.spend(HeavenStars.wishCost))
                    break;
                out.push(HeavenStars.pull(false));
            }
            results = out;
            shown = 0;
            reveal.restart();
        }
        Timer {
            id: reveal
            interval: 220
            repeat: true
            onTriggered: {
                if (wishGroup.shown >= wishGroup.results.length)
                    stop();
                else
                    wishGroup.shown++;
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Repeater {
                model: Chests.results
                PxBox {
                    id: res
                    required property var modelData
                    width: Theme.u * 56
                    height: Theme.u * 44
                    color: Theme.mix(Theme.face, page.rarityColor[String(res.modelData.stars)], 0.25)
                    edgeColor: page.rarityColor[String(res.modelData.stars)]
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Theme.u * 6
                        spacing: Theme.u * 2
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "★".repeat(res.modelData.stars)
                            color: page.rarityColor[String(res.modelData.stars)]
                            kind: "tiny"
                        }
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: res.modelData.icon
                            pixel: Theme.u * 2
                            fill: page.rarityColor[String(res.modelData.stars)]
                        }
                        PxText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: res.modelData.name
                            kind: "tiny"
                            elide: Text.ElideRight
                        }
                        PxText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: res.modelData.kind === "skin" ? I18n.t("СКИН!", "SKIN!") : res.modelData.fresh ? I18n.t("новое", "new") : "+" + res.modelData.refund + "✦"
                            kind: "tiny"
                            color: res.modelData.fresh ? Theme.accent : Theme.textDim
                            font.bold: res.modelData.fresh
                        }
                    }
                }
            }
        }
    }

    // ---- the angel's skins ----
    PxGroup {
        name: "stars-skins"
        width: parent.width
        title: I18n.t("Скины ангела", "The angel's skins")
        icon: "heart"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Перекраски её картинок: носит и помощница на рабочем столе, и ангел на экране блокировки. Лунная и Мятная выпадают из 4★ молитв, Золотая — из 5★.", "Recolours of her pictures, worn by the helper on the desktop and the angel on the lock screen. Moonlit and Mint come from 4★ prayers, Golden from 5★.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            Repeater {
                model: [null].concat(HeavenStars.skins)
                PxBox {
                    id: sk
                    required property var modelData
                    readonly property string sid: modelData ? modelData.id : ""
                    readonly property bool have: !modelData || HeavenStars.hasSkin(sid)
                    readonly property bool on: (HeavenStars.worn ? HeavenStars.worn.id : "") === sid
                    width: Theme.u * 70
                    height: Theme.u * 92
                    color: on ? Theme.mix(Theme.face, Theme.accent, 0.2) : Theme.face
                    edgeColor: on ? Theme.accent : sk.modelData ? page.rarityColor[String(sk.modelData.rarity)] : Theme.edge
                    Item {
                        id: fit
                        x: Theme.u * 3
                        y: Theme.u * 3
                        width: parent.width - Theme.u * 6
                        height: parent.height - Theme.u * 22
                        clip: true
                        SpriteRig {
                            id: rigPic
                            who: "angel"
                            angelVariant: Angel.angelLook === "glitch" || Angel.angelLook === "ophanim" ? Angel.angelLook : ""
                            px: ready ? Math.min(fit.width / rig.size[0], fit.height / rig.size[1]) : 1
                            width: implicitWidth
                            height: implicitHeight
                            anchors.centerIn: parent
                            opacity: sk.have ? 1 : 0.35
                            layer.enabled: sk.modelData !== null
                            layer.smooth: false
                            layer.effect: AngelSkinFx {
                                skin: sk.modelData
                            }
                        }
                        PxIcon {
                            visible: !sk.have
                            anchors.centerIn: parent
                            name: "lock"
                            pixel: Theme.u * 2
                        }
                    }
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.u * 3
                        width: parent.width
                        PxText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: sk.modelData ? I18n.t(sk.modelData.ru, sk.modelData.en) : I18n.t("Обычная", "Her own")
                            font.bold: sk.on
                        }
                        PxText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: sk.on ? I18n.t("надета ♡", "worn ♡") : sk.have ? I18n.t("надеть", "wear") : sk.modelData.rarity + "★"
                            kind: "tiny"
                            dim: !sk.on
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: sk.have
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.y2k.angelSkin = sk.sid
                    }
                }
            }
        }
    }

    // ---- the album ----
    PxGroup {
        name: "stars-album"
        width: parent.width
        title: I18n.t("Альбом карточек · %1/%2", "The album · %1/%2").arg(HeavenStars.albumHave).arg(HeavenStars.cards.length)
        icon: "image"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Карточки выпадают из молитв. Весь ряд 3★ — +%1 ✦, 4★ — +%2 ✦, 5★ — +%3 ✦. Повтор возвращает звёзды.", "Cards come from prayers. A whole row of 3★ gives +%1 ✦, 4★ +%2 ✦, 5★ +%3 ✦. A duplicate gives stars back.").arg(HeavenStars.rowReward["3"]).arg(HeavenStars.rowReward["4"]).arg(HeavenStars.rowReward["5"])
        }
        Repeater {
            model: [3, 4, 5]
            Column {
                id: rowCol
                required property int modelData
                width: parent.width
                spacing: Theme.u * 2
                PxText {
                    text: "★".repeat(rowCol.modelData) + ((HeavenStars.owned.rows || []).includes(String(rowCol.modelData)) ? I18n.t("  · собрано ✓", "  · complete ✓") : "")
                    color: page.rarityColor[String(rowCol.modelData)]
                    font.bold: true
                }
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    Repeater {
                        model: HeavenStars.cards.filter(c => c.rarity === rowCol.modelData)
                        PxBox {
                            id: cardBox
                            required property var modelData
                            readonly property int n: HeavenStars.cardCount(modelData.id)
                            width: Theme.u * 52
                            height: Theme.u * 40
                            sunken: n === 0
                            color: n ? Theme.mix(Theme.face, page.rarityColor[String(rowCol.modelData)], 0.18) : Theme.sunken
                            edgeColor: n ? page.rarityColor[String(rowCol.modelData)] : Theme.edge
                            Column {
                                anchors.centerIn: parent
                                width: parent.width - Theme.u * 6
                                spacing: Theme.u * 2
                                PxIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: cardBox.n ? cardBox.modelData.icon : "lock"
                                    pixel: Theme.u * 2
                                    fill: page.rarityColor[String(rowCol.modelData)]
                                    opacity: cardBox.n ? 1 : 0.4
                                }
                                PxText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: cardBox.n ? I18n.t(cardBox.modelData.ru, cardBox.modelData.en) + (cardBox.n > 1 ? " ×" + cardBox.n : "") : "?"
                                    kind: "tiny"
                                    elide: Text.ElideRight
                                    dim: !cardBox.n
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- the day's tasks ----
    PxGroup {
        name: "stars-tasks"
        width: parent.width
        title: I18n.t("Задания дня", "Today's tasks")
        icon: "check"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Три задания из того, что ты и так делаешь; меняются в полночь. Каждое +%1 ✦, все три — ещё +%2 ✦.", "Three tasks from what you do anyway; new ones at midnight. +%1 ✦ each, all three another +%2 ✦.").arg(HeavenStars.taskReward).arg(HeavenStars.allTasksBonus)
        }
        Repeater {
            model: HeavenStars.tasks
            Row {
                id: taskRow
                required property var modelData
                width: parent.width
                spacing: Theme.u * 4
                PxIcon {
                    name: taskRow.modelData.done ? "check" : "sparkle"
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    width: Theme.u * 120
                    text: I18n.t(taskRow.modelData.ru, taskRow.modelData.en)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: Theme.u * 60
                    height: Theme.u * 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.sunken
                    Rectangle {
                        width: Math.round(parent.width * taskRow.modelData.have / taskRow.modelData.goal)
                        height: parent.height
                        color: taskRow.modelData.done ? Theme.ok : Theme.accent
                    }
                }
                PxText {
                    text: taskRow.modelData.have + "/" + taskRow.modelData.goal
                    anchors.verticalCenter: parent.verticalCenter
                    dim: true
                }
            }
        }
    }

    // ---- the heavenly pass ----
    PxGroup {
        name: "stars-pass"
        width: parent.width
        title: I18n.t("Небесный пропуск · сезон %1", "The heavenly pass · season %1").arg(HeavenStars.season)
        icon: "star"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Сезон — 30 дней (осталось %1). Опыт: минута за компьютером — 1, задание — 60, вход — 30; уровень — %2 опыта. Награды забираются сами.", "A season lasts 30 days (%1 left). Experience: a minute at the computer 1, a task 60, an unlock 30; a level takes %2. Rewards are taken by themselves.").arg(Math.ceil(HeavenStars.seasonDaysLeft)).arg(HeavenStars.levelXp)
        }
        Row {
            spacing: Theme.u * 4
            PxText {
                text: I18n.t("уровень %1 / 30", "level %1 / 30").arg(HeavenStars.level)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: Theme.u * 140
                height: Theme.u * 6
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.sunken
                Rectangle {
                    width: Math.round(parent.width * (HeavenStars.level >= 30 ? 1 : (HeavenStars.xp % HeavenStars.levelXp) / HeavenStars.levelXp))
                    height: parent.height
                    color: Theme.accent
                }
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: 30
                PxBox {
                    id: lv
                    required property int index
                    readonly property int n: index + 1
                    readonly property var r: HeavenStars.passReward(n)
                    readonly property bool got: n <= HeavenStars.level
                    width: Theme.u * 26
                    height: Theme.u * 24
                    color: got ? Theme.mix(Theme.face, Theme.accent, 0.25) : Theme.face
                    edgeColor: r.kind === "frame" || n % 5 === 0 ? Theme.accent3 : Theme.edge
                    Column {
                        anchors.centerIn: parent
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(lv.n)
                            kind: "tiny"
                            dim: true
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: lv.r.kind === "frame" ? "▣" : lv.r.stars + "✦"
                            kind: "tiny"
                            font.bold: lv.r.kind === "frame" || lv.n % 5 === 0
                            color: lv.got ? Theme.accent : Theme.text
                        }
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Рамка окна входа (Небеса)", "Login plate frame (Heaven)")
            hint: I18n.t("рамки дают 10-й и 20-й уровни пропуска", "the pass's levels 10 and 20 give them")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Золото", "Gold"),
                        "value": ""
                    }
                ].concat(HeavenStars.frames.filter(f => (HeavenStars.owned.frames || []).includes(f.id)).map(f => ({
                            "label": f.id === "rose" ? I18n.t("Розовое золото", "Rose gold") : I18n.t("Голограмма", "Hologram"),
                            "value": f.id
                        })))
                currentValue: HeavenStars.frame
                onActivated: v => Config.lock.frame = v
            }
        }
    }
}
