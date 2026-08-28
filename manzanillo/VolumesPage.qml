import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Component.onCompleted: apiClient.fetchVolumes()

    Connections {
        target: apiClient
        function onVolumesErrorOccurred(message) {
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
                text: qsTr("Volumes")
                font.pixelSize: 20
                Layout.fillWidth: true
            }

            Button {
                text: apiClient.volumesBusy ? qsTr("Loading...") : qsTr("Refresh")
                enabled: !apiClient.volumesBusy
                onClicked: apiClient.fetchVolumes()
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
            visible: volumesList.count === 0 && !apiClient.volumesBusy
            text: qsTr("No volumes found")
            opacity: 0.7
        }

        ListView {
            id: volumesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: apiClient.volumesModel

            delegate: Frame {
                width: volumesList.width

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2

                    Label {
                        text: name
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: qsTr("Driver: %1    Created: %2").arg(driver).arg(created)
                        font.pixelSize: 12
                        opacity: 0.7
                    }

                    Label {
                        text: mountpoint
                        font.pixelSize: 12
                        opacity: 0.7
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
