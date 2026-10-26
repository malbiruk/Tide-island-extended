import QtQuick
import IslandBackend

// Charging bolt, percentage and battery glyph. Shared by the control-center header and the
// resting island so both look and colour the same.
Row {
    id: root

    property int capacity: 0
    property bool charging: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property int fontPixelSize: 13

    // Fill colour by state: charging/full success; discharging below 20 % danger, below 40 %
    // warning (the island's "low" threshold), otherwise the accent.
    readonly property color levelColor: {
        if (charging)
            return StyleTokens.success;
        if (capacity < 20)
            return StyleTokens.danger;
        return capacity < 40 ? StyleTokens.warning : StyleTokens.accent;
    }

    spacing: 5

    Text {
        text: "\uf0e7"
        textFormat: Text.PlainText
        color: StyleTokens.textPrimary
        font.pixelSize: root.fontPixelSize
        font.family: root.iconFontFamily
        visible: root.charging
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: root.capacity + "%"
        textFormat: Text.PlainText
        color: StyleTokens.textPrimary
        font.pixelSize: root.fontPixelSize
        font.family: root.textFontFamily
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
    }

    Item {
        width: 28
        height: 14
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            anchors.rightMargin: 2
            radius: 4
            color: StyleTokens.transparent
            border.color: StyleTokens.textSecondary
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 2
                radius: 2
                width: (parent.width - 4) * (Math.max(0, Math.min(100, root.capacity)) / 100.0)
                color: root.levelColor

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            width: 2
            height: 6
            radius: 1
            color: StyleTokens.textSecondary
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
