pragma ComponentBehavior: Bound

import QtQuick
import IslandBackend

Item {
    id: root

    property string text: ""
    property color color: StyleTokens.textPrimary
    property int pixelSize: 14
    property string fontFamily: ""
    property int fontWeight: Font.Bold
    property real letterSpacing: 0
    property real maxWidth: -1
    property real gap: 40
    property real scrollSpeed: 32
    property int pauseDuration: 1800
    property bool active: true
    property bool marqueeEnabled: true
    property int horizontalAlignment: Text.AlignLeft

    readonly property real naturalWidth: measureText.implicitWidth
    readonly property real naturalHeight: measureText.implicitHeight
    readonly property bool needsMarquee: marqueeEnabled && maxWidth > 0 && naturalWidth > maxWidth
    readonly property real displayWidth: (maxWidth > 0) ? Math.min(naturalWidth, maxWidth) : naturalWidth
    readonly property real loopDistance: Math.round(naturalWidth + gap)
    readonly property int scrollDuration: Math.max(1000, Math.round((loopDistance / scrollSpeed) * 1000))
    readonly property bool shouldAnimate: needsMarquee && active

    implicitWidth: displayWidth
    implicitHeight: naturalHeight
    width: displayWidth
    height: naturalHeight
    clip: needsMarquee

    Text {
        id: measureText
        visible: false
        text: root.text
        font.pixelSize: root.pixelSize
        font.family: root.fontFamily
        font.weight: root.fontWeight
        font.letterSpacing: root.letterSpacing
    }

    Text {
        id: staticText
        visible: !root.needsMarquee
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: root.text
        color: root.color
        font.pixelSize: root.pixelSize
        font.family: root.fontFamily
        font.weight: root.fontWeight
        font.letterSpacing: root.letterSpacing
        horizontalAlignment: root.horizontalAlignment
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    Item {
        id: marqueeStrip
        visible: root.needsMarquee
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        x: 0

        Text {
            id: t1
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            text: root.text
            color: root.color
            font.pixelSize: root.pixelSize
            font.family: root.fontFamily
            font.weight: root.fontWeight
            font.letterSpacing: root.letterSpacing
            wrapMode: Text.NoWrap
        }

        Text {
            id: t2
            anchors.verticalCenter: parent.verticalCenter
            x: root.loopDistance
            text: root.text
            color: root.color
            font.pixelSize: root.pixelSize
            font.family: root.fontFamily
            font.weight: root.fontWeight
            font.letterSpacing: root.letterSpacing
            wrapMode: Text.NoWrap
        }

        SequentialAnimation {
            id: marqueeAnim
            running: root.shouldAnimate
            loops: Animation.Infinite

            PauseAnimation {
                duration: root.pauseDuration
            }

            NumberAnimation {
                target: marqueeStrip
                property: "x"
                from: 0
                to: -root.loopDistance
                duration: root.scrollDuration
                easing.type: Easing.Linear
            }

            ScriptAction {
                script: marqueeStrip.x = 0
            }
        }
    }

    function resetMarquee() {
        marqueeStrip.x = 0;
        if (shouldAnimate)
            marqueeAnim.restart();
        else
            marqueeAnim.stop();
    }

    onTextChanged: resetMarquee()
    onMarqueeEnabledChanged: {
        if (!marqueeEnabled) {
            marqueeAnim.stop();
            marqueeStrip.x = 0;
        } else if (shouldAnimate) {
            resetMarquee();
        }
    }
    onShouldAnimateChanged: {
        if (shouldAnimate)
            resetMarquee();
        else {
            marqueeAnim.stop();
            marqueeStrip.x = 0;
        }
    }
}
