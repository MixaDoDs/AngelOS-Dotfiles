import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Панель — what the island bar shows
SPage {
    title: "Панель"
    subtitle: "Острова сверху: часы, погода, музыка и рабочие столы"

    SetRow {
        rowKey: "seconds"
        icon: "clock"
        title: "Секунды"
        desc: "Часы на панели с секундами"
        STog {
            checked: Serp.cfg.barSeconds
            onToggled: on => Serp.cfg.barSeconds = on
        }
    }
    SetRow {
        rowKey: "weather"
        icon: "cloud"
        title: "Погода"
        desc: "Температура и значок погоды рядом с часами"
        STog {
            checked: Serp.cfg.barWeather
            onToggled: on => Serp.cfg.barWeather = on
        }
    }
    SetRow {
        rowKey: "media"
        icon: "music"
        title: "Сейчас играет"
        desc: "Трек в левом острове, пока играет музыка"
        STog {
            checked: Serp.cfg.barMedia
            onToggled: on => Serp.cfg.barMedia = on
        }
    }
    SetRow {
        rowKey: "desks"
        icon: "layout-grid"
        title: "Столы"
        desc: "Как показывать рабочие столы"
        SSwitch {
            options: ["Пилюли", "Цифры"]
            currentIndex: Serp.cfg.deskStyle === "numbers" ? 1 : 0
            onPicked: i => Serp.cfg.deskStyle = i === 1 ? "numbers" : "pills"
        }
    }
}
