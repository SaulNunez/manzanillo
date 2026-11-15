import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: containerDetailPage
    required property string containerId
    // Busy only while this container's own start/stop is in flight (keyed by short id).
    readonly property bool actionBusy: apiClient.busyContainerIds.indexOf(containerDetailPage.containerId.substring(0, 12)) >= 0

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

        FlatToolBar {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: 8

                BackButton {
                    objectName: "containerDetailBackButton"
                    onClicked: containerDetailPage.StackView.view.pop()
                }

                Label {
                    text: apiClient.containerDetail.name || qsTr("Container")
                    font.pointSize: TypeScale.title
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
                    font.pointSize: TypeScale.body
                }
            }

            ErrorBanner {
                id: detailErrorLabel
                objectName: "containerDetailErrorBanner"
                busy: apiClient.containerDetailBusy || containerDetailPage.actionBusy || apiClient.containerLogsStreaming
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

                        // Label column (caption) and value column (body), so values line
                        // up and translations don't carry "Key: %1" layout.
                        GridLayout {
                            objectName: "containerDetailFields"
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 6

                            FieldLabel { text: qsTr("ID") }
                            FieldValue {
                                objectName: "containerDetailIdValue"
                                text: apiClient.containerDetail.id || ""
                                copyable: true
                                copyName: qsTr("container ID")
                            }

                            FieldLabel { text: qsTr("Image") }
                            FieldValue {
                                objectName: "containerDetailImageValue"
                                text: apiClient.containerDetail.image || ""
                            }

                            FieldLabel { text: qsTr("State"); Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft; Layout.topMargin: 0 }
                            StatusBadge {
                                objectName: "containerDetailStateBadge"
                                text: Colors.containerStateLabel(apiClient.containerDetail.state)
                                tint: Colors.containerStateTint(apiClient.containerDetail.state)
                            }

                            // Actions sit under the state, in the value column.
                            Item { implicitWidth: 1; implicitHeight: 1 }
                            RowLayout {
                                spacing: 8

                                Button {
                                    objectName: "startContainerButton"
                                    text: containerDetailPage.actionBusy ? qsTr("Working...") : qsTr("Start")
                                    visible: apiClient.containerDetail.state !== "running"
                                    enabled: !containerDetailPage.actionBusy && !apiClient.containerDetailBusy
                                    onClicked: apiClient.startContainer(apiClient.containerDetail.id)
                                }

                                Button {
                                    objectName: "stopContainerButton"
                                    text: containerDetailPage.actionBusy ? qsTr("Working...") : qsTr("Stop")
                                    visible: apiClient.containerDetail.state === "running"
                                    enabled: !containerDetailPage.actionBusy && !apiClient.containerDetailBusy
                                    onClicked: apiClient.stopContainer(apiClient.containerDetail.id)
                                }
                            }

                            FieldLabel { text: qsTr("Started"); visible: !!apiClient.containerDetail.startedAt }
                            FieldValue {
                                objectName: "containerDetailStartedValue"
                                text: apiClient.containerDetail.startedAt || ""
                                visible: !!apiClient.containerDetail.startedAt
                            }

                            FieldLabel { text: qsTr("Created") }
                            FieldValue {
                                objectName: "containerDetailCreatedValue"
                                text: apiClient.containerDetail.created || ""
                            }

                            FieldLabel { text: qsTr("Command"); visible: !!apiClient.containerDetail.command }
                            FieldValue {
                                objectName: "containerDetailCommandValue"
                                text: apiClient.containerDetail.command || ""
                                visible: !!apiClient.containerDetail.command
                            }

                            FieldLabel { text: qsTr("Working directory"); visible: !!apiClient.containerDetail.workingDir }
                            FieldValue {
                                objectName: "containerDetailWorkingDirValue"
                                text: apiClient.containerDetail.workingDir || ""
                                visible: !!apiClient.containerDetail.workingDir
                            }

                            FieldLabel { text: qsTr("Restart policy"); visible: !!apiClient.containerDetail.restartPolicy }
                            FieldValue {
                                objectName: "containerDetailRestartPolicyValue"
                                text: apiClient.containerDetail.restartPolicy || ""
                                visible: !!apiClient.containerDetail.restartPolicy
                            }
                        }

                        SectionHeading { text: qsTr("Ports") }
                        Label {
                            visible: !apiClient.containerDetail.ports || apiClient.containerDetail.ports.length === 0
                            text: qsTr("(none)")
                            font.pointSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.ports || []
                            delegate: FieldValue { required property string modelData; text: modelData }
                        }

                        SectionHeading { text: qsTr("Networks") }
                        Label {
                            visible: !apiClient.containerDetail.networks || apiClient.containerDetail.networks.length === 0
                            text: qsTr("(none)")
                            font.pointSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.networks || []
                            delegate: FieldValue { required property string modelData; text: modelData }
                        }

                        SectionHeading { text: qsTr("Mounts") }
                        Label {
                            visible: !apiClient.containerDetail.mounts || apiClient.containerDetail.mounts.length === 0
                            text: qsTr("(none)")
                            font.pointSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.mounts || []
                            delegate: FieldValue { required property string modelData; required property int index; objectName: "containerMountValue_" + index; text: modelData }
                        }

                        SectionHeading { text: qsTr("Environment") }
                        Label {
                            visible: !apiClient.containerDetail.env || apiClient.containerDetail.env.length === 0
                            text: qsTr("(none)")
                            font.pointSize: TypeScale.body
                            opacity: 0.7
                        }
                        Repeater {
                            model: apiClient.containerDetail.env || []
                            delegate: FieldValue { required property string modelData; required property int index; objectName: "containerEnvValue_" + index; text: modelData }
                        }
                    }
                }

                ColumnLayout {
                    id: logsPane
                    spacing: 4

                    // Follow new output only while the user wants it: scrolling up pauses,
                    // scrolling back to the bottom (or pressing Follow) resumes.
                    property bool following: true
                    property bool autoScrolling: false

                    function scrollToEnd() {
                        logsPane.autoScrolling = true
                        logsFlickable.contentY = Math.max(0, logsFlickable.contentHeight - logsFlickable.height)
                        logsPane.autoScrolling = false
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            Layout.fillWidth: true
                            text: apiClient.containerLogsStreaming ? qsTr("Streaming logs…") : qsTr("Not streaming")
                            font.pointSize: TypeScale.caption
                            opacity: 0.7
                        }

                        Button {
                            objectName: "logFollowButton"
                            checkable: true
                            checked: logsPane.following
                            text: logsPane.following ? qsTr("Following") : qsTr("Paused")
                            Accessible.name: logsPane.following ? qsTr("Pause following log output") : qsTr("Follow log output")
                            onToggled: {
                                logsPane.following = checked
                                if (checked)
                                    logsPane.scrollToEnd()
                            }
                        }
                    }

                    Flickable {
                        id: logsFlickable
                        objectName: "containerLogsFlickable"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {}
                        ScrollBar.horizontal: ScrollBar {}

                        function atEnd() { return contentY >= contentHeight - height - 2 }

                        onContentYChanged: {
                            if (!logsPane.autoScrolling)
                                logsPane.following = atEnd()
                        }
                        onContentHeightChanged: {
                            if (logsPane.following)
                                logsPane.scrollToEnd()
                        }
                        onHeightChanged: {
                            if (logsPane.following)
                                logsPane.scrollToEnd()
                        }

                        // Plain child, not TextArea.flickable: the attached version scrolls to
                        // keep the cursor visible on every text change, which would fight the
                        // user's scroll position.
                        contentWidth: containerLogsArea.width
                        contentHeight: containerLogsArea.height

                        TextArea {
                            id: containerLogsArea
                            objectName: "containerLogsArea"
                            width: Math.max(implicitWidth, logsFlickable.width)
                            height: Math.max(implicitHeight, logsFlickable.height)
                            readOnly: true
                            wrapMode: TextArea.NoWrap
                            text: apiClient.containerLogs
                            font.family: "monospace"
                            font.pointSize: TypeScale.monospace
                        }
                    }
                }
            }
        }
    }
}
