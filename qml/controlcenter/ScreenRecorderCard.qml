import QtQuick
import Quickshell
import IslandBackend

Item {
    id: root

    // The recordings folder was opened; the control center closes so the file manager is in view.
    signal folderOpened()

    readonly property var userConfig: UserConfig
    readonly property var recorder: ScreenRecorder

    readonly property color cardAccent: StyleTokens.accent
    readonly property color cardAccentSoft: StyleTokens.accentSoft
    readonly property color cardRed: StyleTokens.danger

    readonly property color buttonBg: StyleTokens.cardFill
    readonly property color buttonBgHover: StyleTokens.cardFillHover
    readonly property color buttonBgPressed: StyleTokens.cardFillActive

    readonly property bool isRecording: recorder ? recorder.isRecording : false
    readonly property bool isMicOn: recorder ? recorder.micEnabled : false
    readonly property string timerText: recorder ? recorder.recordingTimeFormatted : "00:00"

    width: parent ? parent.width : 380
    height: isRecording ? 98 : 74

    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: 10
        color: StyleTokens.clearBlack
        clip: true

        MatteSurface {
            anchors.fill: parent
            radius: parent.radius
        }

        // Clicks anywhere on the card stay on it instead of returning to the island.
        MouseArea {
            anchors.fill: parent
        }

        // Subtle glowing border when active, harmonized with Matugen
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: StyleTokens.transparent
            border.width: 1
            border.color: root.isRecording ? StyleTokens.withAlpha(root.cardRed, 0.3) : StyleTokens.transparent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Top Row: Title, Status, and Main Actions
            Row {
                width: parent.width
                height: 46
                spacing: 12

                // Record / Stop Main Button
                Rectangle {
                    id: mainRecordButton
                    width: 44
                    height: 44
                    radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    scale: recordMouse.pressed ? 0.94 : (recordMouse.containsMouse ? 1.04 : 1.0)
                    color: root.isRecording
                        ? StyleTokens.withAlpha(root.cardRed, 0.22)
                        : (recordMouse.pressed
                            ? root.buttonBgPressed
                            : (recordMouse.containsMouse ? root.buttonBgHover : root.buttonBg))
                    border.color: root.isRecording
                        ? root.cardRed
                        : (recordMouse.containsMouse ? StyleTokens.withAlpha(root.cardAccent, 0.4) : StyleTokens.withAlpha(StyleTokens.textPrimary, 0.12))
                    border.width: 1

                    Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Behavior on border.color { ColorAnimation { duration: 90 } }

                    // Icon: Stop square if recording, Red dot if idle
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.isRecording ? 16 : 14
                        height: root.isRecording ? 16 : 14
                        radius: root.isRecording ? 3 : 7
                        color: root.isRecording ? root.cardRed : (recordMouse.containsMouse ? root.cardRed : StyleTokens.withAlpha(root.cardRed, 0.85))

                        Behavior on radius { NumberAnimation { duration: 100 } }
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: recordMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.recorder)
                                root.recorder.toggleRecording();
                        }
                    }
                }

                // Info: Title & Dynamic Status
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - mainRecordButton.width - actionButtonsRow.width - 24
                    spacing: 3

                    Text {
                        text: "Screen Recorder"
                        color: StyleTokens.textPrimary
                        font.pixelSize: 13
                        font.family: userConfig.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 6
                        anchors.left: parent.left

                        // Pulsing dot for live recording
                        Rectangle {
                            visible: root.isRecording
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.cardRed

                            SequentialAnimation on opacity {
                                running: root.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.isRecording ? ("Recording • " + root.timerText) : "wf-recorder"
                            color: root.isRecording ? root.cardRed : StyleTokens.textMuted
                            font.pixelSize: 11
                            font.family: userConfig.textFontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }

                // Quick Action Pill Buttons
                Row {
                    id: actionButtonsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Microphone Toggle Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        scale: micMouse.pressed ? 0.92 : (micMouse.containsMouse ? 1.06 : 1.0)
                        color: root.isMicOn
                            ? StyleTokens.withAlpha(root.cardAccent, 0.22)
                            : (micMouse.pressed
                                ? root.buttonBgPressed
                                : (micMouse.containsMouse ? root.buttonBgHover : root.buttonBg))
                        border.color: root.isMicOn ? root.cardAccent : (micMouse.containsMouse ? StyleTokens.withAlpha(root.cardAccent, 0.35) : StyleTokens.withAlpha(StyleTokens.textPrimary, 0.08))
                        border.width: 1

                        Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 70 } }
                        Behavior on border.color { ColorAnimation { duration: 70 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf130"
                            color: root.isMicOn ? root.cardAccent : (micMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textSecondary)
                            font.pixelSize: 13
                            font.family: userConfig.iconFontFamily
                        }

                        MouseArea {
                            id: micMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.recorder)
                                    root.recorder.toggleMic();
                            }
                        }
                    }

                    // Open Recordings Folder Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        scale: folderMouse.pressed ? 0.92 : (folderMouse.containsMouse ? 1.06 : 1.0)
                        color: folderMouse.pressed
                            ? root.buttonBgPressed
                            : (folderMouse.containsMouse ? root.buttonBgHover : root.buttonBg)
                        border.color: folderMouse.containsMouse ? StyleTokens.withAlpha(root.cardAccent, 0.35) : StyleTokens.withAlpha(StyleTokens.textPrimary, 0.08)
                        border.width: 1

                        Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 70 } }
                        Behavior on border.color { ColorAnimation { duration: 70 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf07b"
                            color: folderMouse.containsMouse ? root.cardAccent : StyleTokens.textSecondary
                            font.pixelSize: 13
                            font.family: userConfig.iconFontFamily
                        }

                        MouseArea {
                            id: folderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.recorder) {
                                    root.recorder.openRecordingsFolder();
                                    root.folderOpened();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
