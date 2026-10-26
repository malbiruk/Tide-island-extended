import QtQuick
import "../island"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
PrivacyHudLayer {
    required property var host
    required property var island

    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    heroFontFamily: host.heroFontFamily
    isMicMuted: island.isMicMuted
    showCondition: island.privacyHudLayerVisible
    onCloseRequested: island.smartRestoreState()
}
