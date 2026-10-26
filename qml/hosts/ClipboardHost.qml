import QtQuick
import "../island"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
ClipboardLayer {
    required property var host
    required property var island

    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    showCondition: island.clipboardLayerVisible
    onCloseRequested: island.smartRestoreState()
}
