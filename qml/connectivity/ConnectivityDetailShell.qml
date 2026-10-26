import QtQuick

Item {
    id: shell

    property bool open: false
    property bool mounted: false
    property bool rightSide: false
    // Centred under the capsule instead of beside it (the battery popup opened from the island).
    property bool below: false
    property string panelKind: "wifi"
    property var provider: null
    property var mainCapsule: null
    property real availableWidth: 0
    property real detailWidth: 318
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
    readonly property real shownY: below ? capsuleY + capsuleHeight + detailGap : capsuleY
    readonly property real hiddenX: below ? shownX : shownX + (rightSide ? -12 : 12)
    readonly property real hiddenY: below ? shownY - 8 : capsuleY + 4
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
    height: detailHeight
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
            origin.y: shell.below ? 0 : Math.min(panelBody.height - 32, Math.max(36, shell.capsuleHeight - 215))
            xScale: shell.panelScale
            yScale: shell.panelScale
        }

        Loader {
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
