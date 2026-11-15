import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The label column of a detail page's GridLayout: caption-style text ("Image",
// "Created"), top-aligned so it lines up with the first line of a wrapping value.
Label {
    font.pointSize: TypeScale.caption
    opacity: 0.7
    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
    Layout.topMargin: 2
}
