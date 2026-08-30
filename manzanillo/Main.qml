import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 800
    height: 600
    visible: true
    title: qsTr("Manzanillo")
    // Window.color is a plain canvas fill, independent of the Controls palette
    // system - it defaults to white and won't follow dark mode on its own,
    // even though individual controls (which read palette.* directly) do.
    // Every Frame/Rectangle in the app that doesn't paint its own opaque
    // background shows this color through, so it has to track the palette too.
    color: palette.window

    // Read once here rather than via the LayoutMirroring attached property on Drawer/StackLayout
    // below - LayoutMirroring only attaches to Items and Windows, not Popups (Drawer).
    readonly property bool rtl: Qt.application.layoutDirection === Qt.RightToLeft

    // Below this width there isn't enough room for a permanently-docked 180px sidebar
    // plus a usable content pane (see the responsiveness guidance: minimum layout width
    // 240px, collapse secondary content below it). Below the breakpoint the Drawer
    // becomes a collapsible overlay instead of a persistent sidebar.
    readonly property int narrowBreakpoint: 600
    readonly property bool narrow: width < narrowBreakpoint

    // Exposed so each page's own ToolBar can host the nav-toggle button itself
    // instead of a separate bar - pages are separate files and can't see
    // navDrawer's id directly, but Window.window.<property> works from anywhere.
    property alias drawerOpen: navDrawer.visible
    function toggleDrawer() {
        navDrawer.visible ? navDrawer.close() : navDrawer.open()
    }

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

    StackLayout {
        anchors.fill: parent
        anchors.leftMargin: narrow ? 0 : (rtl ? 0 : navDrawer.width)
        anchors.rightMargin: narrow ? 0 : (rtl ? navDrawer.width : 0)
        currentIndex: nav.currentIndex

        ContainersPage {}
        ImagesPage {}
        VolumesPage {}
        SettingsPage {}
    }
}
