import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A detail-page value: body-style text that can be selected with the mouse or the
// keyboard (Tab to it, Shift+arrows / Ctrl+A, Ctrl+C), plus an optional copy
// button for IDs and digests. Sits in the value column of a detail page's
// GridLayout, next to a FieldLabel.
RowLayout {
    id: fieldValue

    property string text: ""
    // Show a copy-to-clipboard button after the value.
    property bool copyable: false
    property bool monospace: false
    // What the copy button's accessible name / tool tip says is being copied.
    property string copyName: qsTr("value")

    Layout.fillWidth: true
    spacing: 4

    function copyToClipboard() {
        valueText.selectAll()
        valueText.copy()
        valueText.deselect()
    }

    TextEdit {
        id: valueText
        objectName: "valueText"
        text: fieldValue.text
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        activeFocusOnTab: true
        wrapMode: TextEdit.WrapAnywhere
        color: fieldValue.palette.windowText
        selectionColor: fieldValue.palette.highlight
        selectedTextColor: fieldValue.palette.highlightedText
        font.family: fieldValue.monospace ? "monospace" : Qt.application.font.family
        font.pointSize: fieldValue.monospace ? TypeScale.monospace : TypeScale.body
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Accessible.role: Accessible.StaticText
        Accessible.name: fieldValue.text

        // Show where keyboard focus is, since a read-only TextEdit has no cursor.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.color: fieldValue.palette.highlight
            border.width: 1
            visible: valueText.activeFocus
        }
    }

    ToolButton {
        objectName: "copyButton"
        visible: fieldValue.copyable
        text: "⧉"
        font.pointSize: TypeScale.body
        Accessible.name: qsTr("Copy %1").arg(fieldValue.copyName)
        ToolTip.text: Accessible.name
        ToolTip.visible: hovered
        ToolTip.delay: 500
        Layout.alignment: Qt.AlignTop
        onClicked: fieldValue.copyToClipboard()
    }
}
