pragma Singleton
import QtQuick

// Type scale based on the system font: body text is the desktop's default font
// size and the other steps are ratios of it (the old 20/16/14/12 px scale), all
// in points, so the OS font-size setting rescales the whole app - live, since
// apiClient.systemFont notifies when the desktop font changes.
// Use with font.pointSize, never font.pixelSize.
// Weights: headings Font.DemiBold, row titles Font.Medium.
QtObject {
    readonly property font systemFont: apiClient.systemFont
    // A pixel-sized system font reports pointSize -1; convert at 96 dpi.
    readonly property real body: systemFont.pointSize > 0 ? systemFont.pointSize : systemFont.pixelSize * 0.75

    readonly property real title: body * 20 / 14     // page / detail page title
    readonly property real heading: body * 16 / 14   // section / compose project heading
    readonly property real caption: body * 12 / 14  // secondary/meta text
    readonly property real monospace: caption        // log viewer text: at least caption size
}
