import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: volumeDetailPage
    required property string volumeName
    required property bool inUse

    Component.onCompleted: apiClient.fetchVolumeDetail(volumeDetailPage.volumeName)

    Connections {
        target: apiClient
        function onVolumeDetailErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
        function onVolumeActionErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
    }

    Dialog {
        id: deleteVolumeDialog
        objectName: "volumeDetailDeleteDialog"
        modal: true
        title: qsTr("Delete volume")
        standardButtons: Dialog.Yes | Dialog.No
        width: 360
        anchors.centerIn: Overlay.overlay

        // Deleting removes the volume, so there's nothing left to show here - pop
        // back to the list right away instead of waiting to see if it succeeded.
        onAccepted: {
            apiClient.deleteVolume(volumeDetailPage.volumeName)
            volumeDetailPage.StackView.view.pop()
        }

        contentItem: Label {
            text: qsTr("Delete volume \"%1\"? This cannot be undone.").arg(volumeDetailPage.volumeName)
            wrapMode: Text.WordWrap
            width: deleteVolumeDialog.availableWidth
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolBar {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: 8

                ToolButton {
                    objectName: "volumeDetailBackButton"
                    text: qsTr("< Back")
                    onClicked: volumeDetailPage.StackView.view.pop()
                }

                Label {
                    text: volumeDetailPage.volumeName
                    font.pixelSize: TypeScale.title
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 8

            RowLayout {
                spacing: 8

                Button {
                    objectName: "volumeDetailDeleteButton"
                    text: apiClient.volumeActionBusy ? qsTr("Working...") : qsTr("Delete")
                    enabled: !apiClient.volumeActionBusy && !volumeDetailPage.inUse
                    onClicked: deleteVolumeDialog.open()
                }

                StatusBadge {
                    text: volumeDetailPage.inUse ? qsTr("In use") : qsTr("Not in use")
                    tint: volumeDetailPage.inUse ? Colors.success : Colors.disabled
                }
            }

            RowLayout {
                visible: apiClient.volumeDetailBusy
                spacing: 8

                BusyIndicator {
                    implicitWidth: 20
                    implicitHeight: 20
                    running: apiClient.volumeDetailBusy
                }

                Label {
                    text: qsTr("Loading...")
                    font.pixelSize: TypeScale.body
                }
            }

            DetailErrorLabel {
                id: detailErrorLabel
            }

            ScrollView {
                id: detailScrollView
                visible: !apiClient.volumeDetailBusy
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: detailScrollView.availableWidth
                    spacing: 4

                    Label { text: qsTr("Driver: %1").arg(apiClient.volumeDetail.driver); font.pixelSize: TypeScale.body }
                    Label { text: qsTr("Scope: %1").arg(apiClient.volumeDetail.scope); font.pixelSize: TypeScale.body }
                    Label { text: qsTr("Created: %1").arg(apiClient.volumeDetail.created); font.pixelSize: TypeScale.body }
                    Label { text: qsTr("Mountpoint: %1").arg(apiClient.volumeDetail.mountpoint); font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }

                    SectionHeading { text: qsTr("Labels") }
                    Label {
                        visible: !apiClient.volumeDetail.labels || apiClient.volumeDetail.labels.length === 0
                        text: qsTr("(none)")
                        font.pixelSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.volumeDetail.labels || []
                        delegate: Label { required property string modelData; text: modelData; font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    SectionHeading { text: qsTr("Options") }
                    Label {
                        visible: !apiClient.volumeDetail.options || apiClient.volumeDetail.options.length === 0
                        text: qsTr("(none)")
                        font.pixelSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.volumeDetail.options || []
                        delegate: Label { required property string modelData; text: modelData; font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
