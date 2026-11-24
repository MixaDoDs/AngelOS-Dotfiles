pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool supported: false
    property var picking: null
    readonly property bool pickerVisible: !!picking && permitted(picking.windowId, picking.screen)
    onPickerVisibleChanged: if (!pickerVisible)
        picking = null
    readonly property alias cards: cardsModel

    ListModel {
        id: cardsModel
    }

    Process {
        command: ["niri", "window-crop", "--help"]
        running: true
        onExited: code => root.supported = code === 0
    }

    function permitted(windowId, screen) {
        const w = Niri.windows.find(item => item.id === windowId);
        return !!w && !Shell.locked && !Shell.setupLocked && !!Shell.screenByName(screen)
            && !w.block_out_from_screencast
            && (!Privacy.hiddenNow.length || (!!w.app_id && !Privacy.hiddenNow.some(app => app.id === w.app_id)));
    }

    function begin(windowId, screen) {
        if (picking || !supported || !Number.isSafeInteger(windowId))
            return;
        const w = Niri.windows.find(item => item.id === windowId);
        if (!w)
            return;
        if (!permitted(windowId, screen)) {
            Quickshell.execDetached(["notify-send", "-a", "angelOS",
                I18n.t("Вырезка недоступна для этого окна", "This window cannot be clipped")]);
            return;
        }
        if (cardsModel.count >= 4) {
            Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("На столе уже четыре вырезки", "There are already four clips on the desktop"),
                I18n.t("Уберите одну из них, чтобы добавить новую.", "Remove one to add another.")]);
            return;
        }
        picking = {
            windowId,
            screen,
            appId: w.app_id || "",
            title: Niri.titleOf(w) || w.app_id || I18n.t("Окно", "Window")
        };
    }

    function pin(crop, aspect) {
        const pick = picking;
        if (!pick || !crop || !permitted(pick.windowId, pick.screen) || cardsModel.count >= 4)
            return;
        const used = new Set();
        for (let i = 0; i < cardsModel.count; ++i) {
            const card = cardsModel.get(i);
            if (card.screen === pick.screen)
                used.add(card.slot);
        }
        let slot = 0;
        while (used.has(slot))
            ++slot;
        cardsModel.append({
            windowId: pick.windowId,
            screen: pick.screen,
            appId: pick.appId,
            title: pick.title,
            cropX: crop.x,
            cropY: crop.y,
            cropW: crop.w,
            cropH: crop.h,
            aspect: aspect * crop.w / crop.h,
            slot,
            placeX: Theme.u * (12 + slot % 2 * 176) + (BarLayout.edge === "left" ? Theme.barHeight : 0),
            placeY: Theme.u * (26 + Math.floor(slot / 2) * 124) + (BarLayout.edge === "top" ? Theme.barHeight : 0)
        });
        picking = null;
    }

    Connections {
        target: Niri
        function onWindowsChanged() {
            const ids = new Set(Niri.windows.map(window => window.id));
            for (let i = cardsModel.count - 1; i >= 0; --i)
                if (!ids.has(cardsModel.get(i).windowId))
                    cardsModel.remove(i);
        }
    }
}
