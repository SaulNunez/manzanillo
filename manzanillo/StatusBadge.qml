import QtQuick
import QtQuick.Controls

// Small colored pill for glanceable state (container running/exited, image or
// volume in-use) - pairs color with text so state is never conveyed by color
// alone.
Rectangle {
    id: root
    property alias text: label.text
    property color tint: Colors.disabled

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 6
    radius: implicitHeight / 2
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.15)
    border.color: tint
    border.width: 1

    Label {
        id: label
        anchors.centerIn: parent
        color: tint
        font.pixelSize: TypeScale.caption
        font.weight: Font.DemiBold
    }
}
