import QtQuick
import QtQuick.Window
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

    function openImageDetail(id, tags, inUse) {
        imageStack.push("ImageDetailPage.qml", { imageId: id, tags: tags, inUse: inUse })
    }


    Dialog {
        id: deleteImageDialog
        objectName: "deleteImageDialog"
        property string imageId: ""
        property string imageTags: ""

        modal: true
        title: qsTr("Delete image")
        footer: DialogButtonBox {
            Button {
                objectName: "deleteImageDialogConfirmButton"
                text: qsTr("Delete")
                palette.buttonText: Colors.error
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "deleteImageDialogCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }
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
        width: 400
        anchors.centerIn: Overlay.overlay

        readonly property bool inputValid: pullReferenceField.text.trim().length > 0

        footer: DialogButtonBox {
            Button {
                objectName: "pullImageOkButton"
                text: qsTr("OK")
                enabled: pullImageDialog.inputValid
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "pullImageCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            if (pullImageDialog.inputValid)
                apiClient.pullImage(pullReferenceField.text.trim())
        }

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
                focus: true
                placeholderText: qsTr("e.g. redis:8.6.2")
                onAccepted: if (pullImageDialog.inputValid) pullImageDialog.accept()
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
                    font.pixelSize: TypeScale.monospace
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
        width: 400
        anchors.centerIn: Overlay.overlay

        readonly property bool inputValid: tagRepositoryField.text.trim().length > 0

        footer: DialogButtonBox {
            Button {
                objectName: "tagImageOkButton"
                text: qsTr("OK")
                enabled: tagImageDialog.inputValid
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                objectName: "tagImageCancelButton"
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            if (tagImageDialog.inputValid)
                apiClient.tagImage(tagImageDialog.imageId, tagRepositoryField.text.trim(), tagTagField.text.trim())
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
                objectName: "tagRepositoryField"
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
                objectName: "tagTagField"
                Layout.fillWidth: true
                onAccepted: if (tagImageDialog.inputValid) tagImageDialog.accept()
                placeholderText: qsTr("latest")
            }
        }
    }

    StackView {
        id: imageStack
        objectName: "imageStack"
        anchors.fill: parent
        clip: true
        initialItem: imageListComponent
    }

    Component {
        id: imageListComponent

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
                            text: qsTr("Images")
                            font.pixelSize: TypeScale.title
                            Layout.fillWidth: true
                        }

                        ToolButton {
                            icon.name: "download"
                            text: apiClient.imageActionBusy ? qsTr("Working...") : qsTr("Pull Image")
                            enabled: !apiClient.imageActionBusy
                            onClicked: imagesPage.openPullImageDialog()
                        }

                        ToolButton {
                            icon.name: "run-build"
                            text: apiClient.imageActionBusy ? qsTr("Working...") : qsTr("Build Image")
                            enabled: !apiClient.imageActionBusy
                            onClicked: imagesPage.openBuildImageDialog()
                        }

                        ToolButton {
                            icon.name: "view-refresh"
                            text: apiClient.imagesBusy ? qsTr("Loading...") : qsTr("Refresh")
                            enabled: !apiClient.imagesBusy
                            onClicked: apiClient.fetchImages()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 12
                    spacing: 8

                    Label {
                        id: errorLabel
                        visible: false
                        color: Colors.error
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
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

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Label {
                            anchors.centerIn: parent
                            visible: imagesList.count === 0 && !apiClient.imagesBusy
                            text: qsTr("No images found")
                            font.pixelSize: TypeScale.body
                            opacity: 0.7
                        }

                        ListView {
                            id: imagesList
                            anchors.fill: parent
                            objectName: "imagesListView"
                            clip: true
                        spacing: 4
                        model: apiClient.imagesModel
                        activeFocusOnTab: true
                        Accessible.role: Accessible.List
                        Accessible.name: qsTr("Images")

                        // Keyboard equivalent of tapping a row: arrow keys move currentIndex
                        // (built into ListView), Enter/Return/Space opens its detail page.
                        Keys.onPressed: (event) => {
                            if (currentItem && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                                imagesPage.openImageDetail(currentItem.imageId, currentItem.tags, currentItem.inUse)
                                event.accepted = true
                            }
                        }

                        delegate: RowCard {
                            id: imageRowDelegate
                            required property int index
                            required property string imageId
                            required property string tags
                            required property string size
                            required property string created
                            required property bool inUse
                            objectName: "imageRow_" + imageRowDelegate.imageId
                            width: imagesList.width
                            title: imageRowDelegate.tags
                            statusText: imageRowDelegate.inUse ? qsTr("In use") : qsTr("Not in use")
                            statusTint: imageRowDelegate.inUse ? Colors.success : Colors.disabled
                            // Delete is disabled while the image is in use; say why in a
                            // visible caption (disabled buttons get no hover or focus).
                            readonly property string deleteDisabledReason: imageRowDelegate.inUse
                                ? qsTr("In use by a container — remove the container first") : ""
                            details: [qsTr("Size: %1    Created: %2").arg(imageRowDelegate.size).arg(imageRowDelegate.created)]
                                .concat(imageRowDelegate.deleteDisabledReason.length > 0 ? [imageRowDelegate.deleteDisabledReason] : [])
                            showFocusRing: imageRowDelegate.ListView.isCurrentItem && imagesList.activeFocus
                            onActivated: {
                                imagesList.currentIndex = imageRowDelegate.index
                                imagesPage.openImageDetail(imageRowDelegate.imageId, imageRowDelegate.tags, imageRowDelegate.inUse)
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
                                    Accessible.description: imageRowDelegate.deleteDisabledReason
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
        }
    }
}
