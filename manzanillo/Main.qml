import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 800
    height: 600
    visible: true
    title: qsTr("Manzanillo")

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: nav
            objectName: "navList"
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            model: [qsTr("Containers"), qsTr("Images"), qsTr("Volumes")]
            currentIndex: 0
            delegate: ItemDelegate {
                objectName: "navItem_" + index
                width: nav.width
                text: modelData
                highlighted: ListView.isCurrentItem
                onClicked: nav.currentIndex = index
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: nav.currentIndex

            ContainersPage {}
            ImagesPage {}
            VolumesPage {}
        }
    }
}
