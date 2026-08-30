import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: imagesPage

    Component.onCompleted: apiClient.fetchImages()

    function confirmDeleteImage(id, tags) {
        deleteImageDialog.imageId = id
        deleteImageDialog.imageTags = tags
        deleteImageDialog.open()
    }

    function openPullImageDialog() {
        pullReferenceField.text = ""
        pullImageDialog.open()
    }

    function openBuildImageDialog() {
        buildContextField.text = ""
        buildDockerfileField.text = ""
        buildTagField.text = ""
        buildImageDialog.open()
    }

    function openTagImageDialog(id) {
        tagImageDialog.imageId = id
        tagRepositoryField.text = ""
        tagTagField.text = ""
        tagImageDialog.open()
    }

    Connections {
        target: apiClient
        function onImagesErrorOccurred(message) {
            errorLabel.text = message
            errorLabel.visible = true
        }
        function onImageActionErrorOccurred(message) {
            errorLabel.text = message
            errorLabel.visible = true
        }
    }

    Dialog {
        id: deleteImageDialog
        objectName: "deleteImageDialog"
        property string imageId: ""
        property string imageTags: ""

        modal: true
        title: qsTr("Delete image")
        standardButtons: Dialog.Yes | Dialog.No
        width: 360
        anchors.centerIn: Overlay.overlay

        onAccepted: apiClient.deleteImage(deleteImageDialog.imageId)

        contentItem: Label {
            text: qsTr("Delete image \"%1\"? This cannot be undone.").arg(deleteImageDialog.imageTags)
            wrapMode: Text.WordWrap
            width: deleteImageDialog.availableWidth
        }
    }

    Dialog {
        id: pullImageDialog
        objectName: "pullImageDialog"

        modal: true
        title: qsTr("Pull image")
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 400
        anchors.centerIn: Overlay.overlay

        onAccepted: apiClient.pullImage(pullReferenceField.text.trim())

        contentItem: ColumnLayout {
            width: pullImageDialog.availableWidth
            spacing: 8

            Label {
                text: qsTr("Image reference")
                Layout.fillWidth: true
            }

            TextField {
                id: pullReferenceField
                objectName: "pullReferenceField"
                Layout.fillWidth: true
                placeholderText: qsTr("e.g. redis:8.6.2")
            }
        }
    }

    Dialog {
        id: buildImageDialog
        objectName: "buildImageDialog"

        modal: true
        title: qsTr("Build image")
        // Only a Close button - building doesn't close the dialog, since the log
        // view needs to stay visible while the build streams in.
        standardButtons: Dialog.Close
        width: 480
        anchors.centerIn: Overlay.overlay

        contentItem: ColumnLayout {
            width: buildImageDialog.availableWidth
            spacing: 8

            Label {
                text: qsTr("Build context directory")
                Layout.fillWidth: true
            }

            TextField {
                id: buildContextField
                objectName: "buildContextField"
                Layout.fillWidth: true
                placeholderText: qsTr("e.g. /home/me/my-project")
            }

            Label {
                text: qsTr("Dockerfile (optional, relative to context, defaults to \"Dockerfile\")")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: buildDockerfileField
                objectName: "buildDockerfileField"
                Layout.fillWidth: true
                placeholderText: qsTr("Dockerfile")
            }

            Label {
                text: qsTr("Tag (optional)")
                Layout.fillWidth: true
            }

            TextField {
                id: buildTagField
                objectName: "buildTagField"
                Layout.fillWidth: true
                placeholderText: qsTr("e.g. myimage:latest")
            }

            Button {
                objectName: "startBuildButton"
                text: apiClient.imageActionBusy ? qsTr("Building...") : qsTr("Build")
                enabled: !apiClient.imageActionBusy && buildContextField.text.trim().length > 0
                onClicked: apiClient.buildImage(
                    buildContextField.text.trim(),
                    buildDockerfileField.text.trim(),
                    buildTagField.text.trim())
            }

            Label {
                text: qsTr("Build Log")
                font.bold: true
                Layout.topMargin: 4
                visible: buildLogArea.text.length > 0
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                clip: true
                visible: buildLogArea.text.length > 0

                TextArea {
                    id: buildLogArea
                    objectName: "buildLogArea"
                    readOnly: true
                    wrapMode: TextArea.NoWrap
                    text: apiClient.buildLog
                    font.family: "monospace"
                    font.pixelSize: 11
                    onTextChanged: cursorPosition = length
                }
            }
        }
    }

    Dialog {
        id: tagImageDialog
        objectName: "tagImageDialog"
        property string imageId: ""

        modal: true
        title: qsTr("Add tag")
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 400
        anchors.centerIn: Overlay.overlay

        onAccepted: apiClient.tagImage(tagImageDialog.imageId, tagRepositoryField.text.trim(), tagTagField.text.trim())

        contentItem: ColumnLayout {
            width: tagImageDialog.availableWidth
            spacing: 8

            Label {
                text: qsTr("Repository")
                Layout.fillWidth: true
            }

            TextField {
                id: tagRepositoryField
                objectName: "tagRepositoryField"
                Layout.fillWidth: true
                placeholderText: qsTr("e.g. myrepo/myimage")
            }

            Label {
                text: qsTr("Tag (optional, defaults to \"latest\")")
                Layout.fillWidth: true
            }

            TextField {
                id: tagTagField
                objectName: "tagTagField"
                Layout.fillWidth: true
                placeholderText: qsTr("latest")
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Images")
                font.pixelSize: 20
                Layout.fillWidth: true
            }

            Button {
                text: apiClient.imageActionBusy ? qsTr("Working...") : qsTr("Pull Image")
                enabled: !apiClient.imageActionBusy
                onClicked: imagesPage.openPullImageDialog()
            }

            Button {
                text: apiClient.imageActionBusy ? qsTr("Working...") : qsTr("Build Image")
                enabled: !apiClient.imageActionBusy
                onClicked: imagesPage.openBuildImageDialog()
            }

            Button {
                text: apiClient.imagesBusy ? qsTr("Loading...") : qsTr("Refresh")
                enabled: !apiClient.imagesBusy
                onClicked: apiClient.fetchImages()
            }
        }

        Label {
            id: errorLabel
            visible: false
            color: "red"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Label {
            visible: imagesList.count === 0 && !apiClient.imagesBusy
            text: qsTr("No images found")
            opacity: 0.7
        }

        ListView {
            id: imagesList
            objectName: "imagesListView"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: apiClient.imagesModel

            delegate: Frame {
                id: imageRowDelegate
                required property string imageId
                required property string tags
                required property string size
                required property string created
                required property bool inUse
                width: imagesList.width

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: imageRowDelegate.tags
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Label {
                            text: qsTr("Size: %1    Created: %2").arg(imageRowDelegate.size).arg(imageRowDelegate.created)
                            font.pixelSize: 12
                            opacity: 0.7
                        }

                        Label {
                            text: imageRowDelegate.inUse ? qsTr("In use") : qsTr("Not in use")
                            font.pixelSize: 12
                            font.italic: true
                            color: imageRowDelegate.inUse ? palette.text : "gray"
                        }
                    }

                    ColumnLayout {
                        spacing: 4

                        Button {
                            objectName: "tagImageButton_" + imageRowDelegate.imageId
                            text: qsTr("Tag")
                            enabled: !apiClient.imageActionBusy
                            onClicked: imagesPage.openTagImageDialog(imageRowDelegate.imageId)
                        }

                        Button {
                            objectName: "deleteImageButton_" + imageRowDelegate.imageId
                            text: apiClient.imageActionBusy ? qsTr("Working...") : qsTr("Delete")
                            enabled: !apiClient.imageActionBusy && !imageRowDelegate.inUse
                            onClicked: imagesPage.confirmDeleteImage(imageRowDelegate.imageId, imageRowDelegate.tags)
                        }
                    }
                }
            }
        }
    }
}
