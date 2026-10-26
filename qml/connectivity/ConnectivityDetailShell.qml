import QtQuick

Item {
    id: shell

    property bool open: false
    property bool mounted: false
    property bool rightSide: false
    // Centred under the capsule instead of beside it (the battery popup opened from the island).
    property bool below: false
    // Island on the bottom edge: side popups align with the capsule's bottom, and the "below"
    // popup sits above it.
    property bool atBottom: false
    property string panelKind: "wifi"
    property var provider: null
    property var mainCapsule: null
    property real availableWidth: 0
    property real detailWidth: 318
    // The cap: the shell fits its panel's content up to this height; beyond it the content scrolls.
    property real detailHeight: 404
    property real detailGap: 12
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string heroFontFamily: ""

    property real revealProgress: 0
    readonly property alias surfaceItem: panelBody

    readonly property real capsuleX: mainCapsule ? mainCapsule.x : 0
    readonly property real capsuleY: mainCapsule ? mainCapsule.y : 0
    readonly property real capsuleWidth: mainCapsule ? mainCapsule.width : 0
    readonly property real capsuleHeight: mainCapsule ? mainCapsule.height : 0
    readonly property real shownX: below
        ? Math.max(16, Math.min(availableWidth - width - 16, capsuleX + capsuleWidth / 2 - width / 2))
        : rightSide
            ? Math.min(availableWidth - width - 16, capsuleX + capsuleWidth + detailGap)
            : Math.max(16, capsuleX - width - detailGap)
    readonly property real shownY: below
        ? (atBottom ? capsuleY - detailGap - height : capsuleY + capsuleHeight + detailGap)
        : (atBottom ? capsuleY + capsuleHeight - height : capsuleY)
    readonly property real hiddenX: below ? shownX : shownX + (rightSide ? -12 : 12)
    // Starts a little toward the capsule (below) or toward the screen middle (beside).
    readonly property real hiddenY: below
        ? shownY + (atBottom ? 8 : -8)
        : shownY + (atBottom ? -4 : 4)
    readonly property real panelScale: 0.96 + revealProgress * 0.04

    function startPanelAnimation(nextOpen) {
        revealAnimation.stop();

        if (nextOpen) {
            revealAnimation.to = 1;
            revealAnimation.duration = 140;
            revealAnimation.easing.type = Easing.OutCubic;
            revealAnimation.start();
        } else {
            revealAnimation.to = 0;
            revealAnimation.duration = 100;
            revealAnimation.easing.type = Easing.OutCubic;
            revealAnimation.start();
        }
    }

    x: hiddenX + (shownX - hiddenX) * revealProgress
    y: hiddenY + (shownY - hiddenY) * revealProgress
    width: detailWidth
    height: panelLoader.item ? Math.min(detailHeight, Math.ceil((panelLoader.item as Item).implicitHeight)) : detailHeight
    opacity: revealProgress
    visible: mounted || opacity > 0.001
    z: 3

    onOpenChanged: startPanelAnimation(open)

    NumberAnimation {
        id: revealAnimation

        target: shell
        property: "revealProgress"
    }

    Component.onCompleted: revealProgress = open ? 1 : 0

    Item {
        id: panelBody

        anchors.fill: parent
        transform: Scale {
            origin.x: shell.below ? panelBody.width / 2 : (shell.rightSide ? 0 : panelBody.width)
            origin.y: {
                if (shell.below)
                    return shell.atBottom ? panelBody.height : 0;
                const fromTop = Math.min(panelBody.height - 32, Math.max(36, shell.capsuleHeight - 215));
                return shell.atBottom ? panelBody.height - fromTop : fromTop;
            }
            xScale: shell.panelScale
            yScale: shell.panelScale
        }

        Loader {
            id: panelLoader
            anchors.fill: parent
            active: shell.mounted
            asynchronous: false
            visible: active

            sourceComponent: shell.panelKind.startsWith("audio")
                ? audioDetailComponent
                : connectivityDetailComponent
        }

        Component {
            id: connectivityDetailComponent
            ConnectivityDetailPanel {
                provider: shell.provider
                panelKind: shell.panelKind
                iconFontFamily: shell.iconFontFamily
                textFontFamily: shell.textFontFamily
                heroFontFamily: shell.heroFontFamily
                presentationProgress: shell.revealProgress
            }
        }

        Component {
            id: audioDetailComponent
            AudioDetailPanel {
                provider: shell.provider
                panelKind: shell.panelKind
                iconFontFamily: shell.iconFontFamily
                textFontFamily: shell.textFontFamily
                heroFontFamily: shell.heroFontFamily
                presentationProgress: shell.revealProgress
            }
        }
    }
}
