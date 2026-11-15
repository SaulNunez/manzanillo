import QtQuick
import QtQuick.Controls

// Modal dialog centred over the window. It takes `preferredWidth` but never grows
// wider than the window minus a 16px margin each side, so it stays fully on screen
// in narrow windows. (The overlay can briefly report 0 width while the window is
// being set up; fall back to preferredWidth then.)
Dialog {
    property int preferredWidth: 360

    modal: true
    anchors.centerIn: Overlay.overlay
    width: Overlay.overlay && Overlay.overlay.width > 0
        ? Math.min(preferredWidth, Overlay.overlay.width - 32)
        : preferredWidth
}
