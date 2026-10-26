import QtQuick
import "../island"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
CalendarLayer {
    required property var host
    required property var island

    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    heroFontFamily: host.heroFontFamily
    showCondition: island.calendarLayerVisible
    onCloseRequested: island.smartRestoreState()
}
