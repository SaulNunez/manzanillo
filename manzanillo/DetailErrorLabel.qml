import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Label {
    id: root
    visible: false
    color: "red"
    wrapMode: Text.WordWrap
    Layout.fillWidth: true

    function show(message) {
        root.text = message
        root.visible = true
    }
}
