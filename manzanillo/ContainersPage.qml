import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: containersPage

    Component.onCompleted: apiClient.fetchContainers()

    function openContainerDetail(id) {
        containerStack.push("ContainerDetailPage.qml", { containerId: id })
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

    property string searchText: ""

    // Compose containers are grouped by project/service rather than being a flat
    // list, so filtering them by name/image needs to happen here in QML instead of
    // through the ContainerFilterProxyModel used for the "All Containers" list -
    // matching containers are kept and any project/service left with none is
    // dropped entirely so an empty group doesn't show up as a bare header.
    property var filteredComposeProjects: {
        const text = searchText.trim().toLowerCase()
        if (!text) {
            return apiClient.composeProjects
        }

        const matches = (container) =>
            container.name.toLowerCase().includes(text) || container.image.toLowerCase().includes(text)

        const projects = []
        for (const project of apiClient.composeProjects) {
            const services = []
            for (const service of project.services) {
                const containers = service.containers.filter(matches)
                if (containers.length > 0) {
                    services.push(Object.assign({}, service, { containers: containers }))
                }
            }
            if (services.length > 0) {
                projects.push(Object.assign({}, project, { services: services }))
            }
        }
        return projects
    }

    StackView {
        id: containerStack
        objectName: "containerStack"
        anchors.fill: parent
        clip: true
        initialItem: containerListComponent
    }

    Component {
        id: containerListComponent

        Item {
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
                            text: qsTr("Containers")
                            font.pixelSize: TypeScale.title
                            Layout.fillWidth: true
                        }

                        Button {
                            text: apiClient.containersBusy ? qsTr("Loading...") : qsTr("Refresh")
                            enabled: !apiClient.containersBusy
                            onClicked: apiClient.fetchContainers()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 12
                    spacing: 8

                    Label {
                        id: errorLabel
                        visible: false
                        color: Colors.error
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Connections {
                        target: apiClient
                        function onContainersErrorOccurred(message) {
                            errorLabel.text = message
                            errorLabel.visible = true
                        }
                        function onContainerActionErrorOccurred(message) {
                            errorLabel.text = message
                            errorLabel.visible = true
                        }
                    }

                    Label {
                        text: qsTr("Search")
                        font.pixelSize: TypeScale.caption
                    }

                    TextField {
                        id: searchField
                        objectName: "containerSearchField"
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search containers by name or image…")
                        Accessible.name: qsTr("Search containers by name or image")
                        onTextChanged: {
                            apiClient.filteredContainersModel.setFilterText(text)
                            containersPage.searchText = text
                        }
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

                        ColumnLayout {
                            spacing: 4

                            Label {
                                visible: containersList.count === 0 && !apiClient.containersBusy
                                text: searchField.text.length > 0
                                    ? qsTr("No containers match \"%1\"").arg(searchField.text)
                                    : qsTr("No containers found")
                                opacity: 0.7
                            }

                            ListView {
                                id: containersList
                                objectName: "containersListView"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                model: apiClient.filteredContainersModel
                                activeFocusOnTab: true

                                // Keyboard equivalent of tapping a row: arrow keys move currentIndex
                                // (built into ListView), Enter/Return/Space opens its detail page.
                                Keys.onPressed: (event) => {
                                    if (currentItem && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                                        containersPage.openContainerDetail(currentItem.containerId)
                                        event.accepted = true
                                    }
                                }

                                delegate: Frame {
                                    id: containerRowDelegate
                                    required property string containerId
                                    required property string names
                                    required property string image
                                    required property string status
                                    required property string state
                                    width: containersList.width
                                    // Frame only derives its implicit size automatically from a single
                                    // content child; the focus-ring Rectangle below makes that two, so
                                    // size it explicitly off the RowLayout instead.
                                    implicitHeight: contentRow.implicitHeight + topPadding + bottomPadding

                                    RowLayout {
                                        id: contentRow
                                        anchors.fill: parent
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Label {
                                                text: containerRowDelegate.names
                                                font.bold: true
                                                font.pixelSize: TypeScale.body
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: qsTr("Image: %1").arg(containerRowDelegate.image)
                                                font.pixelSize: TypeScale.caption
                                                opacity: 0.7
                                            }

                                            Label {
                                                text: qsTr("Status: %1").arg(containerRowDelegate.status)
                                                font.pixelSize: TypeScale.caption
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

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: palette.highlight
                                        border.width: 2
                                        visible: containerRowDelegate.ListView.isCurrentItem && containersList.activeFocus
                                    }

                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: {
                                            containersList.currentIndex = index
                                            containersPage.openContainerDetail(containerRowDelegate.containerId)
                                        }
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
                                    visible: containersPage.filteredComposeProjects.length === 0 && !apiClient.containersBusy
                                    text: searchField.text.length > 0
                                        ? qsTr("No Compose containers match \"%1\"").arg(searchField.text)
                                        : qsTr("No Compose projects found")
                                    opacity: 0.7
                                }

                                Repeater {
                                    model: containersPage.filteredComposeProjects

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
                                                Accessible.name: projectDelegate.expanded
                                                    ? qsTr("Collapse %1").arg(projectDelegate.modelData.project)
                                                    : qsTr("Expand %1").arg(projectDelegate.modelData.project)
                                                ToolTip.visible: hovered
                                                ToolTip.text: Accessible.name
                                                onClicked: containersPage.toggleProjectExpanded(projectDelegate.modelData.project)
                                            }

                                            Label {
                                                text: projectDelegate.modelData.project
                                                font.bold: true
                                                font.pixelSize: TypeScale.heading
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
                                                            Accessible.name: serviceDelegate.expanded
                                                                ? qsTr("Collapse %1").arg(serviceDelegate.modelData.service)
                                                                : qsTr("Expand %1").arg(serviceDelegate.modelData.service)
                                                            ToolTip.visible: hovered
                                                            ToolTip.text: Accessible.name
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
                                                                activeFocusOnTab: true
                                                                // Frame only derives its implicit size automatically from a single
                                                                // content child; the focus-ring Rectangle below makes that two, so
                                                                // size it explicitly off the RowLayout instead.
                                                                implicitHeight: contentRow.implicitHeight + topPadding + bottomPadding

                                                                Keys.onPressed: (event) => {
                                                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                                                        containersPage.openContainerDetail(containerDelegate.modelData.id)
                                                                        event.accepted = true
                                                                    }
                                                                }

                                                                RowLayout {
                                                                    id: contentRow
                                                                    anchors.fill: parent
                                                                    spacing: 8

                                                                    ColumnLayout {
                                                                        Layout.fillWidth: true
                                                                        spacing: 2

                                                                        Label {
                                                                            text: containerDelegate.modelData.name
                                                                            font.bold: true
                                                                            font.pixelSize: TypeScale.body
                                                                        }

                                                                        Label {
                                                                            text: qsTr("Image: %1").arg(containerDelegate.modelData.image)
                                                                            font.pixelSize: TypeScale.caption
                                                                            opacity: 0.7
                                                                        }

                                                                        Label {
                                                                            text: qsTr("Status: %1").arg(containerDelegate.modelData.status)
                                                                            font.pixelSize: TypeScale.caption
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

                                                                Rectangle {
                                                                    anchors.fill: parent
                                                                    color: "transparent"
                                                                    border.color: palette.highlight
                                                                    border.width: 2
                                                                    visible: containerDelegate.activeFocus
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
        }
    }
}
