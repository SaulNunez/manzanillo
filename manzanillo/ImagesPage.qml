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
                palette.buttonText: Colors.danger
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

    PageStack {
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
                            objectName: "pullImageToolButton"
                            icon.name: "download"
                            text: qsTr("Pull Image")
                            enabled: !apiClient.imageActionBusy
                            onClicked: imagesPage.openPullImageDialog()
                        }

                        ToolButton {
                            objectName: "buildImageToolButton"
                            icon.name: "run-build"
                            text: qsTr("Build Image")
                            enabled: !apiClient.imageActionBusy
                            onClicked: imagesPage.openBuildImageDialog()
                        }

                        ToolButton {
                            objectName: "refreshImagesButton"
                            icon.name: "view-refresh"
                            text: qsTr("Refresh")
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

                    ErrorBanner {
                        id: errorLabel
                        objectName: "imagesErrorBanner"
                        busy: apiClient.imagesBusy || apiClient.imageActionBusy || apiClient.busyImageIds.length > 0
                    }

                    Connections {
                        target: apiClient
                        function onImagesErrorOccurred(message) {
                            errorLabel.show(message)
                        }
                        function onImageActionErrorOccurred(message) {
                            errorLabel.show(message)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Label {
                            objectName: "imagesEmptyLabel"
                            anchors.centerIn: parent
                            visible: imagesList.count === 0 && !apiClient.imagesBusy
                            text: qsTr("No images found")
                            font.pixelSize: TypeScale.body
                            opacity: 0.7
                        }

                        BusyIndicator {
                            objectName: "imagesBusyIndicator"
                            anchors.centerIn: parent
                            visible: imagesList.count === 0 && apiClient.imagesBusy
                            running: visible
                            Accessible.name: qsTr("Loading images")
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
                        // (built into ListView), Enter/Return/Space opens its detail page and
                        // the Menu key opens its ⋯ actions menu.
                        Keys.onPressed: (event) => {
                            if (currentItem && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                                imagesPage.openImageDetail(currentItem.imageId, currentItem.tags, currentItem.inUse)
                                event.accepted = true
                            } else if (currentItem && event.key === Qt.Key_Menu) {
                                currentItem.openActions()
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
                            readonly property bool busy: apiClient.busyImageIds.indexOf(imageRowDelegate.imageId) >= 0
                            objectName: "imageRow_" + imageRowDelegate.imageId
                            width: imagesList.width
                            title: imageRowDelegate.tags
                            statusText: imageRowDelegate.inUse ? qsTr("In use") : qsTr("Not in use")
                            statusTint: imageRowDelegate.inUse ? Colors.success : Colors.neutral
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

                            // Secondary actions live in a ⋯ menu so opening the image stays
                            // the row's primary action.
                            function openActions() {
                                imageActionsMenu.popup(imageActionsButton, 0, imageActionsButton.height)
                            }

                            // "Working..." on Delete is hidden in the closed menu, so show
                            // this image's busy state on the row itself.
                            BusyIndicator {
                                objectName: "imageBusyIndicator_" + imageRowDelegate.imageId
                                visible: imageRowDelegate.busy
                                running: visible
                                implicitWidth: 24
                                implicitHeight: 24
                                Accessible.name: qsTr("Working...")
                            }

                            ToolButton {
                                id: imageActionsButton
                                objectName: "imageActionsButton_" + imageRowDelegate.imageId
                                text: "⋯"
                                focusPolicy: Qt.StrongFocus
                                Accessible.name: qsTr("Actions for %1").arg(imageRowDelegate.tags)
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("More actions")
                                onClicked: imageRowDelegate.openActions()

                                Menu {
                                    id: imageActionsMenu
                                    objectName: "imageActionsMenu_" + imageRowDelegate.imageId

                                    MenuItem {
                                        objectName: "tagImageButton_" + imageRowDelegate.imageId
                                        text: qsTr("Tag")
                                        enabled: !imageRowDelegate.busy
                                        onTriggered: imagesPage.openTagImageDialog(imageRowDelegate.imageId)
                                    }

                                    MenuItem {
                                        objectName: "deleteImageButton_" + imageRowDelegate.imageId
                                        Accessible.description: imageRowDelegate.deleteDisabledReason
                                        text: imageRowDelegate.busy ? qsTr("Working...") : qsTr("Delete")
                                        enabled: !imageRowDelegate.busy && !imageRowDelegate.inUse
                                        onTriggered: imagesPage.confirmDeleteImage(imageRowDelegate.imageId, imageRowDelegate.tags)
                                    }

                                    // Disabled menu items get no hover or focus, so say why
                                    // Delete is unavailable right under it.
                                    // (Wrapped in an Item so it takes no space when hidden.)
                                    Item {
                                        visible: imageRowDelegate.deleteDisabledReason.length > 0
                                        implicitWidth: deleteReasonLabel.implicitWidth
                                        implicitHeight: visible ? deleteReasonLabel.implicitHeight : 0

                                        Label {
                                            id: deleteReasonLabel
                                            objectName: "imageDeleteReason_" + imageRowDelegate.imageId
                                            width: parent.width
                                            text: imageRowDelegate.deleteDisabledReason
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: TypeScale.caption
                                            opacity: 0.7
                                            leftPadding: 12
                                            rightPadding: 12
                                            bottomPadding: 4
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
    }
}
