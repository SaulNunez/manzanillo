import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 800
    height: 600
    visible: true
    title: qsTr("Manzanillo")

    Drawer {
        id: navDrawer
        objectName: "navDrawer"
        width: 180
        height: parent.height
        edge: Qt.LeftEdge
        modal: false
        interactive: false
        visible: true

        ListView {
            id: nav
            objectName: "navList"
            anchors.fill: parent
            model: [qsTr("Containers"), qsTr("Images"), qsTr("Volumes"), qsTr("Settings")]
            currentIndex: 0
            delegate: ItemDelegate {
                objectName: "navItem_" + index
                width: nav.width
                text: modelData
                highlighted: ListView.isCurrentItem
                onClicked: nav.currentIndex = index
            }
        }
    }

    StackLayout {
        anchors.fill: parent
        anchors.leftMargin: navDrawer.width
        currentIndex: nav.currentIndex

        ContainersPage {}
        ImagesPage {}
        VolumesPage {}
        SettingsPage {}
    }
}
