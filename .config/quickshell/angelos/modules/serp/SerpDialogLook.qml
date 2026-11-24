import QtQuick
import qs.config
import qs.services

// serp-skin: «Which Settings look to keep?» (modules/settings/SettingsLookPrompt) in Serpantinum's
// look. `host` is the prompt's window: `later`; the answer is SettingsLook.choose, as there.
SerpDialog {
    id: root

    property var host: null

    icon: "settings"
    title: I18n.t("Какой вид настроек оставить?", "Which Settings look to keep?")
    body: I18n.t("Привычный — окно как в Windows 11: разделы слева, настройки справа. Новый — Persona 5 на весь экран, его ещё доделываем. Сменить потом: Настройки → Внешний вид → Вид окна настроек.", "Familiar: a window like Windows 11, sections on the left, settings on the right. New: Persona 5 over the whole screen, still being finished. To change it later: Settings → Appearance → Settings window look.")
    cardWidth: Serp.px(480)
    buttons: [
        {
            "label": I18n.t("Позже", "Later"),
            "kind": "flat"
        },
        {
            "label": I18n.t("Новый (P5)", "New (P5)"),
            "icon": "sparkles"
        },
        {
            "label": I18n.t("Привычный", "Familiar"),
            "icon": "app-window",
            "kind": "primary"
        }
    ]
    onDismissed: if (host)
        host.later = true
    onPicked: i => {
        if (i === 0) {
            if (host)
                host.later = true;
        } else
            SettingsLook.choose(i === 1 ? "p5" : "win11");
    }
}
