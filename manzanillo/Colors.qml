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

    // Badge tint and translated label for a Docker container state
    // (created, running, paused, restarting, removing, exited, dead).
    function containerStateTint(state) {
        switch (state) {
        case "running": return colors.success
        case "restarting":
        case "paused": return colors.warning
        case "dead":
        case "failed": return colors.danger
        default: return colors.neutral
        }
    }

    function containerStateLabel(state) {
        switch (state) {
        case "running": return qsTr("Running")
        case "restarting": return qsTr("Restarting")
        case "paused": return qsTr("Paused")
        case "dead": return qsTr("Dead")
        case "failed": return qsTr("Failed")
        case "exited": return qsTr("Exited")
        case "created": return qsTr("Created")
        case "removing": return qsTr("Removing")
        default: return state || ""
        }
    }
}
