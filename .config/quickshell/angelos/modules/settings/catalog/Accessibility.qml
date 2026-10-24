// The settings once in AccessibilityPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Accessibility (2026-10-07): what makes the desktop easier to see. The other pages of the
// section are groups of their old files (the lens, shaking to find the pointer, motion, voice).
CatPage {
    heading: I18n.t("Контраст и прозрачность", "Contrast and transparency")
    subtitle: I18n.t("Чётче текст и рамки, сплошные панели вместо стекла.", "Crisper text and edges, solid panels instead of glass.")
    CatGroup {
        name: "contrast"
        title: I18n.t("Контраст и прозрачность", "Contrast and transparency")
        icon: "eye"
        CatToggle {
            label: I18n.t("Уменьшить прозрачность", "Reduce transparency")
            hint: GoldenGate.on ? I18n.t("стекло Golden Gate становится сплошным", "Golden Gate's glass turns solid") : I18n.t("панели сплошные, без размытия под ними", "solid panels, nothing blurred under them")
            checked: GoldenGate.on ? Config.mac.reduceTransparency : !Config.appearance.blur
            onToggled: v => {
                if (GoldenGate.on)
                    Config.mac.reduceTransparency = v;
                else
                    Config.appearance.blur = !v;
            }
        }
        CatToggle {
            label: I18n.t("Повышенный контраст", "Increase contrast")
            hint: I18n.t("текст ближе к чёрному или белому, рамки чётче", "text closer to black or white, crisper edges")
            checked: Config.appearance.highContrast
            onToggled: v => Config.appearance.highContrast = v
        }
    }
}
