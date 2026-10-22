pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Quick Share (services/QuickShare): LocalSend's protocol, so phones and computers with the
// LocalSend app see this one — who may send, where it lands, the trusted devices.
PxPage {
    heading: I18n.t("Отправить рядом", "Quick Share")
    subtitle: I18n.t("Как AirDrop: файлы и текст на телефон и обратно через LocalSend (Android, iPhone, Windows, Mac). Приложение LocalSend на этом компьютере не нужно — на телефоне нужно.", "Like AirDrop: files and text to a phone and back through LocalSend (Android, iPhone, Windows, Mac). No LocalSend app needed on this computer — on the phone it is.")

    PxGroup {
        name: "receive"
        title: I18n.t("Видимость и приём", "Visibility and receiving")
        icon: "plane"
        width: parent.width
        SettingRow {
            label: I18n.t("Отправка рядом", "Quick Share")
            hint: !QuickShare.wanted ? I18n.t("выключено", "off") : !QuickShare.ready ? I18n.t("запускается…", "starting…") : QuickShare.receiving ? I18n.t("работает · ", "on · ") + QuickShare.myIp : Config.quickshare.receive === "off" ? I18n.t("только отправка", "sending only") : I18n.t("только отправка: порт 53317 занят (открыто приложение LocalSend?)", "sending only: port 53317 is taken (is the LocalSend app open?)")
            PxToggle {
                checked: Config.quickshare.enabled
                onToggled: v => Config.quickshare.enabled = v
            }
        }
        SettingRow {
            label: "KDE Connect"
            hint: !Config.quickshare.kdeconnect ? I18n.t("выключено", "off") : QuickShare.kdcState === "ok" ? I18n.t("телефон с приложением KDE Connect получает файлы, даже когда заблокирован (LocalSend спит)", "a phone with the KDE Connect app gets files even when locked (LocalSend sleeps)") : QuickShare.kdcState === "missing" ? I18n.t("не установлен: sudo pacman -S kdeconnect и sudo ufw allow \"KDE Connect\"; на телефон — приложение KDE Connect", "not installed: sudo pacman -S kdeconnect and sudo ufw allow \"KDE Connect\"; on the phone, the KDE Connect app") : I18n.t("проверяю…", "checking…")
            PxToggle {
                checked: Config.quickshare.kdeconnect
                onToggled: v => Config.quickshare.kdeconnect = v
            }
        }
        SettingRow {
            label: I18n.t("Кто может присылать", "Who can send")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("все, с вопросом", "anyone, asked"),
                        "value": "ask"
                    },
                    {
                        "label": I18n.t("только доверенные", "trusted only"),
                        "value": "trusted"
                    },
                    {
                        "label": I18n.t("никто", "nobody"),
                        "value": "off"
                    }
                ]
                currentValue: Config.quickshare.receive
                onActivated: v => Config.quickshare.receive = v
            }
        }
        SettingRow {
            label: I18n.t("Имя этого компьютера", "This computer's name")
            hint: I18n.t("так его видно на телефоне", "how the phone shows it")
            PxField {
                width: Math.min(Theme.u * 90, parent.width)
                text: Config.quickshare.alias
                placeholder: QuickShare.alias
                onEdited: Config.quickshare.alias = text
            }
        }
        SettingRow {
            label: I18n.t("Куда сохранять", "Where files go")
            PxField {
                width: Math.min(Theme.u * 90, parent.width)
                text: Config.quickshare.dir
                placeholder: "~/Downloads/LocalSend"
                onEdited: Config.quickshare.dir = text
            }
        }
        SettingRow {
            label: "PIN"
            hint: I18n.t("отправителю придётся его ввести; пусто — без PIN", "the sender types it; empty = none")
            PxField {
                width: Math.min(Theme.u * 40, parent.width)
                text: Config.quickshare.pin
                onEdited: Config.quickshare.pin = text
            }
        }
        SettingRow {
            label: I18n.t("Отправить файлы", "Send files")
            hint: I18n.t("ещё: ПКМ по файлу в Nautilus → «Отправить рядом», `angelos share файл…`, кнопка в «Обвести и найти»", "also: Nautilus → right click → “Send nearby”, `angelos share file…`, the Circle to Search button")
            PxButton {
                text: I18n.t("Открыть", "Open")
                icon: "plane"
                onClicked: QuickShare.share([], "")
            }
        }
    }
    PxGroup {
        name: "trusted"
        title: I18n.t("Доверенные устройства", "Trusted devices")
        icon: "heart"
        width: parent.width
        PxText {
            visible: !(Config.quickshare.trusted || []).length
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Пока никого. Нажмите «Принимать всегда» в вопросе о файлах или ПКМ по устройству в окне отправки.", "Nobody yet. Press “Always accept” on a file question, or right-click a device in the share sheet.")
        }
        Repeater {
            model: Config.quickshare.trusted || []
            SettingRow {
                id: trow
                required property var modelData
                label: modelData.alias
                hint: modelData.fp.slice(0, 16) + "…"
                PxButton {
                    text: I18n.t("Забыть", "Forget")
                    danger: true
                    onClicked: QuickShare.trust(trow.modelData, false)
                }
            }
        }
    }
}
