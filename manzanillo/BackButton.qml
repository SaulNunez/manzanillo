import QtQuick
import QtQuick.Controls

// Toolbar "back" button for detail pages. Theme icons aren't mirrored automatically,
// so the arrow is picked by layout direction (it points right in right-to-left layouts), and Esc / the platform Back shortcut
// (e.g. Alt+Left) trigger it while the button is on screen - so only the detail page
// that's actually showing reacts. A popup open over the page (a dialog, the nav
// drawer) takes Esc first.
ToolButton {
    id: backButton

    text: qsTr("Back")
    display: AbstractButton.IconOnly
    icon.name: backButton.mirrored ? "go-next" : "go-previous"
    Accessible.name: qsTr("Back")
    ToolTip.visible: hovered
    ToolTip.text: Accessible.name

    Shortcut {
        sequences: [StandardKey.Back, "Esc"]
        enabled: backButton.visible && backButton.enabled
        onActivated: backButton.clicked()
    }
}
