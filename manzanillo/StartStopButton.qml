import QtQuick
import QtQuick.Controls

// Quick Start/Stop action for a container row: Stop while running, Start otherwise,
// and "Working..." (disabled) while this container's own action is in flight.
Button {
    id: startStopButton
    required property string containerId
    required property string containerState
    required property bool busy

    readonly property bool running: startStopButton.containerState === "running"

    text: startStopButton.busy
        ? qsTr("Working...")
        : (startStopButton.running ? qsTr("Stop") : qsTr("Start"))
    enabled: !startStopButton.busy
    onClicked: startStopButton.running
        ? apiClient.stopContainer(startStopButton.containerId)
        : apiClient.startContainer(startStopButton.containerId)
}
