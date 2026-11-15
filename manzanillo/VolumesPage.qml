import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: volumesPage

    Component.onCompleted: apiClient.fetchVolumes()

    function confirmDeleteVolume(name) {
        deleteVolumeDialog.volumeName = name
        deleteVolumeDialog.open()
    }

    function openVolumeDetail(name, inUse) {
        volumeStack.push("VolumeDetailPage.qml", { volumeName: name, inUse: inUse })
    }

    Dialog {
        id: deleteVolumeDialog
        objectName: "deleteVolumeDialog"
        property string volumeName: ""

        modal: true
        title: qsTr("Delete volume")
        footer: DialogButtonBox {
            Button {
                objectName: "deleteVolumeDialogConfirmButton"
                text: qsTr("Delete")
                palette.buttonText: Colors.danger
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "deleteVolumeDialogCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }
        width: 360
        anchors.centerIn: Overlay.overlay

        onAccepted: apiClient.deleteVolume(deleteVolumeDialog.volumeName)

        contentItem: Label {
            text: qsTr("Delete volume \"%1\"? This cannot be undone.").arg(deleteVolumeDialog.volumeName)
            wrapMode: Text.WordWrap
            width: deleteVolumeDialog.availableWidth
        }
    }

    PageStack {
        id: volumeStack
        objectName: "volumeStack"
        anchors.fill: parent
        clip: true
        initialItem: volumeListComponent
    }

    Component {
        id: volumeListComponent

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                FlatToolBar {
                    Layout.fillWidth: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        ToolButton {
                            text: "☰"
                            visible: Window.window ? Window.window.narrow : false
                            Accessible.name: (Window.window && Window.window.drawerOpen)
                                ? qsTr("Close navigation") : qsTr("Open navigation")
                            ToolTip.visible: hovered
                            ToolTip.text: Accessible.name
                            onClicked: Window.window.toggleDrawer()
                        }

                        Label {
                            text: qsTr("Volumes")
                            font.pointSize: TypeScale.title
                            Layout.fillWidth: true
                        }

                        ToolButton {
                            objectName: "refreshVolumesButton"
                            icon.name: "view-refresh"
                            text: qsTr("Refresh")
                            enabled: !apiClient.volumesBusy
                            onClicked: apiClient.fetchVolumes()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 12
                    spacing: 8

                    ErrorBanner {
                        id: errorLabel
                        objectName: "volumesErrorBanner"
                        busy: apiClient.volumesBusy || apiClient.busyVolumeNames.length > 0
                    }

                    Connections {
                        target: apiClient
                        function onVolumesErrorOccurred(message) {
                            errorLabel.show(message)
                        }
                        function onVolumeActionErrorOccurred(message) {
                            errorLabel.show(message)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Label {
                            objectName: "volumesEmptyLabel"
                            anchors.centerIn: parent
                            visible: volumesList.count === 0 && !apiClient.volumesBusy
                            text: qsTr("No volumes found")
                            font.pointSize: TypeScale.body
                            opacity: 0.7
                        }

                        BusyIndicator {
                            objectName: "volumesBusyIndicator"
                            anchors.centerIn: parent
                            visible: volumesList.count === 0 && apiClient.volumesBusy
                            running: visible
                            Accessible.name: qsTr("Loading volumes")
                        }

                    ListView {
                        id: volumesList
                        anchors.fill: parent
                        objectName: "volumesListView"
                        clip: true
                        spacing: 4
                        model: apiClient.volumesModel
                        activeFocusOnTab: true
                        Accessible.role: Accessible.List
                        Accessible.name: qsTr("Volumes")

                        // Keyboard equivalent of tapping a row: arrow keys move currentIndex
                        // (built into ListView), Enter/Return/Space opens its detail page.
                        Keys.onPressed: (event) => {
                            if (currentItem && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                                volumesPage.openVolumeDetail(currentItem.name, currentItem.inUse)
                                event.accepted = true
                            }
                        }

                        delegate: RowCard {
                            id: volumeRowDelegate
                            required property int index
                            required property string name
                            required property string driver
                            required property string mountpoint
                            required property string created
                            required property bool inUse
                            readonly property bool busy: apiClient.busyVolumeNames.indexOf(volumeRowDelegate.name) >= 0
                            objectName: "volumeRow_" + volumeRowDelegate.name
                            width: volumesList.width
                            title: volumeRowDelegate.name
                            statusText: volumeRowDelegate.inUse ? qsTr("In use") : qsTr("Not in use")
                            statusTint: volumeRowDelegate.inUse ? Colors.success : Colors.neutral
                            // Delete is disabled while the volume is in use; say why in a
                            // visible caption (disabled buttons get no hover or focus).
                            readonly property string deleteDisabledReason: volumeRowDelegate.inUse
                                ? qsTr("In use by a container — remove the container first") : ""
                            details: [
                                qsTr("Driver: %1    Created: %2").arg(volumeRowDelegate.driver).arg(volumeRowDelegate.created),
                                volumeRowDelegate.mountpoint
                            ].concat(volumeRowDelegate.deleteDisabledReason.length > 0 ? [volumeRowDelegate.deleteDisabledReason] : [])
                            showFocusRing: volumeRowDelegate.ListView.isCurrentItem && volumesList.activeFocus
                            onActivated: {
                                volumesList.currentIndex = volumeRowDelegate.index
                                volumesPage.openVolumeDetail(volumeRowDelegate.name, volumeRowDelegate.inUse)
                            }

                            Button {
                                objectName: "deleteVolumeButton_" + volumeRowDelegate.name
                                Accessible.description: volumeRowDelegate.deleteDisabledReason
                                text: volumeRowDelegate.busy ? qsTr("Working...") : qsTr("Delete")
                                enabled: !volumeRowDelegate.busy && !volumeRowDelegate.inUse
                                onClicked: volumesPage.confirmDeleteVolume(volumeRowDelegate.name)
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
