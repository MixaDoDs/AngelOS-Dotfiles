// The settings once in ProgramsPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Programs (services/Programs, scripts/programs.py): what is installed, with «Удалить» on each —
// first what would really go (pacman takes along what only it needed) or why it can't, then the
// removal with one admin password, its last lines shown — and the clean-up: packages nothing
// needs any more, pacman's download cache, Flatpak's unused runtimes. On top «Лишнее» (like
// Omarchy's «Remove preinstalls»): what angelOS's installer put here and angelOS never calls,
// ticked by groups, gone in one go with one password and a bar; updates don't bring it back.
CatPage {
    id: page
    heading: I18n.t("Программы", "Programs")
    subtitle: I18n.t("Что установлено и сколько занимает. Лишнее удаляется отсюда — без терминала.", "What is installed and how much it takes. What you don't need is removed from here, no terminal.")
    Component.onCompleted: {
        Programs.refresh();
        Programs.refreshCleanup();
        Programs.refreshBloat();
    }
    property string filter: "all"       // all | author | flatpak | local
    property bool bySize: false
    readonly property var rows: {
        const q = search.text.trim().toLowerCase();
        let list = Programs.apps.filter(r => {
            if (filter === "author" && !r.catalog)
                return false;
            if (filter === "flatpak" && r.source !== "flatpak")
                return false;
            if (filter === "local" && r.source !== "local")
                return false;
            return !q || r.names.some(n => n.toLowerCase().includes(q)) || String(r.pkg).toLowerCase().includes(q);
        });
        if (bySize)
            list = list.slice().sort((a, b) => b.size - a.size);
        return list;
    }
    function source(r) {
        return r.source === "pacman" ? r.pkg : r.source === "flatpak" ? "Flatpak" : I18n.t("твой ярлык", "a launcher of yours");
    }
    CatGroup {
        id: extras
        name: "bloat"
        title: I18n.t("Лишнее", "Extras")
        icon: "sparkle"
        readonly property var st: Programs.bloat
        readonly property bool mine: Programs.kind === "bloat"
        readonly property int picked: Programs.bloatPicked.length
        CatNote {
            dim: true
            text: I18n.t("Что angelOS поставил, но сам не использует. Отметь ненужное и удали одной кнопкой; твои файлы останутся.", "What angelOS installed but doesn't use. Tick what you don't need and remove it; your files stay.")
        }
        CatNote {
            present: !extras.st
            dim: true
            text: I18n.t("смотрю, что стоит…", "checking what is installed…")
        }
        CatNote {
            present: !!extras.st && extras.st.groups.length === 0
            text: I18n.t("Лишнего нет ♡", "Nothing extra ♡")
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: extras.st ? extras.st.groups : []
                    Column {
                        id: grp
                        required property var modelData
                        readonly property var free: modelData.items.filter(i => !i.locked).map(i => i.item)
                        readonly property bool all: free.length > 0 && free.every(i => Programs.bloatPicked.includes(i))
                        width: parent.width
                        spacing: Theme.u * 2
                        SettingRow {
                            width: parent.width
                            label: grp.modelData.title
                            hint: grp.modelData.hint
                            PxCheck {
                                enabled: grp.free.length > 0 && !Programs.busy
                                checked: grp.all
                                text: I18n.t("все", "all")
                                onToggled: c => {
                                    for (const i of grp.free)
                                        Programs.bloatTick(i, c);
                                }
                            }
                        }
                        Repeater {
                            model: grp.modelData.items
                            SettingRow {
                                id: ex
                                required property var modelData
                                x: Theme.u * 8
                                width: grp.width - x
                                label: modelData.name
                                hint: [modelData.note, Programs.fmt(modelData.size), modelData.locked ? "🔒 " + modelData.locked : ""].filter(s => s).join(" · ")
                                PxCheck {
                                    enabled: !ex.modelData.locked && !Programs.busy
                                    checked: Programs.bloatPicked.includes(ex.modelData.item)
                                    onToggled: c => Programs.bloatTick(ex.modelData.item, c)
                                }
                            }
                        }
                    }
                }
            }
        }
        // ---- the run: a bar, what it does, what was left and why ----
        CatCustom {
            wide: true
            CatBox {
                // ---- the run: a bar, what it does, what was left and why ----
                Column {
                    visible: extras.mine && (Programs.running || Programs.done)
                    width: parent.width
                    spacing: Theme.u * 3
                    PxProgress {
                        width: parent.width
                        busy: Programs.running
                        value: Programs.progress
                        text: Programs.running && /пароль|password/.test(Programs.status) ? I18n.t("жду пароль…", "waiting for the password…") : ""
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Programs.done && (Programs.failed.length || Programs.auth) ? Theme.danger : Theme.accent
                        text: Programs.status
                    }
                    PxText {
                        visible: Programs.skipped.length > 0
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: I18n.t("Оставлено: ", "Left: ") + Programs.skipped.map(s => String(s.id).replace(/^[^:]*:/, "") + " (" + s.why + ")").join(", ")
                    }
                    PxBox {
                        visible: Programs.log.length > 0
                        width: parent.width
                        height: bloatLog.implicitHeight + Theme.u * 6
                        sunken: true
                        color: Theme.mix(Theme.tone("face", Theme.p5For(parent)), "#000000", 0.25)
                        PxText {
                            id: bloatLog
                            x: Theme.u * 3
                            y: Theme.u * 3
                            width: parent.width - Theme.u * 6
                            kind: "tiny"
                            dim: true
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            font.family: Theme.fontMono
                            text: Programs.log.slice(-4).join("\n") || " "
                        }
                    }
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    visible: !!extras.st && extras.st.groups.length > 0
                    spacing: Theme.u * 3
                    PxButton {
                        danger: true
                        icon: "trash"
                        enabled: extras.picked > 0 && !Programs.busy
                        text: extras.picked ? I18n.t("Удалить отмеченное", "Remove the ticked") + " (" + extras.picked + (Programs.bloatSize() ? " · " + Programs.fmt(Programs.bloatSize()) : "") + ")" : I18n.t("Ничего не отмечено", "Nothing ticked")
                        onClicked: Programs.removeBloat()
                    }
                    PxButton {
                        visible: extras.mine && Programs.done
                        text: I18n.t("Понятно", "Got it")
                        onClicked: Programs.reset()
                    }
                }
            }
        }
    }
    CatGroup {
        name: "installed"
        title: I18n.t("Установлено", "Installed")
        icon: "package"
        // ---- the job: what was asked, what would go, how it went ----
        CatCustom {
            wide: true
            CatBox {
                // ---- the job: what was asked, what would go, how it went ----
                PxBox {
                    id: job
                    visible: Programs.kind === "remove" && (Programs.asked.length > 0)
                    width: parent.width
                    height: jobCol.implicitHeight + Theme.u * 8
                    color: Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.14)
                    readonly property var p: Programs.plan
                    Column {
                        id: jobCol
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u * 3
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "title"
                            text: Programs.done ? Programs.status : Programs.running ? I18n.t("Удаляю: ", "Removing: ") + Programs.asked.map(r => Programs.label(r)).join(", ") : I18n.t("Удалить «", "Remove “") + Programs.asked.map(r => Programs.label(r)).join(", ") + I18n.t("»?", "”?")
                        }
                        PxText {
                            visible: Programs.planning
                            dim: true
                            text: I18n.t("смотрю, что удалится вместе с ней…", "working out what goes with it…")
                        }
                        PxText {
                            visible: !!job.p && !Programs.running && !Programs.done
                            width: parent.width
                            wrapMode: Text.Wrap
                            color: job.p && job.p.refused ? Theme.danger : Theme.tone("text", Theme.p5For(parent))
                            text: !job.p ? "" : job.p.refused ? "✕ " + job.p.refused : I18n.t("Уйдёт: ", "Goes: ") + job.p.remove.map(x => x.name + (x.size ? " (" + Programs.fmt(x.size) + ")" : "")).join(", ") + (job.p.size ? I18n.t(" — освободится ", " — frees ") + Programs.fmt(job.p.size) : "") + I18n.t(". Свои файлы и настройки программы в домашней папке остаются.", ". Your files and the app's settings in your home folder stay.")
                        }
                        PxText {
                            visible: Programs.running
                            width: parent.width
                            elide: Text.ElideRight
                            dim: true
                            text: Programs.status
                        }
                        PxBox {
                            visible: (Programs.running || Programs.done) && Programs.log.length > 0
                            width: parent.width
                            height: jobLog.implicitHeight + Theme.u * 6
                            sunken: true
                            color: Theme.mix(Theme.tone("face", Theme.p5For(parent)), "#000000", 0.25)
                            PxText {
                                id: jobLog
                                x: Theme.u * 3
                                y: Theme.u * 3
                                width: parent.width - Theme.u * 6
                                kind: "tiny"
                                dim: true
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                font.family: Theme.fontMono
                                text: Programs.log.slice(-5).join("\n") || " "
                            }
                        }
                        Row {
                            spacing: Theme.u * 3
                            PxButton {
                                visible: !!job.p && !job.p.refused && !Programs.running && !Programs.done
                                danger: true
                                icon: "trash"
                                text: I18n.t("Удалить", "Remove")
                                onClicked: Programs.confirm()
                            }
                            PxButton {
                                visible: !Programs.running
                                text: Programs.done || (job.p && job.p.refused) ? I18n.t("Понятно", "Got it") : I18n.t("Отмена", "Cancel")
                                onClicked: Programs.cancel()
                            }
                        }
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Показать", "Show")
            hint: I18n.t("«от автора» — то, что поставилось вместе с angelOS", "“the author's” is what came along with angelOS")
            model: [
                {
                    "label": I18n.t("Всё", "All"),
                    "value": "all"
                },
                {
                    "label": I18n.t("От автора", "The author's"),
                    "value": "author"
                },
                {
                    "label": "Flatpak",
                    "value": "flatpak"
                },
                {
                    "label": I18n.t("Ярлыки", "Launchers"),
                    "value": "local"
                }
            ]
            currentValue: page.filter
            onActivated: v => page.filter = v
            CatButton {
                checkable: true
                checked: page.bySize
                text: I18n.t("Крупные сверху", "Biggest first")
                onClicked: page.bySize = !page.bySize
            }
        }
        CatField {
            label: I18n.t("Найти", "Find")
            hint: Programs.loaded ? I18n.t("программ: ", "programs: ") + page.rows.length : I18n.t("читаю список…", "reading the list…")
            id: search
            icon: "search"
            placeholder: I18n.t("название", "a name")
        }
        CatRepeat {
            model: page.rows
            delegate: Component {
                CatCustom {
                    id: app
                    required property var modelData
                    readonly property string stays: Programs.why(modelData)
                    label: Programs.label(modelData)
                    hint: [page.source(modelData), Programs.fmt(modelData.size), modelData.catalog ? I18n.t("от автора", "the author's") : "", app.stays].filter(x => x).join(" · ")
                    CatBox {
                        PxButton {
                            icon: "trash"
                            enabled: app.stays === "" && !Programs.busy
                            text: modelData.source === "local" ? I18n.t("Убрать ярлык", "Remove the launcher") : I18n.t("Удалить", "Remove")
                            onClicked: Programs.ask(app.modelData)
                        }
                    }
                }
            }
        }
    }
}
