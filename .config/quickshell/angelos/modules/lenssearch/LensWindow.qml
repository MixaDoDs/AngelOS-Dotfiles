pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Google Lens's results in a window of ours (services/LensSearch): the picture on the left; on
// the right what it is (the name and a line of the AI overview), then the similar pictures, the
// exact matches (their own tab, fetched when opened) and the recognised text. Google's own page
// is one button away, and so is the browser. Long text in a plain font, the pixel font for heads.
Scope {
    // the open window (tests/lens looks into it)
    readonly property var window: loader.item

    LazyLoader {
        id: loader
        active: LensSearch.open

        FloatingWindow {
            id: win
            RightClickGuard {}
            title: Shell.appTitle + " · " + I18n.t("Поиск по картинке", "Picture search")
            visible: true
            color: "transparent"
            implicitWidth: 900
            implicitHeight: 620
            minimumSize: Qt.size(640, 460)
            onClosed: LensSearch.close()
            onVisibleChanged: if (!visible)
                LensSearch.close()

            Item {
                id: view
                anchors.fill: parent
                readonly property int u: Theme.u
                readonly property string sans: Theme.macFont
                readonly property bool done: LensSearch.status === "results"
                property string tab: "visual"
                onDoneChanged: if (done)
                    tab = LensSearch.visual.length ? "visual" : LensSearch.words.length ? "text" : "visual"
                onTabChanged: if (tab === "exact")
                    LensSearch.loadExact()

                Shortcut {
                    context: Qt.WindowShortcut
                    sequence: "Escape"
                    onActivated: LensSearch.close()
                }
                // the selection in the text tab, else all the text
                Shortcut {
                    context: Qt.WindowShortcut
                    sequences: ["Ctrl+C", "Ctrl+С"]
                    onActivated: LensSearch.copyText(textBox.selectedText || LensSearch.text)
                }

                PxWindow {
                    anchors.fill: parent
                    anchors.rightMargin: view.u * 2
                    anchors.bottomMargin: view.u * 2
                    skin: ""
                    translucent: false
                    title: I18n.exe("lens")
                    icon: "search"
                    onCloseClicked: LensSearch.close()
                    onTitlePressed: win.startSystemMove()

                    Item {
                        id: body
                        readonly property string settingsSkin: "classic"
                        width: parent.width
                        height: parent.height

                        // ---- left: the picture (or Google's translation of it) and the ways out
                        Column {
                            id: side
                            width: Math.round(body.width * 0.34)
                            height: parent.height
                            spacing: view.u * 3

                            PxBox {
                                id: picBox
                                width: parent.width
                                height: parent.height - tools.height - parent.spacing
                                sunken: true
                                color: Theme.sunken
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: picBox.inset + view.u * 2
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    source: LensSearch.translateState === "done" && LensSearch.translated ? LensSearch.translated : LensSearch.picture ? "file://" + LensSearch.picture : ""
                                }
                                PxText {
                                    visible: LensSearch.translateState === "done"
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: picBox.inset + view.u * 2
                                    kind: "tiny"
                                    dim: true
                                    text: I18n.t("перевод Google", "Google's translation")
                                }
                            }
                            Column {
                                id: tools
                                width: parent.width
                                spacing: view.u * 2
                                PxButton {
                                    visible: LensSearch.canTranslate && view.done
                                    width: parent.width
                                    icon: "chat"
                                    checkable: false
                                    checked: LensSearch.translateState === "done"
                                    enabled: LensSearch.translateState !== "loading"
                                    text: LensSearch.translateState === "loading" ? I18n.t("Перевожу…", "Translating…") : LensSearch.translateState === "done" ? I18n.t("Показать оригинал", "Show the original") : LensSearch.translateState === "failed" ? I18n.t("Перевод не вышел", "No translation") : I18n.t("Перевести картинку", "Translate the picture")
                                    onClicked: LensSearch.translate()
                                }
                                PxButton {
                                    width: parent.width
                                    icon: "window"
                                    enabled: LensSearch.status !== "captcha"
                                    text: LensSearch.pageShown ? I18n.t("Страница Google открыта", "Google's page is open") : I18n.t("Страница Google", "Google's page")
                                    onClicked: LensSearch.showPage()
                                }
                                Row {
                                    width: parent.width
                                    spacing: view.u * 2
                                    PxButton {
                                        width: (parent.width - parent.spacing) / 2
                                        compact: true
                                        icon: "arrowRight"
                                        text: I18n.t("В браузер", "Browser")
                                        onClicked: LensSearch.toBrowser()
                                    }
                                    PxButton {
                                        width: (parent.width - parent.spacing) / 2
                                        compact: true
                                        icon: "refresh"
                                        enabled: LensSearch.status !== "sending" && LensSearch.status !== "captcha"
                                        text: I18n.t("Ещё раз", "Again")
                                        onClicked: LensSearch.retry()
                                    }
                                }
                            }
                        }

                        // ---- right: what it is, then the tabs
                        Item {
                            id: main
                            anchors.left: side.right
                            anchors.leftMargin: view.u * 5
                            anchors.right: parent.right
                            height: parent.height

                            Column {
                                id: head
                                width: parent.width
                                spacing: view.u
                                visible: view.done && (LensSearch.entity.name || LensSearch.entity.description)
                                height: visible ? implicitHeight : 0
                                PxText {
                                    visible: !!LensSearch.entity.name
                                    width: parent.width
                                    kind: "title"
                                    elide: Text.ElideRight
                                    text: LensSearch.entity.name || ""
                                }
                                Text {
                                    visible: !!LensSearch.entity.description
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    color: Theme.textDim
                                    font.family: view.sans
                                    font.pixelSize: Math.round(Theme.sizeBody * 1.05)
                                    text: LensSearch.entity.description || ""
                                }
                            }

                            PxSegmented {
                                id: tabs
                                anchors.top: head.bottom
                                anchors.topMargin: head.visible ? view.u * 4 : 0
                                visible: view.done
                                currentValue: view.tab
                                model: [
                                    {
                                        "label": I18n.t("Похожие", "Similar") + (LensSearch.visual.length ? " " + LensSearch.visual.length : ""),
                                        "value": "visual",
                                        "icon": "image"
                                    },
                                    {
                                        "label": I18n.t("Точные совпадения", "Exact matches") + (LensSearch.exactState === "done" ? " " + LensSearch.exact.length : ""),
                                        "value": "exact",
                                        "icon": "search"
                                    },
                                    {
                                        "label": I18n.t("Текст", "Text") + (LensSearch.words.length ? "" : " —"),
                                        "value": "text",
                                        "icon": "document"
                                    }
                                ]
                                onActivated: v => view.tab = v
                            }

                            Item {
                                id: area
                                anchors.top: tabs.visible ? tabs.bottom : head.bottom
                                anchors.topMargin: tabs.visible ? view.u * 4 : 0
                                anchors.bottom: parent.bottom
                                width: parent.width

                                // sending: grey cards blinking in steps (no gradients)
                                Grid {
                                    id: skeleton
                                    visible: LensSearch.status === "sending"
                                    width: parent.width
                                    columns: 3
                                    spacing: view.u * 3
                                    property int beat: 0
                                    Timer {
                                        interval: 380
                                        repeat: true
                                        running: skeleton.visible
                                        onTriggered: skeleton.beat = (skeleton.beat + 1) % 6
                                    }
                                    Repeater {
                                        model: 6
                                        PxBox {
                                            id: sk
                                            required property int index
                                            width: (skeleton.width - skeleton.spacing * 2) / 3
                                            height: view.u * 74
                                            sunken: true
                                            color: Theme.sunken
                                            opacity: sk.index === skeleton.beat ? 1 : 0.55
                                            Rectangle {
                                                x: sk.inset + view.u * 3
                                                y: sk.inset + view.u * 3
                                                width: parent.width - x * 2
                                                height: view.u * 40
                                                color: Theme.faceAlt
                                            }
                                            Rectangle {
                                                x: sk.inset + view.u * 3
                                                y: sk.inset + view.u * 47
                                                width: (parent.width - x * 2) * 0.8
                                                height: view.u * 5
                                                color: Theme.faceAlt
                                            }
                                            Rectangle {
                                                x: sk.inset + view.u * 3
                                                y: sk.inset + view.u * 56
                                                width: (parent.width - x * 2) * 0.5
                                                height: view.u * 4
                                                color: Theme.faceAlt
                                            }
                                        }
                                    }
                                }
                                PxText {
                                    visible: LensSearch.status === "sending"
                                    anchors.top: skeleton.bottom
                                    anchors.topMargin: view.u * 4
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    dim: true
                                    text: I18n.t("Ищу по картинке в Google…", "Searching Google by the picture…")
                                }

                                // consent, captcha, nothing found, errors: one note and what to do
                                Column {
                                    id: note
                                    readonly property string kind: LensSearch.status === "consent" || LensSearch.status === "captcha" || LensSearch.status === "empty" || LensSearch.status === "error" ? LensSearch.status : ""
                                    visible: kind !== ""
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, view.u * 200)
                                    spacing: view.u * 4
                                    PxIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: note.kind === "empty" ? "search" : note.kind === "error" ? "warn" : note.kind === "captcha" ? "lock" : "info"
                                        pixel: view.u * 2
                                    }
                                    PxText {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        kind: "title"
                                        wrapMode: Text.Wrap
                                        text: ({
                                                "consent": I18n.t("Google спрашивает про cookies", "Google asks about cookies"),
                                                "captcha": I18n.t("Google попросил капчу", "Google asked for a captcha"),
                                                "empty": I18n.t("Ничего не нашлось", "Nothing found"),
                                                "error": LensSearch.error === "broken" ? I18n.t("Не смог прочитать страницу", "Couldn't read the page") : I18n.t("Не получилось", "That didn't work")
                                            })[note.kind] || ""
                                    }
                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        color: Theme.textDim
                                        font.family: view.sans
                                        font.pixelSize: Theme.sizeBody
                                        text: note.kind === "consent" ? I18n.t("Один раз выберите на странице Google — дальше он запомнит. Картинка отправится сама.", "Choose once on Google's page — it will remember. The picture goes again by itself.") : note.kind === "captcha" ? I18n.t("Поиск открыт в браузере. Полчаса поиск по картинке будет открываться там, чтобы Google успокоился.", "The search is open in the browser. For half an hour picture search opens there, so Google calms down.") : note.kind === "empty" ? I18n.t("Google не нашёл похожих картинок. Попробуйте обвести кусок поменьше или покрупнее.", "Google found no similar pictures. Try circling a smaller or a bigger piece.") : LensSearch.error === "broken" ? I18n.t("Google, похоже, поменял страницу. Её можно открыть как есть.", "Google seems to have changed its page. It can be opened as it is.") : LensSearch.error === "timeout" ? I18n.t("Google долго не отвечает — проверьте сеть.", "Google takes too long — check the network.") : LensSearch.error === "worker" ? I18n.t("Помощник не запустился: нужен qml6 с QtWebEngine.", "The helper didn't start: it needs qml6 with QtWebEngine.") : LensSearch.error === "lost" ? I18n.t("Картинка потерялась по дороге.", "The picture got lost on the way.") : I18n.t("Что-то пошло не так: ", "Something went wrong: ") + LensSearch.error
                                    }
                                    PxButton {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: note.kind === "consent" || note.kind === "error" && LensSearch.error !== "worker" || note.kind === "empty"
                                        accent: note.kind === "consent"
                                        icon: "window"
                                        text: note.kind === "consent" ? I18n.t("Открыть страницу Google", "Open Google's page") : I18n.t("Показать страницу Google", "Show Google's page")
                                        onClicked: LensSearch.showPage()
                                    }
                                    PxButton {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: note.kind === "captcha"
                                        icon: "arrowRight"
                                        text: I18n.t("Открыть в браузере ещё раз", "Open in the browser again")
                                        onClicked: LensSearch.toBrowser()
                                    }
                                }

                                // the cards: similar pictures, or the exact matches
                                PxScroll {
                                    id: cards
                                    readonly property var list: view.tab === "exact" ? LensSearch.exact : LensSearch.visual
                                    visible: view.done && view.tab !== "text" && list.length > 0
                                    anchors.fill: parent
                                    contentHeight: grid.height
                                    onListChanged: contentY = 0
                                    Grid {
                                        id: grid
                                        width: cards.flick.width
                                        columns: Math.max(2, Math.floor((width + spacing) / (view.u * 80 + spacing)))
                                        spacing: view.u * 3
                                        readonly property real cw: (width - spacing * (columns - 1)) / columns
                                        Repeater {
                                            model: cards.list
                                            Card {
                                                cw: grid.cw
                                            }
                                        }
                                    }
                                }
                                PxText {
                                    visible: view.done && view.tab !== "text" && cards.list.length === 0
                                    anchors.centerIn: parent
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    dim: true
                                    text: view.tab === "exact" && LensSearch.exactState === "loading" ? I18n.t("Ищу точные совпадения…", "Looking for exact matches…") : view.tab === "exact" ? I18n.t("Точных совпадений нет", "No exact matches") : I18n.t("Похожих картинок нет — смотрите текст", "No similar pictures — see the text")
                                }

                                // the recognised text: select a part (Ctrl+C) or copy it all
                                Item {
                                    visible: view.done && view.tab === "text"
                                    anchors.fill: parent
                                    PxBox {
                                        id: textFrame
                                        anchors.top: parent.top
                                        anchors.bottom: copyRow.top
                                        anchors.bottomMargin: view.u * 3
                                        width: parent.width
                                        sunken: true
                                        color: Theme.sunken
                                        PxScroll {
                                            id: textScroll
                                            anchors.fill: parent
                                            anchors.margins: textFrame.inset + view.u * 3
                                            contentHeight: textBox.implicitHeight
                                            TextEdit {
                                                id: textBox
                                                width: textScroll.flick.width
                                                readOnly: true
                                                selectByMouse: true
                                                wrapMode: TextEdit.Wrap
                                                textFormat: TextEdit.PlainText
                                                color: Theme.text
                                                selectionColor: Theme.select
                                                selectedTextColor: Theme.selectText
                                                font.family: view.sans
                                                font.pixelSize: Math.round(Theme.sizeBody * 1.15)
                                                text: LensSearch.text
                                            }
                                        }
                                        PxText {
                                            visible: !LensSearch.words.length
                                            anchors.centerIn: parent
                                            dim: true
                                            text: I18n.t("Текста на картинке не нашлось", "No text found in the picture")
                                        }
                                    }
                                    Row {
                                        id: copyRow
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        spacing: view.u * 2
                                        PxText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            kind: "tiny"
                                            dim: true
                                            text: I18n.t("выделите часть — Ctrl+C", "select a part — Ctrl+C")
                                        }
                                        PxButton {
                                            id: copyBtn
                                            enabled: LensSearch.words.length > 0
                                            icon: copied.running ? "check" : "document"
                                            text: copied.running ? I18n.t("Скопировано", "Copied") : I18n.t("Копировать всё", "Copy all")
                                            onClicked: {
                                                LensSearch.copyText(LensSearch.text);
                                                copied.restart();
                                            }
                                            Timer {
                                                id: copied
                                                interval: 1400
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // one result: its picture, title, site with its icon, price
                component Card: PxBox {
                    id: card
                    required property var modelData
                    property real cw: 0
                    width: cw
                    height: cardCol.implicitHeight + card.inset * 2 + Theme.u * 6
                    color: hover.hovered ? Theme.faceAlt : Theme.face
                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: LensSearch.openMatch(card.modelData.url)
                    }
                    Column {
                        id: cardCol
                        x: card.inset + Theme.u * 3
                        y: card.inset + Theme.u * 3
                        width: card.width - x * 2
                        spacing: Theme.u * 2
                        Rectangle {
                            width: parent.width
                            height: Math.round(width * 0.66)
                            color: Theme.sunken
                            clip: true
                            Image {
                                id: thumb
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                source: card.modelData.thumb || ""
                            }
                            PxIcon {
                                visible: thumb.status !== Image.Ready
                                anchors.centerIn: parent
                                name: "image"
                                opacity: 0.5
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: Theme.text
                            font.family: Theme.macFont
                            font.pixelSize: Theme.sizeBody
                            text: card.modelData.title || ""
                        }
                        Row {
                            width: parent.width
                            spacing: Theme.u * 2
                            Image {
                                id: fav
                                visible: !!card.modelData.favicon && status === Image.Ready
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                sourceSize: Qt.size(32, 32)
                                smooth: true
                                source: card.modelData.favicon || ""
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (fav.visible ? fav.width + parent.spacing : 0)
                                kind: "tiny"
                                dim: true
                                elide: Text.ElideRight
                                text: card.modelData.site || ""
                            }
                        }
                        PxText {
                            visible: !!card.modelData.price
                            width: parent.width
                            font.bold: true
                            color: Theme.accent
                            elide: Text.ElideRight
                            text: card.modelData.price || ""
                        }
                        Text {
                            visible: !!card.modelData.extra
                            width: parent.width
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: Theme.textDim
                            font.family: Theme.macFont
                            font.pixelSize: Theme.sizeTiny
                            text: card.modelData.extra || ""
                        }
                    }
                }
            }
        }
    }
}
