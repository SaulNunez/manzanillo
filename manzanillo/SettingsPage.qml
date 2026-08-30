import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Connections {
        target: apiClient
        function onSocketPathChanged(path) { socketField.text = path }
        function onConnectionTestSucceeded(version) {
            testResultLabel.color = Colors.success
            testResultLabel.text = qsTr("Connected. Docker version: %1").arg(version)
        }
        function onConnectionTestFailed(message) {
            testResultLabel.color = Colors.error
            testResultLabel.text = qsTr("Connection failed: %1").arg(message)
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
                    text: "☰"
                    visible: Window.window ? Window.window.narrow : false
                    Accessible.name: (Window.window && Window.window.drawerOpen)
                        ? qsTr("Close navigation") : qsTr("Open navigation")
                    ToolTip.visible: hovered
                    ToolTip.text: Accessible.name
                    onClicked: Window.window.toggleDrawer()
                }

                Label {
                    text: qsTr("Settings")
                    font.pixelSize: TypeScale.title
                    Layout.fillWidth: true
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
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 8

            Label {
                text: qsTr("Docker socket path")
                font.bold: true
            }

            TextField {
                id: socketField
                objectName: "socketField"
                Layout.fillWidth: true
                text: apiClient.socketPath
                placeholderText: qsTr("/var/run/docker.sock")
            }

            Label {
                id: testResultLabel
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }
        }
    }
}
