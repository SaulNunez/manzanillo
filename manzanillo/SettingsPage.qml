import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Item {
    // True between clicking Save and the client confirming the new path.
    property bool savePending: false
    // Whether the last connection test failed; drives the result label's colour
    // as a binding so it follows a live light/dark switch.
    property bool connectionTestFailed: false

    Connections {
        target: apiClient
        function onSocketPathChanged(path) {
            socketField.text = path
            if (savePending) {
                savePending = false
                saveStatusLabel.text = qsTr("✓ Saved. Using the new socket path.")
            }
        }
        function onConnectionTestSucceeded(version) {
            connectionTestFailed = false
            testResultLabel.text = qsTr("Connected. Docker version: %1").arg(version)
        }
        function onConnectionTestFailed(message) {
            connectionTestFailed = true
            testResultLabel.text = qsTr("Connection failed: %1").arg(message)
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: socketField
                    objectName: "socketField"
                    Layout.fillWidth: true
                    text: apiClient.socketPath
                    placeholderText: qsTr("/var/run/docker.sock")
                    onTextChanged: if (text !== apiClient.socketPath) saveStatusLabel.text = ""
                }

                Button {
                    objectName: "saveSocketPathButton"
                    icon.name: "document-save"
                    text: qsTr("Save")
                    enabled: socketField.text.length > 0 && socketField.text !== apiClient.socketPath
                    onClicked: {
                        savePending = true
                        apiClient.setSocketPath(socketField.text)
                    }
                }

                Button {
                    objectName: "testConnectionButton"
                    icon.name: "network-connect"
                    text: apiClient.connectionTestBusy ? qsTr("Testing...") : qsTr("Test Connection")
                    enabled: !apiClient.connectionTestBusy
                    onClicked: apiClient.testConnection()
                }
            }

            Label {
                id: saveStatusLabel
                objectName: "saveStatusLabel"
                color: Colors.success
                visible: text.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                id: testResultLabel
                objectName: "testResultLabel"
                color: connectionTestFailed ? Colors.danger : Colors.success
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: qsTr("Accessibility")
                font.bold: true
                Layout.topMargin: 12
            }

            Switch {
                id: reduceMotionSwitch
                objectName: "reduceMotionSwitch"
                text: qsTr("Reduce motion")
                checked: apiClient.reduceMotion
                onToggled: apiClient.setReduceMotion(checked)
            }

            Label {
                text: qsTr("Switch pages instantly instead of sliding them in and out.")
                font.pixelSize: TypeScale.caption
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }
        }
    }
}
