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

    PageStack {
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
                            text: qsTr("Containers")
                            font.pixelSize: TypeScale.title
                            Layout.fillWidth: true
                        }

                        ToolButton {
                            objectName: "refreshContainersButton"
                            icon.name: "view-refresh"
                            text: qsTr("Refresh")
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
                        color: Colors.danger
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

                    // Ctrl+F (platform Find) jumps to search, but only while this list is
                    // what's on screen - not from another nav page or a pushed detail page.
                    Shortcut {
                        sequences: [StandardKey.Find]
                        enabled: searchField.visible
                        onActivated: {
                            searchField.forceActiveFocus(Qt.ShortcutFocusReason)
                            searchField.selectAll()
                        }
                    }

                    TextField {
                        id: searchField
                        objectName: "containerSearchField"
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search containers by name or image… (Ctrl+F)")
                        Accessible.name: qsTr("Search containers by name or image")
                        // Esc clears a non-empty query; when already empty the key is left
                        // unaccepted so window-level Esc handling still sees it.
                        Keys.onEscapePressed: (event) => {
                            if (text.length > 0) {
                                clear()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
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

                        Item {
                            Label {
                                objectName: "containersEmptyLabel"
                                anchors.centerIn: parent
                                visible: containersList.count === 0 && !apiClient.containersBusy
                                text: searchField.text.length > 0
                                    ? qsTr("No containers match \"%1\"").arg(searchField.text)
                                    : qsTr("No containers found")
                                font.pixelSize: TypeScale.body
                                opacity: 0.7
                            }

                            BusyIndicator {
                                objectName: "containersBusyIndicator"
                                anchors.centerIn: parent
                                visible: containersList.count === 0 && apiClient.containersBusy
                                running: visible
                                Accessible.name: qsTr("Loading containers")
                            }

                            ListView {
                                id: containersList
                                anchors.fill: parent
                                objectName: "containersListView"
                                clip: true
                                spacing: 4
                                model: apiClient.filteredContainersModel
                                activeFocusOnTab: true
                                Accessible.role: Accessible.List
                                Accessible.name: qsTr("Containers")

                                // Keyboard equivalent of tapping a row: arrow keys move currentIndex
                                // (built into ListView), Enter/Return/Space opens its detail page.
                                Keys.onPressed: (event) => {
                                    if (currentItem && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                                        containersPage.openContainerDetail(currentItem.containerId)
                                        event.accepted = true
                                    }
                                }

                                delegate: RowCard {
                                    id: containerRowDelegate
                                    required property int index
                                    required property string containerId
                                    required property string names
                                    required property string image
                                    required property string status
                                    required property string state
                                    readonly property bool busy: apiClient.busyContainerIds.indexOf(containerRowDelegate.containerId) >= 0
                                    objectName: "containerRow_" + containerRowDelegate.containerId
                                    width: containersList.width
                                    title: containerRowDelegate.names
                                    statusText: Colors.containerStateLabel(containerRowDelegate.state)
                                    statusTint: Colors.containerStateTint(containerRowDelegate.state)
                                    details: [
                                        qsTr("Image: %1").arg(containerRowDelegate.image),
                                        qsTr("Status: %1").arg(containerRowDelegate.status)
                                    ]
                                    showFocusRing: containerRowDelegate.ListView.isCurrentItem && containersList.activeFocus
                                    onActivated: {
                                        containersList.currentIndex = containerRowDelegate.index
                                        containersPage.openContainerDetail(containerRowDelegate.containerId)
                                    }

                                    Button {
                                        objectName: "quickActionButton_" + containerRowDelegate.containerId
                                        text: containerRowDelegate.busy
                                            ? qsTr("Working...")
                                            : (containerRowDelegate.state === "running" ? qsTr("Stop") : qsTr("Start"))
                                        enabled: !containerRowDelegate.busy
                                        onClicked: containerRowDelegate.state === "running"
                                            ? apiClient.stopContainer(containerRowDelegate.containerId)
                                            : apiClient.startContainer(containerRowDelegate.containerId)
                                    }
                                }
                            }
                        }

                        ScrollView {
                            id: composeScrollView
                            clip: true

                            ColumnLayout {
                                objectName: "composeProjectsList"
                                width: composeScrollView.availableWidth
                                spacing: 4
                                Accessible.role: Accessible.List
                                Accessible.name: qsTr("Compose projects")

                                BusyIndicator {
                                    objectName: "composeBusyIndicator"
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: containersPage.filteredComposeProjects.length === 0 && apiClient.containersBusy
                                    running: visible
                                    Accessible.name: qsTr("Loading Compose projects")
                                }

                                Label {
                                    objectName: "composeEmptyLabel"
                                    visible: containersPage.filteredComposeProjects.length === 0 && !apiClient.containersBusy
                                    text: searchField.text.length > 0
                                        ? qsTr("No Compose containers match \"%1\"").arg(searchField.text)
                                        : qsTr("No Compose projects found")
                                    font.pixelSize: TypeScale.body
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

                                                            delegate: RowCard {
                                                                id: containerDelegate
                                                                required property var modelData
                                                                readonly property bool busy: apiClient.busyContainerIds.indexOf(containerDelegate.modelData.id) >= 0
                                                                objectName: "composeContainerRow_" + containerDelegate.modelData.id
                                                                Layout.fillWidth: true
                                                                activeFocusOnTab: true
                                                                title: containerDelegate.modelData.name
                                                                statusText: Colors.containerStateLabel(containerDelegate.modelData.state)
                                                                statusTint: Colors.containerStateTint(containerDelegate.modelData.state)
                                                                details: [
                                                                    qsTr("Image: %1").arg(containerDelegate.modelData.image),
                                                                    qsTr("Status: %1").arg(containerDelegate.modelData.status)
                                                                ]
                                                                onActivated: containersPage.openContainerDetail(containerDelegate.modelData.id)

                                                                Button {
                                                                    objectName: "quickActionButton_" + containerDelegate.modelData.id
                                                                    text: containerDelegate.busy
                                                                        ? qsTr("Working...")
                                                                        : (containerDelegate.modelData.state === "running" ? qsTr("Stop") : qsTr("Start"))
                                                                    enabled: !containerDelegate.busy
                                                                    onClicked: containerDelegate.modelData.state === "running"
                                                                        ? apiClient.stopContainer(containerDelegate.modelData.id)
                                                                        : apiClient.startContainer(containerDelegate.modelData.id)
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
