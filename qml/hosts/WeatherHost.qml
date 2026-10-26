import QtQuick
import "../island"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
WeatherLayer {
    required property var host
    required property var island

    weatherService: host.weatherService
    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    heroFontFamily: host.heroFontFamily
    showCondition: island.weatherLayerVisible
    onCloseRequested: island.smartRestoreState()
}
