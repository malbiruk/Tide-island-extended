import TideIsland 1.0
import QtQuick.Controls
import QtQuick
import QtCore
import QtQuick.Effects

PagePanel {
    id: root

    HiddenPathDialog {
        id: avatarFileDialog

        directoryMode: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.gif", "*.bmp"]
        onPathAccepted: function(path) {
            avatarRow.setPath(path)
        }
    }

    function intValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function boolValue(key, fallback) {
        const val = ConfigStore.value(key, fallback);
        return val === undefined || val === null ? fallback : Boolean(val);
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (String(value).trim().length === 0) {
            return fallback
        }

        const parsedValue = Number(value)
        if (isNaN(parsedValue)) {
            return fallback
        }

        const roundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, roundedValue)
        ConfigStore.save()
        return roundedValue
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
            height: weatherPanel.y + weatherPanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "General"
                color: Theme.textColor
                font.pixelSize: 30
                x: 60
                y: 50
            }

            Text {
                id: apperanceTitle
                text: "Island apperance"
                anchors.top: title.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            Rectangle {
                id: apperance
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: apperanceTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: apperanceColumn.implicitHeight + 36

                Column {
                    id: apperanceColumn

                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ChoiceRow {
                        id: edgeRow
                        title: "Island Edge"
                        description: "Screen edge the island is attached to"
                        keyName: "islandEdge"
                        options: [
                            { id: "top", name: "Top" },
                            { id: "bottom", name: "Bottom" }
                        ]
                        selectedId: String(ConfigStore.value("islandEdge", "top")).trim().toLowerCase() === "bottom" ? "bottom" : "top"
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Island Width"
                        description: "Width of island in clock mode"
                        keyName: "islandWidth"
                        fallbackText: "140"
                        numeric: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Island Height"
                        description: "Height of island in clock mode"
                        keyName: "islandHeight"
                        fallbackText: "38"
                        numeric: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Background Transparency"
                        description: "Opacity of the island background (0 = fully transparent, 100 = solid)"
                        keyName: "islandBackgroundOpacity"
                        fallbackText: "60"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    Item {
                        width: parent.width
                        height: Math.max(49, blurLabels.implicitHeight)

                        Column {
                            id: blurLabels
                            anchors.left: parent.left
                            anchors.right: blurSwitch.left
                            anchors.rightMargin: 18
                            anchors.top: parent.top
                            spacing: 5

                            Text {
                                text: "Background Blur"
                                font.family: Theme.textFontFamily
                                font.pixelSize: 18
                                color: Theme.textColor
                            }
                            Text {
                                width: parent.width
                                text: "Blur behind the island and all detail panels"
                                font.family: Theme.textFontFamily
                                font.pixelSize: 14
                                color: Theme.subtleTextColor
                                wrapMode: Text.Wrap
                            }
                        }

                        Switch {
                            id: blurSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 28
                            padding: 0
                            checked: {
                                const value = ConfigStore.value("islandBlurEnabled", true)
                                return typeof value === "boolean" ? value : true
                            }
                            Accessible.name: "Background Blur"
                            onToggled: {
                                ConfigStore.setValue("islandBlurEnabled", checked)
                                ConfigStore.save()
                            }

                            indicator: Rectangle {
                                width: 36
                                height: 22
                                y: (blurSwitch.height - height) / 2
                                radius: 11
                                color: blurSwitch.checked ? Theme.accentColor : Theme.controlPressedColor
                                border.width: blurSwitch.visualFocus ? 2 : 0
                                border.color: Theme.focusBorderColor

                                Rectangle {
                                    x: blurSwitch.checked ? 16 : 2
                                    y: 2
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: "#ffffff"
                                    Behavior on x {
                                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    SplitLine { width: parent.width }

                    ClockFormatRow { width: parent.width }

                    SplitLine { width: parent.width }

                    ChoiceRow {
                        title: "Island Battery"
                        description: "When the island shows the battery (Low: below 40%)"
                        keyName: "islandBatteryMode"
                        options: [
                            { id: "low", name: "Low" },
                            { id: "always", name: "Always" },
                            { id: "never", name: "Never" }
                        ]
                        selectedId: {
                            const mode = String(ConfigStore.value("islandBatteryMode", "low")).trim().toLowerCase()
                            return mode === "always" || mode === "never" ? mode : "low"
                        }
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Reserved Space"
                        description: "Screen space reserved for the island at its edge (exclusive zone)"
                        keyName: "islandExclusiveZone"
                        fallbackText: "45"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Edge Margin"
                        description: "Distance between the island and its screen edge"
                        keyName: "islandTopMargin"
                        fallbackText: "4"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Island Position"
                        description: "X position of island"
                        keyName: "islandPositionX"
                        fallbackText: "50"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }
                }
            }

            Text {
                id: profileTitle
                text: "Profile & System Glance"
                anchors.top: apperance.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            Rectangle {
                id: profilePanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: profileTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: profileColumn.implicitHeight + 36

                Column {
                    id: profileColumn

                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    AvatarRow {
                        id: avatarRow
                        title: "Profile Avatar"
                        description: "Avatar shown in the System Glance dashboard"
                        keyName: "avatarPath"
                        width: parent.width
                    }
                }
            }

            Text {
                id: notificationsTitle
                text: "Notifications"
                anchors.top: profilePanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            Rectangle {
                id: notificationsPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: notificationsTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: notificationsColumn.implicitHeight + 36

                Column {
                    id: notificationsColumn

                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    SwitchRow {
                        title: "Do Not Disturb"
                        description: "Silence notification pop-ups; the bell in the notification center toggles this too"
                        keyName: "doNotDisturb"
                        fallbackValue: false
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Pop-up Duration"
                        description: "Seconds a notification stays up (critical ones stay until dismissed)"
                        keyName: "notificationTimeout"
                        fallbackText: "8"
                        numeric: true
                        minimumValue: 1
                        maximumValue: 600
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Low-Priority Duration"
                        description: "Seconds a low-urgency notification stays up"
                        keyName: "notificationTimeoutLow"
                        fallbackText: "5"
                        numeric: true
                        minimumValue: 1
                        maximumValue: 600
                        width: parent.width
                    }
                }
            }

            Text {
                id: controlCenterTitle
                text: "Control Center"
                anchors.top: notificationsPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            Rectangle {
                id: controlCenterPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: controlCenterTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: controlCenterColumn.implicitHeight + 36

                Column {
                    id: controlCenterColumn

                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    CommandRow {
                        title: "Caffeine Command"
                        description: "Adds a caffeine button to the Display card. The command must accept toggle and status; status prints on or off"
                        keyName: "idleInhibitCommand"
                        placeholderText: "Not set"
                        width: parent.width
                    }
                }
            }

            Text {
                id: tlpTitle
                text: "Power Profiles"
                anchors.top: controlCenterPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            TlpSettings {
                id: tlpPanel
                anchors.top: tlpTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }

            Text {
                id: weatherTitle
                text: "Weather"
                anchors.top: tlpPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            WeatherSettings {
                id: weatherPanel
                anchors.top: weatherTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }

        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component ConfigRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string keyName: ""
        property string fallbackText: ""
        property bool numeric: false
        property int minimumValue: 1
        property int maximumValue: 1000

        height: 49

        Text {
            id: rowTitle
            text: row.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: row.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            anchors.left: rowTitle.left
            color: Theme.subtleTextColor
        }

        ConfigTextField {
            id: field
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: row.numeric ? 100 : 230
            height: 36
            placeholderText: row.fallbackText
            inputMethodHints: row.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: row.numeric ? intValidator : null

            Component.onCompleted: {
                text = root.intValue(row.keyName, Number(row.fallbackText))
            }

            onAccepted: row.commit()
            onEditingFinished: row.commit()
        }

        IntValidator {
            id: intValidator
            bottom: row.minimumValue
            top: row.maximumValue
        }

        function commit() {
            if (numeric) {
                field.text = String(root.saveInt(row.keyName, field.text, Number(row.fallbackText), row.minimumValue, row.maximumValue))
            }
        }
    }

    component ClockFormatRow: Item {
        id: clockRow

        property string selectedFormat: String(ConfigStore.value("clockFormat", "12")) === "24" ? "24" : "12"

        height: 49

        Text {
            id: clockTitle
            text: "Clock Format"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Choose 12-hour or 24-hour time"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: clockTitle.bottom
            anchors.topMargin: 5
            anchors.left: clockTitle.left
            color: Theme.subtleTextColor
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: ["12", "24"]

                Rectangle {
                    id: formatButton
                    readonly property bool selected: clockRow.selectedFormat === modelData

                    width: 82
                    height: 36
                    radius: 7
                    color: selected ? Theme.cardBgColor
                                    : formatMouse.pressed ? Theme.controlPressedColor
                                                          : Theme.componentBgColor
                    border.width: 1
                    border.color: Theme.inputBorderColor

                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData + " hour"
                        color: formatButton.selected ? Theme.textColor : Theme.secondaryTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: formatButton.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: formatMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clockRow.selectedFormat = modelData
                            ConfigStore.setValue("clockFormat", modelData)
                            ConfigStore.save()
                        }
                    }
                }
            }
        }
    }

    component ChoiceRow: Item {
        id: choiceRow

        property string title: ""
        property string description: ""
        property string keyName: ""
        property var options: []
        property string selectedId: ""

        height: 49

        Text {
            id: choiceTitle
            text: choiceRow.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: choiceRow.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: choiceTitle.bottom
            anchors.topMargin: 5
            anchors.left: choiceTitle.left
            width: Math.max(80, parent.width - choiceButtons.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
        }

        Row {
            id: choiceButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: choiceRow.options

                Rectangle {
                    id: choiceButton
                    readonly property bool selected: choiceRow.selectedId === modelData.id

                    width: 82
                    height: 36
                    radius: 7
                    color: selected ? Theme.cardBgColor
                                    : choiceMouse.pressed ? Theme.controlPressedColor
                                                          : Theme.componentBgColor
                    border.width: 1
                    border.color: Theme.inputBorderColor

                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: choiceButton.selected ? Theme.textColor : Theme.secondaryTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: choiceButton.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: choiceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            choiceRow.selectedId = modelData.id
                            ConfigStore.setValue(choiceRow.keyName, modelData.id)
                            ConfigStore.save()
                        }
                    }
                }
            }
        }
    }

    component CommandRow: Item {
        id: commandRow

        property string title: ""
        property string description: ""
        property string keyName: ""
        property string placeholderText: ""

        height: Math.max(49, commandLabels.implicitHeight)

        function savedText() {
            return String(ConfigStore.value(commandRow.keyName, ""))
        }

        function commit() {
            const val = commandField.text.trim()
            if (val === commandRow.savedText())
                return
            if (val.length === 0)
                ConfigStore.remove(commandRow.keyName)
            else
                ConfigStore.setValue(commandRow.keyName, val)
            ConfigStore.save()
        }

        Column {
            id: commandLabels
            anchors.left: parent.left
            anchors.right: commandControls.left
            anchors.rightMargin: 18
            anchors.top: parent.top
            spacing: 5

            Text {
                text: commandRow.title
                font.family: Theme.textFontFamily
                font.pixelSize: 18
                color: Theme.textColor
            }

            Text {
                width: parent.width
                text: commandRow.description
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                color: Theme.subtleTextColor
                wrapMode: Text.Wrap
            }
        }

        Row {
            id: commandControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            ConfigTextField {
                id: commandField
                width: Math.max(160, Math.min(260, (commandRow.width - 320) / 2))
                height: 36
                placeholderText: commandRow.placeholderText
                textPixelSize: 13

                Component.onCompleted: {
                    text = commandRow.savedText()
                }

                onAccepted: commandRow.commit()
                onEditingFinished: commandRow.commit()
            }

            ButtonLike {
                text: "Clear"
                enabled: commandField.text.length > 0 || commandRow.savedText().length > 0
                onClicked: {
                    commandField.text = ""
                    commandRow.commit()
                }
            }
        }
    }

    component ButtonLike: Rectangle {
        id: button

        signal clicked

        property string text: ""
        property bool primary: false

        width: 76
        height: 36
        radius: 6
        color: !button.enabled ? Theme.componentBgColor
                               : button.primary
                                   ? mouseArea.pressed ? Theme.buttonPressedColor
                                                       : mouseArea.containsMouse ? Theme.buttonHoverColor
                                                                                : Theme.buttonColor
                                   : mouseArea.pressed ? Theme.controlPressedColor
                                                       : mouseArea.containsMouse ? Theme.mutedButtonHoverColor
                                                                                : Theme.mutedButtonColor
        border.width: 1
        border.color: button.primary && button.enabled ? color : Theme.inputBorderColor

        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
        Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: !button.enabled ? Theme.subtleTextColor
                                   : button.primary ? Theme.buttonTextColor
                                                    : Theme.mutedButtonTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    component AvatarRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string keyName: "avatarPath"
        property int avatarVersion: 0

        height: 64

        function cleanHome() {
            let h = backend.homeDirectory || "";
            if (!h) {
                h = String(StandardPaths.writableLocation(StandardPaths.HomeLocation) || "");
                if (h.startsWith("file://"))
                    h = h.substring(7);
            }
            return h.replace(/\/+$/, "");
        }

        function resolveAvatarUrl(path) {
            if (!path || path.trim() === "")
                return "";
            let clean = path.trim();
            if (clean.startsWith("~")) {
                clean = cleanHome() + clean.substring(1);
            }
            if (clean.startsWith("/")) {
                return "file://" + clean;
            }
            return clean;
        }

        function effectiveAvatarSource() {
            const dummy = avatarVersion;
            const currentFieldText = (typeof field !== "undefined" && field && field.text) ? field.text.trim() : "";
            const custom = currentFieldText.length > 0 ? currentFieldText : ConfigStore.value(row.keyName, "");
            if (custom && String(custom).trim().length > 0)
                return resolveAvatarUrl(String(custom));

            const disp = ConfigStore.value("displayPicture", "");
            if (disp && String(disp).trim().length > 0)
                return resolveAvatarUrl(String(disp));

            return "file://" + cleanHome() + "/.config/tide-island/avatar.png";
        }

        DropArea {
            id: rowDropArea
            anchors.fill: parent
            onDropped: function(drop) {
                let p = "";
                if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
                    let u = drop.urls[0];
                    p = (typeof u.toLocalFile === "function") ? u.toLocalFile() : String(u);
                } else if (drop.hasText) {
                    p = drop.text.trim();
                }
                if (p.length > 0) {
                    if (p.startsWith("file://")) {
                        p = decodeURIComponent(p.substring(7));
                    }
                    row.setPath(p);
                }
            }
        }

        Item {
            id: avatarContainer
            width: 52
            height: 52
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 26
                color: Theme.componentBgColor
                border.width: 1
                border.color: (rowDropArea.containsDrag || avatarMouseArea.containsMouse) ? Theme.accentColor : Theme.inputBorderColor
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            Text {
                id: monogramText
                anchors.centerIn: parent
                visible: !avatarContainer.hasValidImage
                text: {
                    const home = row.cleanHome();
                    const parts = home.split('/');
                    const user = parts.length > 0 ? parts[parts.length - 1] : "U";
                    return user.charAt(0).toUpperCase();
                }
                font.family: Theme.textFontFamily
                font.pixelSize: 20
                font.weight: Font.Bold
                color: Theme.accentColor
            }

            Image {
                id: rawImage
                anchors.fill: parent
                source: row.effectiveAvatarSource()
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
                cache: false
            }

            Rectangle {
                id: circleMask
                anchors.fill: parent
                radius: 26
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: rawImage
                maskEnabled: true
                maskSource: circleMask
                visible: avatarContainer.hasValidImage
            }

            readonly property bool hasValidImage: rawImage.status === Image.Ready && (rawImage.source != "")

            Rectangle {
                anchors.fill: parent
                radius: 26
                color: Qt.rgba(0, 0, 0, 0.45)
                opacity: (rowDropArea.containsDrag || avatarMouseArea.containsMouse) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: rowDropArea.containsDrag ? "Drop" : "Change"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
            }

            MouseArea {
                id: avatarMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: avatarFileDialog.openForPath(field.text)
            }
        }

        Column {
            anchors.left: avatarContainer.right
            anchors.leftMargin: 16
            anchors.right: controlsRow.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                text: row.title
                font.family: Theme.textFontFamily
                font.pixelSize: 18
                color: Theme.textColor
            }

            Text {
                text: row.description
                font.family: Theme.textFontFamily
                font.pixelSize: 13
                color: Theme.subtleTextColor
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Row {
            id: controlsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            ConfigTextField {
                id: field
                width: Math.max(160, Math.min(260, (row.width - 320) / 2))
                height: 36
                placeholderText: "Auto-detect (~/.face, avatar.png)"
                textPixelSize: 13

                Component.onCompleted: {
                    text = String(ConfigStore.value(row.keyName, ""))
                }

                onAccepted: row.commit()
                onEditingFinished: row.commit()
            }

            ButtonLike {
                id: saveBtn
                text: "Save"
                primary: true
                visible: field.text.trim() !== String(ConfigStore.value(row.keyName, ""))
                onClicked: row.commit()
            }

            ButtonLike {
                text: "Browse"
                primary: !saveBtn.visible
                onClicked: avatarFileDialog.openForPath(field.text)
            }

            ButtonLike {
                text: "Clear"
                enabled: field.text.length > 0 || (ConfigStore.value(row.keyName, "") !== "")
                onClicked: row.clear()
            }
        }

        function setPath(path) {
            field.text = path;
            commit();
        }

        function clear() {
            field.text = "";
            ConfigStore.remove(row.keyName);
            ConfigStore.save();
            avatarVersion++;
        }

        function commit() {
            const val = field.text.trim();
            if (val.length === 0) {
                clear();
            } else {
                ConfigStore.setValue(row.keyName, val);
                ConfigStore.save();
                avatarVersion++;
            }
        }
    }

    component SwitchRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string keyName: ""
        property bool fallbackValue: true

        height: 49

        Text {
            id: switchTitle
            text: row.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: row.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: switchTitle.bottom
            anchors.topMargin: 5
            anchors.left: switchTitle.left
            width: Math.max(80, parent.width - sw.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
        }

        StyledSwitch {
            id: sw
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.boolValue(row.keyName, row.fallbackValue)

            onToggled: function(checked) {
                ConfigStore.setValue(row.keyName, checked)
                ConfigStore.save()
            }
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
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                control.checked = !control.checked
                control.toggled(control.checked)
            }
        }
    }

}
