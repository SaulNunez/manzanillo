pragma Singleton
import QtQuick

// Role-based status colours with separate light and dark values. "Dark" follows
// the live system palette, so a desktop colour-scheme switch recolours the app
// without a restart. Every value reaches at least 4.5:1 against the window and
// button colours (and a StatusBadge's 15% tinted fill) in both themes.
QtObject {
    id: colors

    readonly property SystemPalette systemPalette: SystemPalette {}
    readonly property bool dark: systemPalette.window.hslLightness < 0.5

    readonly property color danger: dark ? "#ff9e94" : "#a8221b"
    readonly property color success: dark ? "#7fd88a" : "#1e6b2a"
    readonly property color warning: dark ? "#f5c060" : "#7a4f00"
    readonly property color neutral: dark ? "#c4c4c4" : "#595959"

    // Docker container states -> badge tone (one of the tokens above) and translated
    // label, so a state's colour and text are defined in one place.
    readonly property var containerStates: ({
        "running": { tone: "success", label: qsTr("Running") },
        "restarting": { tone: "warning", label: qsTr("Restarting") },
        "paused": { tone: "warning", label: qsTr("Paused") },
        "dead": { tone: "danger", label: qsTr("Dead") },
        "exited": { tone: "neutral", label: qsTr("Exited") },
        "created": { tone: "neutral", label: qsTr("Created") },
        "removing": { tone: "neutral", label: qsTr("Removing") }
    })

    function containerStateTint(state) {
        const entry = colors.containerStates[state]
        return colors[entry ? entry.tone : "neutral"]
    }

    // An unknown state shows Docker's raw value rather than nothing.
    function containerStateLabel(state) {
        const entry = colors.containerStates[state]
        return entry ? entry.label : (state || "")
    }
}
