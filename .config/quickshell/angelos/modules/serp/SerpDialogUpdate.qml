import QtQuick
import qs.config
import qs.services

// serp-skin: «angelOS is updated» (modules/settings/UpdatePrompt) in Serpantinum's look. `host`
// is the prompt's window: its pick (current: 0 later, 1 restart) and answer(restart).
SerpDialog {
    id: root

    property var host: null

    icon: "download"
    title: Updates.restored ? I18n.t("Возвращено как было до обновления", "Restored to how it was before the update") : I18n.t("Новая версия установлена", "The new version is installed") + (Updates.landed > 0 ? I18n.t(" (изменений: ", " (changes: ") + Updates.landed + ")" : "")
    body: Updates.restored ? I18n.t("Оболочка запущена с файлами того обновления. Перезагрузить её? Окна и программы останутся открытыми.", "The shell was started with that update's files. Restart it? Windows and apps stay open.") : I18n.t("Сейчас работает ещё прошлая — она в памяти. Перезагрузить оболочку? Окна и программы останутся открытыми, панель пропадёт на пару секунд.", "The previous one is still running from memory. Restart the shell now? Windows and apps stay open; the bar disappears for a couple of seconds.")
    note: I18n.t("«Позже» — новая версия загрузится при следующем входе; перезапустить можно и в Настройки → Обновления.", "“Later”: the new version loads at the next login; Settings → Updates can restart it too.")
    current: host ? host.current : 1
    buttons: [
        {
            "label": I18n.t("Позже", "Later")
        },
        {
            "label": I18n.t("Перезагрузить оболочку", "Restart the shell"),
            "icon": "refresh-cw",
            "kind": "primary"
        }
    ]
    onDismissed: if (host)
        host.answer(false)
    onPicked: i => {
        if (host)
            host.answer(i === 1);
    }
    onHoveredButton: i => {
        if (host)
            host.current = i;
    }
}
