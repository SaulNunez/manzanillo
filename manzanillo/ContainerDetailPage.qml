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
        spacing: 0

        ToolBar {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: 8

                ToolButton {
                    objectName: "containerDetailBackButton"
                    text: qsTr("< Back")
                    onClicked: containerDetailPage.StackView.view.pop()
                }

                Label {
                    text: apiClient.containerDetail.name || qsTr("Container")
                    font.pixelSize: TypeScale.title
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

            RowLayout {
                visible: apiClient.containerDetailBusy
                spacing: 8

                BusyIndicator {
                    implicitWidth: 20
                    implicitHeight: 20
                    running: apiClient.containerDetailBusy
                }

                Label {
                    text: qsTr("Loading...")
                    font.pixelSize: TypeScale.body
                }
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

                        Label { text: qsTr("Id: %1").arg(apiClient.containerDetail.id); font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                        Label { text: qsTr("Image: %1").arg(apiClient.containerDetail.image); font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }

                        RowLayout {
                            spacing: 8

                            Label { text: qsTr("State:"); font.pixelSize: TypeScale.body }
                            StatusBadge {
                                text: apiClient.containerDetail.state || ""
                                tint: apiClient.containerDetail.state === "running" ? Colors.success : Colors.disabled
                            }
                        }

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

                        Label { text: qsTr("Started: %1").arg(apiClient.containerDetail.startedAt); font.pixelSize: TypeScale.body; visible: !!apiClient.containerDetail.startedAt }
                        Label { text: qsTr("Created: %1").arg(apiClient.containerDetail.created); font.pixelSize: TypeScale.body }
                        Label { text: qsTr("Command: %1").arg(apiClient.containerDetail.command); font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; visible: !!apiClient.containerDetail.command }
                        Label { text: qsTr("Working Dir: %1").arg(apiClient.containerDetail.workingDir); font.pixelSize: TypeScale.body; visible: !!apiClient.containerDetail.workingDir }
                        Label { text: qsTr("Restart Policy: %1").arg(apiClient.containerDetail.restartPolicy); font.pixelSize: TypeScale.body; visible: !!apiClient.containerDetail.restartPolicy }

                        SectionHeading { text: qsTr("Ports") }
                        Label {
                            visible: !apiClient.containerDetail.ports || apiClient.containerDetail.ports.length === 0
                            text: qsTr("(none)")
                            font.pixelSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.ports || []
                            delegate: Label { required property string modelData; text: modelData; font.pixelSize: TypeScale.body }
                        }

                        SectionHeading { text: qsTr("Networks") }
                        Label {
                            visible: !apiClient.containerDetail.networks || apiClient.containerDetail.networks.length === 0
                            text: qsTr("(none)")
                            font.pixelSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.networks || []
                            delegate: Label { required property string modelData; text: modelData; font.pixelSize: TypeScale.body }
                        }

                        SectionHeading { text: qsTr("Mounts") }
                        Label {
                            visible: !apiClient.containerDetail.mounts || apiClient.containerDetail.mounts.length === 0
                            text: qsTr("(none)")
                            font.pixelSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.mounts || []
                            delegate: Label { required property string modelData; text: modelData; font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                        }

                        SectionHeading { text: qsTr("Environment") }
                        Label {
                            visible: !apiClient.containerDetail.env || apiClient.containerDetail.env.length === 0
                            text: qsTr("(none)")
                            font.pixelSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.env || []
                            delegate: Label { required property string modelData; text: modelData; font.pixelSize: TypeScale.body; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                        }
                    }
                }

                ColumnLayout {
                    spacing: 4

                    Label {
                        text: apiClient.containerLogsStreaming ? qsTr("Following logs…") : qsTr("Not following")
                        font.pixelSize: TypeScale.caption
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
                            font.pixelSize: TypeScale.monospace
                            onTextChanged: cursorPosition = length
                        }
                    }
                }
            }
        }
    }
}
