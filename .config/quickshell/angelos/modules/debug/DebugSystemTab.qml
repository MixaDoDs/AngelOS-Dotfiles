pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The snapshot (the save and the settings aside, and back), the shell's restart, the game
// on, off and over.
Column {
    id: root

    spacing: Theme.u * 5
    property bool armed: false

    PxGroup {
        width: parent.width
        title: I18n.t("Снимок", "Snapshot")
        icon: "camera"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: {
                const s = GameDebug.snapInfo;
                if (!s)
                    return I18n.t("Снимка нет.", "No snapshot.");
                return I18n.t("Снимок от ", "Snapshot of ") + new Date(s.at).toLocaleString(Qt.locale(), "dd.MM HH:mm:ss") + " · " + (s.realm === "hell" ? I18n.t("ад ", "hell ") + s.circle : I18n.t("рай", "heaven")) + I18n.t(" · холод ", " · chill ") + s.chill + (s.coldRoute ? I18n.t(" (холодный рут)", " (cold route)") : "") + (s.fallen ? I18n.t(" · изменилась", " · changed") : "") + I18n.t(" · падений ", " · falls ") + s.falls + I18n.t(" · возвращений ", " · returns ") + s.returns + I18n.t(" · грехов ", " · sins ") + s.sins;
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            kind: "tiny"
            text: I18n.t("Снимок — копия save.json и settings.json (~/.local/state/angelos/debug-snapshot/), один: новый заменяет старый. «Вернуть» — если в аду, ангел сначала возвращается (проделки отменены, обои на месте), потом файлы кладутся на место и оболочка перезапускается.", "The snapshot is a copy of save.json and settings.json (~/.local/state/angelos/debug-snapshot/), just one: a new one replaces it. “Restore”: in hell the angel comes back first (pranks undone, the wallpaper back), then the files go back and the shell restarts.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: "camera"
                enabled: !GameDebug.snapBusy
                text: GameDebug.snapInfo ? I18n.t("Снять заново", "Take a new one") : I18n.t("Сделать снимок", "Take a snapshot")
                onClicked: GameDebug.snapshot()
            }
            PxButton {
                icon: "arrowLeft"
                accent: true
                enabled: !!GameDebug.snapInfo && !GameDebug.snapBusy
                text: I18n.t("Вернуть снимок", "Restore it")
                onClicked: GameDebug.restore()
            }
        }
    }

    PxGroup {
        width: parent.width
        title: I18n.t("Оболочка", "The shell")
        icon: "power"
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: "power"
                text: I18n.t("Перезапустить оболочку", "Restart the shell")
                onClicked: GameDebug.restart()
            }
            PxButton {
                icon: "folder"
                text: I18n.t("Открыть save.json", "Open save.json")
                onClicked: Shell.openPath(Story.file)
            }
        }
    }

    PxGroup {
        width: parent.width
        title: I18n.t("Игра", "The game")
        icon: "heart"
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: Story.enabled ? "close" : "play"
                text: Story.enabled ? I18n.t("Выключить игру", "Turn the game off") : I18n.t("Включить игру", "Turn the game on")
                onClicked: GameDebug.note(Story.setEnabled(!Story.enabled))
            }
            SettingRow {
                width: Theme.u * 200
                label: I18n.t("Движение", "Motion")
                PxSegmented {
                    model: Motion.levels.map(v => ({
                                "label": v,
                                "value": v
                            }))
                    currentValue: Motion.chosen
                    onActivated: v => Motion.set(v)
                }
            }
            PxButton {
                icon: "refresh"
                danger: root.armed
                text: root.armed ? I18n.t("Точно сбросить игру?", "Really reset the game?") : I18n.t("Сбросить игру", "Reset the game")
                onClicked: {
                    if (!root.armed) {
                        root.armed = true;
                        disarm.restart();
                        return;
                    }
                    root.armed = false;
                    GameDebug.note(Story.reset());
                }
                Timer {
                    id: disarm
                    interval: 4000
                    onTriggered: root.armed = false
                }
            }
        }
    }
}
