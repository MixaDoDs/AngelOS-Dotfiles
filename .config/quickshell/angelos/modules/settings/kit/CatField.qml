import QtQuick

// Text typed in (PxField). While it is typed (edit()), `text` is what is typed, so the handlers
// read it as they read the field's; release() gives the owner's binding back.
CatEntry {
    id: root

    kind: "field"
    property string text: ""
    property string placeholder: ""
    property bool password: false
    property string icon: ""
    signal accepted
    signal edited
    signal editingFinished
    property string _draft: ""
    property bool _typing: false
    Binding {
        target: root
        property: "text"
        value: root._draft
        when: root._typing
        restoreMode: Binding.RestoreBinding
    }
    function edit(t) {
        _draft = t;
        _typing = true;
        edited();
    }
    function release() {
        _typing = false;
    }
}
