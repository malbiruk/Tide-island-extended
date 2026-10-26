import QtQuick
import IslandBackend

Item {
    id: root

    readonly property var userConfig: UserConfig

    property string iconText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property bool showCondition: false

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 130 : 90
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        text: iconText
        color: StyleTokens.textPrimary
        font.pixelSize: userConfig.iconFontSize
        font.family: iconFontFamily
        horizontalAlignment: Text.AlignHCenter
    }
}
