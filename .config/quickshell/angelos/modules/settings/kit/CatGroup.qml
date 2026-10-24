import QtQuick

// A group of settings (PxGroup's data): the entries in order. A CatRepeat stands for the
// entries it makes.
Item {
    id: root

    readonly property bool isCatGroup: true
    property string name: ""
    property string title: ""
    property string icon: ""
    property bool advanced: false
    property bool wide: false
    // the group's visibility (PxGroup's `shown`/`visible`)
    property bool present: true
    readonly property var entries: {
        const out = [];
        for (const c of children)
            if (c.isCatRepeat === true)
                for (const e of c.entries)
                    out.push(e);
            else if (c.kind !== undefined)
                out.push(c);
        return out;
    }
    visible: false
}
