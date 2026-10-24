// The settings once in PeripheralsPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Device charge (2026-10-11; services/Peripherals): the mouse's, the keyboard's, the
// headphones' charge as ampoules on the bar. The devices themselves (a name, an icon, the
// order, which are shown), the ampoules' look, the liquid's colours, the warnings, and where
// the charge is read from.
CatPage {
    id: page
    heading: I18n.t("Заряд устройств", "Device charge")
    subtitle: I18n.t("Мышь, клавиатура, наушники, геймпад — ампулами на панели. Видно только те, что сообщают свой заряд.", "The mouse, the keyboard, the headphones, a gamepad as ampoules on the bar. Only the ones that report their charge show.")
    // the preview's charge: drag it to see every colour of the liquid
    property real demoPercent: 78
    readonly property var kindModel: Peripherals.kinds.map(k => ({
                "label": Peripherals.kindLabel(k),
                "value": k
            }))
    CatGroup {
        name: "devices"
        title: I18n.t("Устройства", "Devices")
        icon: "ampoule"
        CatNote {
            present: Peripherals.all.length === 0
            dim: true
            text: I18n.t("Пока ни одно устройство не сообщает заряд. Bluetooth, Logitech, LAMZU и геймпады появятся сами; проводные заряд не сообщают.", "No device reports its charge yet. Bluetooth, Logitech, LAMZU and gamepads show up by themselves; wired ones don't report it.")
        }
        // a dongle is there and the system won't let it be asked: the udev rule of extras/hid-access
        // (the dotfiles' install.sh installs it) with the admin password, once
        CatButton {
            present: Config.peripherals.vendor && (Peripherals.denied > 0 || Peripherals.grantLog !== "")
            label: I18n.t("Нет доступа к донглу", "No access to the dongle")
            hint: Peripherals.grantLog !== "" ? Peripherals.grantLog : I18n.t("система не даёт спросить донгл. Разрешение откроет только служебный интерфейс мыши — ни клавиш, ни движения через него не прочитать; нужен пароль администратора", "The system won't let the dongle be asked. Allowing opens only the mouse's service interface — no keys or movement can be read through it; it takes the admin password")
            icon: "lock"
            accent: true
            text: I18n.t("Разрешить", "Allow")
            onClicked: Peripherals.grant()
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Peripherals.all
                    Column {
                        id: dev
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: Theme.u * 3
                        // a line between two devices
                        Rectangle {
                            visible: dev.index > 0
                            width: parent.width
                            height: Math.max(1, Theme.u / 2)
                            color: Qt.alpha(Theme.tone("text", Theme.p5For(parent)), 0.18)
                        }
                        Item {
                            width: parent.width
                            height: Math.max(glass.height, words.implicitHeight)
                            PxAmpoule {
                                id: glass
                                pixel: Math.max(2, Math.round(Theme.u * 1.5))
                                value: dev.modelData.percent / 100
                                charging: dev.modelData.charging
                                asleep: dev.modelData.asleep
                                low: dev.modelData.level !== "ok"
                                stops: Peripherals.stops
                                paint: Config.peripherals.paint
                                steps: Config.peripherals.steps
                                glint: Config.peripherals.glint
                                bubbles: Config.peripherals.bubbles
                            }
                            Column {
                                id: words
                                anchors.left: glass.right
                                anchors.leftMargin: Theme.u * 5
                                anchors.right: number.left
                                anchors.rightMargin: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.u
                                Row {
                                    spacing: Theme.u * 2
                                    PxIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: Peripherals.kindIcon(dev.modelData.kind)
                                    }
                                    PxText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, words.width - Theme.u * 18)
                                        elide: Text.ElideRight
                                        font.bold: true
                                        text: dev.modelData.name
                                    }
                                }
                                PxText {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    kind: "tiny"
                                    dim: true
                                    text: (dev.modelData.name !== dev.modelData.ownName ? dev.modelData.ownName + " · " : "") + Peripherals.statusText(dev.modelData) + " · " + (dev.modelData.source === "upower" ? "UPower" : dev.modelData.source === "headsetcontrol" ? "headsetcontrol" : dev.modelData.source === "fake" ? I18n.t("стенд", "stand") : I18n.t("донгл", "dongle"))
                                }
                            }
                            PxText {
                                id: number
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "title"
                                text: dev.modelData.percent + " %"
                            }
                        }
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxField {
                                width: Theme.u * 80
                                text: dev.modelData.name !== dev.modelData.ownName ? dev.modelData.name : ""
                                placeholder: I18n.t("своё имя, Enter", "your name for it, Enter")
                                onAccepted: Peripherals.setName(dev.modelData.id, text)
                            }
                            PxCombo {
                                model: page.kindModel
                                currentValue: dev.modelData.kind
                                onActivated: v => Peripherals.setKind(dev.modelData.id, v)
                            }
                            PxToggle {
                                text: I18n.t("На панели", "On the bar")
                                checked: !dev.modelData.hidden
                                onToggled: v => Peripherals.setHidden(dev.modelData.id, !v)
                            }
                            PxButton {
                                compact: true
                                icon: "arrowUp"
                                enabled: dev.index > 0
                                onClicked: Peripherals.move(dev.modelData.id, -1)
                            }
                            PxButton {
                                compact: true
                                icon: "arrowDown"
                                enabled: dev.index < Peripherals.all.length - 1
                                onClicked: Peripherals.move(dev.modelData.id, 1)
                            }
                            PxButton {
                                visible: dev.modelData.asleep
                                compact: true
                                icon: "close"
                                text: I18n.t("Убрать", "Remove")
                                onClicked: Peripherals.forget(dev.modelData.id)
                            }
                        }
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Порядок", "Order")
            hint: I18n.t("свой — стрелками в списке", "Yours: with the arrows in the list")
            model: [
                {
                    "label": I18n.t("Свой", "Mine"),
                    "value": "manual"
                },
                {
                    "label": I18n.t("Сначала пустые", "Emptiest first"),
                    "value": "lowest"
                }
            ]
            currentValue: Config.peripherals.sort
            onActivated: v => Config.peripherals.sort = v
        }
    }
    CatGroup {
        name: "look"
        title: I18n.t("Ампулы на панели", "The ampoules on the bar")
        icon: "pill"
        // the same item the bar draws, twice as large, with three devices to look at
        CatCustom {
            wide: true
            CatBox {
                // the same item the bar draws, twice as large, with three devices to look at;
                // P5: on the theme's own surface (the ampoules are drawn in the theme's text
                // colour, lost on the paper), a black frame on an accent shadow
                PxBox {
                    id: rackBox
                    readonly property bool p5: Theme.p5For(parent)
                    width: parent.width - (p5 ? Theme.u * 3 : 0)
                    height: stage.implicitHeight + Theme.u * 12
                    sunken: true
                    color: p5 ? Theme.face : Theme.tone("sunken", false)
                    Rectangle {
                        visible: rackBox.p5
                        z: -2
                        x: Theme.u * 3
                        y: Theme.u * 3
                        width: parent.width
                        height: parent.height
                        color: Theme.accent
                    }
                    Rectangle {
                        visible: rackBox.p5
                        z: -1
                        x: -Theme.u * 2
                        y: -Theme.u * 2
                        width: parent.width + Theme.u * 4
                        height: parent.height + Theme.u * 4
                        // a screen: black even on the dark card (where P5's "black" is the light ink)
                        color: Theme.dark ? Theme.mix("#000000", Theme.accent, 0.03) : Theme.p5Black
                    }
                    PxAmpouleRack {
                        id: stage
                        anchors.centerIn: parent
                        pixel: Theme.u * 2
                        rows: 13
                        devices: Peripherals.demo(page.demoPercent)
                    }
                }
            }
        }
        CatSlider {
            label: I18n.t("Заряд для примера", "The preview's charge")
            hint: I18n.t("только для картинки выше: клавиатура заряжается, наушники садятся", "Only for the picture above: the keyboard charges, the headphones run low")
            from: 1
            to: 100
            stepSize: 1
            suffix: " %"
            value: page.demoPercent
            onMoved: v => page.demoPercent = v
        }
        CatToggle {
            label: I18n.t("Ампулы на панели", "Ampoules on the bar")
            hint: I18n.t("виджет «Заряд устройств»; клик — список с цифрами, правый клик — опросить", "The “Device charge” widget; a click lists them with numbers, a right click asks them now")
            checked: Config.peripherals.show
            onToggled: v => Config.peripherals.show = v
        }
        CatToggle {
            label: I18n.t("Значок устройства", "The device's icon")
            hint: I18n.t("рядом с ампулой: чья она", "Next to the ampoule: whose it is")
            checked: Config.peripherals.glyphs
            onToggled: v => Config.peripherals.glyphs = v
        }
        CatChoice {
            label: I18n.t("Проценты", "Percentage")
            model: [
                {
                    "label": I18n.t("Никогда", "Never"),
                    "value": "never"
                },
                {
                    "label": I18n.t("Когда мало", "When low"),
                    "value": "low"
                },
                {
                    "label": I18n.t("Всегда", "Always"),
                    "value": "always"
                }
            ]
            currentValue: Config.peripherals.percent
            onActivated: v => Config.peripherals.percent = v
        }
        CatChoice {
            label: I18n.t("Ширина ампулы", "The ampoule's width")
            model: [
                {
                    "label": I18n.t("Узкая", "Slim"),
                    "value": "slim"
                },
                {
                    "label": I18n.t("Обычная", "Normal"),
                    "value": "normal"
                },
                {
                    "label": I18n.t("Широкая", "Wide"),
                    "value": "wide"
                }
            ]
            currentValue: Config.peripherals.size
            onActivated: v => Config.peripherals.size = v
        }
        CatToggle {
            label: I18n.t("Полка", "The shelf")
            hint: I18n.t("линия, на которой они стоят", "The line they stand on")
            checked: Config.peripherals.rack
            onToggled: v => Config.peripherals.rack = v
        }
        CatSpin {
            label: I18n.t("Показывать", "Show")
            hint: I18n.t("100 % — всегда; ниже — только те, что сели до этой черты, и те, что заряжаются", "100%: always; lower: only the ones down to this line, and the ones charging")
            from: 10
            to: 100
            stepSize: 10
            value: Config.peripherals.showBelow
            suffix: " %"
            onMoved: v => Config.peripherals.showBelow = v
        }
        CatSpin {
            label: I18n.t("Не больше", "At most")
            hint: I18n.t("ампул на панели; остальные — в списке по клику", "Ampoules on the bar; the rest are in the list a click opens")
            from: 1
            to: 8
            value: Config.peripherals.max
            onMoved: v => Config.peripherals.max = v
        }
    }
    CatGroup {
        name: "liquid"
        title: I18n.t("Жидкость", "The liquid")
        icon: "drop"
        // a full ampoule a palette: pick by the look of it
        CatCustom {
            wide: true
            CatBox {
                // a full ampoule a palette: pick by the look of it
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: [
                            {
                                "value": "realm",
                                "label": Theme.realm === "hell" ? I18n.t("Ад", "Hell") : I18n.t("Тема", "Theme")
                            },
                            {
                                "value": "traffic",
                                "label": I18n.t("Светофор", "Traffic light")
                            },
                            {
                                "value": "ice",
                                "label": I18n.t("Лёд", "Ice")
                            },
                            {
                                "value": "mono",
                                "label": I18n.t("Один цвет", "One colour")
                            },
                            {
                                "value": "custom",
                                "label": I18n.t("Свои", "Mine")
                            }
                        ]
                        PxButton {
                            id: swatch
                            required property var modelData
                            checked: Config.peripherals.palette === modelData.value
                            implicitWidth: Math.max(Theme.u * 34, name.implicitWidth + Theme.u * 8)
                            implicitHeight: sample.height + name.implicitHeight + Theme.u * 10
                            Accessible.name: modelData.label
                            onClicked: Config.peripherals.palette = modelData.value
                            PxAmpoule {
                                id: sample
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Theme.u * 4
                                pixel: Theme.u * 2
                                rows: 13
                                value: 1
                                stops: Peripherals.stopsOf(swatch.modelData.value, Theme.realm)
                                paint: "height"
                                steps: Config.peripherals.steps
                                glint: Config.peripherals.glint
                            }
                            PxText {
                                id: name
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.u * 3
                                kind: "tiny"
                                text: swatch.modelData.label
                                color: swatch.checked && Theme.settingsSkinFor(swatch) !== "classic" ? Theme.selectText : Theme.tone("text", Theme.p5For(parent))
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            present: Config.peripherals.palette === "custom"
            label: I18n.t("Свои цвета", "Your colours")
            hint: I18n.t("пусто, половина, полная — #rrggbb", "Empty, half, full: #rrggbb")
            CatBox {
                Row {
                    spacing: Theme.u * 3
                    Repeater {
                        model: 3
                        Row {
                            id: own
                            required property int index
                            readonly property string now: (Config.peripherals.colors || [])[index] || "#ffffff"
                            spacing: Theme.u
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.u * 8
                                height: Theme.u * 8
                                color: own.now
                                border.width: Math.max(1, Theme.u / 2)
                                border.color: Theme.tone("edge", Theme.p5For(parent))
                            }
                            PxField {
                                width: Theme.u * 46
                                text: own.now
                                placeholder: "#rrggbb"
                                onEdited: if (/^#[0-9a-f]{6}$/i.test(text) && text.toLowerCase() !== own.now.toLowerCase()) {
                                    const c = (Config.peripherals.colors || []).slice(0, 3);
                                    while (c.length < 3)
                                        c.push("#ffffff");
                                    c[own.index] = text.toLowerCase();
                                    Config.peripherals.colors = c;
                                }
                            }
                        }
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Как красить", "How it is coloured")
            hint: I18n.t("по высоте: цвета идут снизу вверх, заряд их обрезает; по уровню: вся жидкость одного цвета — цвета своего уровня", "By height: the colours run up the glass and the charge cuts them; by level: all of it in one colour, its level's")
            model: [
                {
                    "label": I18n.t("По высоте", "By height"),
                    "value": "height"
                },
                {
                    "label": I18n.t("По уровню", "By level"),
                    "value": "level"
                }
            ]
            currentValue: Config.peripherals.paint
            onActivated: v => Config.peripherals.paint = v
        }
        CatToggle {
            present: Config.peripherals.paint === "height"
            label: I18n.t("Пиксельные ступени", "Pixel steps")
            hint: I18n.t("цвет на каждый ряд пикселей; без них — плавный переход", "A colour a row of pixels; without them the colours blend")
            checked: Config.peripherals.steps
            onToggled: v => Config.peripherals.steps = v
        }
        CatToggle {
            label: I18n.t("Блик на стекле", "The glass's glint")
            hint: I18n.t("столбик пикселей, не размытие", "A column of pixels, not a blur")
            checked: Config.peripherals.glint
            onToggled: v => Config.peripherals.glint = v
        }
        CatToggle {
            label: I18n.t("Пузырьки при зарядке", "Bubbles while charging")
            hint: I18n.t("заряжается — в ампуле поднимаются пузырьки, кольцо на горлышке жёлтое", "While it charges bubbles rise in the ampoule and the neck's ring is yellow")
            checked: Config.peripherals.bubbles
            onToggled: v => Config.peripherals.bubbles = v
        }
    }
    CatGroup {
        name: "alerts"
        title: I18n.t("Когда устройство садится", "When a device runs low")
        icon: "warn"
        CatToggle {
            label: I18n.t("Предупреждать", "Warn me")
            hint: I18n.t("уведомление один раз на каждом пороге, для каждого устройства", "One notification at each step, for each device")
            checked: Config.peripherals.alerts
            onToggled: v => Config.peripherals.alerts = v
        }
        CatSpin {
            label: I18n.t("Мало", "Low")
            hint: I18n.t("кольцо на горлышке краснеет", "The neck's ring turns red")
            from: 10
            to: 50
            stepSize: 5
            value: Config.peripherals.lowAt
            suffix: " %"
            onMoved: v => Config.peripherals.lowAt = Math.max(v, Config.peripherals.veryLowAt + 1)
        }
        CatSpin {
            label: I18n.t("Почти пусто", "Almost empty")
            hint: I18n.t("ампула мигает", "The ampoule blinks")
            from: 2
            to: 30
            value: Config.peripherals.veryLowAt
            suffix: " %"
            onMoved: v => Config.peripherals.veryLowAt = Math.min(v, Config.peripherals.lowAt - 1)
        }
        CatToggle {
            label: I18n.t("Сказать, когда зарядилось", "Tell me when it is charged")
            checked: Config.peripherals.fullAlert
            onToggled: v => Config.peripherals.fullAlert = v
        }
        CatToggle {
            label: Angel.demon ? I18n.t("Демоница замечает", "The demon notices") : I18n.t("Ангел замечает", "The angel notices")
            hint: I18n.t("говорит, какое устройство садится; молчит в играх и на стриме", "Says which device is running low; quiet in games and on stream")
            checked: Config.peripherals.angel
            onToggled: v => Config.peripherals.angel = v
        }
    }
    CatGroup {
        name: "sources"
        title: I18n.t("Откуда брать заряд", "Where the charge comes from")
        icon: "plug"
        CatToggle {
            label: "UPower"
            hint: I18n.t("Bluetooth-устройства, Logitech, геймпады — сразу, как меняется заряд", "Bluetooth devices, Logitech, gamepads: at once, as the charge changes")
            checked: Config.peripherals.upower
            onToggled: v => Config.peripherals.upower = v
        }
        CatToggle {
            label: I18n.t("Донглы мышей", "Mouse dongles")
            hint: I18n.t("LAMZU: один запрос «сколько заряда» через донгл, настройки мыши не трогаются", "LAMZU: one “how much is left” question through the dongle; the mouse's settings are never touched")
            checked: Config.peripherals.vendor
            onToggled: v => Config.peripherals.vendor = v
        }
        CatToggle {
            label: "headsetcontrol"
            hint: Peripherals.tools.headsetcontrol === false ? I18n.t("USB-гарнитуры (SteelSeries, Logitech, Corsair, HyperX); не установлен — пакет headsetcontrol", "USB headsets (SteelSeries, Logitech, Corsair, HyperX); not installed: the headsetcontrol package") : I18n.t("USB-гарнитуры (SteelSeries, Logitech, Corsair, HyperX)", "USB headsets (SteelSeries, Logitech, Corsair, HyperX)")
            checked: Config.peripherals.headset
            onToggled: v => Config.peripherals.headset = v
        }
        CatChoice {
            label: I18n.t("Опрашивать раз в", "Ask every")
            hint: I18n.t("донглы и гарнитуры; UPower сообщает сам", "The dongles and the headsets; UPower tells by itself")
            combo: true
            model: [1, 2, 5, 10, 30].map(m => ({
                        "label": m + I18n.t(" мин", " min"),
                        "value": m
                    }))
            currentValue: Config.peripherals.pollMinutes
            onActivated: v => Config.peripherals.pollMinutes = v
        }
        CatChoice {
            label: I18n.t("Замолчавшее устройство", "A device that went silent")
            hint: I18n.t("мышь засыпает, когда лежит: десять минут ампула как была, потом бледнеет; здесь — когда убрать её совсем", "A mouse sleeps when it lies still: for ten minutes its ampoule stays as it was, then it pales; this is when it goes for good")
            combo: true
            model: [
                {
                    "label": I18n.t("убирать сразу", "Gone at once"),
                    "value": 0
                },
                {
                    "label": I18n.t("через 30 минут", "After 30 minutes"),
                    "value": 30
                },
                {
                    "label": I18n.t("через 2 часа", "After 2 hours"),
                    "value": 120
                },
                {
                    "label": I18n.t("через сутки", "After a day"),
                    "value": 1440
                }
            ]
            currentValue: Config.peripherals.keepMinutes
            onActivated: v => Config.peripherals.keepMinutes = v
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    spacing: Theme.u * 4
                    PxButton {
                        icon: "refresh"
                        text: I18n.t("Опросить сейчас", "Ask now")
                        onClicked: Peripherals.refresh()
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        dim: true
                        kind: "tiny"
                        text: Peripherals.polledAt > 0 ? I18n.t("последний опрос: ", "last asked: ") + Qt.formatTime(new Date(Peripherals.polledAt), "HH:mm:ss") : I18n.t("ещё не опрашивал", "not asked yet")
                    }
                }
            }
        }
    }
}
