import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Component.onCompleted: apiClient.fetchImages()

    Connections {
        target: apiClient
        function onImagesErrorOccurred(message) {
            errorLabel.text = message
            errorLabel.visible = true
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: apiClient.imagesModel

            delegate: Frame {
                width: imagesList.width

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2

                    Label {
                        text: tags
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: qsTr("Size: %1    Created: %2").arg(size).arg(created)
                        font.pixelSize: 12
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
