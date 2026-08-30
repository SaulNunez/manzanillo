import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shared heading for the detail pages' "Ports"/"Networks"/"Labels" style
// sections - a real heading step (size + weight + a divider) instead of
// body text with font.bold, so scanning a detail page for a section
// actually works.
ColumnLayout {
    id: root
    property alias text: label.text

    Layout.fillWidth: true
    Layout.topMargin: 12
    spacing: 4

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: palette.mid
    }

    Label {
        id: label
        font.pixelSize: TypeScale.heading
        font.weight: Font.DemiBold
    }
}
