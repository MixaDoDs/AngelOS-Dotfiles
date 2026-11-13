import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

Item {
    id: root
    property var plugin
    property bool open: false
    property string original: ""
    property string translated: ""
    property string status: ""
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/ocr-small"
    readonly property string jsonPath: runtimeDir + "/ocr.json"
    readonly property string pluginDir: plugin ? plugin.dir : (Quickshell.env("HOME") + "/.config/angelos/plugins/ocr-small")
    readonly property string translateScript: pluginDir + "/scripts/translate_en_ru.py"
    readonly property string translatePython: pluginDir + "/translate-venv/bin/python"

    function close() {
        open = false;
        translated = "";
        status = "";
    }
    function show() {
        open = true;
        translated = "";
        status = "";
        ocrFile.reload();
    }
    function copyText(text) {
        if (text)
            Quickshell.execDetached(["wl-copy", "--type", "text/plain;charset=utf-8", "--", text]);
    }
    function translate() {
        if (!original || translator.running)
            return;
        status = "Перевожу…";
        translator.command = [translatePython, translateScript];
        translator.running = true;
    }

    FileView {
        id: ocrFile
        path: jsonPath
        printErrors: false
        onLoaded: {
            try {
                root.original = JSON.parse(text()).text || "";
            } catch (e) {
                root.original = "";
            }
        }
        onLoadFailed: {}
    }

    IpcHandler {
        target: "ocrSmall"
        function openCard(): void {
            root.show();
        }
        function closeCard(): void {
            root.close();
        }
    }

    Process {
        id: translator
        stdinEnabled: true
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onStarted: {
            write(root.original);
            stdinEnabled = false;
        }
        onExited: code => {
            stdinEnabled = true;
            const t = String(out.text || "").trim();
            if (code === 0 && t) {
                root.translated = t;
                root.status = "Готово";
            } else {
                root.status = "Ошибка перевода: " + (String(err.text || "").trim().split("\n").slice(-1)[0] || code);
            }
        }
    }

    LazyLoader {
        active: root.open
        PanelWindow {
            id: win
            screen: Shell.focusedScreen
            visible: true
            anchors {
                bottom: true
                right: true
            }
            margins.bottom: Theme.u * 6
            margins.right: Theme.u * 6
            implicitWidth: Theme.u * 175
            implicitHeight: Theme.u * 140
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "angelos-ocr-small"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Item {
                focus: true
                Keys.onEscapePressed: root.close()
                Component.onCompleted: forceActiveFocus()
            }

            PxWindow {
                id: card
                anchors.fill: parent
                title: "OCR"
                icon: "eye"
                onCloseClicked: root.close()

                Column {
                    anchors.fill: parent
                    spacing: Theme.u * 3
                    PxText {
                        width: parent.width
                        text: "Оригинал"
                        kind: "tiny"
                        dim: true
                    }
                    PxBox {
                        width: parent.width
                        height: 120
                        sunken: true
                        color: Theme.sunken
                        PxScroll {
                            anchors.fill: parent
                            PxText {
                                width: parent.width - Theme.u * 4
                                text: root.original
                                kind: "body"
                                wrapMode: Text.Wrap
                                verticalAlignment: Text.AlignTop
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            width: (parent.width - parent.spacing * 2) / 3
                            text: "EN → RU"
                            icon: "chat"
                            enabled: root.original !== "" && !translator.running
                            onClicked: root.translate()
                        }
                        PxButton {
                            width: (parent.width - parent.spacing * 2) / 3
                            text: "Копия оригинала"
                            icon: "copy"
                            enabled: root.original !== ""
                            onClicked: root.copyText(root.original)
                        }
                        PxButton {
                            width: (parent.width - parent.spacing * 2) / 3
                            text: "Копия перевода"
                            icon: "copy"
                            enabled: root.translated !== ""
                            onClicked: root.copyText(root.translated)
                        }
                    }
                    PxText {
                        width: parent.width
                        text: root.status || "Перевод"
                        kind: "tiny"
                        dim: true
                    }
                    PxBox {
                        width: parent.width
                        height: 100
                        sunken: true
                        color: Theme.sunken
                        PxScroll {
                            anchors.fill: parent
                            PxText {
                                width: parent.width - Theme.u * 4
                                text: root.translated
                                kind: "body"
                                wrapMode: Text.Wrap
                                verticalAlignment: Text.AlignTop
                            }
                        }
                    }
                }
            }
            RightClickGuard {}
        }
    }
}
