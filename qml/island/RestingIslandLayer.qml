import QtQuick
import Quickshell.Widgets
import IslandBackend

// The resting island: [cover - lyric/title - cava] [clock] [unread bell, battery]. The clock is kept at the
// island's anchor (the capsule's centre plus `centerShift`); the music section grows to its
// left and the battery section to its right, so the capsule is asymmetric. Section widths are
// exposed for the capsule geometry and stay valid while the layer is hidden.
Item {
    id: root

    property string timeText: ""
    property string timeFontFamily: ""
    property string textFontFamily: ""
    property string iconFontFamily: ""
    property int textPixelSize: 14
    property real minimumCenterWidth: 80
    // Horizontal offset of the clock centre from the capsule centre (animated by the capsule).
    property real centerShift: 0

    property bool musicVisible: false
    property string musicText: ""
    property string artUrl: ""
    property var cavaLevels: []

    property bool batteryVisible: false
    property int batteryCapacity: 0
    property bool batteryCharging: false

    property bool unreadVisible: false

    property bool showCondition: true

    readonly property real edgePadding: 12
    readonly property real innerSpacing: 8
    readonly property real coverSize: 20
    readonly property real musicTextMaxWidth: 200
    readonly property real bellWidth: 22

    readonly property real centerSectionWidth: Math.max(minimumCenterWidth, Math.ceil(timeMetrics.advanceWidth) + edgePadding * 2)
    readonly property real musicContentWidth: coverSize + innerSpacing + musicTitle.width + innerSpacing + cavaBars.implicitWidth
    readonly property real leftSectionWidth: musicVisible ? edgePadding + musicContentWidth : 0
    readonly property real bellSlotWidth: unreadVisible ? bellWidth + (batteryVisible ? innerSpacing : 0) : 0
    readonly property real rightContentWidth: bellSlotWidth + (batteryVisible ? battery.implicitWidth : 0)
    readonly property real rightSectionWidth: rightContentWidth > 0 ? rightContentWidth + edgePadding : 0

    readonly property real centerX: width / 2 + centerShift - centerSectionWidth / 2

    // The section under (x, y) in this item: "music", "bell", "battery", or "clock" for the
    // clock and any other capsule area.
    function sectionAt(x, y) {
        const rightStart = centerX + centerSectionWidth;
        if (x >= rightStart) {
            if (unreadVisible && (!batteryVisible || x < rightStart + bellWidth + innerSpacing / 2))
                return "bell";
            return batteryVisible ? "battery" : "clock";
        }
        return musicVisible && x < centerX ? "music" : "clock";
    }

    anchors.fill: parent
    opacity: showCondition ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: 110
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: timeMetrics
        font.family: root.timeFontFamily
        font.pixelSize: root.textPixelSize + 1
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        text: root.timeText
    }

    // --- Music: cover, current lyric (or title), visualizer ---
    Row {
        id: musicRow
        x: root.centerX - root.musicContentWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.innerSpacing
        opacity: root.musicVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 130
                easing.type: Easing.InOutQuad
            }
        }

        ClippingRectangle {
            width: root.coverSize
            height: root.coverSize
            radius: 5
            color: StyleTokens.track
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: "\uf001"
                textFormat: Text.PlainText
                color: StyleTokens.textMuted
                font.family: root.iconFontFamily
                font.pixelSize: 10
            }

            Image {
                id: cover
                anchors.fill: parent
                source: root.artUrl
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
                asynchronous: true
                smooth: true
            }
        }

        MarqueeText {
            id: musicTitle
            anchors.verticalCenter: parent.verticalCenter
            text: root.musicText
            pixelSize: root.textPixelSize
            fontFamily: root.textFontFamily
            fontWeight: Font.DemiBold
            letterSpacing: -0.15
            maxWidth: root.musicTextMaxWidth
            active: root.musicVisible && root.showCondition
        }

        SwipeCavaBars {
            id: cavaBars
            anchors.verticalCenter: parent.verticalCenter
            levels: root.cavaLevels
            barCount: 5
            barWidth: 3
            barSpacing: 3
            minimumBarHeight: 4
        }
    }

    // --- Clock ---
    Text {
        x: root.centerX
        width: root.centerSectionWidth
        anchors.verticalCenter: parent.verticalCenter
        text: root.timeText
        textFormat: Text.PlainText
        color: StyleTokens.textPrimary
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: root.textPixelSize + 1
        font.family: root.timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
    }

    // --- Unread notifications: bell with an accent dot ---
    Item {
        id: unreadBell
        x: root.centerX + root.centerSectionWidth
        anchors.verticalCenter: parent.verticalCenter
        width: root.bellWidth
        height: 20
        opacity: root.unreadVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 130
                easing.type: Easing.InOutQuad
            }
        }

        Text {
            anchors.centerIn: parent
            text: "\uf0f3"
            textFormat: Text.PlainText
            color: StyleTokens.textPrimary
            font.family: root.iconFontFamily
            font.pixelSize: 14
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.rightMargin: 2
            width: 6
            height: 6
            radius: 3
            color: StyleTokens.accent
        }
    }

    // --- Battery ---
    BatteryIndicator {
        id: battery
        x: root.centerX + root.centerSectionWidth + root.bellSlotWidth
        anchors.verticalCenter: parent.verticalCenter
        capacity: root.batteryCapacity
        charging: root.batteryCharging
        iconFontFamily: root.iconFontFamily
        textFontFamily: root.textFontFamily
        opacity: root.batteryVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 130
                easing.type: Easing.InOutQuad
            }
        }
    }
}
