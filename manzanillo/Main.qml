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

    // Below this width there isn't enough room for a permanently-docked 180px sidebar
    // plus a usable content pane (see the responsiveness guidance: minimum layout width
    // 240px, collapse secondary content below it). Below the breakpoint the Drawer
    // becomes a collapsible overlay instead of a persistent sidebar.
    readonly property int narrowBreakpoint: 600
    readonly property bool narrow: width < narrowBreakpoint

    onNarrowChanged: {
        if (narrow) {
            navDrawer.close()
        } else {
            navDrawer.open()
        }
    }

    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true

    Drawer {
        id: navDrawer
        objectName: "navDrawer"
        width: 180
        height: parent.height
        edge: rtl ? Qt.RightEdge : Qt.LeftEdge
        modal: narrow
        interactive: narrow

        Component.onCompleted: if (!narrow) open()

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
                onClicked: {
                    nav.currentIndex = index
                    // Collapsed/overlay mode: picking a section should close the drawer,
                    // same as any mobile-style navigation drawer. Persistent mode leaves
                    // it open since it never closes there.
                    if (narrow) {
                        navDrawer.close()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: narrow ? 0 : (rtl ? 0 : navDrawer.width)
        anchors.rightMargin: narrow ? 0 : (rtl ? navDrawer.width : 0)
        spacing: 0

        ToolBar {
            Layout.fillWidth: true
            visible: narrow

            RowLayout {
                anchors.fill: parent
                spacing: 8

                ToolButton {
                    objectName: "navMenuButton"
                    text: "☰"
                    Accessible.name: navDrawer.visible ? qsTr("Close navigation") : qsTr("Open navigation")
                    ToolTip.visible: hovered
                    ToolTip.text: Accessible.name
                    onClicked: navDrawer.visible ? navDrawer.close() : navDrawer.open()
                }

                Label {
                    text: nav.currentIndex >= 0 ? nav.model[nav.currentIndex] : ""
                    font.pixelSize: TypeScale.title
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: nav.currentIndex

            ContainersPage {}
            ImagesPage {}
            VolumesPage {}
            SettingsPage {}
        }
    }
}
