import QtQuick
import QtQuick.Controls

// A ToolBar with a flat fill using the system window color instead of
// Fusion's default shaded/bordered toolbar panel, so it reads as part of
// the window chrome rather than a separate gray bar (matching how native
// Plasma/Kirigami apps blend their header into the titlebar).
ToolBar {
    background: Rectangle {
        color: palette.window
    }
}
