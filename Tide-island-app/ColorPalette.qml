import TideIsland 1.0
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    color: Theme.cardBgColor
    radius: 16
    border.width: 1
    border.color: Theme.splitLineColor
    implicitHeight: paletteColumn.implicitHeight + 36

    function boolValue(key, fallback) {
        const val = ConfigStore.value(key, fallback);
        return val === undefined || val === null ? fallback : Boolean(val);
    }

    Column {
        id: paletteColumn

        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        spacing: 16

        Item {
            width: parent.width
            height: 49

            Text {
                id: paletteToggleTitle
                text: "Dynamic Color Palette"
                font.family: Theme.textFontFamily
                font.pixelSize: 18
                color: Theme.textColor
                anchors.top: parent.top
                anchors.left: parent.left
            }

            Text {
                text: "Sync island and controls with your colors.json palette"
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                anchors.top: paletteToggleTitle.bottom
                anchors.topMargin: 5
                anchors.left: paletteToggleTitle.left
                color: Theme.subtleTextColor
            }

            StyledSwitch {
                id: paletteSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.boolValue("colorPaletteEnabled", true)
                onToggled: function(val) {
                    checked = val;
                    ConfigStore.setValue("colorPaletteEnabled", val);
                    ConfigStore.save();
                }
            }
        }

        SplitLine { width: parent.width }

        Item {
            width: parent.width
            height: 49

            Text {
                id: colorsPathTitle
                text: "Colors File Path"
                font.family: Theme.textFontFamily
                font.pixelSize: 18
                color: Theme.textColor
                anchors.top: parent.top
                anchors.left: parent.left
            }

            Text {
                text: "Custom colors.json path (empty for ~/.config/tide-island/colors.json)"
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                anchors.top: colorsPathTitle.bottom
                anchors.topMargin: 5
                anchors.left: colorsPathTitle.left
                color: Theme.subtleTextColor
            }

            ConfigTextField {
                id: colorsPathField
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                height: 36
                placeholderText: "~/.config/tide-island/colors.json"

                Component.onCompleted: {
                    text = String(ConfigStore.value("colorsFilePath", ""))
                }

                onAccepted: commit()
                onEditingFinished: commit()

                function commit() {
                    ConfigStore.setValue("colorsFilePath", text.trim())
                    ConfigStore.save()
                }
            }
        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component StyledSwitch: Item {
        id: control

        signal toggled(bool checked)

        property bool checked: false

        width: 48
        height: 26

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 24
            radius: 12
            color: control.checked ? Theme.accentColor : Theme.componentBgColor
            border.width: 1
            border.color: control.checked ? Theme.accentColor : Theme.inputBorderColor

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }
        }

        Rectangle {
            id: knob

            width: 18
            height: 18
            radius: 9
            x: control.checked ? 22 : 6
            y: 3
            color: Theme.cardBgColor
            border.width: 0

            Behavior on x {
                NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                control.checked = !control.checked;
                control.toggled(control.checked);
            }
        }
    }
}
