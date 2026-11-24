import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.spacing
    PxGroup {
        title: "Бумажки Typer"
        icon: "note"
        width: parent.width
        PxText {
            width: parent.width
            text: "Иконка на панели открывает маленькую заметку. Прикрепи её на рабочий стол, перетаскивай за любую часть. Три быстрых левых клика убирают бумажку."
            wrapMode: Text.Wrap
        }
        SettingRow {
            label: "Быстрая заметка"
            PxButton { text: "Написать"; onClicked: PopupManager.showPanel("typer-note", Niri.focusedOutput) }
        }
        SettingRow {
            label: "Последняя убранная бумажка"
            PxButton { text: "Вернуть"; enabled: TyperNotes.archive.length > 0 && TyperNotes.fading.length === 0; onClicked: TyperNotes.restore() }
        }
        SettingRow {
            label: "Полный текстовый редактор"
            PxButton { text: "Открыть Typer"; onClicked: Quickshell.execDetached(["angelos-typer"]) }
        }
    }
}
