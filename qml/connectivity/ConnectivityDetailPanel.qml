import QtQuick
import IslandBackend
import "../common"

Item {
    id: root

    property var provider: null
    property string panelKind: "wifi"
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string heroFontFamily: textFontFamily
    property real presentationProgress: 1
    implicitHeight: contentFlick.y + contentFlick.contentHeight + contentRoot.anchors.margins * 2

    readonly property bool isWifi: panelKind === "wifi"
    readonly property bool isBluetooth: panelKind === "bluetooth"
    readonly property bool isPower: panelKind === "power"
    readonly property var bluetoothDevices: provider ? provider.bluetoothDeviceValues || [] : []
    readonly property var bluetoothConnectedDevices: bluetoothDevicesForSection("connected")
    readonly property var bluetoothPairedDevices: bluetoothDevicesForSection("paired")
    readonly property var bluetoothAvailableDevices: bluetoothDevicesForSection("available")
    readonly property int bluetoothDeviceCount: bluetoothConnectedDevices.length
        + bluetoothPairedDevices.length
        + bluetoothAvailableDevices.length
    readonly property bool bluetoothScanning: provider && provider.bluetoothAdapter
        ? provider.bluetoothAdapter.discovering
        : !!(provider && provider.bluetoothListRunning)
    readonly property var batteryFacts: isPower ? buildBatteryFacts() : []
    // Offered power profiles as the control center's mode indexes (0 saver, 1 balanced, 2 performance).
    readonly property var powerProfileIndexes: {
        if (!isPower || !provider || !provider.tlpControlsEnabled || !provider.batteryTlpAvailable)
            return [];
        const indexes = [];
        const profiles = SystemServices.powerProfiles;
        for (let i = 0; i < profiles.length; i++) {
            const index = provider.batteryModeIndexForCommand(profiles[i]);
            if (indexes.indexOf(index) < 0)
                indexes.push(index);
        }
        return indexes.sort();
    }

    function formatDuration(seconds) {
        const minutes = Math.round(seconds / 60);
        if (minutes < 60)
            return minutes + " min";
        const rest = minutes % 60;
        return Math.floor(minutes / 60) + " h" + (rest > 0 ? " " + rest + " min" : "");
    }

    function buildBatteryFacts() {
        const status = SystemGlance.batteryStatus;
        const capacity = provider && provider.batteryCapacity > 0 ? provider.batteryCapacity : SystemGlance.batteryCapacity;
        const facts = [
            { label: "Status", value: status === "Not charging" ? "Plugged in, not charging" : (status || "Unknown") },
            { label: "Capacity", value: capacity + "%" }
        ];
        const watts = SystemGlance.batteryPowerWatts;
        if (watts > 0.05) {
            const sign = status === "Charging" ? "+" : (status === "Discharging" ? "\u2212" : "");
            facts.push({ label: "Power", value: sign + watts.toFixed(1) + " W" });
        }
        if (status === "Discharging" && SystemGlance.batteryTimeToEmptySeconds > 0)
            facts.push({ label: "Time to empty", value: formatDuration(SystemGlance.batteryTimeToEmptySeconds) });
        else if (status === "Charging" && SystemGlance.batteryTimeToFullSeconds > 0)
            facts.push({ label: "Time to full", value: formatDuration(SystemGlance.batteryTimeToFullSeconds) });
        facts.push({ label: "Health", value: SystemGlance.batteryHealthPercent + "%" });
        if (SystemGlance.batteryCycleCount > 0)
            facts.push({ label: "Cycle count", value: String(SystemGlance.batteryCycleCount) });
        return facts;
    }

    function safeString(value) {
        return value === undefined || value === null ? "" : String(value);
    }

    function wifiEntryVisible(connected) {
        if (!root.provider) return false;
        return !(connected && root.provider.wifiEnabled && safeString(root.provider.wifiCurrentSsid).length > 0);
    }

    function bluetoothDeviceVisible(device, section) {
        return root.provider && root.provider.bluetoothDeviceMatchesSection
            ? root.provider.bluetoothDeviceMatchesSection(device, section)
            : false;
    }

    function bluetoothDevicesForSection(section) {
        const devices = root.bluetoothDevices || [];
        const filtered = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (root.bluetoothDeviceVisible(device, section))
                filtered.push(device);
        }

        filtered.sort(function(left, right) {
            const leftNamed = root.provider && root.provider.bluetoothDeviceHasFriendlyName
                ? root.provider.bluetoothDeviceHasFriendlyName(left)
                : false;
            const rightNamed = root.provider && root.provider.bluetoothDeviceHasFriendlyName
                ? root.provider.bluetoothDeviceHasFriendlyName(right)
                : false;
            if (leftNamed !== rightNamed)
                return leftNamed ? -1 : 1;

            const leftName = root.provider && root.provider.bluetoothDeviceName
                ? root.provider.bluetoothDeviceName(left)
                : "";
            const rightName = root.provider && root.provider.bluetoothDeviceName
                ? root.provider.bluetoothDeviceName(right)
                : "";
            return leftName.localeCompare(rightName);
        });

        return filtered;
    }

    function focusPromptField() {
        if (wifiPasswordPrompt.visible) {
            wifiPasswordField.forceActiveFocus();
            return;
        }

        if (bluetoothPairingPrompt.visible && bluetoothSecretField.visible)
            bluetoothSecretField.forceActiveFocus();
    }

    // The Glance only polls while it is open; keep the battery facts live while this view is.
    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.isPower && root.visible
        onTriggered: SystemGlance.refreshBattery()
    }

    Timer {
        id: promptFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusPromptField()
    }

    Keys.onEscapePressed: function(event) {
        if (root.isWifi && root.provider && root.provider.wifiPendingPasswordSsid.length > 0) {
            root.provider.clearWifiPrompt();
            event.accepted = true;
            return;
        }
        if (root.isBluetooth && root.provider && root.provider.bluetoothPairingActive) {
            root.provider.cancelBluetoothPairing();
            event.accepted = true;
            return;
        }
        root.closeRequested();
        event.accepted = true;
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.isWifi && root.provider && root.provider.wifiPendingPasswordSsid.length > 0) {
                root.provider.clearWifiPrompt();
                event.accepted = true;
                return;
            }
            if (root.isBluetooth && root.provider && root.provider.bluetoothPairingActive) {
                root.provider.cancelBluetoothPairing();
                event.accepted = true;
                return;
            }
            root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.isBluetooth && root.provider && root.provider.bluetoothPairingActive && root.provider.bluetoothPairingRequiresConfirmation) {
                root.provider.confirmBluetoothPairing();
                event.accepted = true;
            }
        }
    }

    Connections {
        target: root.provider
        ignoreUnknownSignals: true

        function onWifiPendingPasswordSsidChanged() {
            promptFocusTimer.restart();
        }

        function onBluetoothPairingActiveChanged() {
            promptFocusTimer.restart();
        }
    }

    GlassSurface {
        anchors.fill: parent
    }

    Item {
        id: contentRoot
        anchors.fill: parent
        anchors.margins: 16
        opacity: 0.45 + root.presentationProgress * 0.55

        Behavior on opacity {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 24

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.isWifi ? "Wi-Fi" : root.isBluetooth ? "Bluetooth" : "Battery"
                color: StyleTokens.textPrimary
                font.pixelSize: 15
                font.family: root.heroFontFamily
                font.weight: Font.Bold
            }

            Rectangle {
                id: bluetoothScanButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 58
                height: 24
                radius: 12
                visible: root.isBluetooth && root.provider
                    && root.provider.bluetoothAvailable
                    && root.provider.bluetoothEnabled
                color: bluetoothScanMouse.containsMouse
                    ? StyleTokens.moduleHover
                    : StyleTokens.secondaryButton

                Text {
                    anchors.centerIn: parent
                    text: root.bluetoothScanning ? "Stop" : "Scan"
                    color: root.bluetoothScanning ? StyleTokens.accentSoft : StyleTokens.textPrimary
                    font.pixelSize: 10
                    font.family: root.textFontFamily
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: bluetoothScanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.provider)
                            root.provider.toggleBluetoothScan();
                    }
                }
            }
        }

        Column {
            id: topSection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerRow.bottom
            anchors.topMargin: root.isPower ? 10 : 14
            spacing: 10

            Rectangle {
                width: parent.width
                height: visible ? 64 : 0
                radius: 10
                color: StyleTokens.transparent
                visible: root.isWifi && root.provider && root.provider.wifiEnabled && root.provider.wifiCurrentSsid.length > 0

                MouseArea {
                    anchors.fill: parent
                    enabled: root.provider
                        && root.provider.wifiSupported
                        && root.provider.wifiAvailable
                        && !root.provider.wifiBusy
                    onClicked: {
                        if (root.provider)
                            root.provider.disconnectWifi();
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 14

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.provider ? root.provider.wifiGlyph : ""
                        color: StyleTokens.accent
                        font.pixelSize: 16
                        font.family: root.iconFontFamily
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        text: root.provider ? root.provider.wifiCurrentSsid : ""
                        color: StyleTokens.textPrimary
                        font.pixelSize: 12
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.bottom: parent.bottom
                        text: "Connected"
                        color: StyleTokens.textSoft
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✓"
                        color: StyleTokens.success
                        font.pixelSize: 18
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.wifiAvailabilityMessage.length > 0 && root.isWifi
                text: root.provider ? root.provider.wifiAvailabilityMessage : ""
                color: StyleTokens.textMuted
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.wifiInfoMessage.length > 0 && root.isWifi
                text: root.provider ? root.provider.wifiInfoMessage : ""
                color: StyleTokens.accentSoft
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.wifiError.length > 0 && root.isWifi
                text: root.provider ? root.provider.wifiError : ""
                color: StyleTokens.error
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.bluetoothAvailabilityMessage.length > 0 && root.isBluetooth
                text: root.provider ? root.provider.bluetoothAvailabilityMessage : ""
                color: StyleTokens.textMuted
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.bluetoothInfoMessage.length > 0 && root.isBluetooth
                text: root.provider ? root.provider.bluetoothInfoMessage : ""
                color: StyleTokens.accentSoft
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.bluetoothError.length > 0 && root.isBluetooth
                text: root.provider ? root.provider.bluetoothError : ""
                color: StyleTokens.error
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Rectangle {
                id: bluetoothPairingPrompt
                width: parent.width
                height: visible
                    ? ((root.provider && root.provider.bluetoothPairingRequiresInput)
                        ? 122
                        : ((root.provider && root.provider.bluetoothPairingRequiresConfirmation) ? 110 : 82))
                    : 0
                radius: 10
                color: StyleTokens.prompt
                visible: root.isBluetooth && root.provider && root.provider.bluetoothPairingActive
                clip: true

                onVisibleChanged: {
                    if (visible)
                        promptFocusTimer.restart();
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 10

                        Text {
                            width: parent.width
                            text: root.provider ? root.provider.bluetoothPairingTitle : ""
                            color: StyleTokens.textPrimary
                            font.pixelSize: 12
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.provider ? root.provider.bluetoothPairingMessage : ""
                            color: StyleTokens.textSecondary
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            wrapMode: Text.Wrap
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 8
                        visible: root.provider
                            && (root.provider.bluetoothPairingRequiresInput
                                || root.provider.bluetoothPairingRequiresConfirmation)

                        Rectangle {
                            id: bluetoothSecretFieldFrame
                            width: visible
                                ? Math.max(0, parent.width - bluetoothPrimaryButton.width - bluetoothCancelButton.width - 16)
                                : 0
                            height: 34
                            radius: 10
                            color: StyleTokens.input
                            border.color: StyleTokens.inputBorder
                            border.width: 1
                            visible: root.provider && root.provider.bluetoothPairingRequiresInput

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.provider && root.provider.bluetoothPairingNumericInput
                                    ? "Passkey"
                                    : "PIN"
                                color: StyleTokens.textTertiary
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                visible: bluetoothSecretField.text.length === 0 && !bluetoothSecretField.activeFocus
                            }

                            TextInput {
                                id: bluetoothSecretField
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                height: Math.min(parent.height - 8, implicitHeight + 2)
                                color: StyleTokens.textPrimary
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                verticalAlignment: TextInput.AlignVCenter
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                clip: true
                                selectByMouse: true
                                cursorVisible: activeFocus
                                inputMethodHints: root.provider && root.provider.bluetoothPairingNumericInput
                                    ? Qt.ImhDigitsOnly
                                    : Qt.ImhNoPredictiveText
                                maximumLength: root.provider && root.provider.bluetoothPairingNumericInput ? 6 : 16
                                text: root.provider ? root.provider.bluetoothPendingSecretValue : ""
                                onTextChanged: {
                                    if (root.provider)
                                        root.provider.bluetoothPendingSecretValue = text;
                                }
                                Keys.onReturnPressed: {
                                    if (root.provider)
                                        root.provider.submitBluetoothPairingSecret();
                                }
                                Keys.onEnterPressed: {
                                    if (root.provider)
                                        root.provider.submitBluetoothPairingSecret();
                                }
                                Keys.onEscapePressed: {
                                    if (root.provider)
                                        root.provider.cancelBluetoothPairing();
                                }
                            }
                        }

                        Rectangle {
                            id: bluetoothPrimaryButton
                            width: root.provider && root.provider.bluetoothPairingRequiresInput ? 50 : 76
                            height: 34
                            radius: 10
                            color: StyleTokens.accent

                            Text {
                                anchors.centerIn: parent
                                text: root.provider && root.provider.bluetoothPairingRequiresConfirmation
                                    ? "Confirm"
                                    : "Pair"
                                color: StyleTokens.textOnAccent
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!root.provider)
                                        return;

                                    if (root.provider.bluetoothPairingRequiresConfirmation)
                                        root.provider.confirmBluetoothPairing();
                                    else
                                        root.provider.submitBluetoothPairingSecret();
                                }
                            }
                        }

                        Rectangle {
                            id: bluetoothCancelButton
                            width: 58
                            height: 34
                            radius: 10
                            color: StyleTokens.secondaryButton

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: StyleTokens.textPrimary
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.provider)
                                        root.provider.cancelBluetoothPairing();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: wifiPasswordPrompt
                width: parent.width
                height: visible ? 92 : 0
                radius: 10
                color: StyleTokens.prompt
                visible: root.isWifi && root.provider && root.provider.wifiPendingPasswordSsid.length > 0
                clip: true

                onVisibleChanged: {
                    if (visible)
                        promptFocusTimer.restart();
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        text: "Enter password for " + (root.provider ? root.provider.wifiPendingPasswordSsid : "")
                        color: StyleTokens.textPrimary
                        font.pixelSize: 12
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: joinButton.left
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        height: 34
                        radius: 10
                        color: StyleTokens.input
                        border.color: StyleTokens.inputBorder
                        border.width: 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            color: StyleTokens.textTertiary
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            visible: root.provider && root.provider.wifiPendingPasswordValue.length === 0 && !wifiPasswordField.activeFocus
                        }

                        TextInput {
                            id: wifiPasswordField
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: Math.min(parent.height - 8, implicitHeight + 2)
                            color: StyleTokens.textPrimary
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            echoMode: TextInput.Password
                            verticalAlignment: TextInput.AlignVCenter
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            clip: true
                            selectByMouse: true
                            cursorVisible: activeFocus
                            text: root.provider ? root.provider.wifiPendingPasswordValue : ""
                            onTextChanged: {
                                if (root.provider)
                                    root.provider.wifiPendingPasswordValue = text;
                            }
                            Keys.onReturnPressed: {
                                if (root.provider)
                                    root.provider.submitWifiPassword();
                            }
                            Keys.onEnterPressed: {
                                if (root.provider)
                                    root.provider.submitWifiPassword();
                            }
                            Keys.onEscapePressed: {
                                if (root.provider)
                                    root.provider.clearWifiPrompt();
                            }
                        }
                    }

                    Rectangle {
                        id: joinButton
                        anchors.right: cancelButton.left
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        width: 50
                        height: 34
                        radius: 10
                        color: StyleTokens.accent

                        Text {
                            anchors.centerIn: parent
                            text: "Join"
                            color: StyleTokens.textOnAccent
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.provider)
                                    root.provider.submitWifiPassword();
                            }
                        }
                    }

                    Rectangle {
                        id: cancelButton
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 50
                        height: 34
                        radius: 10
                        color: StyleTokens.secondaryButton

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: StyleTokens.textPrimary
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.provider)
                                    root.provider.clearWifiPrompt();
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: contentFlick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topSection.bottom
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentColumn
                width: contentFlick.width
                spacing: 8

                // Battery facts, each shown once: status, capacity, power, time, health, cycles
                Rectangle {
                    visible: root.isPower
                    width: parent.width
                    height: batteryFactsColumn.implicitHeight + 12
                    radius: 10
                    color: StyleTokens.secondaryButton

                    Column {
                        id: batteryFactsColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 6

                        Repeater {
                            model: root.batteryFacts

                            delegate: Item {
                                id: batteryFactRow
                                required property var modelData
                                width: batteryFactsColumn.width
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: batteryFactRow.modelData.label
                                    color: StyleTokens.textMuted
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: batteryFactRow.modelData.value
                                    color: StyleTokens.textPrimary
                                    font.pixelSize: 12
                                    font.family: root.textFontFamily
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.isPower && SystemServices.batteryThresholdSupported
                    width: parent.width
                    height: thresholdContentCol.implicitHeight + 20
                    radius: 10
                    color: StyleTokens.secondaryButton

                    Column {
                        id: thresholdContentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 18

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: ""
                                    color: StyleTokens.accent
                                    font.pixelSize: 12
                                    font.family: root.iconFontFamily
                                }

                                Text {
                                    text: "Charge Limit"
                                    color: StyleTokens.textPrimary
                                    font.pixelSize: 12
                                    font.family: root.textFontFamily
                                    font.weight: Font.DemiBold
                                }
                            }

                            // The value; when the limit is writable the selected preset shows it instead.
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (SystemServices.batteryThresholdBusy)
                                        return "Applying...";
                                    if (SystemServices.batteryThresholdWritable)
                                        return "";
                                    if (SystemServices.batteryThresholdType === "conservation")
                                        return SystemServices.batteryConservationMode ? "80%" : "100%";
                                    return SystemServices.batteryThresholdValue + "%";
                                }
                                color: SystemServices.batteryThresholdBusy ? StyleTokens.warning : StyleTokens.textPrimary
                                font.pixelSize: 12
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                            }
                        }

                        // Lenovo IdeaPad conservation mode
                        Row {
                            visible: SystemServices.batteryThresholdType === "conservation" && SystemServices.batteryThresholdWritable
                            width: parent.width
                            spacing: 8

                            readonly property real pillWidth: (width - spacing) / 2

                            Rectangle {
                                width: parent.pillWidth
                                height: 32
                                radius: 10
                                color: SystemServices.batteryConservationMode ? StyleTokens.accent : StyleTokens.moduleHover
                                opacity: SystemServices.batteryThresholdBusy ? 0.6 : 1.0

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "80% Conservation"
                                    color: SystemServices.batteryConservationMode ? StyleTokens.textOnAccent : StyleTokens.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    font.weight: SystemServices.batteryConservationMode ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !SystemServices.batteryThresholdBusy
                                    onClicked: SystemServices.setBatteryConservationMode(true)
                                }
                            }

                            Rectangle {
                                width: parent.pillWidth
                                height: 32
                                radius: 10
                                color: !SystemServices.batteryConservationMode ? StyleTokens.accent : StyleTokens.moduleHover
                                opacity: SystemServices.batteryThresholdBusy ? 0.6 : 1.0

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "100% Full Charge"
                                    color: !SystemServices.batteryConservationMode ? StyleTokens.textOnAccent : StyleTokens.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    font.weight: !SystemServices.batteryConservationMode ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !SystemServices.batteryThresholdBusy
                                    onClicked: SystemServices.setBatteryConservationMode(false)
                                }
                            }
                        }

                        // Generic end thresholds (ThinkPad, ASUS, Apple Silicon, etc.)
                        Row {
                            id: thresholdPresetsRow
                            visible: SystemServices.batteryThresholdType === "threshold" && SystemServices.batteryThresholdWritable
                            width: parent.width
                            spacing: 6

                            readonly property var presets: SystemServices.batteryThresholdPresets

                            Repeater {
                                model: thresholdPresetsRow.presets

                                delegate: Rectangle {
                                    readonly property bool active: SystemServices.batteryThresholdValue === modelData
                                    width: (thresholdPresetsRow.width - thresholdPresetsRow.spacing * (thresholdPresetsRow.presets.length - 1))
                                        / Math.max(1, thresholdPresetsRow.presets.length)
                                    height: 32
                                    radius: 10
                                    color: active ? StyleTokens.accent : StyleTokens.moduleHover
                                    opacity: SystemServices.batteryThresholdBusy ? 0.6 : 1.0

                                    Behavior on color {
                                        ColorAnimation { duration: 90 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "%"
                                        color: active ? StyleTokens.textOnAccent : StyleTokens.textPrimary
                                        font.pixelSize: 11
                                        font.family: root.textFontFamily
                                        font.weight: active ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !SystemServices.batteryThresholdBusy
                                        onClicked: SystemServices.setBatteryThreshold(modelData)
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: SystemServices.batteryThresholdError.length > 0
                                ? SystemServices.batteryThresholdError
                                : (SystemServices.batteryThresholdWritable ? "" : "Read-only for this user.")
                            color: SystemServices.batteryThresholdError.length > 0 ? StyleTokens.danger : StyleTokens.textMuted
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Power profiles, when a driver (power-profiles-daemon or TLP) answers
                Rectangle {
                    visible: root.isPower && root.powerProfileIndexes.length > 0
                    width: parent.width
                    height: powerModeColumn.implicitHeight + 20
                    radius: 10
                    color: StyleTokens.secondaryButton

                    Column {
                        id: powerModeColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 18

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: ""
                                    color: StyleTokens.accent
                                    font.pixelSize: 12
                                    font.family: root.iconFontFamily
                                }

                                Text {
                                    text: "Power Mode"
                                    color: StyleTokens.textPrimary
                                    font.pixelSize: 12
                                    font.family: root.textFontFamily
                                    font.weight: Font.DemiBold
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.provider && root.provider.batteryModeBusy
                                text: "Applying..."
                                color: StyleTokens.warning
                                font.pixelSize: 12
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                            }
                        }

                        Row {
                            id: powerModeRow
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.powerProfileIndexes

                                delegate: Rectangle {
                                    id: powerModePill
                                    required property int modelData
                                    readonly property bool active: root.provider && root.provider.batteryModeIndex === modelData
                                    width: (powerModeRow.width - powerModeRow.spacing * (root.powerProfileIndexes.length - 1))
                                        / Math.max(1, root.powerProfileIndexes.length)
                                    height: 32
                                    radius: 10
                                    color: active ? StyleTokens.accent : StyleTokens.moduleHover
                                    opacity: root.provider && root.provider.batteryModeBusy ? 0.6 : 1.0

                                    Behavior on color {
                                        ColorAnimation { duration: 90 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.provider ? root.provider.batteryModeLabel(powerModePill.modelData) : ""
                                        color: powerModePill.active ? StyleTokens.textOnAccent : StyleTokens.textPrimary
                                        font.pixelSize: 11
                                        font.family: root.textFontFamily
                                        font.weight: powerModePill.active ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.provider)
                                                root.provider.selectBatteryMode(powerModePill.modelData);
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: root.provider ? root.provider.batteryModeError : ""
                            color: StyleTokens.danger
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.isWifi && root.provider
                        && root.provider.wifiSupported
                        && root.provider.wifiAvailable
                        && !root.provider.wifiEnabled
                    text: "Turn on Wi-Fi to see nearby networks."
                    color: StyleTokens.textMuted
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: root.isWifi && root.provider && root.provider.wifiListRunning
                    text: "Scanning nearby networks..."
                    color: StyleTokens.textMuted
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                }

                Repeater {
                    model: root.isWifi && root.provider ? root.provider.wifiNetworks : null

                    delegate: Rectangle {
                        width: contentColumn.width
                        height: visible ? 52 : 0
                        radius: 10
                        color: StyleTokens.transparent
                        visible: root.wifiEntryVisible(connected)
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.provider
                                && root.provider.wifiSupported
                                && root.provider.wifiAvailable
                                && root.provider.wifiEnabled
                                && !root.provider.wifiBusy
                            onClicked: {
                                if (!root.provider) return;
                                root.provider.connectWifiNetwork({
                                    ssid: ssid,
                                    type: type,
                                    secure: secure,
                                    savedConnection: savedConnection,
                                    connected: connected
                                });
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 12

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.provider ? root.provider.wifiGlyph : ""
                                color: connected ? StyleTokens.accent : StyleTokens.disabledControl
                                font.pixelSize: 14
                                font.family: root.iconFontFamily
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 26
                                anchors.top: parent.top
                                anchors.right: rightInfo.left
                                anchors.rightMargin: 8
                                text: displayName
                                color: StyleTokens.textPrimary
                                font.pixelSize: 12
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 26
                                anchors.bottom: parent.bottom
                                anchors.right: rightInfo.left
                                anchors.rightMargin: 8
                                text: secure ? "Secure network" : "Open network"
                                color: StyleTokens.textMuted
                                font.pixelSize: 10
                                font.family: root.textFontFamily
                                elide: Text.ElideRight
                            }

                            Row {
                                id: rightInfo
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: signal + "%"
                                    color: StyleTokens.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    visible: signal >= 0
                                }

                                Text {
                                    text: ""
                                    color: StyleTokens.textSubtle
                                    font.pixelSize: 11
                                    font.family: root.iconFontFamily
                                    visible: secure
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.isBluetooth && root.provider && root.provider.bluetoothAvailable && !root.provider.bluetoothEnabled
                    text: "Turn on Bluetooth to see nearby devices."
                    color: StyleTokens.textMuted
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: root.isBluetooth && root.provider
                        && root.provider.bluetoothEnabled
                        && root.bluetoothScanning
                    text: "Scanning nearby devices..."
                    color: StyleTokens.textMuted
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                }

                Text {
                    width: parent.width
                    visible: root.isBluetooth && root.provider
                        && root.provider.bluetoothEnabled
                        && !root.bluetoothScanning
                        && root.bluetoothDeviceCount === 0
                    text: "No devices found. Put your device in pairing mode, then scan again."
                    color: StyleTokens.textMuted
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                    wrapMode: Text.Wrap
                }

                Item {
                    width: parent.width
                    height: btConnectedSection.visible ? btConnectedSection.implicitHeight : 0
                    visible: root.isBluetooth && root.bluetoothConnectedDevices.length > 0

                    Column {
                        id: btConnectedSection
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Connected"
                            color: StyleTokens.textTertiary
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: root.bluetoothConnectedDevices

                            delegate: BluetoothDeviceRow {
                                width: btConnectedSection.width
                                provider: root.provider
                                device: modelData
                                section: "connected"
                                iconFontFamily: root.iconFontFamily
                                textFontFamily: root.textFontFamily
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: btPairedSection.visible ? btPairedSection.implicitHeight : 0
                    visible: root.isBluetooth && root.bluetoothPairedDevices.length > 0

                    Column {
                        id: btPairedSection
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Paired"
                            color: StyleTokens.textTertiary
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: root.bluetoothPairedDevices

                            delegate: BluetoothDeviceRow {
                                width: btPairedSection.width
                                provider: root.provider
                                device: modelData
                                section: "paired"
                                iconFontFamily: root.iconFontFamily
                                textFontFamily: root.textFontFamily
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: btAvailableSection.visible ? btAvailableSection.implicitHeight : 0
                    visible: root.isBluetooth && root.bluetoothAvailableDevices.length > 0

                    Column {
                        id: btAvailableSection
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Available"
                            color: StyleTokens.textTertiary
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: root.bluetoothAvailableDevices

                            delegate: BluetoothDeviceRow {
                                width: btAvailableSection.width
                                provider: root.provider
                                device: modelData
                                section: "available"
                                iconFontFamily: root.iconFontFamily
                                textFontFamily: root.textFontFamily
                            }
                        }
                    }
                }
            }
        }

    }
}
