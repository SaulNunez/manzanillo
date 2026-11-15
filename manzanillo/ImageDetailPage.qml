import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: imageDetailPage
    required property string imageId
    // Busy only while this image's own delete/tag is in flight.
    readonly property bool actionBusy: Busy.image(imageDetailPage.imageId)
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

    AppDialog {
        id: deleteImageDialog
        objectName: "imageDetailDeleteDialog"
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
        preferredWidth: 360

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

    AppDialog {
        id: tagImageDialog
        objectName: "imageDetailTagDialog"
        title: qsTr("Add tag")
        preferredWidth: 400

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
                    Accessible.description: deleteReasonLabel.visible ? deleteReasonLabel.text : ""
                    text: imageDetailPage.actionBusy ? qsTr("Working...") : qsTr("Delete")
                    palette.buttonText: Colors.danger
                    enabled: !imageDetailPage.actionBusy && !imageDetailPage.inUse
                    onClicked: deleteImageDialog.open()
                }
            }

            // Delete is disabled while the image is in use; say why in a visible
            // caption under it (disabled buttons get no hover or keyboard focus).
            Label {
                id: deleteReasonLabel
                objectName: "imageDetailDeleteReason"
                visible: imageDetailPage.inUse
                text: qsTr("In use by a container — remove the container first")
                font.pointSize: TypeScale.caption
                opacity: 0.7
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
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

                    // Label column (caption) and value column (body), so values line
                    // up and translations don't carry "Key: %1" layout.
                    GridLayout {
                        objectName: "imageDetailFields"
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 6

                        FieldLabel { text: qsTr("ID") }
                        FieldValue {
                            objectName: "imageDetailIdValue"
                            text: apiClient.imageDetail.id || ""
                            copyable: true
                            copyName: qsTr("image ID")
                        }

                        FieldLabel { text: qsTr("Status"); Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft; Layout.topMargin: 0 }
                        StatusBadge {
                            text: imageDetailPage.inUse ? qsTr("In use") : qsTr("Not in use")
                            tint: imageDetailPage.inUse ? Colors.success : Colors.neutral
                        }

                        FieldLabel { text: qsTr("Created") }
                        FieldValue {
                            objectName: "imageDetailCreatedValue"
                            text: apiClient.imageDetail.created || ""
                        }

                        FieldLabel { text: qsTr("Size") }
                        FieldValue {
                            objectName: "imageDetailSizeValue"
                            text: apiClient.imageDetail.size || ""
                        }

                        FieldLabel { text: qsTr("Architecture") }
                        FieldValue {
                            objectName: "imageDetailArchitectureValue"
                            text: apiClient.imageDetail.architecture || ""
                        }

                        FieldLabel { text: qsTr("OS") }
                        FieldValue {
                            objectName: "imageDetailOsValue"
                            text: apiClient.imageDetail.os || ""
                        }

                        FieldLabel { text: qsTr("Author"); visible: !!apiClient.imageDetail.author }
                        FieldValue {
                            objectName: "imageDetailAuthorValue"
                            text: apiClient.imageDetail.author || ""
                            visible: !!apiClient.imageDetail.author
                        }

                        FieldLabel { text: qsTr("Command"); visible: !!apiClient.imageDetail.command }
                        FieldValue {
                            objectName: "imageDetailCommandValue"
                            text: apiClient.imageDetail.command || ""
                            visible: !!apiClient.imageDetail.command
                        }

                        FieldLabel { text: qsTr("Working directory"); visible: !!apiClient.imageDetail.workingDir }
                        FieldValue {
                            objectName: "imageDetailWorkingDirValue"
                            text: apiClient.imageDetail.workingDir || ""
                            visible: !!apiClient.imageDetail.workingDir
                        }
                    }

                    SectionHeading { text: qsTr("Tags") }
                    Label {
                        visible: !apiClient.imageDetail.tags || apiClient.imageDetail.tags.length === 0
                        text: qsTr("(none)")
                        font.pointSize: TypeScale.body
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.imageDetail.tags || []
                        delegate: FieldValue { required property string modelData; text: modelData }
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
                        delegate: FieldValue { required property string modelData; required property int index; objectName: "imageDigestValue_" + index; text: modelData; copyable: true; copyName: qsTr("digest") }
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
                        delegate: FieldValue { required property string modelData; text: modelData }
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
                        delegate: FieldValue { required property string modelData; text: modelData }
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
                        delegate: FieldValue { required property string modelData; text: modelData }
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
                        delegate: FieldValue { required property string modelData; text: modelData; monospace: true }
                    }
                }
            }
        }
    }
}
