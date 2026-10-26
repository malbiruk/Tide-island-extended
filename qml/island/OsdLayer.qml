import QtQuick
import IslandBackend

Item {
    id: root

    readonly property var userConfig: UserConfig

    property string iconText: ""
    property real progress: -1
    property string customText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string heroFontFamily: activeConfig.heroFontFamily
    property string slideDirection: "none"
    property real transitionProgress: 0
    readonly property bool showProgress: progress >= 0
    // Muted volume: the bar is dimmed (the icon is the mute glyph).
    property bool muted: false
    readonly property bool showText: progress < 0 && customText !== ""
    property bool showCondition: false
    property real hiddenLeftPadding: 16
    property real hiddenRightPadding: 16
    readonly property real clampedProgress: slideDirection === "right"
        ? Math.max(0, Math.min(1, transitionProgress))
        : (slideDirection === "left"
            ? Math.max(0, Math.min(1, -transitionProgress))
            : 0)
    readonly property real revealProgress: slideDirection === "none" ? 1 : (1 - clampedProgress)
    readonly property real contentX: slideDirection === "right"
        ? (width + hiddenRightPadding) * clampedProgress
        : (slideDirection === "left"
            ? -(width + hiddenLeftPadding) * clampedProgress
            : 0)

    anchors.fill: parent
    clip: true
    opacity: showCondition ? revealProgress : 0

    Behavior on opacity {
        enabled: slideDirection === "none"

        NumberAnimation {
            duration: showCondition ? 170 : 120
            easing.type: Easing.InOutQuad
        }
    }

    // [icon] [bar] [percent]: the bar matches the control center sliders.
    Item {
        x: contentX
        width: parent.width
        height: parent.height
        visible: showProgress

        Text {
            id: progressIcon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: iconText
            color: StyleTokens.textPrimary
            font.pixelSize: userConfig.iconFontSize
            font.family: iconFontFamily
        }

        TextMetrics {
            id: percentMetrics
            font: percentText.font
            text: "100%"
        }

        Text {
            id: percentText
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(percentMetrics.advanceWidth)
            horizontalAlignment: Text.AlignRight
            text: Math.round(Math.max(0, Math.min(1, progress)) * 100) + "%"
            color: StyleTokens.textPrimary
            font.pixelSize: userConfig.bodyFontSize
            font.family: heroFontFamily
            font.weight: Font.Bold
            font.letterSpacing: -0.35
        }

        Rectangle {
            id: progressTrack
            anchors.left: progressIcon.right
            anchors.leftMargin: 12
            anchors.right: percentText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: StyleTokens.cardFillHover

            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * Math.max(0, Math.min(1, progress))
                color: root.muted ? StyleTokens.textMuted : StyleTokens.accent
                opacity: root.muted ? 0.6 : 1
            }
        }
    }

    Item {
        x: contentX
        width: parent.width
        height: parent.height
        visible: showText

        Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
                text: iconText
                color: StyleTokens.textPrimary
                font.pixelSize: userConfig.iconFontSize
                font.family: iconFontFamily
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: customText
                color: StyleTokens.textPrimary
                font.pixelSize: userConfig.bodyFontSize
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
