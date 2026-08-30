import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: imageDetailPage
    required property string imageId
    required property string tags

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
        standardButtons: Dialog.Yes | Dialog.No
        width: 360
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
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 400
        anchors.centerIn: Overlay.overlay

        onAccepted: apiClient.tagImage(imageDetailPage.imageId, tagRepositoryField.text.trim(), tagTagField.text.trim())

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
                placeholderText: qsTr("latest")
            }
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
                    objectName: "imageDetailBackButton"
                    text: qsTr("< Back")
                    onClicked: imageDetailPage.StackView.view.pop()
                }

                Label {
                    text: imageDetailPage.tags
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
                    objectName: "imageDetailTagButton"
                    text: qsTr("Tag")
                    enabled: !apiClient.imageActionBusy
                    onClicked: {
                        tagRepositoryField.text = ""
                        tagTagField.text = ""
                        tagImageDialog.open()
                    }
                }

                Button {
                    objectName: "imageDetailDeleteButton"
                    text: apiClient.imageActionBusy ? qsTr("Working...") : qsTr("Delete")
                    enabled: !apiClient.imageActionBusy
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
                }
            }

            DetailErrorLabel {
                id: detailErrorLabel
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

                    Label { text: qsTr("Id: %1").arg(apiClient.imageDetail.id); wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    Label { text: qsTr("Created: %1").arg(apiClient.imageDetail.created) }
                    Label { text: qsTr("Size: %1").arg(apiClient.imageDetail.size) }
                    Label { text: qsTr("Architecture: %1    OS: %2").arg(apiClient.imageDetail.architecture).arg(apiClient.imageDetail.os) }
                    Label { text: qsTr("Author: %1").arg(apiClient.imageDetail.author); visible: !!apiClient.imageDetail.author }
                    Label { text: qsTr("Command: %1").arg(apiClient.imageDetail.command); wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; visible: !!apiClient.imageDetail.command }
                    Label { text: qsTr("Working Dir: %1").arg(apiClient.imageDetail.workingDir); visible: !!apiClient.imageDetail.workingDir }

                    Label { text: qsTr("Tags"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.imageDetail.tags || apiClient.imageDetail.tags.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.tags || []
                        delegate: Label { required property string modelData; text: modelData }
                    }

                    Label { text: qsTr("Digests"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.imageDetail.digests || apiClient.imageDetail.digests.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.digests || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    Label { text: qsTr("Exposed Ports"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.imageDetail.exposedPorts || apiClient.imageDetail.exposedPorts.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.exposedPorts || []
                        delegate: Label { required property string modelData; text: modelData }
                    }

                    Label { text: qsTr("Environment"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.imageDetail.env || apiClient.imageDetail.env.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.env || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    Label { text: qsTr("Labels"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.imageDetail.labels || apiClient.imageDetail.labels.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.labels || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    Label { text: qsTr("Layers"); font.bold: true; Layout.topMargin: 8 }
                    Repeater {
                        model: apiClient.imageDetail.layers || []
                        delegate: Label {
                            required property string modelData
                            text: modelData
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                            font.family: "monospace"
                            font.pixelSize: TypeScale.monospace
                        }
                    }
                }
            }
        }
    }
}
