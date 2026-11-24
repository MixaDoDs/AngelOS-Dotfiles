// The settings once in DriverPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Device driver (2026-10-12; services/Devices, scripts/devices.py): mice set up from the
// shell, without the maker's site or a Windows utility. A device is drawn from its
// description file (data/devices, ~/.config/angelos/devices): what it says it can do is on
// the page, the rest is not.
CatPage {
    id: page
    heading: I18n.t("Драйвер устройств", "Device driver")
    subtitle: I18n.t("Чувствительность, частота опроса и сенсор мыши.", "The mouse's sensitivity, polling rate and sensor.")
    // the helper runs only while this page is on the screen
    readonly property bool live: showing && !!Window.window && Window.window.visible
    property bool held: false
    function sync() {
        if (live === held)
            return;
        held = live;
        if (live)
            Devices.hold();
        else
            Devices.release();
    }
    onLiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held)
            Devices.release();
    }
    readonly property var dev: Devices.current
    readonly property var st: Devices.state
    readonly property bool isMouse: !!dev && dev.kind === "mouse"
    readonly property var mouse: st && st.kind === "mouse" ? st : null
    function capOf(name) {
        const c = dev && dev.capabilities ? dev.capabilities[name] : null;
        return c && typeof c === "object" ? c : ({});
    }
    function sleepLabel(sec) {
        return sec < 60 ? sec + I18n.t(" с", " s") : sec / 60 + I18n.t(" мин", " min");
    }
    // the mouse's DPI stages with one of them changed, as the helper takes them
    function stagesWith(index, dpi) {
        return page.mouse.dpiStages.map((s, i) => i === index ? dpi : s.x);
    }
    function cap(name) {
        return !!dev && !!dev.capabilities && !!dev.capabilities[name];
    }
    property bool sureRestore: false
    Timer {
        id: unsure
        interval: 5000
        onTriggered: page.sureRestore = false
    }
    CatGroup {
        name: "devices"
        title: I18n.t("Устройства", "Devices")
        icon: "chip"
        CatNote {
            present: Devices.testing && Devices.fake === ""
            dim: true
            text: I18n.t("Самопроверка оболочки: настоящие устройства не опрашиваются.", "The shell's self-test: no real device is asked.")
        }
        CatNote {
            present: !Devices.scanned && Devices.wanted
            dim: true
            text: I18n.t("Ищу устройства…", "Looking for devices…")
        }
        CatNote {
            present: Devices.scanned && Devices.devices.length === 0
            dim: true
            text: I18n.t("Ни одно знакомое устройство не подключено. Список — в «Ещё…»; своё можно описать файлом.", "No known device is plugged in. The list is under More…; describe your own in a file.")
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Devices.devices
                    Item {
                        id: row
                        required property var modelData
                        readonly property bool chosen: modelData.id === Devices.currentId
                        width: parent.width
                        height: Math.max(words.implicitHeight, pick.height) + Theme.u * 4
                        PxIcon {
                            id: glyph
                            anchors.verticalCenter: parent.verticalCenter
                            name: "mouse"
                        }
                        Column {
                            id: words
                            anchors.left: glyph.right
                            anchors.leftMargin: Theme.u * 4
                            anchors.right: pick.left
                            anchors.rightMargin: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                font.bold: true
                                text: row.modelData.name + (row.modelData.fake ? " · " + I18n.t("эмулятор", "emulator") : "")
                            }
                            PxText {
                                width: parent.width
                                wrapMode: Text.Wrap
                                kind: "tiny"
                                dim: true
                                text: {
                                    const parts = [Devices.supportLabel(row.modelData.support)];
                                    if (row.chosen && page.st)
                                        parts.push(I18n.t("прошивка ", "firmware ") + page.st.firmware.version);
                                    if (row.modelData.access === "denied")
                                        parts.push(I18n.t("нет доступа", "no access"));
                                    else if (row.modelData.access === "busy")
                                        parts.push(I18n.t("интерфейс занят", "the interface is taken"));
                                    if (row.modelData.origin === "user")
                                        parts.push(I18n.t("ваш файл описания", "your description file"));
                                    return parts.join(" · ");
                                }
                            }
                        }
                        PxButton {
                            id: pick
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Devices.devices.length > 1 && !row.chosen
                            compact: true
                            text: I18n.t("Открыть", "Open")
                            onClicked: {
                                Devices.close();
                                Devices.open(row.modelData.id);
                            }
                        }
                    }
                }
            }
        }
        // reading the settings: a second or less
        CatCustom {
            wide: true
            CatBox {
                // reading the settings: a second or less
                PxProgress {
                    visible: Devices.loading
                    width: parent.width
                    value: Devices.progress
                }
            }
        }
        CatNote {
            present: Devices.backingUp !== ""
            dim: true
            text: I18n.t("Снимаю резервную копию всех настроек устройства — один раз, перед первой записью…", "Taking a backup of every setting of the device: once, before the first write…")
        }
        // why the device does not open, in words, and what there is to do about it
        CatCustom {
            wide: true
            CatBox {
                // why the device does not open, in words, and what there is to do about it
                PxBox {
                    visible: !!Devices.error && !Devices.loading
                    width: parent.width
                    height: trouble.implicitHeight + Theme.u * 10
                    sunken: true
                    color: Theme.toneFor("sunken", parent)
                    Column {
                        id: trouble
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u * 2
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            font.bold: true
                            text: Devices.errorText(Devices.error)
                        }
                        PxText {
                            visible: !!Devices.error && !!Devices.error.detail
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "mono"
                            dim: true
                            text: Devices.error ? Devices.error.detail || "" : ""
                        }
                        Row {
                            spacing: Theme.u * 3
                            PxButton {
                                compact: true
                                icon: "refresh"
                                text: I18n.t("Проверить ещё раз", "Try again")
                                onClicked: {
                                    Devices.error = null;
                                    Devices.rescan();
                                }
                            }
                            PxButton {
                                compact: true
                                icon: "document"
                                text: I18n.t("Справка", "The guide")
                                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.shellDir + "/docs/devices.md"])
                            }
                        }
                    }
                }
            }
        }
        // a description file that is broken says so here, and breaks nothing else
        CatCustom {
            wide: true
            CatBox {
                // a description file that is broken says so here, and breaks nothing else
                Repeater {
            model: Devices.broken
            Column {
                id: bad
                required property var modelData
                width: parent.width
                spacing: Theme.u
                PxText {
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    font.bold: true
                    color: Theme.danger
                    text: I18n.t("Файл описания с ошибками: ", "A description file with problems: ") + bad.modelData.file
                }
                Repeater {
                    model: bad.modelData.problems.slice(0, 6)
                    PxText {
                        required property var modelData
                        width: bad.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        text: (modelData.at ? modelData.at + ": " : "") + I18n.t(modelData.ru, modelData.en)
                    }
                }
                PxText {
                    visible: bad.modelData.problems.length > 6
                    kind: "tiny"
                    dim: true
                    text: I18n.t("…и ещё ", "…and ") + (bad.modelData.problems.length - 6) + I18n.t("; все — `angelos devices check ФАЙЛ`", " more; all of them: `angelos devices check FILE`")
                }
            }
        }
            }
        }
    }
    CatGroup {
        name: "mouse"
        title: I18n.t("Мышь", "The mouse")
        icon: "mouse"
        present: page.isMouse
        CatNote {
            present: !page.mouse && !Devices.loading && !Devices.error
            dim: true
            text: I18n.t("Открываю мышь…", "Opening the mouse…")
        }
        CatNote {
            present: !!page.mouse
            dim: true
            text: !page.mouse ? "" : I18n.t("Заряд: ", "Charge: ") + page.mouse.battery.percent + " %" + (page.mouse.battery.charging ? I18n.t(", заряжается", ", charging") : "") + " · " + I18n.t("прошивка ", "firmware ") + page.mouse.firmware.version + " · " + I18n.t("профиль ", "profile ") + page.mouse.profile + (Devices.canWrite ? I18n.t(" · настройки пишутся в мышь сразу и читаются обратно", " · settings go to the mouse at once and are read back") : I18n.t(" · только чтение", " · reading only"))
        }
        CatChoice {
            present: !!page.mouse && page.cap("pollingRate")
            label: I18n.t("Частота опроса", "Polling rate")
            hint: I18n.t("сколько раз в секунду мышь сообщает о движении; выше — плавнее и больше нагрузка на процессор и батарею", "How many times a second the mouse reports its movement; higher is smoother and costs more CPU and battery")
            enabled: Devices.canWrite && !Devices.working
            model: (page.capOf("pollingRate").values || []).map(v => ({
                        "label": v >= 1000 ? v / 1000 + "K" : String(v),
                        "value": v
                    }))
            currentValue: page.mouse ? page.mouse.pollingRate : 0
            onActivated: v => Devices.setMouse("pollingRate", v)
        }
        CatCustom {
            present: !!page.mouse && page.cap("dpi")
            label: "DPI"
            hint: I18n.t("ступени чувствительности; активная выделена, клик по номеру делает её активной", "The sensitivity stages; the active one is marked, a click on its number makes a stage the active one")
            CatBox {
                Column {
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.mouse ? page.mouse.dpiStages : []
                        Row {
                            id: stage
                            required property var modelData
                            required property int index
                            spacing: Theme.u * 3
                            PxButton {
                                compact: true
                                accent: !!page.mouse && page.mouse.dpiActive === stage.index + 1
                                enabled: Devices.canWrite && !Devices.working
                                text: String(stage.index + 1)
                                onClicked: Devices.setMouse("dpiActive", stage.index + 1)
                            }
                            PxSpin {
                                enabled: Devices.canWrite && !Devices.working
                                from: page.capOf("dpi").min || 50
                                to: page.capOf("dpi").max || 26000
                                stepSize: page.capOf("dpi").step || 50
                                value: stage.modelData.x
                                onMoved: v => Devices.setMouse("dpiStages", page.stagesWith(stage.index, v))
                            }
                            PxButton {
                                visible: !!page.mouse && page.mouse.dpiStages.length > 1
                                compact: true
                                icon: "close"
                                enabled: Devices.canWrite && !Devices.working
                                onClicked: Devices.setMouse("dpiStages", page.mouse.dpiStages.filter((s, i) => i !== stage.index).map(s => s.x))
                            }
                        }
                    }
                    PxButton {
                        visible: !!page.mouse && page.mouse.dpiStages.length < (page.capOf("dpi").stages || 5)
                        compact: true
                        icon: "plus"
                        enabled: Devices.canWrite && !Devices.working
                        text: I18n.t("Ступень", "A stage")
                        onClicked: Devices.setMouse("dpiStages", page.mouse.dpiStages.map(s => s.x).concat([page.mouse.dpiStages[page.mouse.dpiStages.length - 1].x]))
                    }
                }
            }
        }
        CatChoice {
            present: !!page.mouse && page.cap("lod")
            label: I18n.t("Высота отрыва (LOD)", "Lift-off distance")
            hint: I18n.t("на какой высоте над ковриком мышь перестаёт видеть движение", "How high above the pad the mouse stops seeing movement")
            enabled: Devices.canWrite && !Devices.working
            model: (page.capOf("lod").values || []).map(v => ({
                        "label": v + I18n.t(" мм", " mm"),
                        "value": v
                    }))
            currentValue: page.mouse ? page.mouse.lod : 0
            onActivated: v => Devices.setMouse("lod", v)
        }
        CatSpin {
            present: !!page.mouse && page.cap("debounce")
            label: "Debounce"
            hint: I18n.t("Меньше — быстрее клик, больше — меньше случайных двойных кликов.", "Less: a faster click. More: fewer accidental double clicks.")
            enabled: Devices.canWrite && !Devices.working
            from: page.capOf("debounce").min || 0
            to: page.capOf("debounce").max || 15
            stepSize: 1
            suffix: I18n.t(" мс", " ms")
            value: page.mouse ? page.mouse.debounce : 0
            onMoved: v => Devices.setMouse("debounce", v)
        }
        CatCustom {
            present: !!page.mouse && (page.cap("motionSync") || page.cap("angleSnap") || page.cap("rippleControl"))
            label: I18n.t("Сенсор", "The sensor")
            hint: I18n.t("Тонкая подстройка сенсора: плавность, выпрямление линий, меньше дрожи.", "Fine sensor tuning: smoothness, straightened lines, less jitter.")
            CatBox {
                Column {
                    spacing: Theme.u * 2
                    PxToggle {
                        visible: page.cap("motionSync")
                        enabled: Devices.canWrite && !Devices.working
                        text: "Motion Sync"
                        checked: !!page.mouse && page.mouse.motionSync
                        onToggled: v => Devices.setMouse("motionSync", v)
                    }
                    PxToggle {
                        visible: page.cap("angleSnap")
                        enabled: Devices.canWrite && !Devices.working
                        text: "Angle Snap"
                        checked: !!page.mouse && page.mouse.angleSnap
                        onToggled: v => Devices.setMouse("angleSnap", v)
                    }
                    PxToggle {
                        visible: page.cap("rippleControl")
                        enabled: Devices.canWrite && !Devices.working
                        text: "Ripple Control"
                        checked: !!page.mouse && page.mouse.ripple
                        onToggled: v => Devices.setMouse("ripple", v)
                    }
                }
            }
        }
        CatChoice {
            present: !!page.mouse && page.cap("sleep")
            label: I18n.t("Сон", "Sleep")
            hint: I18n.t("через сколько без движения мышь засыпает", "After how long without movement the mouse falls asleep")
            enabled: Devices.canWrite && !Devices.working
            model: (page.capOf("sleep").values || []).map(v => ({
                        "label": page.sleepLabel(v),
                        "value": v
                    }))
            currentValue: page.mouse ? page.mouse.sleep : 0
            onActivated: v => Devices.setMouse("sleep", v)
        }
        CatNote {
            present: !!Devices.failed
            text: Devices.failed ? I18n.t("Не записано: ", "Not written: ") + I18n.t(Devices.failed.ru, Devices.failed.en) + (Devices.failed.detail ? " (" + Devices.failed.detail + ")" : "") : ""
        }
    }
    CatGroup {
        name: "mouseBackup"
        title: I18n.t("Вернуть как было", "Put it back")
        icon: "refresh"
        advanced: true
        present: page.isMouse && !!page.mouse
        CatButton {
            label: I18n.t("Резервная копия", "The backup")
            hint: page.mouse && page.mouse.backup ? I18n.t("настройки мыши, как они были до первой записи из оболочки: ", "The mouse's settings as they were before the shell's first write: ") + page.mouse.backup : I18n.t("снимается сама перед первой записью в мышь", "Taken by itself before the first write to the mouse")
            compact: true
            danger: page.sureRestore
            icon: "refresh"
            enabled: Devices.canWrite && !Devices.working && !!page.mouse && page.mouse.backup !== ""
            text: page.sureRestore ? I18n.t("Точно вернуть всё?", "Really put it all back?") : I18n.t("Вернуть как было", "Put it back")
            onClicked: {
                if (!page.sureRestore) {
                    page.sureRestore = true;
                    unsure.restart();
                    return;
                }
                page.sureRestore = false;
                Devices.restore();
            }
        }
    }
    CatGroup {
        name: "support"
        title: I18n.t("Что поддерживается", "What is supported")
        icon: "info"
        advanced: true
        CatNote {
            dim: true
            text: I18n.t("Устройство описано файлом. «Проверено на железе» — автор держал его в руках; «по описанию» — нет.", "Each device is a description file. «Tested on hardware»: the author had it in hand; «by spec»: not.")
        }
        CatRepeat {
            model: Devices.known
            delegate: Component {
                CatCustom {
                    required property var modelData
                    label: modelData.name
                    hint: [modelData.maker || "", modelData.family, Devices.supportLabel(modelData.support), modelData.origin === "user" ? I18n.t("ваш файл", "your file") : ""].filter(x => x !== "").join(" · ")
                    CatBox {
                    }
                }
            }
        }
        CatButton {
            label: I18n.t("Своё устройство", "A device of your own")
            hint: I18n.t("Файл устройства кладётся в ~/.config/angelos/devices и появляется здесь сам.", "A device file goes into ~/.config/angelos/devices and shows up here by itself.")
            compact: true
            icon: "folder"
            text: I18n.t("Папка", "The folder")
            onClicked: Quickshell.execDetached(["sh", "-c", 'd="${XDG_CONFIG_HOME:-$HOME/.config}/angelos/devices"; mkdir -p "$d" && exec gio open "$d"'])
            CatButton {
                compact: true
                icon: "document"
                text: I18n.t("Как описать", "How to describe one")
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.shellDir + "/docs/devices.md"])
            }
        }
    }
}
