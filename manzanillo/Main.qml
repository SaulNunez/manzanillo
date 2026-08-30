import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 800
    height: 600
    visible: true
    title: qsTr("Manzanillo")

    // Read once here rather than via the LayoutMirroring attached property on Drawer/StackLayout
    // below - LayoutMirroring only attaches to Items and Windows, not Popups (Drawer).
    readonly property bool rtl: Qt.application.layoutDirection === Qt.RightToLeft

    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true

    Drawer {
        id: navDrawer
        objectName: "navDrawer"
        width: 180
        height: parent.height
        edge: rtl ? Qt.RightEdge : Qt.LeftEdge
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
        anchors.leftMargin: rtl ? 0 : navDrawer.width
        anchors.rightMargin: rtl ? navDrawer.width : 0
        currentIndex: nav.currentIndex

        ContainersPage {}
        ImagesPage {}
        VolumesPage {}
        SettingsPage {}
    }
}
