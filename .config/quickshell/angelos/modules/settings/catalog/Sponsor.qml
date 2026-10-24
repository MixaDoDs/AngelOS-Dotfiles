// The settings once in SponsorPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// «Спонсор» (services/Telemetry, scripts/telemetry.py, data/sponsor.json): the donate button
// (DonationAlerts), the sponsor wall — names only, checked weekly by the author's relay — and
// the telemetry answer with exactly what goes.
CatPage {
    heading: I18n.t("Спонсор", "Sponsor")
    subtitle: I18n.t("angelOS делает один человек. Донат помогает ему не бросать — и попасть на стену спонсоров.", "angelOS is made by one person. A donation keeps it going, and puts you on the sponsor wall.")
    Component.onCompleted: {
        Telemetry.loadSponsors();
        Telemetry.loadPreview();
        Telemetry.refreshStatus();
    }
    CatGroup {
        name: "donate"
        title: I18n.t("Поддержать", "Support")
        icon: "heart"
        CatCustom {
            wide: true
            CatBox {
                Row {
                    width: parent.width
                    spacing: Theme.u * 6
                    PxIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "heart"
                        pixel: Theme.u * 3
                        fill: Theme.ngoPink
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.u * 40
                        spacing: Theme.u * 3
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "title"
                            text: I18n.t("Задонатить через DonationAlerts", "Donate via DonationAlerts")
                        }
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            dim: true
                            text: I18n.t("Любая сумма. Имя из доната раз в неделю попадает на стену ниже — подпишись, как хочешь, чтобы тебя видели.", "Any amount. Once a week the name from the donation goes on the wall below: sign it the way you want to be seen.")
                        }
                        PxButton {
                            text: I18n.t("Задонатить ♡", "Donate ♡")
                            icon: "heart"
                            accent: true
                            onClicked: Telemetry.donate()
                        }
                        PxText {
                            kind: "tiny"
                            dim: true
                            text: Telemetry.donateUrl.replace(/^https?:\/\/(www\.)?/, "")
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "wall"
        title: I18n.t("Стена спонсоров", "Sponsor wall")
        icon: "star"
        CatNote {
            present: !Telemetry.sponsors.length
            dim: true
            text: Telemetry.sponsorsOffline && !Telemetry.hasEndpoint ? I18n.t("Стена скоро появится. Стань первым ♡", "The wall is coming soon. Be the first ♡") : Telemetry.sponsorsOffline ? I18n.t("Не достучался до стены — нет сети?", "Couldn't reach the wall: no network?") : I18n.t("Пока пусто. Стань первым ♡", "Empty so far. Be the first ♡")
        }
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    visible: Telemetry.sponsors.length > 0
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: Telemetry.sponsors
                        Item {
                            id: chip
                            required property string modelData
                            required property int index
                            width: label.implicitWidth + Theme.u * 8
                            height: label.implicitHeight + Theme.u * 3
                            PxPill {
                                anchors.fill: parent
                                color: chip.index < 3 ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.ngoPink, 0.35) : Theme.tone("face", Theme.p5For(parent))
                                edge: chip.index < 3 ? Theme.ngoPink : Theme.tone("edge", Theme.p5For(parent))
                            }
                            PxText {
                                id: label
                                anchors.centerIn: parent
                                text: (chip.index < 3 ? "♡ " : "") + chip.modelData
                            }
                        }
                    }
                }
            }
        }
        CatNote {
            present: Telemetry.sponsorsUpdated !== ""
            textKind: "tiny"
            dim: true
            text: I18n.t("обновлено ", "updated ") + Telemetry.sponsorsUpdated.slice(0, 10) + I18n.t(" · проверяется раз в неделю", " · checked once a week")
        }
    }
    CatGroup {
        id: tele
        name: "telemetry"
        title: I18n.t("Телеметрия", "Telemetry")
        icon: "chip"
        readonly property var r: Telemetry.preview
        function line(ru, en, v) {
            return v === undefined || v === null || v === "" ? null : {
                "label": I18n.t(ru, en),
                "value": String(v)
            };
        }
        readonly property var rows: !r ? [] : [line("angelOS", "angelOS", r.angelos ? I18n.t("релиз ", "release ") + r.angelos.release + (r.angelos.codename ? " «" + r.angelos.codename + "»" : "") + (r.angelos.commit ? ", " + r.angelos.commit : "") : ""), line("Quickshell · Qt · niri", "Quickshell · Qt · niri", [r.quickshell, r.qt, r.niri].join(" · ")), line("Система", "System", r.os ? r.os.distro + ", " + r.os.kernel : ""), line("Процессор", "CPU", r.cpu ? r.cpu.model + I18n.t(", потоков: ", ", threads: ") + r.cpu.threads : ""), line("Память", "Memory", r.ram_gb + I18n.t(" ГБ", " GB")), line("Видеокарта", "Graphics", (r.gpus || []).join("; ")), line("Экраны", "Screens", (r.screens || []).map(s => s.mode + (s.scale && s.scale !== 1 ? " ×" + s.scale : "")).join(", ")), line("Ноутбук", "Laptop", r.laptop ? I18n.t("да", "yes") : I18n.t("нет", "no")), line("Выбор в настройках", "Settings picked", r.choices ? Object.keys(r.choices).filter(k => r.choices[k] !== null && r.choices[k] !== "").map(k => k + ": " + r.choices[k]).join(", ") : ""), line("Номер компьютера", "Computer number", I18n.t("случайный, не связан с тобой", "random, not tied to you"))].filter(x => !!x)
        CatToggle {
            label: I18n.t("Отправлять телеметрию автору", "Send telemetry to the author")
            hint: I18n.t("раз в неделю: версии и железо — так видно, на чём angelOS живёт и что чинить первым. Выключишь — отправленное удалится", "once a week: versions and hardware, so the author sees what angelOS runs on and what to fix first. Switch it off and what was sent gets deleted")
            checked: Telemetry.on
            onToggled: v => Telemetry.setConsent(v ? "yes" : "no")
        }
        CatNote {
            textKind: "tiny"
            dim: true
            text: I18n.t("Что уходит:", "What goes:")
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: tele.rows
                    Row {
                        required property var modelData
                        width: parent.width
                        spacing: Theme.u * 3
                        PxText {
                            width: Theme.u * 70
                            wrapMode: Text.Wrap
                            dim: true
                            text: parent.modelData.label
                        }
                        PxText {
                            width: parent.width - Theme.u * 73
                            wrapMode: Text.Wrap
                            text: parent.modelData.value
                        }
                    }
                }
            }
        }
        CatNote {
            textKind: "tiny"
            dim: true
            text: I18n.t("Не уходит никогда: имя пользователя и компьютера, пути, файлы, история, IP-адрес. Без «да» ничего не собирается.", "Never sent: the user or computer name, paths, files, history, the IP address. Without a «yes» nothing is collected.")
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    visible: Telemetry.on
                    spacing: Theme.u * 3
                    PxButton {
                        compact: true
                        icon: "refresh"
                        text: I18n.t("Отправить сейчас", "Send now")
                        enabled: Telemetry.hasEndpoint
                        onClicked: Telemetry.sendNow()
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        dim: true
                        text: !Telemetry.hasEndpoint ? I18n.t("приёмник ещё не включён — пока ничего не уходит", "the receiver isn't on yet: nothing goes for now") : Telemetry.status.last ? I18n.t("последняя: ", "last: ") + new Date(Telemetry.status.last * 1000).toLocaleDateString(Qt.locale(I18n.t("ru_RU", "en_US"))) + (Telemetry.status.result && Telemetry.status.result !== "ok" ? " · " + Telemetry.status.result : "") : I18n.t("ещё не отправлялась", "not sent yet")
                    }
                }
            }
        }
    }
}
