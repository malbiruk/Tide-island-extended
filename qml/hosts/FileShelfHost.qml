import QtQuick
import "../island"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
FileShelfLayer {
    required property var host
    required property var island

    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    showCondition: island.fileShelfLayerVisible
    dropPreviewOnly: !island.fileShelfOpenedManually
    onCloseRequested: island.smartRestoreState()
    onClearedAll: island.smartRestoreState(true)
}
