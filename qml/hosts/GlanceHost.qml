import QtQuick
import "../island"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
SystemGlanceLayer {
    required property var host
    required property var island

    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    heroFontFamily: host.heroFontFamily
    showCondition: island.glanceLayerVisible
    onCloseRequested: island.smartRestoreState()
    onOpenCalendarRequested: {
        island.smartRestoreState();
        host.showCalendarWindow();
    }
    onOpenWeatherRequested: {
        island.smartRestoreState();
        host.showWeatherWindow();
    }
}
