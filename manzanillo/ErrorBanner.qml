import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shared error banner for list and detail pages: an icon plus the message (so the
// error never relies on colour alone) and a keyboard-reachable dismiss button.
// Bind `busy` to "a fetch or action for this page is in flight"; the banner clears
// itself whenever new work starts, so a stale error never outlives a later retry.
Rectangle {
    id: root
    property string text: ""
    property bool busy: false
    readonly property color accentColor: Colors.danger

    function show(message) {
        root.text = message
        root.visible = true
    }

    function clear() {
        root.visible = false
        root.text = ""
    }

    onBusyChanged: if (busy) root.clear()

    visible: false
    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 12
    radius: 4
    color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
    border.color: accentColor
    border.width: 1

    Accessible.role: Accessible.AlertMessage
    Accessible.name: root.text

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 4
        spacing: 8

        // Drawn rather than taken from the icon theme so it always renders.
        Rectangle {
            objectName: "errorBannerIcon"
            implicitWidth: 18
            implicitHeight: 18
            radius: width / 2
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter
            Accessible.ignored: true

            Label {
                anchors.centerIn: parent
                text: "!"
                color: palette.window
                font.pointSize: TypeScale.caption
                font.weight: Font.Bold
            }
        }

        Label {
            objectName: "errorBannerText"
            text: root.text
            wrapMode: Text.WordWrap
            font.pointSize: TypeScale.body
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        ToolButton {
            objectName: "errorBannerDismissButton"
            text: "✕"
            activeFocusOnTab: true
            focusPolicy: Qt.StrongFocus
            Accessible.name: qsTr("Dismiss error")
            ToolTip.text: qsTr("Dismiss error")
            ToolTip.visible: hovered
            ToolTip.delay: 500
            Layout.alignment: Qt.AlignVCenter
            onClicked: root.clear()
        }
    }
}
