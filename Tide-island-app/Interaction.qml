import QtQuick
import QtQuick.Controls
import TideIsland 1.0

PagePanel {
    id: root

    // The shell matches a click against the primary, secondary and middle slots
    // in that order, so the app always gives each slot its own mouse button;
    // a "none" slot sharing a button would swallow another slot's action.
    readonly property var clickSlots: [
        { "prefix": "dynamicIslandPrimary", "button": 1, "action": "none" },
        { "prefix": "dynamicIslandSecondary", "button": 3, "action": "toggleControlCenter" },
        { "prefix": "dynamicIslandMiddle", "button": 2, "action": "toggleClipboard" }
    ]
    readonly property var clickActionOptions: [
        { "label": "None", "value": 0, "action": "none" },
        { "label": "Control Center", "value": 1, "action": "toggleControlCenter" },
        { "label": "Clipboard", "value": 2, "action": "toggleClipboard" }
    ]
    readonly property var hoverActionOptions: [
        { "label": "Disabled", "value": 0 },
        { "label": "Control Center", "value": 2 }
    ]

    property int revision: 0

    function normalizedButton(value, fallback) {
        const parsedValue = Number(value)
        if (parsedValue === 1 || parsedValue === 2 || parsedValue === 3)
            return parsedValue
        return fallback
    }

    function normalizedHoverAction(value) {
        // 1 was the removed music player.
        return Number(value) === 2 ? 2 : 0
    }

    function normalizedAutoHideDelay(value) {
        const parsedValue = Number(value)
        if (isNaN(parsedValue))
            return 1000
        return Math.min(10000, Math.max(100, Math.round(parsedValue)))
    }

    function boolValue(key, fallback) {
        const value = ConfigStore.value(key, fallback)
        return value === true || value === "true"
    }

    function normalizedAction(value) {
        const action = String(value === undefined || value === null ? "" : value).trim()
        // toggleExpandedPlayer was the removed music player.
        return action === "" || action === "toggleExpandedPlayer" ? "none" : action
    }

    function actionForButton(button) {
        revision

        for (let index = 0; index < clickSlots.length; index++) {
            const slot = clickSlots[index]
            if (normalizedButton(ConfigStore.value(slot.prefix + "Button", slot.button), slot.button) === button)
                return normalizedAction(ConfigStore.value(slot.prefix + "Action", slot.action))
        }
        return "none"
    }

    function actionOptionValue(button) {
        const action = actionForButton(button)
        for (let index = 0; index < clickActionOptions.length; index++) {
            if (clickActionOptions[index].action === action)
                return clickActionOptions[index].value
        }
        return -1
    }

    function setActionForButton(button, optionValue) {
        const actions = {}
        for (let index = 0; index < clickSlots.length; index++)
            actions[clickSlots[index].button] = actionForButton(clickSlots[index].button)
        for (let index = 0; index < clickActionOptions.length; index++) {
            if (clickActionOptions[index].value === optionValue)
                actions[button] = clickActionOptions[index].action
        }

        for (let index = 0; index < clickSlots.length; index++) {
            const slot = clickSlots[index]
            ConfigStore.setValue(slot.prefix + "Button", slot.button)
            ConfigStore.setValue(slot.prefix + "Action", actions[slot.button])
        }
        ConfigStore.save()
        revision += 1
    }

    function hoverActionValue() {
        revision
        return normalizedHoverAction(ConfigStore.value("hoverExpandAction", 0))
    }

    function setHoverAction(value) {
        ConfigStore.setValue("hoverExpandAction", value)
        ConfigStore.save()
        revision += 1
    }

    function islandAutoHideEnabled() {
        revision
        return boolValue("islandAutoHideEnabled", true)
    }

    function setIslandAutoHideEnabled(enabled) {
        ConfigStore.setValue("islandAutoHideEnabled", enabled)
        ConfigStore.save()
        revision += 1
    }

    function islandAutoHideKeepActivities() {
        revision
        return boolValue("islandAutoHideKeepActivities", true)
    }

    function setIslandAutoHideKeepActivities(enabled) {
        ConfigStore.setValue("islandAutoHideKeepActivities", enabled)
        ConfigStore.save()
        revision += 1
    }

    function islandAutoHideDelayMs() {
        revision
        return normalizedAutoHideDelay(ConfigStore.value("islandAutoHideDelayMs", 1000))
    }

    function hideDelaySecondsText() {
        const seconds = islandAutoHideDelayMs() / 1000
        if (Math.abs(seconds - Math.round(seconds)) < 0.001)
            return String(Math.round(seconds))
        return String(Math.round(seconds * 10) / 10)
    }

    function saveCustomHideDelay(value) {
        const parsedValue = Number(String(value).trim())
        const seconds = isNaN(parsedValue) ? islandAutoHideDelayMs() / 1000 : parsedValue
        const boundedSeconds = Math.min(10, Math.max(0.1, seconds))
        const delayMs = normalizedAutoHideDelay(boundedSeconds * 1000)
        ConfigStore.setValue("islandAutoHideDelayMs", delayMs)
        ConfigStore.save()
        revision += 1
        return delayMs / 1000
    }

    function privacyCameraBubbleEnabled() {
        revision
        return boolValue("privacyCameraBubbleEnabled", true)
    }

    function setPrivacyCameraBubbleEnabled(enabled) {
        ConfigStore.setValue("privacyCameraBubbleEnabled", enabled)
        ConfigStore.save()
        revision += 1
    }

    function privacyMicBubbleEnabled() {
        revision
        return boolValue("privacyMicBubbleEnabled", true)
    }

    function setPrivacyMicBubbleEnabled(enabled) {
        ConfigStore.setValue("privacyMicBubbleEnabled", enabled)
        ConfigStore.save()
        revision += 1
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function(event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64
                const maxY = Math.max(0, scroller.contentHeight - scroller.height)
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta))
                event.accepted = true
            }
        }

        Item {
            id: content

            width: scroller.width
            height: privacyPanel.y + privacyPanel.height + 40

            Text {
                id: title

                text: "Interaction"
                x: 60
                y: 50
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 30
            }

            Text {
                id: clickTitle

                text: "Click"
                anchors.top: title.bottom
                anchors.topMargin: 40
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: clickPanel

                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: clickTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: clickColumn.implicitHeight + 30

                Column {
                    id: clickColumn

                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 15

                    ClickActionRow {
                        title: "Left Click"
                        description: "Action for a left click on the island"
                        button: 1
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ClickActionRow {
                        title: "Middle Click"
                        description: "Action for a middle click on the island"
                        button: 2
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ClickActionRow {
                        title: "Right Click"
                        description: "Action for a right click on the island"
                        button: 3
                        width: parent.width
                    }
                }
            }

            Text {
                id: hoverTitle

                text: "Hover"
                anchors.top: clickPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: hoverPanel

                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: hoverTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: hoverColumn.implicitHeight + 30

                Column {
                    id: hoverColumn

                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 15

                    HoverActionRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    AutoHideRow {
                        width: parent.width
                    }

                    KeepActivitiesAutoHideRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    HideDelayRow {
                        width: parent.width
                    }
                }
            }

            Text {
                id: privacyTitle

                text: "Privacy Indicators"
                anchors.top: hoverPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: privacyPanel

                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: privacyTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: privacyColumn.implicitHeight + 30

                Column {
                    id: privacyColumn

                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 15

                    PrivacyCameraRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    PrivacyMicRow {
                        width: parent.width
                    }
                }
            }
        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component ClickActionRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property int button: 1

        height: 49

        Text {
            id: rowTitle

            text: row.title
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: row.description
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - buttonGroup.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        ButtonGroup {
            id: buttonGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.clickActionOptions
            selectedValue: root.actionOptionValue(row.button)

            onSelected: function(value) {
                root.setActionForButton(row.button, value)
            }
        }
    }

    component HoverActionRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Hover Expand"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Choose what opens when the island is hovered"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - hoverGroup.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        ButtonGroup {
            id: hoverGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.hoverActionOptions
            selectedValue: root.hoverActionValue()

            onSelected: function(value) {
                root.setHoverAction(value)
            }
        }
    }

    component PrivacyCameraRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Camera Bubble"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Show camera indicator bubble on the island when in use"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - cameraSwitch.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        StyledSwitch {
            id: cameraSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.privacyCameraBubbleEnabled()

            onToggled: function(checked) {
                root.setPrivacyCameraBubbleEnabled(checked)
            }
        }
    }

    component PrivacyMicRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Microphone Bubble"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Show microphone indicator bubble on the island when in use"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - micSwitch.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        StyledSwitch {
            id: micSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.privacyMicBubbleEnabled()

            onToggled: function(checked) {
                root.setPrivacyMicBubbleEnabled(checked)
            }
        }
    }

    component AutoHideRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Auto Hide"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Hide the island until the pointer reaches its screen edge"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - autoHideSwitch.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        StyledSwitch {
            id: autoHideSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.islandAutoHideEnabled()

            onToggled: function(checked) {
                root.setIslandAutoHideEnabled(checked)
            }
        }
    }

    component KeepActivitiesAutoHideRow: Item {
        id: row
        height: 49

        enabled: root.islandAutoHideEnabled()
        opacity: enabled ? 1.0 : 0.4

        Text {
            id: rowTitle
            text: "Keep Activities Visible"
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 16
        }

        Text {
            text: "Stay revealed while music or the battery is showing"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - keepActivitiesSwitch.width - 52)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 13
        }

        StyledSwitch {
            id: keepActivitiesSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.islandAutoHideKeepActivities()

            onToggled: function(checked) {
                root.setIslandAutoHideKeepActivities(checked)
            }
        }
    }

    component HideDelayRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Hide Delay"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Delay after the pointer leaves the island"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - delayControls.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        Row {
            id: delayControls

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            ConfigTextField {
                id: delayField

                width: 72
                height: 36
                textPixelSize: 14
                placeholderText: "1"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 0.1
                    top: 10
                    decimals: 1
                    notation: DoubleValidator.StandardNotation
                }

                savedText: root.hideDelaySecondsText()
                onCommitted: row.commitCustomDelay()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "s"
                color: Theme.subtleTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }
        }

        function commitCustomDelay() {
            delayField.text = String(root.saveCustomHideDelay(delayField.text))
        }
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
            id: switchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // checked stays bound to the config; it follows once the change is saved.
            onClicked: control.toggled(!control.checked)
        }
    }

    component ButtonGroup: Row {
        id: group

        signal selected(int value)

        property var options: []
        property int selectedValue: -1

        width: implicitWidth
        height: implicitHeight
        spacing: 6

        Repeater {
            model: group.options

            Rectangle {
                id: option

                property bool selectedState: group.selectedValue === modelData.value

                width: Math.max(74, optionText.implicitWidth + 24)
                height: 36
                radius: 7
                color: selectedState ? Theme.cardBgColor
                                     : optionMouse.pressed ? Theme.controlPressedColor
                                                           : Theme.componentBgColor
                border.width: 1
                border.color: Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Text {
                    id: optionText

                    anchors.centerIn: parent
                    text: modelData.label
                    color: option.selectedState ? Theme.textColor : Theme.secondaryTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    font.weight: option.selectedState ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: group.selected(modelData.value)
                }
            }
        }
    }
}
