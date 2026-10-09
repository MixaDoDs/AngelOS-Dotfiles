pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Updates for everyone: check the dotfiles repository and apply new versions.
PxPage {
    id: page

    heading: I18n.t("Обновления", "Updates")
    subtitle: I18n.t("angelOS обновляется из репозитория dotfiles, из которого его установили: git pull и установщик без пакетов. Сначала снимок всех файлов, которые он может заменить, — если что-то пойдёт не так, отсюда же можно вернуть как было. Конфиги, которые ты менял, установщик не трогает.", "angelOS updates from the dotfiles repository it was installed from: git pull and the installer without packages. First a snapshot of every file it may replace — if something goes wrong, you can go back from here. Configs you changed are left alone.")

    Component.onCompleted: {
        Updates.find();
        if (Updates.repo && Updates.state === "idle")
            Updates.check();
    }

    PxGroup {
        name: "status"
        title: I18n.t("Состояние", "Status")
        icon: "download"
        width: parent.width

        // no repository yet: offer the official one
        Column {
            visible: !Updates.repo
            width: parent.width
            spacing: Theme.u * 4
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: I18n.t("Репозиторий dotfiles не найден. Скачать официальный в ~/.local/share/angelos/dotfiles, чтобы получать обновления?", "No dotfiles repository found. Download the official one to ~/.local/share/angelos/dotfiles to receive updates?")
            }
            PxButton {
                icon: "download"
                accent: true
                enabled: !Updates.busy
                text: Updates.state === "cloning" ? I18n.t("скачиваю…", "downloading…") : I18n.t("Скачать dotfiles", "Download dotfiles")
                onClicked: Updates.clone()
            }
        }

        SettingRow {
            visible: Updates.release !== null
            label: I18n.t("Релиз", "Release")
            hint: Updates.release ? Updates.release.date : ""
            PxText {
                width: parent.width
                text: Updates.release ? Wallpapers.releaseLabel(Updates.release) : ""
                color: Theme.accent
            }
        }
        SettingRow {
            visible: !!Updates.repo
            label: I18n.t("Репозиторий", "Repository")
            hint: Updates.remote
            PxText {
                width: parent.width
                elide: Text.ElideMiddle
                text: Updates.repo + (Updates.branch ? "  ·  " + Updates.branch : "")
            }
        }
        SettingRow {
            visible: !!Updates.repo
            label: I18n.t("Новое", "New")
            hint: Config.updates.lastCheck ? I18n.t("проверено ", "checked ") + new Date(Config.updates.lastCheck).toLocaleString(Qt.locale(), "dd.MM HH:mm") : ""
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                color: Updates.error || Updates.failedUpdate ? Theme.danger : Updates.available ? Theme.accent : Theme.textDim
                // a failed attempt that wasn't undone moved the repository, not the system:
                // "up to date" would be a lie then
                text: Updates.state === "checking" ? I18n.t("проверяю…", "checking…") : Updates.error ? "✕ " + Updates.error : Updates.available ? I18n.t("доступно изменений: ", "changes available: ") + Updates.behind : Updates.failedUpdate ? I18n.t("последнее обновление не установилось — см. ниже", "the last update did not install — see below") : I18n.t("у тебя последняя версия ♡", "you are up to date ♡")
            }
        }
        // stopped before the snapshot: nothing was changed, but say where, why and what next
        Column {
            visible: Updates.lastRun === "failed" && !Updates.canRestore && !!Updates.failure
            width: parent.width
            spacing: Theme.u * 2
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.danger
                text: "✕ " + Updates.failureText(Updates.failedStage, Updates.failure)
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: Updates.nextStep(Updates.failedStage)
            }
        }
        PxText {
            visible: !Updates.trusted && !!Updates.repo
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: I18n.t("origin репозитория указывает не на официальный репозиторий и не на тот, из которого ставилась система — обновление отключено.", "The repository origin is neither the official one nor the one this system was installed from — updating is disabled.")
        }
        PxText {
            visible: Updates.dirty > 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.accent3
            text: I18n.t("В папке репозитория свои правки (файлов: " + Updates.dirty + ") — обновление их бы потеряло, поэтому выключено. Закоммить или отложи их (git stash -u) либо откати, потом нажми «Проверить».", "The repository folder has edits of its own (" + Updates.dirty + " files) — an update would lose them, so it is off. Commit or put them aside (git stash -u), or drop them, then press Check.")
        }
        // a developer's working clone: commits GitHub doesn't have
        PxText {
            visible: Updates.ahead > 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.accent3
            text: Updates.behind > 0 ? I18n.t("Ветка разошлась с " + (Updates.upstream || "origin") + ": своих коммитов " + Updates.ahead + ", новых " + Updates.behind + " — перемотать нельзя, обновление выключено. Перенеси свои коммиты поверх новых (git pull --rebase) и нажми «Проверить».", "The branch went its own way from " + (Updates.upstream || "origin") + ": " + Updates.ahead + " commits of its own, " + Updates.behind + " new — it can't be fast-forwarded, so updating is off. Put your commits on top of the new ones (git pull --rebase) and press Check.") : I18n.t("В репозитории своих коммитов: " + Updates.ahead + ", которых нет в " + (Updates.upstream || "origin") + ", а нового там нет — обновлять нечего. Свою версию ставь её установщиком (./install.sh).", "The repository has " + Updates.ahead + " commits of its own that " + (Updates.upstream || "origin") + " doesn't have, and nothing new came — there is nothing to update. Install your version with its installer (./install.sh).")
        }
        Flow {
            visible: !!Updates.repo
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: "refresh"
                text: I18n.t("Проверить", "Check")
                enabled: !Updates.busy
                onClicked: Updates.check()
            }
            PxButton {
                icon: "download"
                accent: Updates.available
                enabled: !Updates.busy && !Updates.blocked
                text: Updates.state === "updating" ? I18n.t("обновляю…", "updating…") : I18n.t("Обновить", "Update")
                onClicked: Updates.update()
            }
            PxButton {
                visible: Updates.needsRestart
                accent: true
                icon: "power"
                text: I18n.t("Перезапустить оболочку", "Restart the shell")
                onClicked: Updates.restartShell()
            }
        }
        PxText {
            visible: !!Updates.repo && !Updates.blocked && !Updates.needsRestart
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.textDim
            text: Updates.systemPackages >= 0 && !Updates.busy ? I18n.t("Система обновлена вместе с angelOS (пакетов: ", "The system was updated along with angelOS (packages: ") + Updates.systemPackages + ")." : I18n.t("«Обновить» сначала обновляет систему (pacman -Syu, спросит пароль администратора), потом angelOS — чтобы новой оболочке хватило свежих Quickshell и Qt.", "Update upgrades the system first (pacman -Syu, asks for the admin password), then angelOS — so the new shell gets a fresh enough Quickshell and Qt.")
        }
        PxText {
            visible: Updates.needsRestart
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.accent
            text: Updates.restored ? I18n.t("Прежняя версия возвращена на диск, но в памяти ещё та, что была запущена, — перезапусти оболочку.", "The previous version is back on disk, but the one in memory is still running — restart the shell.") : I18n.t("Новая версия установлена, но работает ещё прошлая — она загрузится после перезапуска оболочки или следующего входа.", "The new version is installed, but the previous one is still running: it loads after a shell restart or the next login.")
        }
        SettingRow {
            label: I18n.t("Проверять раз в день", "Check once a day")
            hint: I18n.t("только уведомление, ставится по кнопке", "only a notification; installing is up to you")
            PxToggle {
                checked: Config.updates.autoCheck
                onToggled: c => Config.updates.autoCheck = c
            }
        }
    }

    // the last attempt went wrong: what, where its snapshot is, the way back
    PxGroup {
        name: "restored"
        id: failedGroup
        visible: Updates.canRestore || Updates.lastStatus === "restored" && Updates.conflicts.length > 0
        title: Updates.lastStatus === "restored" ? I18n.t("Возвращено как было", "Restored") : Updates.lastStatus === "restore-failed" ? I18n.t("Вернуть не получилось", "The restore failed") : I18n.t("Обновление не установлено", "The update is not installed")
        icon: Updates.lastStatus === "restored" ? "heart" : "warn"
        width: parent.width

        PxText {
            visible: Updates.lastStatus !== "restored"
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: "✕ " + (Updates.lastStatus === "restore-failed" ? Updates.failure : Updates.failureText(Updates.failedStage, Updates.failure))
        }
        PxText {
            visible: Updates.lastStatus !== "restored" && Updates.lastStatus !== "restore-failed"
            width: parent.width
            wrapMode: Text.Wrap
            text: Updates.nextStep(Updates.failedStage)
        }
        PxText {
            visible: Updates.lastStatus !== "restored"
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.textDim
            text: Updates.lastStatus === "restore-failed" ? I18n.t("Снимок цел, ничего из него не потеряно. Подробности — в журнале ниже; можно поправить и попробовать ещё раз.", "The snapshot is intact, nothing from it is lost. Details are in the log below; fix it and try again.") : I18n.t("Часть файлов могла уже смениться. Перед обновлением всё, что оно трогает, сохранено — можно вернуть систему к состоянию до этой попытки. Файлы, которые ты успел изменить после неё, останутся как есть.", "Some files may already have changed. Everything the update touches was saved first — you can put the system back to how it was before this attempt. Files you changed after it stay as they are.")
        }
        SettingRow {
            label: I18n.t("Снимок", "Snapshot")
            hint: I18n.t("резервная копия до обновления", "the copy taken before the update")
            PxText {
                width: parent.width
                wrapMode: Text.WrapAnywhere
                kind: "mono"
                text: Updates.backupDir
            }
        }
        PxButton {
            visible: Updates.canRestore
            icon: "refresh"
            accent: true
            enabled: !Updates.busy
            text: Updates.state === "restoring" ? I18n.t("возвращаю…", "restoring…") : I18n.t("Вернуть как было до обновления", "Restore the state before the update")
            onClicked: Updates.restore()
        }
        PxText {
            visible: Updates.conflicts.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.accent3
            text: I18n.t("Эти файлы изменились уже после обновления — оставлены как есть (версия до обновления лежит в снимке):", "These files changed after the update — kept as they are (the version from before is in the snapshot):")
        }
        Repeater {
            model: Updates.conflicts
            PxText {
                required property string modelData
                width: parent.width
                elide: Text.ElideMiddle
                kind: "mono"
                text: "• " + modelData.replace(Config.home + "/", "~/")
            }
        }
    }

    PxGroup {
        name: "what-s-new"
        visible: Updates.incoming.length > 0
        title: I18n.t("Что нового", "What's new")
        icon: "sparkle"
        width: parent.width
        Repeater {
            model: Updates.incoming
            PxText {
                required property string modelData
                width: parent.width
                elide: Text.ElideRight
                text: "✧ " + modelData.replace(/^\S+\s/, "")
            }
        }
    }

    PxGroup {
        name: "log"
        visible: Updates.log.length > 0
        title: I18n.t("Журнал", "Log")
        icon: "terminal"
        width: parent.width
        PxBox {
            width: parent.width
            height: Theme.u * 110
            sunken: true
            color: Theme.sunken
            PxScroll {
                id: logScroll
                anchors.fill: parent
                anchors.margins: Theme.u * 3
                contentHeight: logText.implicitHeight
                PxText {
                    id: logText
                    width: logScroll.width - Theme.u * 6
                    kind: "mono"
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    text: Updates.log.join("\n")
                    onTextChanged: Qt.callLater(() => logScroll.contentY = Math.max(0, logScroll.contentHeight - logScroll.height))
                }
            }
        }
    }
}
