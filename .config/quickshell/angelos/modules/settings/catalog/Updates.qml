// The settings once in UpdatesPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Updates for everyone: check the dotfiles repository and apply new versions.
CatPage {
    id: page
    heading: I18n.t("Обновления", "Updates")
    subtitle: I18n.t("angelOS обновляется из своего репозитория. Перед обновлением всё сохраняется — если что-то пойдёт не так, вернёшь здесь же. Твои правки конфигов не трогаются.", "angelOS updates from its own repository. Everything is saved first: if something goes wrong, roll back right here. Your own config edits stay.")
    Component.onCompleted: {
        Updates.find();
        if (Updates.repo && Updates.state === "idle")
            Updates.check();
    }
    CatGroup {
        name: "status"
        title: I18n.t("Состояние", "Status")
        icon: "download"
        // no repository yet: offer the official one
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatCustom {
            present: Updates.release !== null
            label: I18n.t("Релиз", "Release")
            hint: Updates.release ? Updates.release.date : ""
            CatBox {
                PxText {
                    width: parent.width
                    text: Updates.release ? Wallpapers.releaseLabel(Updates.release) : ""
                    color: Theme.accent
                }
            }
        }
        CatCustom {
            present: !!Updates.repo
            label: I18n.t("Репозиторий", "Repository")
            hint: Updates.remote
            CatBox {
                PxText {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: Updates.repo + (Updates.branch ? "  ·  " + Updates.branch : "")
                }
            }
        }
        CatCustom {
            present: !!Updates.repo
            label: I18n.t("Новое", "New")
            hint: Config.updates.lastCheck ? I18n.t("проверено ", "checked ") + new Date(Config.updates.lastCheck).toLocaleString(Qt.locale(), "dd.MM HH:mm") : ""
            CatBox {
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Updates.error || Updates.failedUpdate ? Theme.danger : Updates.available ? Theme.accent : Theme.tone("textDim", Theme.p5For(parent))
                    // a failed attempt that wasn't undone moved the repository, not the system:
                    // "up to date" would be a lie then
                    text: Updates.state === "checking" ? I18n.t("проверяю…", "checking…") : Updates.error ? "✕ " + Updates.error : Updates.available ? I18n.t("доступно изменений: ", "changes available: ") + Updates.behind : Updates.failedUpdate ? I18n.t("последнее обновление не установилось — см. ниже", "the last update did not install — see below") : I18n.t("у тебя последняя версия ♡", "you are up to date ♡")
                }
            }
        }
        // stopped before the snapshot: nothing was changed, but say where, why and what next
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatNote {
            present: !Updates.trusted && !!Updates.repo
            text: I18n.t("origin репозитория указывает не на официальный репозиторий и не на тот, из которого ставилась система — обновление отключено.", "The repository origin is neither the official one nor the one this system was installed from — updating is disabled.")
        }
        CatNote {
            present: Updates.dirty > 0
            text: I18n.t("В папке репозитория свои правки (файлов: " + Updates.dirty + ") — обновление их бы потеряло, поэтому выключено. Закоммить или отложи их (git stash -u) либо откати, потом нажми «Проверить».", "The repository folder has edits of its own (" + Updates.dirty + " files) — an update would lose them, so it is off. Commit or put them aside (git stash -u), or drop them, then press Check.")
        }
        // a developer's working clone: commits GitHub doesn't have
        CatNote {
            present: Updates.ahead > 0
            text: Updates.behind > 0 ? I18n.t("Ветка разошлась с " + (Updates.upstream || "origin") + ": своих коммитов " + Updates.ahead + ", новых " + Updates.behind + " — перемотать нельзя, обновление выключено. Перенеси свои коммиты поверх новых (git pull --rebase) и нажми «Проверить».", "The branch went its own way from " + (Updates.upstream || "origin") + ": " + Updates.ahead + " commits of its own, " + Updates.behind + " new — it can't be fast-forwarded, so updating is off. Put your commits on top of the new ones (git pull --rebase) and press Check.") : I18n.t("В репозитории своих коммитов: " + Updates.ahead + ", которых нет в " + (Updates.upstream || "origin") + ", а нового там нет — обновлять нечего. Свою версию ставь её установщиком (./install.sh).", "The repository has " + Updates.ahead + " commits of its own that " + (Updates.upstream || "origin") + " doesn't have, and nothing new came — there is nothing to update. Install your version with its installer (./install.sh).")
        }
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatNote {
            present: !!Updates.repo && !Updates.blocked && !Updates.needsRestart
            text: Updates.systemPackages >= 0 && !Updates.busy ? I18n.t("Система обновлена вместе с angelOS (пакетов: ", "The system was updated along with angelOS (packages: ") + Updates.systemPackages + ")." : I18n.t("«Обновить» сначала обновляет систему (pacman -Syu, спросит пароль администратора), потом angelOS — чтобы новой оболочке хватило свежих Quickshell и Qt.", "Update upgrades the system first (pacman -Syu, asks for the admin password), then angelOS — so the new shell gets a fresh enough Quickshell and Qt.")
        }
        CatNote {
            present: Updates.needsRestart
            text: Updates.restored ? I18n.t("Прежняя версия возвращена на диск, но в памяти ещё та, что была запущена, — перезапусти оболочку.", "The previous version is back on disk, but the one in memory is still running — restart the shell.") : I18n.t("Новая версия установлена, но работает ещё прошлая — она загрузится после перезапуска оболочки или следующего входа.", "The new version is installed, but the previous one is still running: it loads after a shell restart or the next login.")
        }
        CatToggle {
            label: I18n.t("Проверять раз в день", "Check once a day")
            hint: I18n.t("только уведомление, ставится по кнопке", "only a notification; installing is up to you")
            checked: Config.updates.autoCheck
            onToggled: c => Config.updates.autoCheck = c
        }
        // what the author added since this system was set up (services/AppsSync): its own window
        CatButton {
            present: AppsSync.count > 0 || AppsSync.running
            label: I18n.t("Новое от автора", "New from the author")
            hint: AppsSync.running ? I18n.t("ставится…", "installing…") : I18n.t("программы и пакеты, которых у тебя ещё нет: ", "apps and packages you don't have yet: ") + AppsSync.count
            icon: "download"
            text: I18n.t("Посмотреть", "Look")
            onClicked: AppsSync.install()
        }
    }
    // the last attempt went wrong: what, where its snapshot is, the way back
    CatGroup {
        name: "restored"
        id: failedGroup
        title: Updates.lastStatus === "restored" ? I18n.t("Возвращено как было", "Restored") : Updates.lastStatus === "restore-failed" ? I18n.t("Вернуть не получилось", "The restore failed") : I18n.t("Обновление не установлено", "The update is not installed")
        icon: Updates.lastStatus === "restored" ? "heart" : "warn"
        present: Updates.canRestore || Updates.lastStatus === "restored" && Updates.conflicts.length > 0
        CatNote {
            present: Updates.lastStatus !== "restored"
            text: "✕ " + (Updates.lastStatus === "restore-failed" ? Updates.failure : Updates.failureText(Updates.failedStage, Updates.failure))
        }
        CatNote {
            present: Updates.lastStatus !== "restored" && Updates.lastStatus !== "restore-failed"
            text: Updates.nextStep(Updates.failedStage)
        }
        CatNote {
            present: Updates.lastStatus !== "restored"
            text: Updates.lastStatus === "restore-failed" ? I18n.t("Снимок цел, ничего из него не потеряно. Подробности — в журнале ниже; можно поправить и попробовать ещё раз.", "The snapshot is intact, nothing from it is lost. Details are in the log below; fix it and try again.") : I18n.t("Часть файлов могла уже смениться. Перед обновлением всё, что оно трогает, сохранено — можно вернуть систему к состоянию до этой попытки. Файлы, которые ты успел изменить после неё, останутся как есть.", "Some files may already have changed. Everything the update touches was saved first — you can put the system back to how it was before this attempt. Files you changed after it stay as they are.")
        }
        CatCustom {
            label: I18n.t("Снимок", "Snapshot")
            hint: I18n.t("резервная копия до обновления", "the copy taken before the update")
            CatBox {
                PxText {
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    kind: "mono"
                    text: Updates.backupDir
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                PxButton {
                    visible: Updates.canRestore
                    icon: "refresh"
                    accent: true
                    enabled: !Updates.busy
                    text: Updates.state === "restoring" ? I18n.t("возвращаю…", "restoring…") : I18n.t("Вернуть как было до обновления", "Restore the state before the update")
                    onClicked: Updates.restore()
                }
            }
        }
        CatNote {
            present: Updates.conflicts.length > 0
            text: I18n.t("Эти файлы изменились уже после обновления — оставлены как есть (версия до обновления лежит в снимке):", "These files changed after the update — kept as they are (the version from before is in the snapshot):")
        }
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    CatGroup {
        name: "what-s-new"
        title: I18n.t("Что нового", "What's new")
        icon: "sparkle"
        present: Updates.incoming.length > 0
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    CatGroup {
        name: "log"
        title: I18n.t("Журнал", "Log")
        icon: "terminal"
        present: Updates.log.length > 0
        CatCustom {
            wide: true
            CatBox {
                PxBox {
                    width: parent.width
                    height: Theme.u * 110
                    sunken: true
                    color: Theme.tone("sunken", Theme.p5For(parent))
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
    }
}
