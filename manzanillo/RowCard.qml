import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A clickable list row: bold title, status badge, caption metadata lines and
// trailing actions, with a focus ring. Tapping it, pressing Enter/Return/Space
// while it has focus, or the accessibility "press" action emits activated().
//
// Screen readers see it as a button named "<title>, <status>".
Frame {
    id: rowCard

    property string title: ""
    property string statusText: ""
    property color statusTint: Colors.neutral
    // Caption lines shown under the title, one string per line.
    property var details: []
    // When the focus ring shows. Defaults to the row's own keyboard focus; rows
    // inside a ListView bind it to "current item while the list has focus".
    property bool showFocusRing: activeFocus
    // Trailing controls (e.g. action buttons), laid out right of the text.
    default property alias trailing: trailingRow.data

    signal activated()

    // Frame only derives its implicit size automatically from a single content
    // child; the focus-ring Rectangle below makes that two, so size it
    // explicitly off the RowLayout instead.
    implicitHeight: contentRow.implicitHeight + topPadding + bottomPadding

    Accessible.role: Accessible.Button
    Accessible.name: statusText.length > 0 ? qsTr("%1, %2").arg(title).arg(statusText) : title
    Accessible.description: details.join(", ")
    Accessible.onPressAction: rowCard.activated()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            rowCard.activated()
            event.accepted = true
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: rowCard.title
                    font.bold: true
                    font.pixelSize: TypeScale.body
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                StatusBadge {
                    objectName: "statusBadge"
                    visible: rowCard.statusText.length > 0
                    text: rowCard.statusText
                    tint: rowCard.statusTint
                }
            }

            Repeater {
                model: rowCard.details

                delegate: Label {
                    required property string modelData
                    text: modelData
                    font.pixelSize: TypeScale.caption
                    opacity: 0.7
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            id: trailingRow
            spacing: 8
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: rowCard.palette.highlight
        border.width: 2
        visible: rowCard.showFocusRing
    }

    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: rowCard.activated()
    }
}
