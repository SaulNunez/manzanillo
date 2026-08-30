import QtQuick
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
        standardButtons: Dialog.Yes | Dialog.No
        width: 360
        anchors.centerIn: Overlay.overlay

        onAccepted: apiClient.deleteVolume(deleteVolumeDialog.volumeName)

        contentItem: Label {
            text: qsTr("Delete volume \"%1\"? This cannot be undone.").arg(deleteVolumeDialog.volumeName)
            wrapMode: Text.WordWrap
            width: deleteVolumeDialog.availableWidth
        }
    }

    StackView {
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
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: qsTr("Volumes")
                        font.pixelSize: 20
                        Layout.fillWidth: true
                    }

                    Button {
                        text: apiClient.volumesBusy ? qsTr("Loading...") : qsTr("Refresh")
                        enabled: !apiClient.volumesBusy
                        onClicked: apiClient.fetchVolumes()
                    }
                }

                Label {
                    id: errorLabel
                    visible: false
                    color: "red"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Connections {
                    target: apiClient
                    function onVolumesErrorOccurred(message) {
                        errorLabel.text = message
                        errorLabel.visible = true
                    }
                    function onVolumeActionErrorOccurred(message) {
                        errorLabel.text = message
                        errorLabel.visible = true
                    }
                }

                Label {
                    visible: volumesList.count === 0 && !apiClient.volumesBusy
                    text: qsTr("No volumes found")
                    opacity: 0.7
                }

                ListView {
                    id: volumesList
                    objectName: "volumesListView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: apiClient.volumesModel
                    activeFocusOnTab: true

                    // Keyboard equivalent of tapping a row: arrow keys move currentIndex
                    // (built into ListView), Enter/Return/Space opens its detail page.
                    Keys.onPressed: (event) => {
                        if (currentItem && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                            volumesPage.openVolumeDetail(currentItem.name, currentItem.inUse)
                            event.accepted = true
                        }
                    }

                    delegate: Frame {
                        id: volumeRowDelegate
                        required property string name
                        required property string driver
                        required property string mountpoint
                        required property string created
                        required property bool inUse
                        width: volumesList.width
                        // Frame only derives its implicit size automatically from a single
                        // content child; the focus-ring Rectangle below makes that two, so
                        // size it explicitly off the RowLayout instead.
                        implicitHeight: contentRow.implicitHeight + topPadding + bottomPadding

                        RowLayout {
                            id: contentRow
                            anchors.fill: parent
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: volumeRowDelegate.name
                                    font.bold: true
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: qsTr("Driver: %1    Created: %2").arg(volumeRowDelegate.driver).arg(volumeRowDelegate.created)
                                    font.pixelSize: 12
                                    opacity: 0.7
                                }

                                Label {
                                    text: volumeRowDelegate.mountpoint
                                    font.pixelSize: 12
                                    opacity: 0.7
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: volumeRowDelegate.inUse ? qsTr("In use") : qsTr("Not in use")
                                    font.pixelSize: 12
                                    font.italic: true
                                    color: volumeRowDelegate.inUse ? palette.text : "#666666"
                                }
                            }

                            Button {
                                objectName: "deleteVolumeButton_" + volumeRowDelegate.name
                                text: apiClient.volumeActionBusy ? qsTr("Working...") : qsTr("Delete")
                                enabled: !apiClient.volumeActionBusy && !volumeRowDelegate.inUse
                                onClicked: volumesPage.confirmDeleteVolume(volumeRowDelegate.name)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: palette.highlight
                            border.width: 2
                            visible: volumeRowDelegate.ListView.isCurrentItem && volumesList.activeFocus
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                volumesList.currentIndex = index
                                volumesPage.openVolumeDetail(volumeRowDelegate.name, volumeRowDelegate.inUse)
                            }
                        }
                    }
                }
            }
        }
    }
}
