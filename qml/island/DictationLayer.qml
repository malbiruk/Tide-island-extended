import QtQuick
import QtQuick.Shapes
import IslandBackend

// [mic] [waveform]: voxtype's scrolling mic level while recording; frozen, dimmed and pulsing
// while the recording is transcribed.
Item {
    id: root

    readonly property var userConfig: UserConfig

    property string iconText: ""
    property string iconFontFamily: userConfig.iconFontFamily
    // Levels 0..1, oldest first; a new array per column.
    property var waveform: []
    property int publishSerial: 0
    property int columnInterval: 0
    property bool transcribing: false
    property bool showCondition: false
    property real pulse: 1

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 170 : 120
            easing.type: Easing.InOutQuad
        }
    }

    onPublishSerialChanged: {
        if (!transcribing)
            scrollAnimation.restart();
    }
    onTranscribingChanged: {
        if (transcribing)
            scrollAnimation.stop();
    }

    SequentialAnimation on pulse {
        running: root.transcribing && root.showCondition
        loops: Animation.Infinite

        NumberAnimation { to: 0.45; duration: 750; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 750; easing.type: Easing.InOutSine }
    }

    Text {
        id: micIcon
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: iconText
        color: StyleTokens.textPrimary
        font.pixelSize: userConfig.iconFontSize
        font.family: iconFontFamily
    }

    Item {
        id: waveArea
        anchors.left: micIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        height: userConfig.iconFontSize
        clip: true

        // The shape runs one column past the right edge and slides left by one column per new
        // column, so levels scroll in instead of jumping; the last point starts out of view.
        readonly property int count: root.waveform.length
        readonly property real columnWidth: count > 2 ? width / (count - 2) : width

        // 3-tap smoothed levels mirrored around the centre line, tapered at both visible ends.
        readonly property var outline: {
            const levels = root.waveform;
            const n = levels.length;
            if (n < 3)
                return [];
            const cy = height / 2;
            const amp = Math.max(1, height / 2 - 1.5);
            const upper = new Array(n);
            const lower = new Array(n);
            for (let i = 0; i < n; i++) {
                const s = levels[Math.max(0, i - 1)] * 0.25 + levels[i] * 0.5 + levels[Math.min(n - 1, i + 1)] * 0.25;
                // Over the visible width, not the shape's.
                const t = i / (n - 2);
                const taper = Math.max(0, Math.min(1, t * 12, (1 - t) * 12));
                const e = Math.max(0.02, Math.max(0, Math.min(1, s)) * taper) * amp;
                const x = i * columnWidth;
                upper[i] = Qt.point(x, cy - e);
                lower[n - 1 - i] = Qt.point(x, cy + e);
            }
            return upper.concat(lower, [upper[0]]);
        }

        Shape {
            id: waveShape
            width: waveArea.width + waveArea.columnWidth
            height: waveArea.height
            opacity: root.transcribing ? root.pulse : 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.transcribing ? StyleTokens.textMuted : StyleTokens.accent
                strokeColor: StyleTokens.transparent

                PathPolyline { path: waveArea.outline }
            }
        }

        NumberAnimation {
            id: scrollAnimation
            target: waveShape
            property: "x"
            from: 0
            to: -waveArea.columnWidth
            duration: root.columnInterval
        }
    }
}
