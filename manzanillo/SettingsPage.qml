import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Connections {
        target: apiClient
        function onSocketPathChanged(path) { socketField.text = path }
        function onConnectionTestSucceeded(version) {
            testResultLabel.color = "green"
            testResultLabel.text = qsTr("Connected. Docker version: %1").arg(version)
        }
        function onConnectionTestFailed(message) {
            testResultLabel.color = "red"
            testResultLabel.text = qsTr("Connection failed: %1").arg(message)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label {
            text: qsTr("Settings")
            font.pixelSize: 20
        }

        Label {
            text: qsTr("Docker socket path")
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            TextField {
                id: socketField
                objectName: "socketField"
                Layout.fillWidth: true
                text: apiClient.socketPath
                placeholderText: qsTr("/var/run/docker.sock")
            }

            Button {
                objectName: "saveSocketPathButton"
                text: qsTr("Save")
                enabled: socketField.text.length > 0
                onClicked: apiClient.setSocketPath(socketField.text)
            }

            Button {
                objectName: "testConnectionButton"
                text: apiClient.connectionTestBusy ? qsTr("Testing...") : qsTr("Test Connection")
                enabled: !apiClient.connectionTestBusy
                onClicked: apiClient.testConnection()
            }
        }

        Label {
            id: testResultLabel
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }
    }
}
