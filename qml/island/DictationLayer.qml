import QtQuick
import QtQuick.Shapes
import IslandBackend

// Recording: [mic] [scrolling mic level] [clock, counting down near voxtype's limit].
// Transcribing: [spinner] [travelling ripple] [frozen clock]. Then, for a successful dictation
// only: [check] [N characters], briefly.
Item {
    id: root

    readonly property var userConfig: UserConfig

    property string iconText: ""
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    // The host's cap on the capsule's width; only a result that long is elided.
    property real maximumWidth: Infinity
    // Levels 0..1, oldest first; a new array per column.
    property var waveform: []
    property int publishSerial: 0
    property int columnInterval: 0
    // result is {chars, limit} or null.
    property string dictationState: "idle"
    property var result: null
    property real startedAtMs: 0
    property int limitSecs: 0
    property real finalSecs: 0
    property bool showCondition: false

    readonly property string liveMode: dictationState === "recording" ? "recording"
        : dictationState === "transcribing" ? "transcribing"
        : result ? "result" : ""
    // "recording", "transcribing" or "result": follows liveMode but holds through "" (idle, no
    // result), so the capsule leaves showing what it showed, at the same width. The result and
    // final time are held the same way.
    property string mode: "transcribing"
    property var shownResult: null
    property real shownFinalSecs: 0

    readonly property int sideMargin: 18
    implicitWidth: mode === "result"
        ? Math.ceil(2 * sideMargin + checkIcon.implicitWidth + resultRow.spacing + resultText.implicitWidth)
        : 248

    property real now: Date.now()
    readonly property real elapsedSecs: Math.max(0, now - startedAtMs) / 1000
    readonly property real remainingSecs: limitSecs > 0 ? Math.max(0, limitSecs - elapsedSecs) : 0
    readonly property bool countingDown: mode === "recording" && limitSecs > 0
        && remainingSecs <= Math.min(15, limitSecs / 2)

    // Transcribing eases the last recorded levels into a slow travelling ripple (as voxtype's RecipeRenderer).
    property var rippleLevels: []
    property real ripplePhase: 0
    property real rippleDue: 0

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 170 : 120
            easing.type: Easing.InOutQuad
        }
    }

    onLiveModeChanged: latch()
    onResultChanged: latch()
    onFinalSecsChanged: latch()
    onShowConditionChanged: latch()
    onModeChanged: {
        if (mode === "transcribing")
            startRipple();
    }
    Component.onCompleted: {
        latch();
        if (mode === "transcribing")
            startRipple();
    }

    onPublishSerialChanged: {
        if (mode === "recording")
            scrollAnimation.restart();
    }

    function latch() {
        if (!showCondition)
            return;
        shownFinalSecs = finalSecs;
        if (result)
            shownResult = result;
        if (liveMode !== "")
            mode = liveMode;
    }

    function clockText(secs) {
        const s = Math.max(0, Math.floor(secs));
        const sec = s % 60;
        return Math.floor(s / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }

    function startRipple() {
        scrollAnimation.stop();
        waveShape.x = 0;
        rippleLevels = waveform.slice();
        ripplePhase = 0;
        rippleDue = 0;
    }

    // About 30 steps a second: smooth enough for this slow motion, at a fraction of the outline
    // rebuilds of every frame.
    function stepRipple(frameTime) {
        rippleDue += frameTime;
        if (rippleDue < 0.033)
            return;
        const dt = Math.min(0.05, rippleDue);
        rippleDue = 0;
        const n = rippleLevels.length;
        const ease = 1 - Math.exp(-6 * dt);
        ripplePhase += dt;
        const next = new Array(n);
        for (let i = 0; i < n; i++) {
            const t = waveArea.columnT(i, n);
            const target = 0.10 + 0.22 * Math.pow(0.5 + 0.5 * Math.sin(ripplePhase * 3.2 - t * Math.PI * 4), 2);
            next[i] = rippleLevels[i] + (target - rippleLevels[i]) * ease;
        }
        // A new array, so the outline re-evaluates.
        rippleLevels = next;
    }

    Timer {
        interval: 250
        repeat: true
        running: root.dictationState === "recording" && root.showCondition
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    FrameAnimation {
        running: root.mode === "transcribing" && root.showCondition
        onTriggered: root.stepRipple(frameTime)
    }

    Text {
        id: micIcon
        anchors.left: parent.left
        anchors.leftMargin: root.sideMargin
        anchors.verticalCenter: parent.verticalCenter
        visible: root.mode === "recording"
        text: iconText
        color: StyleTokens.textPrimary
        font.pixelSize: userConfig.iconFontSize
        font.family: iconFontFamily
    }

    // voxtype's transcribing spinner (StateIcon.qml), drawn on its 24x24 grid in the mic's place.
    Item {
        id: spinner
        anchors.centerIn: micIcon
        width: 24
        height: 24
        scale: userConfig.iconFontSize / 24
        visible: root.mode === "transcribing"

        Shape {
            id: spinnerShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // 2 px on screen at any scale.
            readonly property real strokeWidth: 2 / spinner.scale

            ShapePath {
                strokeColor: Qt.rgba(StyleTokens.textPrimary.r, StyleTokens.textPrimary.g, StyleTokens.textPrimary.b, 0.25)
                strokeWidth: spinnerShape.strokeWidth
                fillColor: StyleTokens.transparent

                PathAngleArc { centerX: 12; centerY: 12; radiusX: 8.5; radiusY: 8.5; startAngle: 0; sweepAngle: 360 }
            }

            ShapePath {
                strokeColor: StyleTokens.textPrimary
                strokeWidth: spinnerShape.strokeWidth
                fillColor: StyleTokens.transparent
                capStyle: ShapePath.RoundCap

                PathAngleArc { centerX: 12; centerY: 12; radiusX: 8.5; radiusY: 8.5; startAngle: -90; sweepAngle: 110 }
            }
        }

        RotationAnimation {
            target: spinnerShape
            property: "rotation"
            from: 0
            to: 360
            duration: 1200
            direction: RotationAnimation.Clockwise
            loops: Animation.Infinite
            running: root.mode === "transcribing" && root.showCondition
            // The next run starts from the top again.
            onRunningChanged: {
                if (!running)
                    spinnerShape.rotation = 0;
            }
        }
    }

    TextMetrics {
        id: clockMetrics
        font: clock.font
        text: "00:00"
    }

    Text {
        id: clock
        anchors.right: parent.right
        anchors.rightMargin: root.sideMargin
        anchors.verticalCenter: parent.verticalCenter
        // Fixed, so the waveform keeps still as the digits change; past 99 minutes it just grows.
        width: Math.max(Math.ceil(clockMetrics.advanceWidth), implicitWidth)
        horizontalAlignment: Text.AlignRight
        visible: root.mode !== "result"
        text: root.mode === "transcribing" ? root.clockText(root.shownFinalSecs)
            : root.countingDown ? root.clockText(Math.ceil(root.remainingSecs))
            : root.clockText(root.elapsedSecs)
        // Matches the mic glyph while recording.
        color: root.mode === "transcribing" ? StyleTokens.textMuted
            : !root.countingDown ? StyleTokens.textPrimary
            : root.remainingSecs <= 5 ? StyleTokens.danger
            : StyleTokens.warning
        font.pixelSize: userConfig.bodyFontSize
        font.family: root.heroFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.35
    }

    Item {
        id: waveArea
        anchors.left: micIcon.right
        anchors.leftMargin: 12
        anchors.right: clock.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: userConfig.iconFontSize
        visible: root.mode !== "result"
        clip: true

        // The shape runs one column past the right edge and slides left by one column per new
        // column, so levels scroll in instead of jumping; the last point starts out of view.
        readonly property int count: root.waveform.length
        readonly property real columnWidth: count > 2 ? width / (count - 2) : width

        // A column's position across the visible width, not the shape's.
        function columnT(i, n) {
            return i / (n - 2);
        }

        // 3-tap smoothed levels mirrored around the centre line, tapered at both visible ends.
        readonly property var outline: {
            const levels = root.mode === "transcribing" ? root.rippleLevels : root.waveform;
            const n = levels.length;
            if (n < 3)
                return [];
            const cy = height / 2;
            const amp = Math.max(1, height / 2 - 1.5);
            const upper = new Array(n);
            const lower = new Array(n);
            for (let i = 0; i < n; i++) {
                const s = levels[Math.max(0, i - 1)] * 0.25 + levels[i] * 0.5 + levels[Math.min(n - 1, i + 1)] * 0.25;
                const t = columnT(i, n);
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
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: StyleTokens.accent
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

    Row {
        id: resultRow
        anchors.centerIn: parent
        spacing: 14
        visible: root.mode === "result"

        Text {
            id: checkIcon
            text: "\uf00c"
            color: StyleTokens.textPrimary
            font.pixelSize: root.userConfig.iconFontSize
            font.family: root.iconFontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: resultText
            width: Math.min(implicitWidth, root.maximumWidth - 2 * root.sideMargin - checkIcon.width - resultRow.spacing)
            elide: Text.ElideRight
            text: {
                const r = root.shownResult;
                if (!r)
                    return "";
                const chars = r.chars === 1 ? "1 character" : r.chars + " characters";
                return r.limit ? "Time limit reached · " + chars : chars;
            }
            color: StyleTokens.textPrimary
            font.pixelSize: root.userConfig.bodyFontSize
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
            font.letterSpacing: -0.15
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
