// The settings once in VaultPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Passwords (services/Vault, scripts/vault.py): Bitwarden — through its own CLI or rbw — and
// 1Password in the launcher. Here: which manager is connected and whether it is open, the
// first sign-in (a terminal's business), and how careful the shell is with what it copies.
CatPage {
    id: page
    heading: I18n.t("Пароли", "Passwords")
    subtitle: I18n.t("Bitwarden и 1Password в лаунчере: Win+Space → pw и название. Enter копирует пароль.", "Bitwarden and 1Password in the launcher: Win+Space → pw and a name. Enter copies the password.")
    Component.onCompleted: Vault.refresh()
    function stateText(b) {
        if (!b.installed)
            return I18n.t("не установлен: нужна программа ", "not installed: it needs the ") + b.cli + I18n.t("", " program");
        if (b.state === "setup")
            return I18n.t("установлен, вход ещё не выполнен", "installed, not signed in yet");
        const who = b.account ? Vault.mask(b.account) + " · " : "";
        if (b.state === "unlocked")
            return who + I18n.t("открыт", "unlocked") + (Vault.listed ? I18n.t(" · записей: ", " · entries: ") + Vault.items.filter(i => i.backend === b.id).length : "");
        return who + I18n.t("закрыт", "locked");
    }
    CatGroup {
        name: "managers"
        title: I18n.t("Менеджеры паролей", "Password managers")
        icon: "lock"
        CatNote {
            present: !Vault.loaded
            dim: true
            text: I18n.t("Смотрю, что установлено…", "Looking at what is installed…")
        }
        CatNote {
            present: Vault.error !== ""
            text: "✕ " + Vault.error
        }
        CatRepeat {
            model: Vault.backends
            delegate: Component {
                CatCustom {
                    id: row
                    required property var modelData
                    label: modelData.name
                    hint: page.stateText(modelData) + (Vault.errors[modelData.id] && modelData.state === "unlocked" ? " · ✕ " + Vault.errors[modelData.id] : "")
                    CatBox {
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxButton {
                                visible: !row.modelData.installed
                                icon: "download"
                                text: I18n.t("Установить", "Install")
                                onClicked: Vault.setup(row.modelData.id, "install")
                            }
                            PxButton {
                                visible: row.modelData.state === "setup"
                                icon: "arrowRight"
                                accent: true
                                text: I18n.t("Войти…", "Sign in…")
                                onClicked: Vault.setup(row.modelData.id, "login")
                            }
                            PxField {
                                id: pw
                                visible: row.modelData.state === "locked" && Vault.wantsPassword(row.modelData.id)
                                width: Math.min(Theme.u * 60, parent.width)
                                password: true
                                placeholder: Vault.asks(row.modelData.id) === "pin" ? "PIN" : I18n.t("мастер-пароль", "master password")
                                onAccepted: {
                                    if (text !== "")
                                        Vault.unlock(row.modelData.id, text);
                                    text = "";
                                }
                            }
                            PxButton {
                                visible: row.modelData.state === "locked"
                                enabled: !Vault.busy && (!pw.visible || pw.text !== "")
                                icon: "lock"
                                text: Vault.busy === "unlock:" + row.modelData.id ? I18n.t("Открываю…", "Unlocking…") : I18n.t("Открыть", "Unlock")
                                onClicked: {
                                    Vault.unlock(row.modelData.id, pw.visible ? pw.text : "");
                                    pw.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
        // no master password each time: it waits in the login keyring, as it is or under a PIN
        CatRepeat {
            model: Vault.backends.filter(b => b.remembers && b.installed && b.state !== "setup")
            delegate: Component {
                CatCustom {
                    id: keep
                    required property var modelData
                    label: I18n.t("Без мастер-пароля: ", "No master password: ") + modelData.name
                    hint: modelData.saved === "keyring" ? I18n.t("включено: хранилище открывается само, пока ты вошёл в систему", "on: the vault opens by itself while you are logged in") : modelData.saved === "pin" ? I18n.t("включено: вместо мастер-пароля спрашивается твой PIN", "on: your PIN is asked instead of the master password") : I18n.t("введи мастер-пароль один раз — он ляжет в связку ключей системы (её открывает вход в систему). Свой PIN — по желанию: тогда спрашивается он", "type the master password once: it goes into the system's keyring (opened by your login). A PIN of your own is optional: then that is asked")
                    CatBox {
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxField {
                                id: master
                                visible: !keep.modelData.saved
                                width: Math.min(Theme.u * 50, parent.width)
                                password: true
                                placeholder: I18n.t("пароль", "password")
                            }
                            PxField {
                                id: pin
                                visible: !keep.modelData.saved
                                width: Theme.u * 30
                                password: true
                                placeholder: "PIN"
                            }
                            PxButton {
                                visible: !keep.modelData.saved
                                enabled: master.text !== "" && !Vault.busy
                                icon: "check"
                                text: I18n.t("Запомнить", "Remember")
                                onClicked: {
                                    Vault.remember(keep.modelData.id, master.text, pin.text);
                                    master.text = "";
                                    pin.text = "";
                                }
                            }
                            PxButton {
                                visible: !!keep.modelData.saved
                                icon: "trash"
                                text: I18n.t("Забыть", "Forget")
                                onClicked: Vault.forget(keep.modelData.id)
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    spacing: Theme.u * 3
                    PxButton {
                        icon: "refresh"
                        text: I18n.t("Проверить снова", "Look again")
                        onClicked: Vault.refresh()
                    }
                    PxButton {
                        visible: Vault.open.length > 0
                        enabled: !Vault.busy
                        icon: "download"
                        text: Vault.busy === "sync" ? I18n.t("Обновляю…", "Fetching…") : I18n.t("Обновить записи", "Fetch the entries again")
                        onClicked: Vault.sync()
                    }
                    PxButton {
                        visible: Vault.open.length > 0
                        icon: "lock"
                        text: I18n.t("Закрыть всё", "Lock everything")
                        onClicked: Vault.lock()
                    }
                }
            }
        }
        CatNote {
            dim: true
            text: I18n.t("Первый вход — один раз в терминале. Для 1Password включи в нём «Интеграция с 1Password CLI».", "Sign in once in a terminal. For 1Password, turn on «Integrate with 1Password CLI» in its app.")
        }
    }
    CatGroup {
        name: "launcher"
        title: I18n.t("В лаунчере", "In the launcher")
        icon: "search"
        CatToggle {
            label: I18n.t("Искать пароли в лаунчере", "Find passwords in the launcher")
            hint: I18n.t("Win+Space → «pw гитхаб»: Enter — пароль, Ctrl+Enter — логин, Shift+Enter — код 2FA", "Win+Space → “pw github”: Enter copies the password, Ctrl+Enter the login, Shift+Enter the 2FA code")
            checked: Config.vault.enabled
            onToggled: c => Config.vault.enabled = c
        }
        CatToggle {
            label: I18n.t("И в обычном поиске", "In the ordinary search too")
            hint: I18n.t("пока хранилище открыто, записи находятся и без «pw» — просто по названию; на стриме не показываются", "while the vault is open, entries are found without “pw” too, just by name; never shown on stream")
            checked: Config.vault.everywhere
            onToggled: c => Config.vault.everywhere = c
        }
        CatToggle {
            label: I18n.t("Прятать на стриме", "Hide on stream")
            hint: I18n.t("На стриме названия и логины закрыты точками. Пароль на экране не показывается никогда.", "On stream, names and logins are dotted out. A password is never shown.")
            checked: Config.vault.hideOnStream
            onToggled: c => Config.vault.hideOnStream = c
        }
    }
    CatGroup {
        name: "safety"
        title: I18n.t("Осторожность", "Care")
        icon: "eye"
        CatSpin {
            label: I18n.t("Стирать буфер обмена через", "Wipe the clipboard after")
            hint: I18n.t("скопированный пароль исчезает сам и не попадает в историю буфера; 0 — не стирать", "a copied password goes away by itself and never gets into the clipboard history; 0: keep it")
            value: Config.vault.clearAfter
            from: 0
            to: 300
            stepSize: 5
            suffix: I18n.t(" с", " s")
            onMoved: v => Config.vault.clearAfter = Math.round(v)
        }
        CatSpin {
            label: I18n.t("Закрывать хранилище через", "Lock the vault after")
            hint: I18n.t("минуты без обращений к паролям; 0 — не закрывать. Касается того, что открыла сама оболочка", "minutes without touching the passwords; 0: never. For what the shell unlocked itself")
            value: Config.vault.lockAfter
            from: 0
            to: 240
            stepSize: 5
            suffix: I18n.t(" мин", " min")
            onMoved: v => Config.vault.lockAfter = Math.round(v)
        }
        CatToggle {
            label: I18n.t("Закрывать вместе с экраном", "Lock with the screen")
            hint: I18n.t("экран заблокирован — хранилище тоже", "when the screen locks, so does the vault")
            checked: Config.vault.lockWithScreen
            onToggled: c => Config.vault.lockWithScreen = c
        }
    }
}
