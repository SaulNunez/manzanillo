import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: containerDetailPage
    required property string containerId

    Component.onCompleted: apiClient.fetchContainerDetail(containerDetailPage.containerId)
    // Belt-and-suspenders alongside the tab-switch handler below - guarantees the
    // log stream stops however this page goes away (Back button, or otherwise).
    Component.onDestruction: apiClient.stopContainerLogs()

    Connections {
        target: apiClient
        function onContainerDetailErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
        function onContainerActionErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
        function onContainerLogsErrorOccurred(message) {
            detailErrorLabel.show(message)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                objectName: "containerDetailBackButton"
                text: qsTr("< Back")
                onClicked: containerDetailPage.StackView.view.pop()
            }

            Label {
                text: apiClient.containerDetail.name || qsTr("Container")
                font.pixelSize: 20
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Label {
            visible: apiClient.containerDetailBusy
            text: qsTr("Loading...")
        }

        DetailErrorLabel {
            id: detailErrorLabel
        }

        TabBar {
            id: detailTabBar
            objectName: "containerDetailTabBar"
            Layout.fillWidth: true

            TabButton { objectName: "detailsTab"; text: qsTr("Details") }
            TabButton { objectName: "logsTab"; text: qsTr("Logs") }

            onCurrentIndexChanged: {
                if (currentIndex === 1) {
                    apiClient.startContainerLogs(containerDetailPage.containerId)
                } else {
                    apiClient.stopContainerLogs()
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: detailTabBar.currentIndex

            ScrollView {
                id: detailScrollView
                visible: !apiClient.containerDetailBusy
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: detailScrollView.availableWidth
                    spacing: 4

                    Label { text: qsTr("Id: %1").arg(apiClient.containerDetail.id); wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    Label { text: qsTr("Image: %1").arg(apiClient.containerDetail.image); wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    Label { text: qsTr("State: %1").arg(apiClient.containerDetail.state) }

                    RowLayout {
                        spacing: 8
                        Layout.topMargin: 4

                        Button {
                            objectName: "startContainerButton"
                            text: apiClient.containerActionBusy ? qsTr("Working...") : qsTr("Start")
                            visible: apiClient.containerDetail.state !== "running"
                            enabled: !apiClient.containerActionBusy && !apiClient.containerDetailBusy
                            onClicked: apiClient.startContainer(apiClient.containerDetail.id)
                        }

                        Button {
                            objectName: "stopContainerButton"
                            text: apiClient.containerActionBusy ? qsTr("Working...") : qsTr("Stop")
                            visible: apiClient.containerDetail.state === "running"
                            enabled: !apiClient.containerActionBusy && !apiClient.containerDetailBusy
                            onClicked: apiClient.stopContainer(apiClient.containerDetail.id)
                        }
                    }

                    Label { text: qsTr("Started: %1").arg(apiClient.containerDetail.startedAt); visible: !!apiClient.containerDetail.startedAt }
                    Label { text: qsTr("Created: %1").arg(apiClient.containerDetail.created) }
                    Label { text: qsTr("Command: %1").arg(apiClient.containerDetail.command); wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; visible: !!apiClient.containerDetail.command }
                    Label { text: qsTr("Working Dir: %1").arg(apiClient.containerDetail.workingDir); visible: !!apiClient.containerDetail.workingDir }
                    Label { text: qsTr("Restart Policy: %1").arg(apiClient.containerDetail.restartPolicy); visible: !!apiClient.containerDetail.restartPolicy }

                    Label { text: qsTr("Ports"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.containerDetail.ports || apiClient.containerDetail.ports.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.containerDetail.ports || []
                        delegate: Label { required property string modelData; text: modelData }
                    }

                    Label { text: qsTr("Networks"); font.bold: true; Layout.topMargin: 8 }
                    Repeater {
                        model: apiClient.containerDetail.networks || []
                        delegate: Label { required property string modelData; text: modelData }
                    }

                    Label { text: qsTr("Mounts"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.containerDetail.mounts || apiClient.containerDetail.mounts.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.containerDetail.mounts || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    Label { text: qsTr("Environment"); font.bold: true; Layout.topMargin: 8 }
                    Label {
                        visible: !apiClient.containerDetail.env || apiClient.containerDetail.env.length === 0
                        text: qsTr("(none)")
                        opacity: 0.7
                    }
                    Repeater {
                        model: apiClient.containerDetail.env || []
                        delegate: Label { required property string modelData; text: modelData; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }
                }
            }

            ColumnLayout {
                spacing: 4

                Label {
                    text: apiClient.containerLogsStreaming ? qsTr("Following logs…") : qsTr("Not following")
                    opacity: 0.7
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: containerLogsArea
                        objectName: "containerLogsArea"
                        readOnly: true
                        wrapMode: TextArea.NoWrap
                        text: apiClient.containerLogs
                        font.family: "monospace"
                        font.pixelSize: 11
                        onTextChanged: cursorPosition = length
                    }
                }
            }
        }
    }
}
