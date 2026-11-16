import QtQuick
import QtQuick.Controls

// StackView used for every list -> detail drill-down. Honours the "Reduce motion"
// setting: when it's on, the style's push/pop/replace transitions are disabled so
// pages switch instantly.
StackView {
    id: stack

    readonly property bool reduceMotion: apiClient.reduceMotion

    function applyMotionPreference() {
        for (const transition of [pushEnter, pushExit, popEnter, popExit, replaceEnter, replaceExit]) {
            if (transition) {
                transition.enabled = !reduceMotion
            }
        }
    }

    Component.onCompleted: applyMotionPreference()
    onReduceMotionChanged: applyMotionPreference()
}
