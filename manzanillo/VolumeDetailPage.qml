import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: volumeDetailPage
    required property string volumeName
    // Busy only while this volume's own delete is in flight.
    readonly property bool actionBusy: apiClient.busyVolumeNames.indexOf(volumeDetailPage.volumeName) >= 0
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
        footer: DialogButtonBox {
            Button {
                objectName: "volumeDetailDeleteDialogConfirmButton"
                text: qsTr("Delete")
                palette.buttonText: Colors.danger
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "volumeDetailDeleteDialogCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }
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

        FlatToolBar {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: 8

                BackButton {
                    objectName: "volumeDetailBackButton"
                    onClicked: volumeDetailPage.StackView.view.pop()
                }

                Label {
                    text: volumeDetailPage.volumeName
                    font.pointSize: TypeScale.title
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

            // Status on the left; Delete is pushed to the far right and tinted so
            // the destructive action stands apart.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StatusBadge {
                    text: volumeDetailPage.inUse ? qsTr("In use") : qsTr("Not in use")
                    tint: volumeDetailPage.inUse ? Colors.success : Colors.neutral
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    objectName: "volumeDetailDeleteButton"
                    Accessible.description: deleteReasonLabel.visible ? deleteReasonLabel.text : ""
                    text: volumeDetailPage.actionBusy ? qsTr("Working...") : qsTr("Delete")
                    enabled: !volumeDetailPage.actionBusy && !volumeDetailPage.inUse
                    palette.buttonText: Colors.danger
                    onClicked: deleteVolumeDialog.open()
                }
            }

            // Delete is disabled while the volume is in use; say why in a visible
            // caption under it (disabled buttons get no hover or keyboard focus).
            Label {
                id: deleteReasonLabel
                objectName: "volumeDetailDeleteReason"
                visible: volumeDetailPage.inUse
                text: qsTr("In use by a container — remove the container first")
                font.pointSize: TypeScale.caption
                opacity: 0.7
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
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
                    font.pointSize: TypeScale.body
                }
            }

            ErrorBanner {
                id: detailErrorLabel
                objectName: "volumeDetailErrorBanner"
                busy: apiClient.volumeDetailBusy || volumeDetailPage.actionBusy
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

                    Label { text: qsTr("Driver: %1").arg(apiClient.volumeDetail.driver); font.pointSize: TypeScale.body }
                    Label { text: qsTr("Scope: %1").arg(apiClient.volumeDetail.scope); font.pointSize: TypeScale.body }
                    Label { text: qsTr("Created: %1").arg(apiClient.volumeDetail.created); font.pointSize: TypeScale.body }
                    Label { text: qsTr("Mountpoint: %1").arg(apiClient.volumeDetail.mountpoint); font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }

                    SectionHeading { text: qsTr("Labels") }
                    Label {
                        visible: !apiClient.volumeDetail.labels || apiClient.volumeDetail.labels.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.volumeDetail.labels || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    SectionHeading { text: qsTr("Options") }
                    Label {
                        visible: !apiClient.volumeDetail.options || apiClient.volumeDetail.options.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.volumeDetail.options || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
