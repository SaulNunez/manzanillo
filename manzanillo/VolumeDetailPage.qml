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
                    font.pixelSize: 20
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

                Label {
                    text: volumeDetailPage.inUse ? qsTr("In use") : qsTr("Not in use")
                    font.italic: true
                    color: volumeDetailPage.inUse ? palette.text : "#666666"
                }
            }

            Label {
                visible: apiClient.volumeDetailBusy
                text: qsTr("Loading...")
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

                    Label { text: qsTr("Driver: %1").arg(apiClient.volumeDetail.driver) }
                    Label { text: qsTr("Scope: %1").arg(apiClient.volumeDetail.scope) }
                    Label { text: qsTr("Created: %1").arg(apiClient.volumeDetail.created) }
                    Label { text: qsTr("Mountpoint: %1").arg(apiClient.volumeDetail.mountpoint); wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }

                    Label { text: qsTr("Labels"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.volumeDetail.labels || apiClient.volumeDetail.labels.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.volumeDetail.labels || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    Label { text: qsTr("Options"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.volumeDetail.options || apiClient.volumeDetail.options.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.volumeDetail.options || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
