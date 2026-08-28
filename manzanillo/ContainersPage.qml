import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Component.onCompleted: apiClient.fetchContainers()

    Connections {
        target: apiClient
        function onContainersErrorOccurred(message) {
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
                text: qsTr("Containers")
                font.pixelSize: 20
                Layout.fillWidth: true
            }

            Button {
                text: apiClient.containersBusy ? qsTr("Loading...") : qsTr("Refresh")
                enabled: !apiClient.containersBusy
                onClicked: apiClient.fetchContainers()
            }
        }

        Label {
            id: errorLabel
            visible: false
            color: "red"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        TabBar {
            id: tabBar
            objectName: "containersTabBar"
            Layout.fillWidth: true

            TabButton { objectName: "allContainersTab"; text: qsTr("All Containers") }
            TabButton { objectName: "composeTab"; text: qsTr("Compose") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            ListView {
                id: containersList
                clip: true
                spacing: 4
                model: apiClient.containersModel

                delegate: Frame {
                    width: containersList.width

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 2

                        Label {
                            text: names
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Label {
                            text: qsTr("Image: %1").arg(image)
                            font.pixelSize: 12
                            opacity: 0.7
                        }

                        Label {
                            text: qsTr("Status: %1").arg(status)
                            font.pixelSize: 12
                            opacity: 0.7
                        }
                    }
                }
            }

            ScrollView {
                id: composeScrollView
                clip: true

                ColumnLayout {
                    width: composeScrollView.availableWidth
                    spacing: 4

                    Label {
                        visible: apiClient.composeProjects.length === 0 && !apiClient.containersBusy
                        text: qsTr("No Compose projects found")
                        opacity: 0.7
                    }

                    Repeater {
                        model: apiClient.composeProjects

                        delegate: ColumnLayout {
                            id: projectDelegate
                            required property var modelData
                            required property int index
                            property bool expanded: false

                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                ToolButton {
                                    objectName: "projectToggle_" + projectDelegate.index
                                    text: projectDelegate.expanded ? "▼" : "▶"
                                    onClicked: projectDelegate.expanded = !projectDelegate.expanded
                                }

                                Label {
                                    text: projectDelegate.modelData.project
                                    font.bold: true
                                    font.pixelSize: 16
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                visible: projectDelegate.expanded
                                Layout.leftMargin: 24
                                Layout.fillWidth: true
                                spacing: 2

                                Repeater {
                                    model: projectDelegate.modelData.services

                                    delegate: ColumnLayout {
                                        id: serviceDelegate
                                        required property var modelData
                                        required property int index
                                        property bool expanded: false

                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true

                                            ToolButton {
                                                objectName: "serviceToggle_" + serviceDelegate.index
                                                text: serviceDelegate.expanded ? "▼" : "▶"
                                                onClicked: serviceDelegate.expanded = !serviceDelegate.expanded
                                            }

                                            Label {
                                                text: serviceDelegate.modelData.service
                                                Layout.fillWidth: true
                                            }
                                        }

                                        ColumnLayout {
                                            visible: serviceDelegate.expanded
                                            Layout.leftMargin: 24
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Repeater {
                                                model: serviceDelegate.modelData.containers

                                                delegate: Frame {
                                                    id: containerDelegate
                                                    required property var modelData
                                                    Layout.fillWidth: true

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        spacing: 2

                                                        Label {
                                                            text: containerDelegate.modelData.name
                                                            font.bold: true
                                                        }

                                                        Label {
                                                            text: qsTr("Image: %1").arg(containerDelegate.modelData.image)
                                                            font.pixelSize: 12
                                                            opacity: 0.7
                                                        }

                                                        Label {
                                                            text: qsTr("Status: %1").arg(containerDelegate.modelData.status)
                                                            font.pixelSize: 12
                                                            opacity: 0.7
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
        }
    }
}
