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
