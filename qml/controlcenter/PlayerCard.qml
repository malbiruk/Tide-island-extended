pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import IslandBackend

// Media card in the control center: cover, title/artist, transport controls, a thin progress
// bar, and a close button that hides it until playback starts again.
Rectangle {
    id: root

    signal previousRequested()
    signal playPauseRequested()
    signal nextRequested()
    signal dismissRequested()

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property bool playing: false
    property real progress: 0
    property string iconFontFamily: ""
    property string textFontFamily: ""

    radius: 10
    color: StyleTokens.clearBlack
    clip: true

    MatteSurface {
        anchors.fill: parent
        radius: root.radius
    }

    // Clicks anywhere on the card stay on it instead of returning to the island.
    MouseArea {
        anchors.fill: parent
    }

    ClippingRectangle {
        id: cover
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 52
        radius: 8
        color: StyleTokens.track

        Text {
            anchors.centerIn: parent
            visible: coverImage.status !== Image.Ready
            text: "\uf001"
            textFormat: Text.PlainText
            color: StyleTokens.textMuted
            font.family: root.iconFontFamily
            font.pixelSize: 18
        }

        Image {
            id: coverImage
            anchors.fill: parent
            source: root.artUrl
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(104, 104)
            asynchronous: true
            smooth: true
        }
    }

    Item {
        anchors.left: cover.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12

        Column {
            anchors.left: parent.left
            anchors.right: controls.left
            anchors.rightMargin: 10
            anchors.top: parent.top
            spacing: 2

            Text {
                width: parent.width
                text: root.title
                textFormat: Text.PlainText
                color: StyleTokens.textPrimary
                font.pixelSize: 13
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.artist
                textFormat: Text.PlainText
                color: StyleTokens.textSecondary
                font.pixelSize: 11
                font.family: root.textFontFamily
                elide: Text.ElideRight
            }
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            spacing: 4

            Repeater {
                model: [
                    { glyph: "\u{F04AE}", action: "previous", size: 18 },
                    { glyph: root.playing ? "\u{F03E4}" : "\u{F040A}", action: "playPause", size: 22 },
                    { glyph: "\u{F04AD}", action: "next", size: 18 }
                ]

                delegate: Item {
                    id: controlButton
                    required property var modelData
                    width: 26
                    height: 26

                    Text {
                        anchors.centerIn: parent
                        text: controlButton.modelData.glyph
                        textFormat: Text.PlainText
                        color: controlMouse.containsMouse ? StyleTokens.accent : StyleTokens.textPrimary
                        font.family: root.iconFontFamily
                        font.pixelSize: controlButton.modelData.size
                        scale: controlMouse.pressed ? 0.88 : 1
                    }

                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (controlButton.modelData.action === "previous")
                                root.previousRequested();
                            else if (controlButton.modelData.action === "next")
                                root.nextRequested();
                            else
                                root.playPauseRequested();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 4
            radius: 2
            color: StyleTokens.cardFillHover

            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * Math.max(0, Math.min(1, root.progress))
                color: StyleTokens.accent
            }
        }
    }

    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.rightMargin: 4
        width: 18
        height: 18

        Text {
            anchors.centerIn: parent
            text: "\u{F0156}"
            textFormat: Text.PlainText
            color: closeMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textMuted
            font.family: root.iconFontFamily
            font.pixelSize: 12
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissRequested()
        }
    }
}
