import QtQuick
import IslandBackend

Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal transientRequested(string icon, real progress, string text)

    // The resting music section and the expanded player show the visualizer while on screen.
    property bool lyricsCavaActive: false

    readonly property string systemServicesClientId: "island-system-state-" + Math.random().toString(36).slice(2)
    readonly property string defaultStatusIcon: "\ud83c\udfa7"
    readonly property string volumeStatusIcon: "\ueb75"
    readonly property string muteStatusIcon: "\ueb24"
    readonly property string brightnessLowStatusIcon: "\u{F00DE}"
    readonly property string brightnessMediumStatusIcon: "\u{F00DF}"
    readonly property string brightnessHighStatusIcon: "\u{F00E0}"
    readonly property string chargingStatusIcon: "\uf0e7"
    readonly property string dischargingStatusIcon: "\uf244"
    readonly property string bluetoothStatusIcon: "\u{F02CB}"
    readonly property string micStatusIcon: "\uf130"
    readonly property string micMuteStatusIcon: "\uf131"

    property int batteryCapacity: (typeof SysBackend !== "undefined" && SysBackend.batteryCapacity > 0)
        ? SysBackend.batteryCapacity
        : (typeof SystemGlance !== "undefined" && SystemGlance.batteryCapacity > 0 ? SystemGlance.batteryCapacity : 0)
    property bool isCharging: {
        const s = (typeof SysBackend !== "undefined" && SysBackend.batteryStatus !== "" && SysBackend.batteryStatus !== "Unknown")
            ? SysBackend.batteryStatus
            : (typeof SystemGlance !== "undefined" ? SystemGlance.batteryStatus : "");
        return s === "Charging" || s === "Full";
    }
    property real currentVolume: -1
    property bool isMuted: false
    property real currentMicVolume: -1
    property bool isMicMuted: false
    property real currentBrightness: -1
    property var cavaLevels: [0, 0, 0, 0, 0]

    property string _lastChargeStatus: SysBackend.batteryStatus
    property string _pendingVolType: ""
    property real _pendingVolVal: 0.0
    property string _lastVolType: ""
    property real _lastVolVal: -1.0
    property string _pendingMicType: ""
    property real _pendingMicVal: 0.0
    property string _lastMicType: ""
    property real _lastMicVal: -1.0
    property bool _bluetoothVolumeSuppressed: false
    property real _pendingBrightnessValue: 0.0

    onLyricsCavaActiveChanged: updateCavaSubscription()
    Component.onCompleted: {
        refreshMissingValues();
        updateCavaSubscription();
        SystemServices.requestMicVolume();
    }

    Component.onDestruction: SystemServices.setCavaClientActive(systemServicesClientId, false)

    function statusIcon(name) {
        switch (name) {
        case "default":
            return defaultStatusIcon;
        case "volume":
            return volumeStatusIcon;
        case "mute":
            return muteStatusIcon;
        case "mic":
            return micStatusIcon;
        case "micMute":
            return micMuteStatusIcon;
        case "brightnessLow":
            return brightnessLowStatusIcon;
        case "brightnessMedium":
            return brightnessMediumStatusIcon;
        case "brightnessHigh":
            return brightnessHighStatusIcon;
        case "charging":
            return chargingStatusIcon;
        case "discharging":
            return dischargingStatusIcon;
        case "bluetooth":
            return bluetoothStatusIcon;
        default:
            return "";
        }
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function brightnessStatusIcon(value) {
        if (value < 0.3) return statusIcon("brightnessLow");
        if (value < 0.7) return statusIcon("brightnessMedium");
        return statusIcon("brightnessHigh");
    }

    function refreshMissingValues() {
        if (batteryCapacity <= 0) {
            if (typeof SysBackend !== "undefined" && SysBackend.batteryCapacity > 0)
                batteryCapacity = SysBackend.batteryCapacity;
            else if (typeof SystemGlance !== "undefined" && SystemGlance.batteryCapacity > 0)
                batteryCapacity = SystemGlance.batteryCapacity;
        }
        if (currentBrightness < 0)
            SystemServices.requestBrightness();
        if (currentVolume < 0)
            SystemServices.requestVolume();
    }

    function updateCavaSubscription() {
        const active = lyricsCavaActive;
        SystemServices.setCavaClientActive(systemServicesClientId, active);
        if (active)
            cavaLevels = SystemServices.cavaLevels;
    }

    Timer {
        id: bluetoothVolumeSuppressionTimer

        interval: 2000

        onTriggered: root._bluetoothVolumeSuppressed = false
    }

    Timer {
        id: volumeDebounce

        interval: 16

        onTriggered: {
            // The first reading after startup is a silent baseline, not a change.
            if (root._lastVolType === "") {
                root._lastVolType = root._pendingVolType;
                root._lastVolVal = root._pendingVolVal;
                return;
            }
            if (root._bluetoothVolumeSuppressed) return;
            if (root._pendingVolType !== root._lastVolType
                    || Math.abs(root._pendingVolVal - root._lastVolVal) > 0.001) {
                root._lastVolType = root._pendingVolType;
                root._lastVolVal = root._pendingVolVal;
                root.transientRequested(
                    root._pendingVolType === "MUTE" ? root.statusIcon("mute") : root.statusIcon("volume"),
                    root._pendingVolVal,
                    ""
                );
            }
        }
    }

    Timer {
        id: micDebounce

        interval: 16

        onTriggered: {
            if (root._lastMicType === "") {
                root._lastMicType = root._pendingMicType;
                root._lastMicVal = root._pendingMicVal;
                return;
            }
            if (root._pendingMicType !== root._lastMicType
                    || Math.abs(root._pendingMicVal - root._lastMicVal) > 0.001) {
                root._lastMicType = root._pendingMicType;
                root._lastMicVal = root._pendingMicVal;
                root.transientRequested(
                    root._pendingMicType === "MIC_MUTE" ? root.statusIcon("micMute") : root.statusIcon("mic"),
                    root._pendingMicVal,
                    ""
                );
            }
        }
    }

    Timer {
        id: brightnessDebounce

        interval: 16

        onTriggered: root.transientRequested(
            root.brightnessStatusIcon(root._pendingBrightnessValue),
            root._pendingBrightnessValue,
            ""
        )
    }

    Connections {
        target: SystemServices

        function onBrightnessSnapshotReady(value, errorString) {
            if (errorString === "" && value >= 0)
                root.currentBrightness = root.clamp01(value);
        }

        function onVolumeSnapshotReady(value, muted, errorString) {
            if (errorString !== "" || value < 0)
                return;
            root.currentVolume = root.clamp01(value);
            root.isMuted = muted;
        }

        function onMicVolumeSnapshotReady(value, muted, errorString) {
            if (errorString !== "" || value < 0)
                return;
            root.currentMicVolume = root.clamp01(value);
            root.isMicMuted = muted;
        }

        function onCavaLevelsChanged() {
            root.cavaLevels = SystemServices.cavaLevels;
        }
    }

    Connections {
        target: SysBackend

        function onVolumeChanged(volPercentage, isMuted) {
            const nextVolType = isMuted ? "MUTE" : "VOL";
            const nextVolValue = root.clamp01(volPercentage / 100.0);
            const unchanged = root.isMuted === isMuted
                && Math.abs(root.currentVolume - nextVolValue) <= 0.001
                && root._pendingVolType === nextVolType
                && Math.abs(root._pendingVolVal - nextVolValue) <= 0.001;

            if (unchanged)
                return;

            root._pendingVolType = nextVolType;
            root._pendingVolVal = nextVolValue;
            root.currentVolume = nextVolValue;
            root.isMuted = isMuted;
            volumeDebounce.restart();
        }

        function onMicChanged(micPercentage, isMuted) {
            const nextMicType = isMuted ? "MIC_MUTE" : "MIC";
            const nextMicValue = root.clamp01(micPercentage / 100.0);
            const unchanged = root.isMicMuted === isMuted
                && Math.abs(root.currentMicVolume - nextMicValue) <= 0.001
                && root._pendingMicType === nextMicType
                && Math.abs(root._pendingMicVal - nextMicValue) <= 0.001;

            if (unchanged)
                return;

            root._pendingMicType = nextMicType;
            root._pendingMicVal = nextMicValue;
            root.currentMicVolume = nextMicValue;
            root.isMicMuted = isMuted;
            micDebounce.restart();
        }

        function onBatteryCapacityChanged(capacity) {
            if (capacity > 0)
                root.batteryCapacity = capacity;
            else if (typeof SysBackend !== "undefined" && SysBackend.batteryCapacity > 0)
                root.batteryCapacity = SysBackend.batteryCapacity;
        }

        function onBatteryStatusChanged(statusString) {
            if (statusString && statusString !== "" && statusString !== "Unknown")
                root.isCharging = (statusString === "Charging" || statusString === "Full");
        }

        function onBatteryChanged(capacity, statusString) {
            if (capacity > 0)
                root.batteryCapacity = capacity;
            else if (typeof SysBackend !== "undefined" && SysBackend.batteryCapacity > 0)
                root.batteryCapacity = SysBackend.batteryCapacity;
            if (statusString && statusString !== "" && statusString !== "Unknown")
                root.isCharging = (statusString === "Charging" || statusString === "Full");
            if (root._lastChargeStatus !== "" && root._lastChargeStatus !== statusString) {
                if (statusString === "Charging")
                    root.transientRequested(root.statusIcon("charging"), -1.0, "");
                else if (statusString === "Discharging")
                    root.transientRequested(root.statusIcon("discharging"), -1.0, "");
            }
            root._lastChargeStatus = statusString;
        }

        function onBrightnessChanged(value) {
            root._pendingBrightnessValue = value;
            root.currentBrightness = value;
            brightnessDebounce.restart();
        }

        function onBluetoothChanged(isConnected) {
            root._bluetoothVolumeSuppressed = true;
            bluetoothVolumeSuppressionTimer.restart();
            if (isConnected)
                return;

            root.transientRequested(root.statusIcon("bluetooth"), -1.0, "Disconnected");
        }
    }
}
