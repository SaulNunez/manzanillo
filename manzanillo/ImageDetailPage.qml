import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: imageDetailPage
    required property string imageId
    // Busy only while this image's own delete/tag is in flight.
    readonly property bool actionBusy: apiClient.busyImageIds.indexOf(imageDetailPage.imageId) >= 0
    required property string tags
    required property bool inUse

    Component.onCompleted: apiClient.fetchImageDetail(imageDetailPage.imageId)

    Connections {
        target: apiClient
        function onImageDetailErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
        function onImageActionErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
    }

    Dialog {
        id: deleteImageDialog
        objectName: "imageDetailDeleteDialog"
        modal: true
        title: qsTr("Delete image")
        footer: DialogButtonBox {
            Button {
                objectName: "imageDetailDeleteDialogConfirmButton"
                text: qsTr("Delete")
                palette.buttonText: Colors.danger
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "imageDetailDeleteDialogCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }
        width: Overlay.overlay ? Math.min(360, Overlay.overlay.width - 32) : 360
        anchors.centerIn: Overlay.overlay

        // Deleting removes the image, so there's nothing left to show here - pop
        // back to the list right away instead of waiting to see if it succeeded.
        onAccepted: {
            apiClient.deleteImage(imageDetailPage.imageId)
            imageDetailPage.StackView.view.pop()
        }

        contentItem: Label {
            text: qsTr("Delete image \"%1\"? This cannot be undone.").arg(imageDetailPage.tags)
            wrapMode: Text.WordWrap
            width: deleteImageDialog.availableWidth
        }
    }

    Dialog {
        id: tagImageDialog
        objectName: "imageDetailTagDialog"
        modal: true
        title: qsTr("Add tag")
        width: Overlay.overlay ? Math.min(400, Overlay.overlay.width - 32) : 400
        anchors.centerIn: Overlay.overlay

        readonly property bool inputValid: tagRepositoryField.text.trim().length > 0

        footer: DialogButtonBox {
            Button {
                objectName: "imageDetailTagOkButton"
                text: qsTr("OK")
                enabled: tagImageDialog.inputValid
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "imageDetailTagCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            if (tagImageDialog.inputValid)
                apiClient.tagImage(imageDetailPage.imageId, tagRepositoryField.text.trim(), tagTagField.text.trim())
        }

        contentItem: ColumnLayout {
            width: tagImageDialog.availableWidth
            spacing: 8

            Label {
                text: qsTr("Repository")
                Layout.fillWidth: true
            }

            TextField {
                id: tagRepositoryField
                objectName: "imageDetailTagRepositoryField"
                Layout.fillWidth: true
                focus: true
                onAccepted: if (tagImageDialog.inputValid) tagImageDialog.accept()
                placeholderText: qsTr("e.g. myrepo/myimage")
            }

            Label {
                text: qsTr("Tag (optional, defaults to \"latest\")")
                Layout.fillWidth: true
            }

            TextField {
                id: tagTagField
                objectName: "imageDetailTagTagField"
                Layout.fillWidth: true
                onAccepted: if (tagImageDialog.inputValid) tagImageDialog.accept()
                placeholderText: qsTr("latest")
            }
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
                    objectName: "imageDetailBackButton"
                    onClicked: imageDetailPage.StackView.view.pop()
                }

                Label {
                    text: imageDetailPage.tags
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

            // Non-destructive actions sit on the left; Delete is pushed to the far
            // right and tinted so it isn't the same weight as Tag beside it.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    objectName: "imageDetailTagButton"
                    text: qsTr("Tag")
                    enabled: !imageDetailPage.actionBusy
                    onClicked: {
                        tagRepositoryField.text = ""
                        tagTagField.text = ""
                        tagImageDialog.open()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    objectName: "imageDetailDeleteButton"
                    text: imageDetailPage.actionBusy ? qsTr("Working...") : qsTr("Delete")
                    palette.buttonText: Colors.danger
                    enabled: !imageDetailPage.actionBusy
                    onClicked: deleteImageDialog.open()
                }
            }

            RowLayout {
                visible: apiClient.imageDetailBusy
                spacing: 8

                BusyIndicator {
                    implicitWidth: 20
                    implicitHeight: 20
                    running: apiClient.imageDetailBusy
                }

                Label {
                    text: qsTr("Loading...")
                    font.pointSize: TypeScale.body
                }
            }

            ErrorBanner {
                id: detailErrorLabel
                objectName: "imageDetailErrorBanner"
                busy: apiClient.imageDetailBusy || imageDetailPage.actionBusy
            }

            ScrollView {
                id: detailScrollView
                visible: !apiClient.imageDetailBusy
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: detailScrollView.availableWidth
                    spacing: 4

                    Label { text: qsTr("Id: %1").arg(apiClient.imageDetail.id); font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }

                    RowLayout {
                        spacing: 8

                        Label { text: qsTr("Status:"); font.pointSize: TypeScale.body }
                        StatusBadge {
                            text: imageDetailPage.inUse ? qsTr("In use") : qsTr("Not in use")
                            tint: imageDetailPage.inUse ? Colors.success : Colors.neutral
                        }
                    }

                    Label { text: qsTr("Created: %1").arg(apiClient.imageDetail.created); font.pointSize: TypeScale.body }
                    Label { text: qsTr("Size: %1").arg(apiClient.imageDetail.size); font.pointSize: TypeScale.body }
                    Label { text: qsTr("Architecture: %1    OS: %2").arg(apiClient.imageDetail.architecture).arg(apiClient.imageDetail.os); font.pointSize: TypeScale.body }
                    Label { text: qsTr("Author: %1").arg(apiClient.imageDetail.author); font.pointSize: TypeScale.body; visible: !!apiClient.imageDetail.author }
                    Label { text: qsTr("Command: %1").arg(apiClient.imageDetail.command); font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; visible: !!apiClient.imageDetail.command }
                    Label { text: qsTr("Working Dir: %1").arg(apiClient.imageDetail.workingDir); font.pointSize: TypeScale.body; visible: !!apiClient.imageDetail.workingDir }

                    SectionHeading { text: qsTr("Tags") }
                    Label {
                        visible: !apiClient.imageDetail.tags || apiClient.imageDetail.tags.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.tags || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body }
                    }

                    SectionHeading { text: qsTr("Digests") }
                    Label {
                        visible: !apiClient.imageDetail.digests || apiClient.imageDetail.digests.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.digests || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    SectionHeading { text: qsTr("Exposed Ports") }
                    Label {
                        visible: !apiClient.imageDetail.exposedPorts || apiClient.imageDetail.exposedPorts.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.exposedPorts || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body }
                    }

                    SectionHeading { text: qsTr("Environment") }
                    Label {
                        visible: !apiClient.imageDetail.env || apiClient.imageDetail.env.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.env || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    SectionHeading { text: qsTr("Labels") }
                    Label {
                        visible: !apiClient.imageDetail.labels || apiClient.imageDetail.labels.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.labels || []
                        delegate: Label { required property string modelData; text: modelData; font.pointSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    SectionHeading { text: qsTr("Layers") }
                    Label {
                        visible: !apiClient.imageDetail.layers || apiClient.imageDetail.layers.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.layers || []
                        delegate: Label {
                            required property string modelData
                            text: modelData
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                            font.family: "monospace"
                            font.pointSize: TypeScale.monospace
                        }
                    }
                }
            }
        }
    }
}
