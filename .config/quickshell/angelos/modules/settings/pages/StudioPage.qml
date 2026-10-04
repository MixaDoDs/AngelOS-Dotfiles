pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Мастер плагинов", "Plugin Studio")
    subtitle: I18n.t("Опиши идею → ответь на вопросы → проверь результат → установи. ИИ получает правила angelOS: тему, размеры, настройки и жизненный цикл плагинов.", "Describe an idea → answer questions → review → install. AI receives the angelOS rules for themes, sizing, settings and plugin lifecycle.")
    property bool connectionOpen: !PluginStudio.hasKey
    property bool historyOpen: false
    property bool resetConfirm: false
    property bool addDesktop: true
    property string selectedFile: "manifest.json"
    readonly property var plan: PluginStudio.plan
    readonly property var draft: PluginStudio.draft
    readonly property var spec: plan ? plan.spec : null
    readonly property bool installed: !!PluginStudio.session.installed
    readonly property var questions: plan ? plan.questions : []
    readonly property var files: draft ? draft.files || [] : []
    readonly property string code: (files.find(f => f.path === selectedFile) || files[0] || {}).content || ""
    // improving an installed plugin (Settings → Plugins → Improve, or the list below)
    readonly property bool editing: PluginStudio.editing
    readonly property var editPlugin: editing ? Plugins.byId(PluginStudio.target) : null
    readonly property var userPlugins: Plugins.plugins.filter(p => !p.bundled)
    property string pendingEdit: ""     // asks once before the current conversation is dropped
    property string codeView: "code"    // code | diff
    property bool editingFile: false
    property string editBuffer: ""
    property bool deleteConfirm: false
    property bool rollbackConfirm: false
    readonly property var changesList: draft && draft.changes ? draft.changes : []
    readonly property var changeOf: changesList.find(c => c.path === selectedFile) || null
    readonly property bool dirtyFile: editingFile && editBuffer !== code
    onSelectedFileChanged: {
        editingFile = false;
        deleteConfirm = false;
    }
    function improve(id) {
        if ((page.messages.length > 0 || page.draft) && pendingEdit !== id && !(page.editing && PluginStudio.target === id)) {
            pendingEdit = id;
            return;
        }
        pendingEdit = "";
        if (PluginStudio.startEdit(id)) {
            selectedFile = "manifest.json";
            codeView = "code";
        }
    }
    readonly property var messages: (PluginStudio.session.messages || []).map(m => {
        if (m.role === "user")
            return {role: I18n.t("Ты", "You"), text: m.content};
        try {
            return {role: "angelOS", text: JSON.parse(m.content).summary};
        } catch (e) {
            return {role: "angelOS", text: ""};
        }
    })

    function submit() {
        PluginStudio.send("plan", {prompt: prompt.text.trim()});
    }
    function answer(question, value) {
        PluginStudio.composer += (PluginStudio.composer ? "\n" : "") + question + " — " + value;
        prompt.input.forceActiveFocus();
    }
    function kindLabel(kind) {
        return ({
            desktop: I18n.t("Виджет рабочего стола", "Desktop widget"),
            bar: I18n.t("Виджет панели", "Bar widget"),
            service: I18n.t("Фоновый сервис", "Background service"),
            menu: I18n.t("Меню рабочего стола", "Desktop menu"),
            launcher: I18n.t("Поиск в лаунчере", "Launcher search")
        })[kind] || kind;
    }
    Component.onCompleted: {
        if (!PluginStudio.busy)
            PluginStudio.refresh();
        takeEditRequest();
    }
    // Settings → Plugins → Improve
    function takeEditRequest() {
        const id = PluginStudio.editRequest;
        if (!id || PluginStudio.busy)
            return;
        PluginStudio.editRequest = "";
        improve(id);
    }
    Connections {
        target: PluginStudio
        function onCompleted(action) {
            if (action === "save_key")
                page.connectionOpen = false;
            if (action === "save_file" || action === "update" || action === "rollback" || action === "edit_start")
                page.editingFile = false;
            if (action === "delete_file")
                page.selectedFile = "manifest.json";
            if (action === "generate" && page.editing && page.changesList.length) {
                page.selectedFile = page.changesList[0].path;
                page.codeView = "diff";
            }
            if (action === "edit_start")
                Qt.callLater(() => page.contentY = 0);
            const section = action === "plan" ? planGroup : action === "generate" || action === "review" ? resultGroup : action === "install" ? installedGroup : null;
            if (section)
                Qt.callLater(() => page.contentY = Math.max(0, Math.min(section.y, page.contentHeight - page.height)));
        }
        function onBusyChanged() {
            page.takeEditRequest();
        }
        function onEditRequestChanged() {
            page.takeEditRequest();
        }
        function onErrorChanged() {
            if (PluginStudio.error)
                Qt.callLater(() => page.contentY = Math.max(0, page.contentHeight - page.height));
        }
    }

    Flow {
        width: parent.width
        spacing: Theme.u * 3
        Repeater {
            model: page.editing ? [I18n.t("1 · Что изменить", "1 · What to change"), I18n.t("2 · План (можно пропустить)", "2 · Plan (optional)"), I18n.t("3 · Изменения", "3 · Changes"), I18n.t("4 · Обновление", "4 · Update")] : [I18n.t("1 · Идея", "1 · Idea"), I18n.t("2 · План", "2 · Plan"), I18n.t("3 · Результат", "3 · Review"), I18n.t("4 · Установка", "4 · Install")]
            PxButton {
                required property string modelData
                required property int index
                text: modelData
                compact: true
                checked: index === (page.editing ? (page.draft && page.draft.changed ? 2 : page.plan ? 1 : PluginStudio.session.updated ? 3 : 0) : page.installed ? 3 : page.draft ? 2 : page.plan ? 1 : 0)
                enabled: false
                opacity: 1
            }
        }
    }

    PxGroup {
        name: "improving"
        id: editBanner
        visible: page.editing
        title: I18n.t("Доработка: ", "Improving: ") + (page.editPlugin ? I18n.label(page.editPlugin.name) : PluginStudio.target)
        icon: "gear"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: PluginStudio.target + (page.draft && page.draft.manifest && page.draft.manifest.version ? "  ·  v" + page.draft.manifest.version : "") + ((PluginStudio.session.kept || []).length ? I18n.t("  ·  без изменений останутся: ", "  ·  kept as they are: ") + PluginStudio.session.kept.join(", ") : "")
            dim: true
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Опиши изменение — ИИ перепишет файлы, покажет разницу и проверит плагин в песочнице. Или правь файлы сам во встроенном редакторе ниже. «Обновить плагин» сохранит прошлую версию и перезагрузит плагин без перезапуска оболочки.", "Describe a change — AI rewrites the files, shows the difference and checks the plugin in a sandbox. Or edit the files yourself in the built-in editor below. “Update plugin” keeps the previous version and reloads the plugin without restarting the shell.")
        }
        PxText {
            visible: !!PluginStudio.session.updated
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.ok
            text: I18n.t("Плагин обновлён и перезагружен ♡ Можно дорабатывать дальше.", "Plugin updated and reloaded ♡ You can keep improving it.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                text: I18n.t("Папка плагина", "Plugin folder")
                icon: "folder"
                onClicked: Shell.openPath(Config.pluginsDir + "/" + PluginStudio.target)
            }
            PxButton {
                visible: !!page.editPlugin && !!page.editPlugin.settings && Plugins.isEnabled(page.editPlugin)
                text: I18n.t("Его настройки", "Its settings")
                icon: "gear"
                onClicked: Shell.openSettings("plugin:" + PluginStudio.target)
            }
            PxButton {
                visible: (PluginStudio.backups[PluginStudio.target] || 0) > 0
                enabled: !PluginStudio.busy
                text: page.rollbackConfirm ? I18n.t("Точно вернуть прошлую?", "Really restore?") : I18n.t("Вернуть прошлую версию (", "Restore previous version (") + (PluginStudio.backups[PluginStudio.target] || 0) + ")"
                icon: "arrowLeft"
                danger: page.rollbackConfirm
                onClicked: {
                    if (!page.rollbackConfirm) {
                        page.rollbackConfirm = true;
                        return;
                    }
                    page.rollbackConfirm = false;
                    PluginStudio.rollback(PluginStudio.target);
                }
            }
        }
    }

    PxGroup {
        name: "improve-another-plugin"
        id: editPick
        // a sub-page while a conversation is open (`shown` then, PxGroup), a plain group before
        readonly property bool any: page.userPlugins.length > 0 && !(page.editing && page.userPlugins.length === 1)
        visible: any
        shown: any
        title: page.editing ? I18n.t("Доработать другой плагин", "Improve another plugin") : I18n.t("Доработать готовый плагин", "Improve an installed plugin")
        icon: "plug"
        width: parent.width
        advanced: page.editing || page.messages.length > 0
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Твои плагины из ~/.config/angelos/plugins. Встроенные не меняются — их можно скопировать как свои через «Новый плагин».", "Your plugins from ~/.config/angelos/plugins. Bundled ones stay as they are.")
        }
        Repeater {
            model: page.userPlugins
            Row {
                id: pickRow
                required property var modelData
                width: parent.width
                spacing: Theme.u * 4
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: pickRow.modelData.icon || "plug"
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.u * 16 - pickBtn.width - Theme.u * 8
                    elide: Text.ElideRight
                    text: I18n.label(pickRow.modelData.name) + "  v" + (pickRow.modelData.version || "0") + ((PluginStudio.backups[pickRow.modelData.id] || 0) ? I18n.t("  · версий в запасе: ", "  · saved versions: ") + PluginStudio.backups[pickRow.modelData.id] : "")
                }
                PxButton {
                    id: pickBtn
                    anchors.verticalCenter: parent.verticalCenter
                    compact: true
                    enabled: !PluginStudio.busy
                    checked: page.editing && PluginStudio.target === pickRow.modelData.id
                    text: page.pendingEdit === pickRow.modelData.id ? I18n.t("Закрыть текущий диалог?", "Drop the current conversation?") : page.editing && PluginStudio.target === pickRow.modelData.id ? I18n.t("Открыт", "Open") : I18n.t("Доработать", "Improve")
                    icon: "sparkle"
                    danger: page.pendingEdit === pickRow.modelData.id
                    onClicked: page.improve(pickRow.modelData.id)
                }
            }
        }
    }

    PxGroup {
        name: "ai-connection"
        title: I18n.t("Подключение ИИ", "AI connection")
        icon: "sparkle"
        width: parent.width
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            PxText {
                readonly property var p: PluginStudio.providers.find(x => x.value === Config.developer.provider)
                text: (p ? p.label : Config.developer.provider) + " · " + (PluginStudio.model || I18n.t("модель по умолчанию", "default model")) + (PluginStudio.effort ? " · " + PluginStudio.effort : "") + " · " + (PluginStudio.isCli ? (!PluginStudio.cliState.installed ? I18n.t("CLI не установлен", "CLI not installed") : PluginStudio.cliState.loggedIn ? I18n.t("вход выполнен ♡", "signed in ♡") : I18n.t("нужно войти", "sign-in needed")) : (PluginStudio.hasKey ? I18n.t("ключ сохранён", "key saved") : I18n.t("нужен API-ключ", "API key needed")))
                wrapMode: Text.Wrap
                width: Math.min(implicitWidth, parent.width)
            }
            PxButton {
                compact: true
                text: page.connectionOpen ? I18n.t("Свернуть", "Collapse") : I18n.t("Настроить", "Configure")
                onClicked: page.connectionOpen = !page.connectionOpen
            }
        }
        Column {
            visible: page.connectionOpen
            width: parent.width
            spacing: Theme.u * 5
            enabled: !PluginStudio.busy
            SettingRow {
                label: I18n.t("Провайдер", "Provider")
                PxCombo {
                    width: parent.width
                    model: PluginStudio.providers
                    currentValue: Config.developer.provider
                    onActivated: value => {
                        apiKey.text = "";
                        Config.developer.provider = value;
                        PluginStudio.refresh();
                    }
                }
            }
            // ---- model: cards with what each is good for ----
            PxText {
                text: I18n.t("Модель", "Model")
                font.bold: true
            }
            Grid {
                width: parent.width
                columns: Math.max(1, Math.floor(width / (Theme.u * 105)))
                spacing: Theme.u * 2
                Repeater {
                    model: PluginStudio.modelList
                    PxBox {
                        id: mcard
                        required property var modelData
                        readonly property bool current: PluginStudio.model === modelData.id
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        height: mcol.implicitHeight + Theme.u * 6
                        sunken: current
                        color: current ? Theme.mix(Theme.face, Theme.accent, 0.3) : mm.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
                        Column {
                            id: mcol
                            x: Theme.u * 3
                            y: Theme.u * 3
                            width: parent.width - Theme.u * 6
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: (mcard.current ? "♡ " : "") + (mcard.modelData.id === "" ? I18n.t("По умолчанию", "Default") : mcard.modelData.label)
                                font.bold: true
                            }
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                kind: "tiny"
                                dim: true
                                text: mcard.modelData.id === "" ? mcard.modelData.label : ({
                                        "fast": I18n.t("быстрая, для простых плагинов", "fast, for simple plugins"),
                                        "balanced": I18n.t("баланс скорости и качества ♡", "speed and quality ♡"),
                                        "smart": I18n.t("умнее, для сложной логики", "smarter, for complex logic"),
                                        "deep": I18n.t("самая мощная, дольше и дороже", "the strongest, slower and pricier")
                                    })[mcard.modelData.speed] || mcard.modelData.id
                            }
                        }
                        MouseArea {
                            id: mm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PluginStudio.setModel(mcard.modelData.id)
                        }
                    }
                }
            }
            SettingRow {
                label: I18n.t("Своя модель", "Custom model")
                hint: PluginStudio.isCli ? I18n.t("точное имя, если нужной нет в списке", "an exact name if yours is not listed") : I18n.t("API ID модели", "the model's API ID")
                PxField {
                    width: parent.width
                    text: PluginStudio.modelInfo ? "" : PluginStudio.model
                    placeholder: PluginStudio.modelInfo ? PluginStudio.model || "—" : ""
                    onEdited: if (text.trim() !== "")
                        PluginStudio.setModel(text.trim())
                }
            }
            // ---- reasoning level ----
            SettingRow {
                visible: PluginStudio.effortLevels.length > 0
                label: I18n.t("Уровень рассуждений", "Reasoning level")
                hint: PluginStudio.effortHint(PluginStudio.effort) + I18n.t(". Для плагинов обычно хватает medium; high/xhigh — для сложных, max — если не получилось.", ". medium is usually enough for plugins; high/xhigh for complex ones, max when nothing else worked.")
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: [""].concat(PluginStudio.effortLevels)
                        PxButton {
                            required property string modelData
                            compact: true
                            text: modelData === "" ? I18n.t("авто", "auto") : modelData
                            checked: PluginStudio.effort === modelData
                            onClicked: PluginStudio.setEffort(modelData)
                        }
                    }
                }
            }
            SettingRow {
                label: I18n.t("Автоисправление", "Auto-repair")
                hint: I18n.t("если проверка нашла ошибки, ИИ сам исправляет их столько раз", "when checks fail, the AI fixes them itself this many times")
                PxSegmented {
                    model: [0, 1, 2].map(v => ({
                                "label": v === 0 ? I18n.t("нет", "off") : String(v),
                                "value": v
                            }))
                    currentValue: Config.developer.autoRepair
                    onActivated: v => Config.developer.autoRepair = v
                }
            }

            // ---- browser sign-in through the official CLI ----
            Column {
                visible: PluginStudio.isCli
                width: parent.width
                spacing: Theme.u * 3
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: PluginStudio.hasKey ? Theme.ok : Theme.textDim
                    text: !PluginStudio.cliState.installed ? (Config.developer.provider === "codex-cli" ? I18n.t("Codex CLI не найден. Установи: sudo pacman -S openai-codex (или npm i -g @openai/codex).", "Codex CLI not found. Install it: sudo pacman -S openai-codex (or npm i -g @openai/codex).") : I18n.t("Claude Code не найден. Установи его: https://claude.com/claude-code", "Claude Code not found. Install it from https://claude.com/claude-code")) : PluginStudio.cliState.loggedIn ? I18n.t("Вход выполнен", "Signed in") + (PluginStudio.cliState.method ? " (" + PluginStudio.cliState.method + ")" : "") + " ♡" : I18n.t("Не выполнен вход.", "Not signed in.")
                }
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxButton {
                        visible: !!PluginStudio.cliState.installed
                        text: PluginStudio.cliState.loggedIn ? I18n.t("Войти заново", "Sign in again") : I18n.t("Войти через браузер", "Sign in via browser")
                        icon: "lock"
                        accent: !PluginStudio.cliState.loggedIn
                        onClicked: PluginStudio.login()
                    }
                    PxButton {
                        text: I18n.t("Проверить вход", "Check sign-in")
                        icon: "refresh"
                        onClicked: PluginStudio.refresh()
                    }
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    dim: true
                    text: Config.developer.provider === "codex-cli" ? I18n.t("Запросы идут через твой Codex CLI и расходуют лимиты ChatGPT-подписки (или провайдера из ~/.codex/config.toml). Codex запускается без shell, веб-поиска, MCP и computer use, в пустой папке и только на чтение.", "Requests go through your Codex CLI and use your ChatGPT plan limits (or the provider in ~/.codex/config.toml). Codex runs without shell, web search, MCP or computer use, in an empty read-only folder.") : I18n.t("Запросы идут через Claude Code и расходуют лимиты подписки Claude. Claude запускается без инструментов, MCP и твоих настроек/хуков, в пустой папке. API-ключ из окружения не используется.", "Requests go through Claude Code and use your Claude plan limits. Claude runs without tools, MCP or your settings/hooks, in an empty folder. An API key in the environment is ignored.")
                }
            }

            // ---- API key (paid API access) ----
            Column {
                visible: !PluginStudio.isCli
                width: parent.width
                spacing: Theme.u * 5
                SettingRow {
                    label: "API key"
                    hint: PluginStudio.hasKey ? I18n.t("Сохранён. Вставь новый, чтобы заменить.", "Saved. Paste a new key to replace it.") : ""
                    PxField {
                        id: apiKey
                        width: parent.width
                        password: true
                        placeholder: Config.developer.provider === "anthropic" ? "Anthropic API key" : "OpenAI API key"
                    }
                }
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxButton {
                        text: I18n.t("Сохранить ключ", "Save key")
                        icon: "lock"
                        enabled: apiKey.text.trim().length > 0
                        onClicked: {
                            if (PluginStudio.send("save_key", {key: apiKey.text.trim()}))
                                apiKey.text = "";
                        }
                    }
                    PxButton {
                        text: I18n.t("Удалить ключ", "Delete key")
                        enabled: PluginStudio.hasKey
                        onClicked: PluginStudio.send("delete_key")
                    }
                }
                SettingRow {
                    label: I18n.t("Лимит ответа", "Output limit")
                    hint: I18n.t("Токенов на генерацию", "Tokens per generation")
                    PxSpin {
                        from: 2048
                        to: 64000
                        stepSize: 2000
                        value: Config.developer.maxOutputTokens
                        onMoved: value => Config.developer.maxOutputTokens = value
                    }
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: I18n.t("Нужен ключ API с отдельным балансом; запросы платные. Без ключа выбери «вход через браузер» — тогда хватит подписки Claude или ChatGPT. Ключ хранится локально в закрытом файле, отдельно от плагинов. Провайдер получает диалог и документацию angelOS.", "An API key uses separate, paid API billing. Without one, pick a browser sign-in provider — a Claude or ChatGPT subscription is enough. The key stays in a private local file, separate from plugins. The provider receives the conversation and angelOS documentation.")
                    dim: true
                }
            }
        }
    }

    PxGroup {
        name: "what-change"
        title: page.editing ? I18n.t("Что изменить", "What to change") : I18n.t("Твоя идея", "Your idea")
        icon: "heart"
        width: parent.width
        visible: !page.installed
        PxTextArea {
            id: prompt
            text: PluginStudio.composer
            onEdited: PluginStudio.composer = text
            width: parent.width
            implicitHeight: Theme.u * 65
            readOnly: PluginStudio.busy
            placeholder: page.plan ? I18n.t("Ответь на вопросы или напиши, что изменить в плане…", "Answer the questions or describe changes to the plan…") : page.editing ? I18n.t("Например: добавь в настройки выбор цвета, сделай виджет поменьше, показывай проценты…", "For example: add a colour choice to the settings, make the widget smaller, show percentages…") : I18n.t("Например: хочу виджет на рабочем столе, который показывает, сколько осталось токенов в Codex.", "For example: I want a desktop widget showing how many Codex tokens I have left.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            // a desktop widget that only knows heaven: the AI draws its hell (offered while the demon rules)
            PxButton {
                visible: Angel.hellShown && page.editing && !page.plan && PluginStudio.needsHell(Plugins.byId(PluginStudio.target))
                text: I18n.t("Сделать адскую версию", "Make the hell version")
                icon: "fire"
                accent: true
                enabled: !PluginStudio.busy && PluginStudio.hasKey
                onClicked: PluginStudio.makeHell()
            }
            PxButton {
                visible: page.editing && !page.plan
                text: I18n.t("Сразу переделать", "Change it now")
                icon: "sparkle"
                accent: true
                enabled: !PluginStudio.busy && PluginStudio.hasKey && prompt.text.trim() !== ""
                onClicked: PluginStudio.applyChange(prompt.text.trim())
            }
            PxButton {
                text: page.plan ? I18n.t("Отправить уточнение", "Send clarification") : page.editing ? I18n.t("Сначала обсудить", "Discuss first") : I18n.t("Обсудить идею", "Discuss idea")
                icon: page.editing && !page.plan ? "" : "sparkle"
                accent: !page.editing || !!page.plan
                enabled: !PluginStudio.busy && PluginStudio.hasKey && prompt.text.trim() !== ""
                onClicked: page.submit()
            }
            PxButton {
                text: I18n.t("Пример: счётчик", "Example: counter")
                visible: !page.plan && !page.editing && prompt.text === ""
                enabled: !PluginStudio.busy
                onClicked: PluginStudio.composer = I18n.t("Хочу виджет-счётчик на рабочем столе: кнопка увеличивает число, а в настройках можно сбросить его. Сохраняй число между перезапусками.", "I want a desktop counter widget: a button increments the number, and settings can reset it. Keep the count between restarts.")
            }
            PxButton {
                visible: page.messages.length > 0
                text: page.historyOpen ? I18n.t("Скрыть диалог", "Hide conversation") : I18n.t("История диалога", "Conversation")
                onClicked: page.historyOpen = !page.historyOpen
            }
        }
        PxText {
            visible: PluginStudio.busy && (PluginStudio.action === "plan" || (page.editing && !page.plan && PluginStudio.action === "generate"))
            width: parent.width
            wrapMode: Text.Wrap
            text: PluginStudio.statusText
            color: Theme.accent
        }
        Column {
            width: parent.width
            visible: page.historyOpen
            spacing: Theme.u * 4
            Repeater {
                model: page.messages
                PxText {
                    required property var modelData
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: modelData.role + ": " + modelData.text
                }
            }
        }
    }

    PxGroup {
        name: "what-will-change"
        id: planGroup
        visible: !!page.plan
        title: page.editing ? I18n.t("Что изменится", "What will change") : I18n.t("Как будет работать", "How it will work")
        icon: "layers"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.plan ? page.plan.summary : ""
        }
        Repeater {
            model: page.questions
            Column {
                id: question
                required property var modelData
                required property int index
                width: parent.width
                spacing: Theme.u * 3
                PxText {
                    width: parent.width
                    text: (question.index + 1) + ". " + question.modelData.question
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    font.bold: true
                }
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    Repeater {
                        model: question.modelData.options
                        PxBox {
                            id: choice
                            required property string modelData
                            width: Math.min(choiceLabel.implicitWidth + Theme.u * 12, parent.width)
                            height: choiceLabel.implicitHeight + Theme.u * 10
                            enabled: !PluginStudio.busy
                            opacity: enabled ? 1 : 0.45
                            sunken: choiceMouse.pressed
                            color: choiceMouse.containsMouse ? Theme.faceAlt : Theme.face
                            PxText {
                                id: choiceLabel
                                anchors.centerIn: parent
                                width: parent.width - Theme.u * 6
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: choice.modelData
                            }
                            MouseArea {
                                id: choiceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.answer(question.modelData.question, choice.modelData)
                            }
                        }
                    }
                }
            }
        }
        PxText {
            width: parent.width
            visible: !!page.spec
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            font.bold: true
            text: page.spec ? page.spec.name + " · " + page.kindLabel(page.spec.kind) + "\n" + page.spec.id : ""
        }
        PxText {
            width: parent.width
            visible: !!page.spec && ["desktop", "bar"].includes(page.spec.kind)
            wrapMode: Text.Wrap
            text: page.spec ? I18n.t("Размер содержимого: ", "Content size: ") + page.spec.widthUnits + " × " + page.spec.heightUnits + " u  ·  " + (page.spec.widthUnits * Theme.u) + " × " + (page.spec.heightUnits * Theme.u) + " px" + I18n.t(" при текущем масштабе. Цвета и шрифты — из активной темы.", " at the current scale. Colors and fonts follow the active theme.") : ""
            dim: true
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.spec ? page.spec.behavior : ""
        }
        Repeater {
            model: page.spec ? [
                {title: I18n.t("Данные и доступ", "Data and access"), items: page.spec.dataSources},
                {title: I18n.t("Настройки", "Settings"), items: page.spec.settings},
                {title: I18n.t("Зависимости", "Dependencies"), items: page.spec.dependencies},
                {title: I18n.t("Ограничения", "Limitations"), items: page.spec.limitations}
            ] : []
            PxText {
                required property var modelData
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: modelData.title + ": " + (modelData.items.length ? modelData.items.join(" · ") : I18n.t("нет", "none"))
                dim: true
            }
        }
        PxButton {
            visible: page.questions.length > 0
            text: I18n.t("Ответить в поле запроса", "Answer in the prompt field")
            enabled: !PluginStudio.busy
            onClicked: {
                page.contentY = 0;
                prompt.input.forceActiveFocus();
            }
        }
        PxButton {
            visible: page.editing ? !!page.plan : !page.draft && !page.installed
            text: page.editing ? I18n.t("План подходит — переделать", "Approve plan — apply changes") : I18n.t("План подходит — создать плагин", "Approve plan — generate plugin")
            icon: "sparkle"
            accent: true
            enabled: !PluginStudio.busy && PluginStudio.hasKey && page.questions.length === 0 && prompt.text.trim() === ""
            onClicked: PluginStudio.send("generate")
        }
        PxText {
            visible: PluginStudio.busy && PluginStudio.action === "generate"
            width: parent.width
            wrapMode: Text.Wrap
            text: PluginStudio.statusText
            color: Theme.accent
        }
    }

    PxGroup {
        name: "changes-files"
        id: resultGroup
        visible: !!page.draft
        title: page.editing ? I18n.t("Изменения и файлы", "Changes and files") : I18n.t("Результат", "Result")
        icon: "package"
        width: parent.width
        PxText {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.draft ? page.draft.summary || "" : ""
        }
        PxText {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.draft ? (page.draft.notes || []).join("\n") : ""
            dim: true
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: page.draft && page.draft.errors.length ? Theme.danger : Theme.ok
            text: page.draft ? (page.draft.errors.length
                ? I18n.t("Нужно исправить:\n", "Needs fixing:\n") + page.draft.errors.join("\n")
                : (page.draft.check && page.draft.check.startsWith("runtime check:") ? I18n.t("Проверено: структура, синтаксис и загрузка в Quickshell (в песочнице). Посмотри код и поведение после установки.", "Checked: structure, syntax and loading in Quickshell (sandboxed). Review the code and behaviour after installing.") : I18n.t("Структура и синтаксис проверены", "Structure and syntax checked") + (page.draft.check ? " (" + page.draft.check + ")" : "") + ".")) : ""
        }
        // improving: what differs from the installed version
        PxText {
            visible: page.editing
            width: parent.width
            wrapMode: Text.Wrap
            font.bold: page.changesList.length > 0
            text: page.changesList.length ? I18n.t("Изменено файлов: ", "Files changed: ") + page.changesList.length + I18n.t(" — нажми на файл, чтобы увидеть разницу", " — click one to see the difference") : I18n.t("Пока без изменений: это установленная версия.", "No changes yet: this is the installed version.")
        }
        Flow {
            visible: page.editing && page.changesList.length > 0
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: page.changesList
                PxButton {
                    required property var modelData
                    compact: true
                    kind: "tiny"
                    checked: page.selectedFile === modelData.path && page.codeView === "diff"
                    text: ({"added": "+ ", "removed": "− ", "changed": "~ "})[modelData.status] + modelData.path + "  +" + modelData.added + " −" + modelData.removed
                    onClicked: {
                        page.selectedFile = modelData.path;
                        page.codeView = "diff";
                    }
                }
            }
        }
        Item {
            width: parent.width
            height: fileCombo.height
            PxCombo {
                id: fileCombo
                width: parent.width - (viewSwitch.visible ? viewSwitch.width + Theme.u * 3 : 0)
                model: page.files.map(f => ({label: f.path + (page.changesList.some(c => c.path === f.path) ? "  ✎" : ""), value: f.path}))
                currentValue: page.selectedFile
                onActivated: value => page.selectedFile = value
            }
            PxSegmented {
                id: viewSwitch
                visible: page.editing && !page.editingFile
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                model: [{label: I18n.t("Код", "Code"), value: "code"}, {label: I18n.t("Разница", "Diff"), value: "diff"}]
                currentValue: page.codeView
                onActivated: value => page.codeView = value
            }
        }
        PxTextArea {
            visible: !(page.editing && page.codeView === "diff" && !page.editingFile)
            width: parent.width
            implicitHeight: Theme.u * 125
            readOnly: !page.editingFile
            monospace: true
            text: page.editingFile ? page.editBuffer : page.code
            onEdited: if (page.editingFile)
                page.editBuffer = text
        }
        PxBox {
            visible: page.editing && page.codeView === "diff" && !page.editingFile
            width: parent.width
            height: Theme.u * 125
            sunken: true
            color: Theme.sunken
            PxText {
                visible: !page.changeOf
                anchors.centerIn: parent
                text: I18n.t("В этом файле изменений нет", "No changes in this file")
                dim: true
            }
            ListView {
                anchors.fill: parent
                anchors.margins: Theme.u * 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: page.changeOf ? page.changeOf.diff.split("\n") : []
                delegate: PxText {
                    required property string modelData
                    width: ListView.view ? ListView.view.width : 0
                    kind: "mono"
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: modelData
                    color: modelData.startsWith("+") ? Theme.ok : modelData.startsWith("-") ? Theme.danger : modelData.startsWith("@@") ? Theme.accent : Theme.textDim
                }
            }
        }
        // the built-in editor: the draft's files, checked again on every save
        Flow {
            visible: !page.installed
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                visible: !page.editingFile
                enabled: !PluginStudio.busy && page.files.some(f => f.path === page.selectedFile)
                text: I18n.t("Править вручную", "Edit by hand")
                icon: "terminal"
                onClicked: {
                    page.editBuffer = page.code;
                    page.editingFile = true;
                }
            }
            PxButton {
                visible: page.editingFile
                enabled: !PluginStudio.busy && page.dirtyFile
                accent: true
                text: I18n.t("Сохранить и проверить", "Save and check")
                icon: "check"
                onClicked: PluginStudio.saveFile(page.selectedFile, page.editBuffer)
            }
            PxButton {
                visible: page.editingFile
                enabled: !PluginStudio.busy
                text: I18n.t("Отменить правку", "Discard edit")
                onClicked: page.editingFile = false
            }
            PxButton {
                visible: !page.editingFile && page.selectedFile !== "manifest.json" && page.files.some(f => f.path === page.selectedFile)
                enabled: !PluginStudio.busy
                danger: page.deleteConfirm
                text: page.deleteConfirm ? I18n.t("Точно удалить ", "Really delete ") + page.selectedFile + "?" : I18n.t("Удалить файл", "Delete file")
                icon: "trash"
                onClicked: {
                    if (!page.deleteConfirm) {
                        page.deleteConfirm = true;
                        return;
                    }
                    page.deleteConfirm = false;
                    PluginStudio.deleteFile(page.selectedFile);
                }
            }
        }
        Row {
            visible: !page.installed && !page.editingFile
            width: parent.width
            spacing: Theme.u * 3
            PxField {
                id: newFile
                width: Math.min(Theme.u * 110, parent.width - newFileBtn.width - Theme.u * 3)
                placeholder: I18n.t("новый файл, напр. Helper.qml", "new file, e.g. Helper.qml")
                onAccepted: newFileBtn.clicked()
            }
            PxButton {
                id: newFileBtn
                text: I18n.t("Добавить файл", "Add file")
                icon: "plus"
                enabled: !PluginStudio.busy && /^[A-Za-z0-9_-][A-Za-z0-9_.\/-]*\.(qml|js|json|py|sh|md|txt|svg)$/.test(newFile.text.trim()) && !page.files.some(f => f.path === newFile.text.trim())
                onClicked: {
                    const name = newFile.text.trim();
                    const qml = name.endsWith(".qml") ? "import QtQuick\nimport qs.config\nimport qs.widgets\n\nItem {\n}\n" : "";
                    if (PluginStudio.saveFile(name, qml)) {
                        page.selectedFile = name;
                        newFile.text = "";
                    }
                }
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                text: I18n.t("Открыть файлы", "Open files")
                icon: "folder"
                onClicked: if (page.draft)
                    Shell.openPath(page.installed ? Config.pluginsDir + "/" + PluginStudio.session.installed : page.draft.directory)
            }
            PxButton {
                visible: !page.installed
                text: I18n.t("Проверить ещё раз", "Recheck files")
                icon: "refresh"
                enabled: !PluginStudio.busy
                onClicked: PluginStudio.send("review")
            }
            PxButton {
                visible: !page.installed && (!page.editing || (page.draft && page.draft.errors.length > 0))
                text: page.draft && page.draft.errors.length ? I18n.t("Исправить с ИИ", "Repair with AI") : I18n.t("Пересоздать с ИИ", "Regenerate with AI")
                enabled: !PluginStudio.busy && PluginStudio.hasKey && prompt.text.trim() === ""
                onClicked: PluginStudio.send("generate")
            }
        }
        PxText {
            visible: !page.installed
            width: parent.width
            wrapMode: Text.Wrap
            text: page.editing ? I18n.t("Перед обновлением прошлая версия сохраняется в ~/.local/state/angelos/plugin-backups (последние 10), её можно вернуть одной кнопкой. Новый код работает с правами твоего пользователя; до обновления он только загружается для проверки в песочнице.", "Before updating, the previous version is saved to ~/.local/state/angelos/plugin-backups (last 10) and can be restored with one click. New code runs with your user permissions; before the update it is only loaded for checks in a sandbox.") : I18n.t("После установки код работает с правами твоего пользователя. До нажатия «Установить» он только один раз загружается для проверки в песочнице — без сети, домашней папки и сокетов.", "Installed code runs with your user permissions. Before you click Install it is only loaded once for checks, in a sandbox without network, home folder or sockets.")
            dim: true
        }
        PxToggle {
            visible: !page.installed && !page.editing && !!page.draft && !!page.draft.manifest.desktopWidget
            text: I18n.t("Добавить виджет на текущий экран", "Add widget to the current screen")
            checked: page.addDesktop
            onToggled: value => page.addDesktop = value
        }
        PxButton {
            visible: !page.installed && !page.editing
            text: I18n.t("Установить", "Install")
            icon: "plus"
            accent: true
            enabled: !PluginStudio.busy && !!page.draft && page.draft.errors.length === 0 && prompt.text.trim() === "" && !page.editingFile
            onClicked: PluginStudio.install(page.addDesktop)
        }
        PxButton {
            visible: page.editing
            text: I18n.t("Обновить плагин", "Update plugin")
            icon: "check"
            accent: true
            enabled: !PluginStudio.busy && !!page.draft && page.draft.changed && page.draft.errors.length === 0 && !page.editingFile
            onClicked: PluginStudio.update()
        }
    }

    PxGroup {
        name: "plugin-installed"
        id: installedGroup
        visible: page.installed
        title: I18n.t("Плагин установлен ♡", "Plugin installed ♡")
        icon: "heart"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Он доступен в Настройки → Плагины. Там его можно настроить и выключить.", "Find it in Settings → Plugins, where you can configure or disable it.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                text: I18n.t("Настроить плагин", "Configure plugin")
                icon: "gear"
                enabled: !!Plugins.byId(PluginStudio.session.installed)
                onClicked: Shell.openSettings("plugin:" + PluginStudio.session.installed)
            }
            PxButton {
                text: I18n.t("Доработать", "Improve it")
                icon: "sparkle"
                enabled: !PluginStudio.busy
                onClicked: page.improve(PluginStudio.session.installed)
            }
            PxButton {
                text: I18n.t("Все плагины", "All plugins")
                onClicked: Shell.openSettings("plugins")
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.u * 3
        PxText {
            visible: PluginStudio.busy
            width: parent.width
            wrapMode: Text.Wrap
            text: PluginStudio.statusText
            color: Theme.accent
        }
        PxText {
            visible: PluginStudio.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: PluginStudio.error
            color: Theme.danger
        }
        PxText {
            visible: !!PluginStudio.session.usage
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Последний запрос: ", "Last request: ") + ((PluginStudio.session.usage || {}).input_tokens || 0) + I18n.t(" входных / ", " input / ") + ((PluginStudio.session.usage || {}).output_tokens || 0) + I18n.t(" выходных токенов.", " output tokens.")
            dim: true
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                visible: PluginStudio.busy && ["plan", "generate"].includes(PluginStudio.action)
                text: I18n.t("Отменить запрос", "Cancel request")
                onClicked: PluginStudio.cancel()
            }
            PxButton {
                visible: page.messages.length > 0 || page.installed || page.editing
                enabled: !PluginStudio.busy
                text: page.resetConfirm ? (page.editing ? I18n.t("Закончить доработку?", "Finish improving?") : I18n.t("Начать новый диалог?", "Start a new conversation?")) : page.editing ? I18n.t("Закончить доработку", "Finish improving") : I18n.t("Новый плагин", "New plugin")
                onClicked: {
                    if (!page.resetConfirm) {
                        page.resetConfirm = true;
                        return;
                    }
                    if (PluginStudio.send("reset")) {
                        PluginStudio.composer = "";
                        page.resetConfirm = false;
                        page.selectedFile = "manifest.json";
                    }
                }
            }
        }
    }
}
