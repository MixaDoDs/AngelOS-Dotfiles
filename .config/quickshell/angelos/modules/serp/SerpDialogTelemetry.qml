import QtQuick
import qs.config
import qs.services

// serp-skin: the telemetry question (modules/settings/TelemetryPrompt) in Serpantinum's look.
// `host` is the prompt's window: `due` (false = later) and answer("yes" | "no").
SerpDialog {
    id: root

    property var host: null

    icon: "cpu"
    title: I18n.t("Помочь автору телеметрией?", "Help the author with telemetry?")
    body: I18n.t("Раз в неделю автору angelOS уходят версии и железо: процессор, видеокарта, память, экраны, версии Quickshell и системы. Имён, файлов и IP — нет. Скажешь «нет» — ничего не собирается. Передумать и посмотреть, что именно уходит: Настройки → angelOS → Телеметрия.", "Once a week angelOS's author gets the versions and the hardware: CPU, graphics, memory, screens, the Quickshell and system versions. No names, files or IP. Say no and nothing is collected. To change your mind or see exactly what goes: Settings → angelOS → Telemetry.")
    cardWidth: Serp.px(480)
    buttons: [
        {
            "label": I18n.t("Позже", "Later"),
            "kind": "flat"
        },
        {
            "label": I18n.t("Нет", "No")
        },
        {
            "label": I18n.t("Да, помогу ♡", "Yes, I'll help ♡"),
            "icon": "heart",
            "kind": "primary"
        }
    ]
    onDismissed: if (host)
        host.due = false
    onPicked: i => {
        if (!host)
            return;
        if (i === 0)
            host.due = false;
        else
            host.answer(i === 2 ? "yes" : "no");
    }
}
