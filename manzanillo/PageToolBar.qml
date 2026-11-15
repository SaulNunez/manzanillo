import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

// The header bar shared by the top-level pages: nav toggle (narrow windows only),
// page title, and the page's action buttons. Declare the actions as ToolButton
// children:
//
//     PageToolBar {
//         objectName: "imagesPageToolBar"
//         title: qsTr("Images")
//         ToolButton { objectName: "refreshImagesButton"; text: qsTr("Refresh"); onClicked: ... }
//     }
//
// When the buttons don't fit next to the title (narrow window, long translations)
// they are hidden and offered instead from a ⋯ overflow menu, whose items mirror
// each button's text, icon and enabled state and trigger its clicked() signal.
FlatToolBar {
    id: toolBar

    property string title
    default property alias actions: actionsRow.data

    // Every child of the actions row is an action button (that's all pages put there).
    readonly property var actionButtons: Array.from(actionsRow.children)

    // Sum the buttons' implicit widths rather than reading actionsRow.implicitWidth:
    // a hidden layout reports 0, which would flip `overflowing` back and forth.
    readonly property real actionsWidth: {
        let total = 0
        for (let i = 0; i < actionButtons.length; ++i)
            total += actionButtons[i].implicitWidth + (i > 0 ? actionsRow.spacing : 0)
        return total
    }

    readonly property real availableForActions: availableWidth
        - (navButton.visible ? navButton.implicitWidth + row.spacing : 0)
        - Math.min(titleLabel.implicitWidth, availableWidth / 2) - row.spacing

    readonly property bool overflowing: actionButtons.length > 0 && actionsWidth > availableForActions

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 8

        ToolButton {
            id: navButton
            text: "☰"
            visible: Window.window ? Window.window.narrow : false
            Accessible.name: (Window.window && Window.window.drawerOpen)
                ? qsTr("Close navigation") : qsTr("Open navigation")
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name
            onClicked: Window.window.toggleDrawer()
        }

        // Keeps its full width (up to half the bar) - the actions overflow first.
        Label {
            id: titleLabel
            objectName: "pageToolBarTitle"
            text: toolBar.title
            font.pixelSize: TypeScale.title
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        RowLayout {
            id: actionsRow
            spacing: 8
            visible: !toolBar.overflowing
        }

        ToolButton {
            id: overflowButton
            objectName: toolBar.objectName + "OverflowButton"
            visible: toolBar.overflowing
            text: "⋯"
            Accessible.name: qsTr("More actions")
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name
            onClicked: overflowMenu.opened ? overflowMenu.close() : overflowMenu.open()

            Menu {
                id: overflowMenu
                objectName: toolBar.objectName + "OverflowMenu"
                y: overflowButton.height

                Instantiator {
                    model: toolBar.actionButtons
                    delegate: MenuItem {
                        required property var modelData
                        objectName: modelData.objectName + "MenuItem"
                        text: modelData.text
                        icon.name: modelData.icon.name
                        enabled: modelData.enabled
                        onTriggered: modelData.clicked()
                    }
                    onObjectAdded: (index, object) => overflowMenu.insertItem(index, object)
                    onObjectRemoved: (index, object) => overflowMenu.removeItem(object)
                }
            }
        }
    }
}
