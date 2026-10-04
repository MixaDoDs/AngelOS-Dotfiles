pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Шрифты", "Fonts")
    subtitle: I18n.t("Пиксельные шрифты для заголовков, текста и кода. Размеры подгоняются под сетку шрифта, чтобы буквы оставались чёткими.", "Pixel fonts for titles, text and code. Sizes snap to each font's pixel grid so glyphs stay crisp.")
    Component.onCompleted: Fonts.refresh()

    readonly property string sample: I18n.t("Привет, ангел ♡ 0123", "Hello, angel ♡ 0123")

    PxGroup {
        name: "presets"
        title: I18n.t("Готовые наборы", "Presets")
        icon: "sparkle"
        width: parent.width
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Repeater {
                model: Fonts.presets
                PxButton {
                    required property var modelData
                    readonly property bool current: Config.appearance.fontTitle === modelData.fonts[0] && Config.appearance.fontBody === modelData.fonts[1] && Config.appearance.fontMono === modelData.fonts[2]
                    text: modelData.label + (modelData.needs.some(id => !Fonts.installed(id)) ? I18n.t(" · скачать", " · download") : "")
                    checked: current
                    enabled: !Fonts.busy
                    onClicked: Fonts.applyPreset(modelData)
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Недостающие шрифты скачиваются с GitHub / Google Fonts, проверяются по SHA-256 и ставятся в ~/.local/share/fonts/angelos.", "Missing fonts are downloaded from GitHub / Google Fonts, verified by SHA-256 and installed to ~/.local/share/fonts/angelos.")
        }
    }

    PxGroup {
        name: "interface"
        title: I18n.t("Интерфейс", "Interface")
        icon: "document"
        width: parent.width
        SettingRow {
            label: I18n.t("Масштаб шрифтов", "Font scale")
            hint: I18n.t("Пиксельный шрифт чёток только в целое число своих клеток, поэтому шрифты растут ступенями, каждый в свой момент: на ×1.25 крупнеют заголовки, на ×1.5 — и основной текст. Строки, панель и меню растут вместе с текстом.", "A pixel font is crisp only at a whole number of its cells, so the fonts grow in steps, each at its own: at 1.25× the headings grow, at 1.5× the body text too. Rows, the bar and the menus grow with the text.")
            PxSegmented {
                model: [1, 1.25, 1.5, 1.75, 2].map(v => ({
                            "label": "×" + v,
                            "value": v
                        }))
                currentValue: Config.appearance.fontScale
                onActivated: v => Config.appearance.fontScale = v
            }
        }
        Repeater {
            model: [
                {
                    "key": "fontTitle",
                    "role": "title",
                    "label": I18n.t("Заголовки и панель", "Titles and bar"),
                    "kind": "title"
                },
                {
                    "key": "fontBody",
                    "role": "body",
                    "label": I18n.t("Текст", "Text"),
                    "kind": "body"
                },
                {
                    "key": "fontMono",
                    "role": "mono",
                    "label": I18n.t("Код и терминал", "Code"),
                    "kind": "mono"
                }
            ]
            Column {
                id: slot
                required property var modelData
                width: parent.width
                spacing: Theme.u * 2
                SettingRow {
                    label: slot.modelData.label
                    PxCombo {
                        width: Math.min(parent.width, Theme.u * 140)
                        model: Fonts.choices(slot.modelData.role)
                        currentValue: Config.appearance[slot.modelData.key]
                        onActivated: v => Config.appearance[slot.modelData.key] = v
                    }
                }
                PxText {
                    width: parent.width
                    elide: Text.ElideRight
                    kind: slot.modelData.kind
                    text: page.sample
                    color: Theme.accent
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("♡ — шрифт хорошо подходит для этой роли. Масштаб шрифтов — вверху этой страницы.", "♡ marks fonts that suit the role. The font scale is at the top of this page.")
        }
    }

    PxGroup {
        name: "pixel-fonts"
        title: I18n.t("Пиксельные шрифты", "Pixel fonts")
        icon: "package"
        width: parent.width
        PxText {
            visible: Fonts.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: Fonts.error
        }
        Repeater {
            model: Fonts.catalog
            PxBox {
                id: card
                required property var modelData
                width: parent.width
                height: cardCol.implicitHeight + Theme.u * 8
                color: Theme.mix(Theme.face, Theme.accent, card.modelData.installed ? 0.06 : 0)
                Column {
                    id: cardCol
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 2
                    Row {
                        width: parent.width
                        spacing: Theme.u * 4
                        PxText {
                            text: card.modelData.families.join(" / ")
                            font.bold: true
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "tiny"
                            dim: true
                            text: [card.modelData.cyrillic ? I18n.t("кириллица", "Cyrillic") : I18n.t("только латиница", "Latin only"), card.modelData.native ? card.modelData.native + " px" : "", card.modelData.license, card.modelData.note].filter(s => s).join(" · ")
                        }
                    }
                    Text {
                        visible: card.modelData.installed
                        width: parent.width
                        elide: Text.ElideRight
                        text: page.sample
                        color: Theme.text
                        font.family: card.modelData.families[0]
                        font.pixelSize: Theme.fontPx(16, card.modelData.families[0])
                        font.hintingPreference: Font.PreferFullHinting
                        renderType: Text.NativeRendering
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            visible: !card.modelData.installed && card.modelData.installable
                            compact: true
                            icon: "arrowDown"
                            text: Fonts.busyId === card.modelData.id ? I18n.t("Скачиваю…", "Downloading…") : I18n.t("Установить", "Install")
                            enabled: !Fonts.busy
                            onClicked: Fonts.install(card.modelData.id)
                        }
                        Repeater {
                            model: card.modelData.installed ? [["fontTitle", I18n.t("Заголовки", "Titles")], ["fontBody", I18n.t("Текст", "Text")], ["fontMono", I18n.t("Код", "Code")]] : []
                            PxButton {
                                required property var modelData
                                readonly property string family: card.modelData.families[modelData[0] === "fontMono" && card.modelData.families.length > 1 ? 1 : 0]
                                compact: true
                                text: modelData[1]
                                checked: Theme[modelData[0]] === family
                                onClicked: Config.appearance[modelData[0]] = family
                            }
                        }
                        PxButton {
                            visible: card.modelData.removable
                            compact: true
                            icon: "trash"
                            enabled: !Fonts.busy
                            onClicked: Fonts.remove(card.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
