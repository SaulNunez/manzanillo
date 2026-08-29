import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: containersPage

    Component.onCompleted: apiClient.fetchContainers()

    function openContainerDetail(id) {
        detailErrorLabel.visible = false
        apiClient.fetchContainerDetail(id)
        containerDetailDialog.open()
    }

    // Compose project/service expand state is kept here, keyed by name, instead of as
    // local delegate state - the Compose tree's Repeaters get rebuilt from scratch on
    // every containers refresh (e.g. after a quick start/stop action), which would
    // otherwise reset every delegate's local "expanded" property back to false.
    property var expandedProjects: ({})
    property var expandedServices: ({})

    function toggleProjectExpanded(project) {
        const updated = Object.assign({}, expandedProjects)
        updated[project] = !updated[project]
        expandedProjects = updated
    }

    function toggleServiceExpanded(project, service) {
        const key = project + "/" + service
        const updated = Object.assign({}, expandedServices)
        updated[key] = !updated[key]
        expandedServices = updated
    }

    Connections {
        target: apiClient
        function onContainersErrorOccurred(message) {
            errorLabel.text = message
            errorLabel.visible = true
        }
        function onContainerDetailErrorOccurred(message) {
            detailErrorLabel.text = message
            detailErrorLabel.visible = true
        }
        function onContainerActionErrorOccurred(message) {
            detailErrorLabel.text = message
            detailErrorLabel.visible = true
            errorLabel.text = message
            errorLabel.visible = true
        }
    }

    Dialog {
        id: containerDetailDialog
        objectName: "containerDetailDialog"
        modal: true
        standardButtons: Dialog.Close
        width: 600
        anchors.centerIn: Overlay.overlay
        title: apiClient.containerDetail.name || qsTr("Container")

        contentItem: ScrollView {
            implicitWidth: 560
            implicitHeight: 400
            clip: true

            ColumnLayout {
                width: 560
                spacing: 4

                Label {
                    visible: apiClient.containerDetailBusy
                    text: qsTr("Loading...")
                }

                Label {
                    id: detailErrorLabel
                    visible: false
                    color: "red"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    visible: !apiClient.containerDetailBusy
                    Layout.fillWidth: true
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
                objectName: "containersListView"
                clip: true
                spacing: 4
                model: apiClient.containersModel

                delegate: Frame {
                    id: containerRowDelegate
                    required property string containerId
                    required property string names
                    required property string image
                    required property string status
                    required property string state
                    width: containersList.width

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: containerRowDelegate.names
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: qsTr("Image: %1").arg(containerRowDelegate.image)
                                font.pixelSize: 12
                                opacity: 0.7
                            }

                            Label {
                                text: qsTr("Status: %1").arg(containerRowDelegate.status)
                                font.pixelSize: 12
                                opacity: 0.7
                            }
                        }

                        Button {
                            objectName: "quickActionButton_" + containerRowDelegate.containerId
                            text: apiClient.containerActionBusy
                                ? qsTr("Working...")
                                : (containerRowDelegate.state === "running" ? qsTr("Stop") : qsTr("Start"))
                            enabled: !apiClient.containerActionBusy
                            onClicked: containerRowDelegate.state === "running"
                                ? apiClient.stopContainer(containerRowDelegate.containerId)
                                : apiClient.startContainer(containerRowDelegate.containerId)
                        }
                    }

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: containersPage.openContainerDetail(containerRowDelegate.containerId)
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
                            readonly property bool expanded: containersPage.expandedProjects[projectDelegate.modelData.project] === true

                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                ToolButton {
                                    objectName: "projectToggle_" + projectDelegate.index
                                    text: projectDelegate.expanded ? "▼" : "▶"
                                    onClicked: containersPage.toggleProjectExpanded(projectDelegate.modelData.project)
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
                                        readonly property bool expanded: containersPage.expandedServices[projectDelegate.modelData.project + "/" + serviceDelegate.modelData.service] === true

                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true

                                            ToolButton {
                                                objectName: "serviceToggle_" + serviceDelegate.index
                                                text: serviceDelegate.expanded ? "▼" : "▶"
                                                onClicked: containersPage.toggleServiceExpanded(projectDelegate.modelData.project, serviceDelegate.modelData.service)
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

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        spacing: 8

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
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

                                                        Button {
                                                            objectName: "quickActionButton_" + containerDelegate.modelData.id
                                                            text: apiClient.containerActionBusy
                                                                ? qsTr("Working...")
                                                                : (containerDelegate.modelData.state === "running" ? qsTr("Stop") : qsTr("Start"))
                                                            enabled: !apiClient.containerActionBusy
                                                            onClicked: containerDelegate.modelData.state === "running"
                                                                ? apiClient.stopContainer(containerDelegate.modelData.id)
                                                                : apiClient.startContainer(containerDelegate.modelData.id)
                                                        }
                                                    }

                                                    TapHandler {
                                                        cursorShape: Qt.PointingHandCursor
                                                        onTapped: containersPage.openContainerDetail(containerDelegate.modelData.id)
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
