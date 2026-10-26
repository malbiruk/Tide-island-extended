import QtQuick
import QtQuick.Shapes
import Quickshell.Bluetooth
import Quickshell.Io
import IslandBackend
import "../common/BluetoothFormatting.js" as BluetoothFormatting
import "../island"

Item {
    id: controlCenter

    signal connectivityPanelRequested(string kind, bool open)
    signal requestNotification(string appName, string summary, string body)
    signal weatherRequested()
    signal calendarRequested()
    signal notificationCenterRequested()
    signal powerMenuRequested()
    signal playerPreviousRequested()
    signal playerPlayPauseRequested()
    signal playerNextRequested()
    signal playerDismissRequested()
    signal closeRequested()

    // Shell-wide unread notifications: an accent dot on the header bell.
    property int unreadNotificationCount: 0

    // Media card (fed by the window's MPRIS controller)
    property bool playerCardVisible: false
    property string playerTitle: ""
    property string playerArtist: ""
    property string playerArtUrl: ""
    property bool playerPlaying: false
    property real playerProgress: 0

    // Idle inhibit ("caffeine") through UserConfig.idleInhibitCommand: `<cmd> toggle` / `<cmd> status`.
    readonly property string idleInhibitCommand: UserConfig.idleInhibitCommand
    property bool idleInhibitOn: false
    readonly property bool idleInhibitBusy: idleInhibitToggleProcess.running || idleInhibitStatusProcess.running

    function refreshIdleInhibit() {
        if (idleInhibitCommand !== "" && !idleInhibitStatusProcess.running)
            idleInhibitStatusProcess.running = true;
    }

    function toggleIdleInhibit() {
        if (idleInhibitCommand !== "" && !idleInhibitBusy)
            idleInhibitToggleProcess.running = true;
    }

    Process {
        id: idleInhibitToggleProcess
        command: [controlCenter.idleInhibitCommand, "toggle"]
        running: false
        onExited: controlCenter.refreshIdleInhibit()
    }

    Process {
        id: idleInhibitStatusProcess
        command: [controlCenter.idleInhibitCommand, "status"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                controlCenter.idleInhibitOn = line.trim().toLowerCase() === "on";
            }
        }
    }

    readonly property var userConfig: UserConfig

    property var weatherService: null
    property bool showCondition: false
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    // ... rest of properties ...

    scale: showCondition ? 1.0 : 0.97
    transformOrigin: Item.Top

    Behavior on scale {
        NumberAnimation {
            duration: showCondition ? 140 : 100
            easing.type: Easing.OutCubic
        }
    }
    property string currentTime: "00:00"
    property string currentDateLabel: ""
    property int batteryCapacity: 0
    property bool isCharging: false
    readonly property int effectiveBatteryCap: (controlCenter.batteryCapacity > 0)
        ? controlCenter.batteryCapacity
        : ((typeof SysBackend !== "undefined" && SysBackend.batteryCapacity > 0)
            ? SysBackend.batteryCapacity
            : ((typeof SystemGlance !== "undefined" && SystemGlance.batteryCapacity > 0) ? SystemGlance.batteryCapacity : 0))
    readonly property bool effectiveCharging: controlCenter.isCharging
        || (typeof SysBackend !== "undefined" && (SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"))
        || (typeof SystemGlance !== "undefined" && (SystemGlance.batteryStatus === "Charging" || SystemGlance.batteryStatus === "Full"))
    property real volumeLevel: -1
    property bool volumeMuted: false
    property real brightnessLevel: -1
    property real micLevel: -1
    property bool micMuted: false
    property int sliderIntroDelay: 0
    property int currentWorkspace: 1
    property string currentTrack: ""
    property string currentArtist: ""

    property real localVolume: 0.5
    property real localBrightness: 0.5
    property real localMicVolume: 0.5
    property real displayedVolume: 0.5
    property real displayedBrightness: 0.5
    property real displayedMicVolume: 0.5
    property real pendingVolume: 0.5
    property real pendingBrightness: 0.5
    property real pendingMicVolume: 0.5
    property real lastAppliedVolume: -1
    property real lastAppliedBrightness: -1
    property real lastAppliedMicVolume: -1
    property bool brightnessSetterRunning: false
    property bool volumeSetterRunning: false
    property bool micSetterRunning: false
    property bool sliderIntroPending: false
    property bool readyForCardAnimations: false
    property bool wifiPanelOpen: false
    property bool bluetoothPanelOpen: false
    property bool powerPanelOpen: false
    property bool audioOutputPanelOpen: false
    property bool audioInputPanelOpen: false
    property bool powerViewActive: false
    property bool batteryModeBusy: false
    property bool batteryModeStateRunning: false
    property bool batteryModeSetterRunning: false
    property bool batteryTlpAvailable: false
    property bool batteryTlpChecked: false
    property int batteryModeIndex: 1
    property int batteryModeAppliedIndex: 1
    property int batteryModePendingIndex: 1
    property string batteryModeError: ""
    property string batteryModeLastCommandOutput: ""
    property int batteryModeRefreshPollsRemaining: 0
    // Do-not-disturb is tide's own state, persisted as "doNotDisturb" in userconfig.json.
    readonly property bool focusEnabled: UserConfig.doNotDisturb

    property string wifiLocalInfoMessage: ""
    property string wifiLocalError: ""
    property string wifiPendingPasswordSsid: ""
    property string wifiPendingPasswordValue: ""

    property string bluetoothInfoMessage: ""
    property string bluetoothError: ""
    property string bluetoothPairAndConnectPath: ""
    property string bluetoothPendingSecretValue: ""
    readonly property var wifiController: WifiController
    readonly property var bluetoothPairingAgent: BluetoothPairingAgent
    readonly property var wifiNetworks: wifiController ? wifiController.networks : null

    readonly property real sliderKnobSize: 24
    readonly property color panelColor: StyleTokens.panel
    readonly property color moduleColor: StyleTokens.module
    readonly property color moduleHover: StyleTokens.moduleHover
    readonly property color trackColor: StyleTokens.track
    readonly property color textPrimary: StyleTokens.textPrimary
    readonly property color textSecondary: StyleTokens.textSecondary
    readonly property color cardAccent: StyleTokens.accent
    readonly property color cardAccentPressed: StyleTokens.accentPressed
    readonly property color cardFillActive: StyleTokens.cardFillActive
    readonly property color cardFillHover: StyleTokens.cardFillHover
    readonly property color buttonFill: StyleTokens.buttonFill
    readonly property color buttonFillHover: StyleTokens.buttonFillHover
    readonly property color buttonFillPressed: StyleTokens.buttonFillPressed
    readonly property string wifiGlyph: ""
    readonly property string bluetoothGlyph: ""
    readonly property string brightnessIconGlyph: "\u{F00DF}"
    readonly property string brightnessLowIconGlyph: "\u{F00DE}"
    readonly property string brightnessMediumIconGlyph: "\u{F00DF}"
    readonly property string brightnessHighIconGlyph: "\u{F00E0}"
    readonly property string volumeIconGlyph: "\ueb75"
    readonly property string volumeMuteIconGlyph: "\ueb24"
    readonly property string micIconGlyph: "\uf130"
    readonly property string micMuteIconGlyph: "\uf131"
    readonly property real batteryModeCardHeight: 80
    readonly property real roundToggleButtonSize: 58
    readonly property real roundToggleButtonGap: 18

    readonly property bool isRecording: ScreenRecorder ? ScreenRecorder.isRecording : false
    readonly property bool isReplayActive: ScreenRecorder ? ScreenRecorder.isReplayActive : false
    readonly property real activeRecorderExtraHeight: (activeScreenRecorderCard && activeScreenRecorderCard.visible && activeScreenRecorderCard.height > 0)
        ? activeScreenRecorderCard.height + mainContent.spacing
        : 0
    readonly property real playerCardExtraHeight: playerCard.visible ? playerCard.height + mainContent.spacing : 0

    // The former drawer is now a fixed row (tray / recorder) with no handle.
    readonly property real controlCenterExtraHeight: 12 + batteryModeCardHeight
        + playerCardExtraHeight
        + activeRecorderExtraHeight
    readonly property real controlCenterMaximumExtraHeight: controlCenterExtraHeight
    readonly property bool bluetoothAvailable: !!bluetoothAdapter
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDeviceValues: bluetoothAdapter ? bluetoothAdapter.devices.values : []
    readonly property bool wifiSupported: !!(wifiController && wifiController.supported)
    readonly property bool wifiReadOnly: wifiController && wifiController.readOnly !== undefined ? !!wifiController.readOnly : true
    readonly property bool wifiAvailable: !!(wifiController && wifiController.available)
    readonly property bool wifiEnabled: !!(wifiController && wifiController.enabled)
    readonly property bool wifiBusy: !!(wifiController && wifiController.busy)
    readonly property bool wifiListRunning: !!(wifiController && wifiController.scanning)
    readonly property string wifiCurrentSsid: (wifiController && wifiController.currentSsid) || ""
    readonly property string wifiInfoMessage: wifiLocalInfoMessage.length > 0
        ? wifiLocalInfoMessage
        : ((wifiController && wifiController.infoMessage) || "")
    readonly property string wifiError: wifiLocalError.length > 0
        ? wifiLocalError
        : ((wifiController && wifiController.errorMessage) || "")
    readonly property string wifiUnsupportedReason: (wifiController && wifiController.unsupportedReason) || ""
    readonly property string wifiAvailabilityMessage: {
        if (wifiUnsupportedReason.length > 0) return wifiUnsupportedReason;
        if (wifiSupported && !wifiAvailable) return "No Wi-Fi device is available.";
        return "";
    }
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property bool bluetoothBusy: bluetoothAdapter
        ? bluetoothAdapter.state === BluetoothAdapterState.Enabling
            || bluetoothAdapter.state === BluetoothAdapterState.Disabling
        : false
    readonly property bool bluetoothPairingActive: !!(bluetoothPairingAgent && bluetoothPairingAgent.requestActive)
    readonly property bool bluetoothPairingRequiresInput: !!(bluetoothPairingAgent && bluetoothPairingAgent.requestRequiresInput)
    readonly property bool bluetoothPairingNumericInput: !!(bluetoothPairingAgent && bluetoothPairingAgent.requestNumericInput)
    readonly property bool bluetoothPairingRequiresConfirmation: !!(bluetoothPairingAgent && bluetoothPairingAgent.requestRequiresConfirmation)
    readonly property string bluetoothPairingTitle: (bluetoothPairingAgent && bluetoothPairingAgent.promptTitle) || ""
    readonly property string bluetoothPairingMessage: (bluetoothPairingAgent && bluetoothPairingAgent.promptMessage) || ""
    readonly property string bluetoothPairingDisplayedCode: (bluetoothPairingAgent && bluetoothPairingAgent.displayedCode) || ""
    readonly property bool hasConnectivityPrompt: wifiPendingPasswordSsid.length > 0 || bluetoothPairingActive
    readonly property bool anyConnectivityPanelOpen: wifiPanelOpen || bluetoothPanelOpen || audioOutputPanelOpen || audioInputPanelOpen || powerPanelOpen
    readonly property string wifiStatusText: (wifiController && wifiController.statusText) || "Unavailable"
    readonly property string bluetoothStatusText: buildBluetoothStatusText()
    readonly property string bluetoothAvailabilityMessage: bluetoothAvailable ? "" : "No Bluetooth adapter is available."
    readonly property string powerDriver: {
        const d = trimString(userConfig.powerProfileDriver);
        return d.length > 0 ? d : "auto";
    }
    readonly property bool tlpControlsEnabled: {
        if (powerDriver === "disabled" || powerDriver === "none") return false;
        if (powerDriver === "powerprofilesctl") return true;
        if (powerDriver === "tlp") return trimString(userConfig.tlpPermissionMode) !== "skip";
        return true;
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function trimString(value) {
        if (value === undefined || value === null) return "";
        return String(value).trim();
    }

    function batteryModeLabel(index) {
        if (index <= 0) return "Power Saver";
        if (index >= 2) return "Performance";
        return "Balanced";
    }

    function batteryModeCommand(index) {
        if (index <= 0) return "power-saver";
        if (index >= 2) return "performance";
        return "balanced";
    }

    function batteryModeIndexForCommand(command) {
        const normalized = trimString(command).toLowerCase();
        if (normalized === "power-saver" || normalized === "bat") return 0;
        if (normalized === "performance" || normalized === "ac") return 2;
        return 1;
    }

    function setBatteryModeVisualIndex(index, animate) {
        const nextIndex = Math.max(0, Math.min(2, index));
        batteryModeIndex = nextIndex;
    }

    function refreshBatteryModeState() {
        if (batteryModeStateRunning)
            return;

        batteryModeStateRunning = true;
        SystemServices.requestPowerProfileState(controlCenter.powerDriver);
    }

    function applyBatteryModeState(available, profile, output, errorString) {
        batteryModeStateRunning = false;
        batteryTlpChecked = true;
        batteryTlpAvailable = !!available;

        if (!batteryTlpAvailable) {
            batteryModeBusy = false;
            batteryModeError = trimString(errorString).length > 0 ? errorString : "Power service not available.";
            setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
            return;
        }

        if (batteryModeError === "TLP is not installed." || batteryModeError === "Power service not available.")
            batteryModeError = "";

        let resolvedProfile = trimString(profile);
        if (resolvedProfile.length === 0) {
            const profileMatch = String(output || "").match(/TLP profile\s*=\s*([a-z-]+)/i);
            if (profileMatch)
                resolvedProfile = profileMatch[1];
        }

        if (resolvedProfile.length > 0) {
            const nextIndex = batteryModeIndexForCommand(resolvedProfile);
            batteryModeAppliedIndex = nextIndex;
            setBatteryModeVisualIndex(nextIndex, true);

            if (batteryModeRefreshPollsRemaining > 0 && nextIndex === batteryModePendingIndex) {
                batteryModeRefreshPollsRemaining = 0;
                batteryModeRefreshTimer.stop();
                batteryModeError = "";
            }
        }
    }

    function rollbackBatteryMode(message) {
        batteryModeBusy = false;
        batteryModeError = message;
        setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
    }

    function classifyBatteryModeFailure(exitCode) {
        const details = trimString(batteryModeLastCommandOutput).toLowerCase();

        if (details.indexOf("powerprofilesctl") >= 0)
            return "powerprofilesctl failed to set profile.";
        if (details.indexOf("sorry, try again") >= 0 || details.indexOf("incorrect password attempt") >= 0)
            return "The configured sudo password did not work.";
        if (details.indexOf("pkexec") >= 0 && details.indexOf("not installed") >= 0)
            return "Install pkexec or set tlpSudoPassword in userconfig.json.";
        if (details.indexOf("sudo is not installed") >= 0)
            return "sudo is not installed.";
        if (details.indexOf("sudo:") >= 0 && details.indexOf("password") >= 0) {
            if (trimString(userConfig.tlpPermissionMode) === "ask")
                return "Install pkexec or set tlpSudoPassword in userconfig.json.";
            return "sudo needs a password; set tlpSudoPassword in userconfig.json.";
        }
        if (details.indexOf("sudo:") >= 0 && details.indexOf("no new privileges") >= 0)
            return "sudo is blocked by the current process security flags.";
        if (details.indexOf("sudo:") >= 0 && details.indexOf("a terminal is required") >= 0)
            return "sudo needs a real terminal, but the panel could not open one.";
        if (details.indexOf("missing root privilege") >= 0)
            return "Power service needs admin permission.";
        if (details.indexOf("command not found") >= 0 || details.indexOf("not found") >= 0) {
            if (details.indexOf("tlp") >= 0)
                return "TLP is not installed.";
            if (details.indexOf("powerprofilesctl") >= 0)
                return "powerprofilesctl is not installed.";
        }

        if (exitCode === 127)
            return "Power service command not found.";
        if (exitCode === 126)
            return "Authentication required to apply mode.";
        return "Could not apply power mode.";
    }

    function queueBatteryModeStateRefresh(polls) {
        batteryModeRefreshPollsRemaining = Math.max(0, polls);
        if (batteryModeRefreshPollsRemaining > 0)
            batteryModeRefreshTimer.restart();
        else
            batteryModeRefreshTimer.stop();
    }

    function selectBatteryMode(index) {
        if (batteryModeBusy) {
            if (batteryModeSetterRunning)
                SystemServices.cancelPowerProfileApply();
            batteryModeBusy = false;
            batteryModeSetterRunning = false;
        }

        queueBatteryModeStateRefresh(0);

        const nextIndex = Math.max(0, Math.min(2, index));

        if (!controlCenter.tlpControlsEnabled) {
            rollbackBatteryMode("Power mode switching is disabled in userconfig.json.");
            return;
        }

        if (!batteryTlpChecked) {
            refreshBatteryModeState();
            rollbackBatteryMode("Checking power service. Try again in a moment.");
            return;
        }

        if (!batteryTlpAvailable) {
            rollbackBatteryMode(batteryModeError.length > 0 ? batteryModeError : "Power service not available.");
            return;
        }

        if (nextIndex === batteryModeAppliedIndex) {
            batteryModeError = "";
            setBatteryModeVisualIndex(nextIndex, true);
            return;
        }

        batteryModePendingIndex = nextIndex;
        batteryModeBusy = true;
        batteryModeSetterRunning = true;
        batteryModeError = "";
        setBatteryModeVisualIndex(nextIndex, true);
        batteryModeLastCommandOutput = "";
        const permissionMode = trimString(userConfig.tlpPermissionMode);
        const sudoPassword = permissionMode === "password"
            ? trimString(userConfig.tlpSudoPassword)
            : "";
        SystemServices.setPowerProfileMode(controlCenter.powerDriver, batteryModeCommand(nextIndex), sudoPassword, permissionMode === "ask");
    }

    function finishBatteryModeApply(success, exitCode, output, errorString) {
        batteryModeSetterRunning = false;
        batteryModeBusy = false;
        batteryModeLastCommandOutput = trimString(output);
        if (batteryModeLastCommandOutput.length === 0)
            batteryModeLastCommandOutput = trimString(errorString);

        if (!success) {
            rollbackBatteryMode(classifyBatteryModeFailure(exitCode));
            return;
        }

        batteryModeAppliedIndex = batteryModePendingIndex;
        batteryModeError = "";
        setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
        refreshBatteryModeState();
    }

    function clearWifiPrompt() {
        wifiPendingPasswordSsid = "";
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "";
        wifiLocalError = "";
    }

    function clearWifiMessages() {
        wifiLocalInfoMessage = "";
        wifiLocalError = "";
        if (wifiController && typeof wifiController.clearMessages === "function")
            wifiController.clearMessages();
    }

    function clearBluetoothMessages() {
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }

    function submitBluetoothPairingSecret() {
        if (!bluetoothPairingAgent || !bluetoothPairingRequiresInput)
            return;

        const secret = trimString(bluetoothPendingSecretValue);
        if (!secret) {
            bluetoothError = bluetoothPairingNumericInput
                ? "Enter the 6-digit passkey first."
                : "Enter the PIN first.";
            return;
        }

        if (bluetoothPairingNumericInput && !/^\d{1,6}$/.test(secret)) {
            bluetoothError = "Passkeys must be 1 to 6 digits.";
            return;
        }

        bluetoothError = "";
        bluetoothPairingAgent.submitSecret(secret);
        bluetoothPendingSecretValue = "";
    }

    function confirmBluetoothPairing() {
        if (!bluetoothPairingAgent)
            return;

        bluetoothError = "";
        bluetoothPairingAgent.confirmRequest();
    }

    function cancelBluetoothPairing() {
        if (!bluetoothPairingAgent)
            return;

        bluetoothPairingAgent.cancelRequest();
        bluetoothPendingSecretValue = "";
    }

    function isConnectivityPanelOpen(kind) {
        if (kind === "wifi") return wifiPanelOpen;
        if (kind === "bluetooth") return bluetoothPanelOpen;
        if (kind === "power") return powerPanelOpen;
        if (kind === "audio_output" || kind === "output") return audioOutputPanelOpen;
        if (kind === "audio_input" || kind === "input") return audioInputPanelOpen;
        return false;
    }

    function setConnectivityPanelOpen(kind, open, emitSignal) {
        if (emitSignal === undefined)
            emitSignal = true;

        const nextOpen = !!open;
        let changed = false;

        if (nextOpen) {
            if (kind !== "wifi" && wifiPanelOpen) {
                wifiPanelOpen = false;
                clearWifiPrompt();
                clearWifiMessages();
                if (emitSignal) connectivityPanelRequested("wifi", false);
            }
            if (kind !== "bluetooth" && bluetoothPanelOpen) {
                bluetoothPanelOpen = false;
                if (bluetoothPairingActive)
                    cancelBluetoothPairing();
                if (bluetoothAdapter && bluetoothAdapter.discovering)
                    bluetoothAdapter.discovering = false;
                bluetoothScanStopTimer.stop();
                bluetoothConnectAfterPairTimer.stop();
                bluetoothConnectionTimeoutTimer.stop();
                bluetoothPairAndConnectPath = "";
                bluetoothPendingSecretValue = "";
                clearBluetoothMessages();
                if (emitSignal) connectivityPanelRequested("bluetooth", false);
            }
            if (kind !== "power" && powerPanelOpen) {
                powerPanelOpen = false;
                if (emitSignal) connectivityPanelRequested("power", false);
            }
            if (!kind.startsWith("audio")) {
                if (audioOutputPanelOpen) {
                    audioOutputPanelOpen = false;
                    if (emitSignal) connectivityPanelRequested("audio_output", false);
                }
                if (audioInputPanelOpen) {
                    audioInputPanelOpen = false;
                    if (emitSignal) connectivityPanelRequested("audio_input", false);
                }
                SystemServices.setAudioMonitoringActive(false);
            }
        }

        if (kind === "wifi") {
            changed = wifiPanelOpen !== nextOpen;
            wifiPanelOpen = nextOpen;

            if (nextOpen) {
                if (showCondition) {
                    requestWifiStateRefresh();
                    if (wifiSupported && wifiEnabled)
                        requestWifiListRefresh(true);
                }
            } else {
                clearWifiPrompt();
                clearWifiMessages();
            }
        } else if (kind === "bluetooth") {
            changed = bluetoothPanelOpen !== nextOpen;
            bluetoothPanelOpen = nextOpen;

            if (nextOpen) {
                if (bluetoothAdapter && bluetoothEnabled && !bluetoothAdapter.discovering) {
                    bluetoothAdapter.discovering = true;
                    bluetoothInfoMessage = "Scanning for nearby devices...";
                    bluetoothScanStopTimer.restart();
                }
            } else {
                if (bluetoothPairingActive)
                    cancelBluetoothPairing();
                if (bluetoothAdapter && bluetoothAdapter.discovering)
                    bluetoothAdapter.discovering = false;
                bluetoothScanStopTimer.stop();
                bluetoothConnectAfterPairTimer.stop();
                bluetoothConnectionTimeoutTimer.stop();
                bluetoothPairAndConnectPath = "";
                bluetoothPendingSecretValue = "";
                clearBluetoothMessages();
            }
        } 
        else if (kind === "power") {
            changed = powerPanelOpen !== nextOpen;
            powerPanelOpen = nextOpen;
            if (nextOpen) {
                SystemServices.requestBatteryThresholdState();
                if (tlpControlsEnabled)
                    refreshBatteryModeState();
            }
        }
        else if (kind === "audio_output" || kind === "output") {
            changed = audioOutputPanelOpen !== nextOpen;
            audioOutputPanelOpen = nextOpen;
            if (nextOpen) {
                if (audioInputPanelOpen) {
                    audioInputPanelOpen = false;
                    if (emitSignal) connectivityPanelRequested("audio_input", false);
                }
                SystemServices.setAudioMonitoringActive(true);
                SystemServices.requestAudioOutputs();
                SystemServices.requestAppStreams();
            } else if (!audioInputPanelOpen) {
                SystemServices.setAudioMonitoringActive(false);
            }
            if (changed && emitSignal)
                connectivityPanelRequested("audio_output", nextOpen);
            return;
        }
        else if (kind === "audio_input" || kind === "input") {
            changed = audioInputPanelOpen !== nextOpen;
            audioInputPanelOpen = nextOpen;
            if (nextOpen) {
                if (audioOutputPanelOpen) {
                    audioOutputPanelOpen = false;
                    if (emitSignal) connectivityPanelRequested("audio_output", false);
                }
                SystemServices.setAudioMonitoringActive(true);
                SystemServices.requestAudioInputs();
            } else if (!audioOutputPanelOpen) {
                SystemServices.setAudioMonitoringActive(false);
            }
            if (changed && emitSignal)
                connectivityPanelRequested("audio_input", nextOpen);
            return;
        }
        else {
            return;
        }

        if (changed && emitSignal)
            connectivityPanelRequested(kind, nextOpen);
    }

    function toggleConnectivityOverlay(kind) {
        setConnectivityPanelOpen(kind, !isConnectivityPanelOpen(kind));
    }

    function triggerShutdown() {
        if (!shutdownProcess.running)
            shutdownProcess.running = true;
    }
    function triggerRestart() {
        if (!restartProcess.running)
            restartProcess.running = true;
    }
    function triggerSleep() {
        if (!sleepProcess.running)
            sleepProcess.running = true;
    }
    function triggerLock() {
        if (!lockProcess.running)
            lockProcess.running = true;
    }

    function closeConnectivityPanels(emitSignals) {
        if (emitSignals === undefined)
            emitSignals = true;

        setConnectivityPanelOpen("wifi", false, emitSignals);
        setConnectivityPanelOpen("bluetooth", false, emitSignals);
        setConnectivityPanelOpen("power", false, emitSignals);
        setConnectivityPanelOpen("audio_output", false, emitSignals);
        setConnectivityPanelOpen("audio_input", false, emitSignals);
        clearWifiPrompt();
        clearWifiMessages();
        clearBluetoothMessages();
    }

    function closeConnectivityOverlays(emitSignals) {
        closeConnectivityPanels(emitSignals);
    }

    function requestWifiStateRefresh() {
        if (!showCondition || !wifiController || typeof wifiController.refreshState !== "function") return;
        wifiController.refreshState();
    }

    function requestWifiListRefresh(rescan) {
        if (!showCondition || !wifiController || typeof wifiController.refreshNetworks !== "function") return;
        if (!wifiSupported || !wifiAvailable || !wifiEnabled) return;
        wifiController.refreshNetworks(!!rescan);
    }

    function toggleWifiEnabled() {
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController && typeof wifiController.setEnabled === "function")
            wifiController.setEnabled(!wifiEnabled);
    }

    function disconnectWifi() {
        if (!wifiSupported || !wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }

        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController && typeof wifiController.disconnectCurrent === "function")
            wifiController.disconnectCurrent();
    }

    function connectWifiNetwork(network) {
        if (!network) return;
        if (!wifiSupported) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "Wi-Fi control is unavailable.";
            return;
        }
        if (!wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }
        if (!wifiEnabled) {
            wifiLocalError = "Turn on Wi-Fi first.";
            return;
        }
        if (network.connected) return;

        const ssid = trimString(network.ssid);
        const networkType = trimString(network.type);
        const secure = !!network.secure;
        const savedConnection = !!network.savedConnection;

        if (!ssid) {
            wifiLocalError = "Hidden networks are not supported in this panel yet.";
            return;
        }

        if (!savedConnection && networkType === "wep") {
            wifiLocalError = "WEP networks aren't supported by this panel.";
            return;
        }

        if (!savedConnection && networkType === "8021x") {
            wifiLocalError = "802.1X networks need to be provisioned first.";
            return;
        }

        clearWifiPrompt();
        clearWifiMessages();

        if (savedConnection) {
            if (wifiController && typeof wifiController.connectToNetwork === "function")
                wifiController.connectToNetwork(ssid);
            return;
        }

        if (!secure) {
            if (wifiController && typeof wifiController.connectToNetwork === "function")
                wifiController.connectToNetwork(ssid);
            return;
        }

        wifiPendingPasswordSsid = ssid;
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "Enter the password for " + ssid + ".";
    }

    function submitWifiPassword() {
        const ssid = trimString(wifiPendingPasswordSsid);
        if (!ssid) return;

        if (trimString(wifiPendingPasswordValue).length === 0) {
            wifiLocalError = "Enter a password first.";
            return;
        }

        const password = wifiPendingPasswordValue;
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController && typeof wifiController.connectToNetwork === "function")
            wifiController.connectToNetwork(ssid, password);
    }

    function applyBrightnessSnapshot(value) {
        if (value >= 0 && !brightnessCard.pressed)
            syncBrightnessFromLevel(value);
    }

    function applyVolumeSnapshot(value, muted) {
        if (muted !== undefined)
            volumeMuted = muted;
        if (value >= 0 && !volumeCard.pressed)
            syncVolumeFromLevel(value, muted);
    }

    function applyMicVolumeSnapshot(value, muted) {
        if (muted !== undefined)
            micMuted = muted;
        if (value >= 0 && !micCard.pressed)
            syncMicVolumeFromLevel(value, muted);
    }

    function flushBrightness(force) {
        const nextValue = clamp01(pendingBrightness);
        if (!force && Math.abs(nextValue - lastAppliedBrightness) < 0.01) return;
        if (brightnessSetterRunning) {
            brightnessApplyTimer.restart();
            return;
        }

        lastAppliedBrightness = nextValue;
        brightnessSetterRunning = true;
        SystemServices.setBrightness(nextValue);
    }

    function queueBrightness(value) {
        localBrightness = clamp01(value);
        if (showCondition && !sliderIntroPending) displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        brightnessApplyTimer.restart();
    }

    function currentBrightnessGlyph(val) {
        if (val < 0.30) return brightnessLowIconGlyph;
        if (val < 0.70) return brightnessMediumIconGlyph;
        return brightnessHighIconGlyph;
    }

    function cycleBrightnessPreset() {
        const presets = [0.10, 0.30, 0.65, 1.0];
        const current = clamp01(displayedBrightness);
        let nextValue = presets[0];
        for (let i = 0; i < presets.length; i++) {
            if (presets[i] > current + 0.04) {
                nextValue = presets[i];
                break;
            }
        }
        queueBrightness(nextValue);
        brightnessApplyTimer.stop();
        flushBrightness(true);
    }

    function flushVolume(force) {
        const nextValue = clamp01(pendingVolume);
        if (!force && Math.abs(nextValue - lastAppliedVolume) < 0.01) return;
        if (volumeSetterRunning) {
            volumeApplyTimer.restart();
            return;
        }

        lastAppliedVolume = nextValue;
        volumeSetterRunning = true;
        SystemServices.setVolume(nextValue);
    }

    function queueVolume(value) {
        localVolume = clamp01(value);
        if (showCondition && !sliderIntroPending) displayedVolume = localVolume;
        pendingVolume = localVolume;
        volumeApplyTimer.restart();
    }

    function flushMicVolume(force) {
        const nextValue = clamp01(pendingMicVolume);
        if (!force && Math.abs(nextValue - lastAppliedMicVolume) < 0.01) return;
        if (micSetterRunning) {
            micApplyTimer.restart();
            return;
        }

        lastAppliedMicVolume = nextValue;
        micSetterRunning = true;
        SystemServices.setMicVolume(nextValue);
    }

    function queueMicVolume(value) {
        localMicVolume = clamp01(value);
        if (showCondition && !sliderIntroPending) displayedMicVolume = localMicVolume;
        pendingMicVolume = localMicVolume;
        micApplyTimer.restart();
    }

    function syncBrightnessFromLevel(level) {
        if (level < 0) return;
        localBrightness = clamp01(level);
        if (showCondition && !sliderIntroPending) displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        lastAppliedBrightness = localBrightness;
    }

    function syncVolumeFromLevel(level, muted) {
        if (muted !== undefined)
            volumeMuted = muted;
        if (level < 0) return;
        localVolume = clamp01(level);
        if (showCondition && !sliderIntroPending) displayedVolume = localVolume;
        pendingVolume = localVolume;
        lastAppliedVolume = localVolume;
    }

    function syncMicVolumeFromLevel(level, muted) {
        if (muted !== undefined)
            micMuted = muted;
        if (level < 0) return;
        localMicVolume = clamp01(level);
        if (showCondition && !sliderIntroPending) displayedMicVolume = localMicVolume;
        pendingMicVolume = localMicVolume;
        lastAppliedMicVolume = localMicVolume;
    }

    function syncLevelsFromProps() {
        syncBrightnessFromLevel(brightnessLevel);
        syncVolumeFromLevel(volumeLevel, volumeMuted);
        syncMicVolumeFromLevel(micLevel, micMuted);
    }

    function bluetoothDeviceName(device) {
        if (!device) return "Unknown device";
        return BluetoothFormatting.displayName(
            device.name,
            device.deviceName,
            device.address,
            device.icon
        );
    }

    function bluetoothDeviceHasFriendlyName(device) {
        if (!device) return false;
        return BluetoothFormatting.friendlyName(
            device.name,
            device.deviceName,
            device.address
        ).length > 0;
    }

    function bluetoothDeviceAddress(device) {
        return device ? BluetoothFormatting.addressLabel(device.address) : "";
    }

    function bluetoothDeviceStateText(device) {
        if (!device) return "";
        if (device.pairing) return "Pairing";

        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting";
        case BluetoothDeviceState.Connected:
            return "Connected";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting";
        default:
            break;
        }

        if (device.paired || device.bonded) return "Paired";
        return "Available";
    }

    function bluetoothDeviceSubtitle(device) {
        const parts = [];
        const stateLabel = bluetoothDeviceStateText(device);
        if (stateLabel.length > 0) parts.push(stateLabel);
        if (device && device.batteryAvailable) parts.push(bluetoothBatteryPercent(device) + "%");
        if (device && !bluetoothDeviceHasFriendlyName(device)) {
            const address = bluetoothDeviceAddress(device);
            if (address.length > 0) parts.push(address);
        }
        return parts.join(" • ");
    }

    function bluetoothBatteryPercent(device) {
        if (!device || !device.batteryAvailable)
            return -1;

        const rawValue = Math.max(0, Number(device.battery) || 0);
        return Math.max(0, Math.min(100, Math.round(rawValue <= 1 ? rawValue * 100 : rawValue)));
    }

    function bluetoothDeviceMatchesSection(device, section) {
        if (!device) return false;

        const paired = device.paired || device.bonded;
        if (section === "connected") return device.connected;
        if (section === "paired") return !device.connected && paired;
        if (section === "available") return !paired;
        return false;
    }

    function buildBluetoothStatusText() {
        if (!bluetoothAvailable) return "Unavailable";
        if (!bluetoothEnabled) return "Off";

        const devices = bluetoothDeviceValues || [];
        const connectedNames = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.connected)
                connectedNames.push(bluetoothDeviceName(device));
        }

        if (connectedNames.length === 1) return connectedNames[0];
        if (connectedNames.length > 1) return connectedNames[0] + " +" + (connectedNames.length - 1);
        if (bluetoothAdapter.discovering) return "Scanning";
        return bluetoothBusy ? "Working..." : "On";
    }

    function toggleBluetoothEnabled() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }

        bluetoothError = "";
        bluetoothInfoMessage = "";
        bluetoothPairAndConnectPath = "";

        if (bluetoothAdapter.discovering)
            bluetoothAdapter.discovering = false;

        bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    }

    function toggleBluetoothScan() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }
        if (!bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";
        if (bluetoothAdapter.discovering) {
            bluetoothAdapter.discovering = false;
            bluetoothInfoMessage = "";
            bluetoothScanStopTimer.stop();
        } else {
            bluetoothAdapter.discovering = true;
            bluetoothInfoMessage = "Scanning for nearby devices...";
            bluetoothScanStopTimer.restart();
        }
    }

    function handleBluetoothDevicePressed(device) {
        if (!device) return;
        if (!bluetoothAdapter || !bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";

        if (device.connected) {
            bluetoothInfoMessage = "Disconnecting from " + bluetoothDeviceName(device) + "...";
            bluetoothMessageClearTimer.restart();
            device.disconnect();
            return;
        }

        if (device.paired || device.bonded) {
            bluetoothPairAndConnectPath = device.dbusPath;
            bluetoothInfoMessage = "Connecting to " + bluetoothDeviceName(device) + "...";
            device.trusted = true;
            bluetoothConnectionTimeoutTimer.restart();
            device.connect();
            return;
        }

        bluetoothPairAndConnectPath = device.dbusPath;
        bluetoothInfoMessage = "Pairing " + bluetoothDeviceName(device) + "...";
        bluetoothConnectionTimeoutTimer.restart();
        device.pair();
    }

    function bluetoothDeviceForPath(path) {
        const devices = bluetoothDeviceValues || [];
        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.dbusPath === path)
                return device;
        }
        return null;
    }

    function finishBluetoothConnection(device) {
        if (!device || bluetoothPairAndConnectPath !== device.dbusPath)
            return;

        if (device.paired || device.bonded)
            device.trusted = true;

        bluetoothConnectAfterPairTimer.stop();
        bluetoothConnectionTimeoutTimer.stop();
        bluetoothPairAndConnectPath = "";
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }

    function continueBluetoothPairAndConnect(device) {
        if (!device || bluetoothPairAndConnectPath !== device.dbusPath)
            return;
        if (device.pairing)
            return;

        if (!(device.paired || device.bonded)) {
            bluetoothConnectAfterPairTimer.stop();
            bluetoothConnectionTimeoutTimer.stop();
            bluetoothPairAndConnectPath = "";
            bluetoothInfoMessage = "";
            if (!bluetoothPairingActive)
                bluetoothError = "Pairing failed or was canceled.";
            return;
        }

        device.trusted = true;
        if (device.connected) {
            finishBluetoothConnection(device);
            return;
        }

        bluetoothInfoMessage = "Connecting to " + bluetoothDeviceName(device) + "...";
        bluetoothConnectAfterPairTimer.restart();
    }

    function handleBluetoothConnectionStateChanged(device) {
        if (!device || bluetoothPairAndConnectPath !== device.dbusPath)
            return;

        if (device.connected) {
            if (device.pairing)
                return;
            finishBluetoothConnection(device);
            return;
        }

        if (!device.pairing
                && (device.paired || device.bonded)
                && device.state === BluetoothDeviceState.Disconnected
                && !bluetoothConnectAfterPairTimer.running) {
            bluetoothConnectionTimeoutTimer.stop();
            bluetoothPairAndConnectPath = "";
            bluetoothInfoMessage = "";
            bluetoothError = "Paired successfully, but the connection failed. Make sure the device is still ready to connect.";
        }
    }

    function forgetBluetoothDevice(device) {
        if (!device) return;
        const name = bluetoothDeviceName(device);
        if (bluetoothPairAndConnectPath === device.dbusPath) {
            bluetoothConnectAfterPairTimer.stop();
            bluetoothConnectionTimeoutTimer.stop();
            bluetoothPairAndConnectPath = "";
        }
        device.forget();
        bluetoothError = "";
        bluetoothInfoMessage = "Forgot " + name + ".";
        bluetoothMessageClearTimer.restart();
    }

    anchors.fill: parent
    anchors.margins: 12
    opacity: showCondition ? 1 : 0
    visible: opacity > 0

    Keys.onEscapePressed: function(event) {
        if (controlCenter.hasConnectivityPrompt) {
            if (controlCenter.wifiPendingPasswordSsid.length > 0)
                controlCenter.clearWifiPrompt();
            else if (controlCenter.bluetoothPairingActive)
                controlCenter.cancelBluetoothPairing();
            event.accepted = true;
            return;
        }
        if (controlCenter.anyConnectivityPanelOpen) {
            controlCenter.closeConnectivityPanels();
            event.accepted = true;
            return;
        }
        if (controlCenter.powerViewActive) {
            controlCenter.powerViewActive = false;
            controlCenter.closeRequested();
            event.accepted = true;
            return;
        }
        controlCenter.closeRequested();
        event.accepted = true;
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (controlCenter.hasConnectivityPrompt) {
                if (controlCenter.wifiPendingPasswordSsid.length > 0)
                    controlCenter.clearWifiPrompt();
                else if (controlCenter.bluetoothPairingActive)
                    controlCenter.cancelBluetoothPairing();
                event.accepted = true;
                return;
            }
            if (controlCenter.anyConnectivityPanelOpen) {
                controlCenter.closeConnectivityPanels();
                event.accepted = true;
                return;
            }
            if (controlCenter.powerViewActive) {
                controlCenter.powerViewActive = false;
                controlCenter.closeRequested();
                event.accepted = true;
                return;
            }
            controlCenter.closeRequested();
            event.accepted = true;
        } else if (controlCenter.powerViewActive) {
            if (event.key === Qt.Key_1) {
                controlCenter.triggerLock();
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                controlCenter.triggerSleep();
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                controlCenter.triggerRestart();
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                controlCenter.triggerShutdown();
                event.accepted = true;
            }
        }
    }

    onBrightnessLevelChanged: syncBrightnessFromLevel(brightnessLevel)
    onVolumeLevelChanged: syncVolumeFromLevel(volumeLevel, volumeMuted)
    onVolumeMutedChanged: volumeMuted = volumeMuted
    onMicLevelChanged: syncMicVolumeFromLevel(micLevel, micMuted)
    onMicMutedChanged: micMuted = micMuted
    onShowConditionChanged: {
        if (showCondition) {
            readyForCardAnimations = false;
            controlCenter.forceActiveFocus();
            syncLevelsFromProps();
            sliderIntroPending = true;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            displayedMicVolume = localMicVolume;
            sliderIntroTimer.interval = sliderIntroDelay;
            sliderIntroTimer.restart();
            refreshBatteryModeState();
            refreshIdleInhibit();
            requestWifiStateRefresh();
            if (wifiPanelOpen && wifiSupported && wifiEnabled)
                requestWifiListRefresh(true);
        } else {
            readyForCardAnimations = false;
            sliderIntroTimer.stop();
            sliderIntroPending = false;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            displayedMicVolume = localMicVolume;
            powerViewActive = false;
            closeConnectivityPanels();
        }
    }

    Component.onCompleted: {
        refreshIdleInhibit();
        if (showCondition) {
            readyForCardAnimations = false;
            sliderIntroPending = true;
            sliderIntroTimer.interval = sliderIntroDelay;
            sliderIntroTimer.restart();
        }
        syncLevelsFromProps();
        displayedBrightness = localBrightness;
        displayedVolume = localVolume;
        displayedMicVolume = localMicVolume;
        SystemServices.requestBrightness();
        SystemServices.requestVolume();
        SystemServices.requestMicVolume();
        refreshBatteryModeState();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 140 : 60
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on displayedBrightness {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !brightnessCard.pressed

        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }
    }

    Behavior on displayedVolume {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !volumeCard.pressed

        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }
    }

    Behavior on displayedMicVolume {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !micCard.pressed

        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }
    }

    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                controlCenter.requestNotification("Power", "Shutdown failed",
                    "Could not power off via systemctl.");
        }
    }
    Process {
        id: restartProcess
        command: ["systemctl", "reboot"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                controlCenter.requestNotification("Power", "Restart failed",
                    "Could not reboot via systemctl.");
        }
    }
    Process {
        id: sleepProcess
        command: ["systemctl", "suspend"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                controlCenter.requestNotification("Power", "Sleep failed",
                    "Could not suspend via systemctl.");
        }
    }
    Process {
        id: lockProcess
        command: [
            "sh",
            "-c",
            "if command -v tide-island >/dev/null 2>&1; then tide-island --lock; "
                + "elif command -v hyprlock >/dev/null 2>&1; then hyprlock; "
                + "elif command -v swaylock >/dev/null 2>&1; then swaylock; "
                + "elif command -v i3lock >/dev/null 2>&1; then i3lock; "
                + "elif command -v loginctl >/dev/null 2>&1; then loginctl lock-session; "
                + "else exit 127; fi"
        ]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 127)
                controlCenter.requestNotification("Power", "Lock unavailable",
                    "Install hyprlock, swaylock, or i3lock to enable screen locking.");
        }
    }

    Connections {
        target: ScreenRecorder
        ignoreUnknownSignals: true

        function onNotificationRequested(title, message) {
            controlCenter.requestNotification("Screen Recorder", title, message);
        }
    }

    Connections {
        target: SystemServices

        function onTlpStateReady(available, profile, output, errorString) {
            controlCenter.applyBatteryModeState(available, profile, output, errorString);
        }

        function onTlpSetFinished(success, exitCode, output, errorString) {
            controlCenter.finishBatteryModeApply(success, exitCode, output, errorString);
        }

        function onBrightnessSnapshotReady(value, errorString) {
            if (errorString === "")
                controlCenter.applyBrightnessSnapshot(value);
        }

        function onBrightnessSetFinished(value, success, errorString) {
            controlCenter.brightnessSetterRunning = false;
            if (success && !brightnessCard.pressed)
                controlCenter.applyBrightnessSnapshot(value);
            if (success && Math.abs(controlCenter.pendingBrightness - controlCenter.lastAppliedBrightness) >= 0.01)
                brightnessApplyTimer.restart();
        }

        function onVolumeSnapshotReady(value, muted, errorString) {
            if (errorString === "")
                controlCenter.applyVolumeSnapshot(value, muted);
        }

        function onVolumeSetFinished(value, success, errorString) {
            controlCenter.volumeSetterRunning = false;
            if (success && !volumeCard.pressed)
                controlCenter.applyVolumeSnapshot(value, controlCenter.volumeMuted);
            if (success && Math.abs(controlCenter.pendingVolume - controlCenter.lastAppliedVolume) >= 0.01)
                volumeApplyTimer.restart();
        }

        function onMicVolumeSnapshotReady(value, muted, errorString) {
            if (errorString === "")
                controlCenter.applyMicVolumeSnapshot(value, muted);
        }

        function onMicVolumeSetFinished(value, success, errorString) {
            controlCenter.micSetterRunning = false;
            if (success && !micCard.pressed)
                controlCenter.applyMicVolumeSnapshot(value, controlCenter.micMuted);
            if (success && Math.abs(controlCenter.pendingMicVolume - controlCenter.lastAppliedMicVolume) >= 0.01)
                micApplyTimer.restart();
        }
    }

    Timer {
        id: brightnessApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushBrightness(false)
    }

    Timer {
        id: volumeApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushVolume(false)
    }

    Timer {
        id: micApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushMicVolume(false)
    }

    Timer {
        id: sliderIntroTimer
        interval: controlCenter.sliderIntroDelay
        repeat: false

        onTriggered: {
            controlCenter.sliderIntroPending = false;
            controlCenter.readyForCardAnimations = true;
            controlCenter.displayedBrightness = controlCenter.localBrightness;
            controlCenter.displayedVolume = controlCenter.localVolume;
            controlCenter.displayedMicVolume = controlCenter.localMicVolume;
        }
    }

    Timer {
        id: batteryModeRefreshTimer
        interval: 1500
        repeat: true
        onTriggered: {
            if (controlCenter.batteryModeRefreshPollsRemaining <= 0) {
                stop();
                return;
            }

            controlCenter.batteryModeRefreshPollsRemaining -= 1;
            controlCenter.refreshBatteryModeState();

            if (controlCenter.batteryModeRefreshPollsRemaining <= 0)
                stop();
        }
    }

    Timer {
        id: bluetoothScanStopTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothAdapter && controlCenter.bluetoothAdapter.discovering)
                controlCenter.bluetoothAdapter.discovering = false;
            controlCenter.bluetoothInfoMessage = "";
        }
    }

    Timer {
        id: bluetoothConnectAfterPairTimer
        interval: 350
        repeat: false
        onTriggered: {
            const device = controlCenter.bluetoothDeviceForPath(controlCenter.bluetoothPairAndConnectPath);
            if (!device)
                return;
            if (device.connected) {
                controlCenter.finishBluetoothConnection(device);
                return;
            }
            device.connect();
        }
    }

    Timer {
        id: bluetoothConnectionTimeoutTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothPairAndConnectPath.length === 0)
                return;
            bluetoothConnectAfterPairTimer.stop();
            controlCenter.bluetoothPairAndConnectPath = "";
            controlCenter.bluetoothInfoMessage = "";
            controlCenter.bluetoothError = "Bluetooth pairing or connection timed out. Put the device back in pairing mode and try again.";
        }
    }

    Timer {
        id: bluetoothMessageClearTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothPairAndConnectPath.length === 0)
                controlCenter.bluetoothInfoMessage = "";
        }
    }

    Connections {
        target: wifiController

        function onEnabledChanged() {
            if (!controlCenter.wifiEnabled)
                controlCenter.clearWifiPrompt();
        }
    }

    Connections {
        target: bluetoothAdapter

        function onEnabledChanged() {
            if (!controlCenter.bluetoothAdapter.enabled) {
                controlCenter.bluetoothPairAndConnectPath = "";
                controlCenter.bluetoothInfoMessage = "";
                controlCenter.bluetoothError = "";
                bluetoothScanStopTimer.stop();
                bluetoothConnectAfterPairTimer.stop();
                bluetoothConnectionTimeoutTimer.stop();
            }
        }

        function onDiscoveringChanged() {
            if (!controlCenter.bluetoothAdapter.discovering)
                bluetoothScanStopTimer.stop();
        }
    }

    // Keep device state observers outside the filtered UI rows. A device moves
    // from "available" to "paired" during first-time pairing, which destroys
    // its old row before a row-local PairedChanged handler can reliably finish
    // the trust-and-connect sequence.
    Repeater {
        model: controlCenter.bluetoothDeviceValues

        delegate: Item {
            width: 0
            height: 0
            visible: false

            property var bluetoothDevice: modelData

            Connections {
                target: bluetoothDevice
                ignoreUnknownSignals: true

                function onPairedChanged() {
                    controlCenter.continueBluetoothPairAndConnect(bluetoothDevice);
                }

                function onBondedChanged() {
                    controlCenter.continueBluetoothPairAndConnect(bluetoothDevice);
                }

                function onPairingChanged() {
                    controlCenter.continueBluetoothPairAndConnect(bluetoothDevice);
                }

                function onConnectedChanged() {
                    controlCenter.handleBluetoothConnectionStateChanged(bluetoothDevice);
                }

                function onStateChanged() {
                    controlCenter.handleBluetoothConnectionStateChanged(bluetoothDevice);
                }
            }
        }
    }

    Connections {
        target: bluetoothPairingAgent

        function onRequestChanged() {
            controlCenter.bluetoothPendingSecretValue = "";
            if (controlCenter.bluetoothPairingActive) {
                controlCenter.bluetoothError = "";
                controlCenter.setConnectivityPanelOpen("bluetooth", true);
            }
        }

        function onRegistrationErrorChanged() {
            if (!controlCenter.bluetoothPairingAgent)
                return;

            if (!controlCenter.bluetoothPairingAgent.registered
                    && controlCenter.bluetoothPairingAgent.registrationError.length > 0
                    && controlCenter.bluetoothPanelOpen) {
                controlCenter.bluetoothError = controlCenter.bluetoothPairingAgent.registrationError;
            }
        }
    }

    Column {
        id: mainContent
        anchors.fill: parent
        visible: !controlCenter.powerViewActive
        spacing: 12

        Behavior on opacity {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Item {
            width: parent.width
            height: 28

            Item {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 220
                height: parent.height

                Text {
                    id: timeLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: currentTime
                    color: StyleTokens.textPrimaryBright
                    font.pixelSize: 19
                    font.family: heroFontFamily
                    font.weight: Font.Bold
                    font.letterSpacing: -0.45
                }

                Text {
                    id: dateLabel
                    anchors.left: timeLabel.right
                    anchors.leftMargin: 10
                    anchors.baseline: timeLabel.baseline
                    text: currentDateLabel
                    color: dateMouse.containsMouse ? StyleTokens.textPrimaryBright : textSecondary
                    font.pixelSize: 12
                    font.family: textFontFamily
                    font.weight: Font.Medium

                    Behavior on color { ColorAnimation { duration: 60 } }

                    MouseArea {
                        id: dateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.calendarRequested()
                    }
                }

                Rectangle {
                    id: weatherChip
                    anchors.left: dateLabel.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    width: weatherChipRow.implicitWidth + 14
                    radius: 11
                    color: weatherHover.containsMouse ? StyleTokens.moduleHover : StyleTokens.module
                    visible: weatherService && weatherService.hasData && userConfig.weatherEnabled

                    Row {
                        id: weatherChipRow
                        anchors.centerIn: parent
                        spacing: 4

                        WeatherIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            weatherType: weatherService ? weatherService.weatherType : "sunny"
                            iconColor: weatherService ? weatherService.iconColor : StyleTokens.warning
                            glyph: weatherService ? weatherService.iconGlyph : "\ue30d"
                            iconFontFamily: controlCenter.iconFontFamily
                            iconSize: 14
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: weatherService ? weatherService.tempString : ""
                            color: StyleTokens.textPrimary
                            font.pixelSize: 11
                            font.family: controlCenter.textFontFamily
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: weatherHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.weatherRequested()
                    }
                }
            }

            Row {
                anchors.right: headerBatteryPill.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [
                        { glyph: "\u{F009C}", action: "notifications" },
                        { glyph: "\u{F0425}", action: "power" }
                    ]

                    delegate: Rectangle {
                        id: headerButton
                        required property var modelData
                        width: 24
                        height: 22
                        radius: 11
                        color: headerButtonMouse.containsMouse ? StyleTokens.moduleHover : StyleTokens.module

                        Text {
                            anchors.centerIn: parent
                            text: headerButton.modelData.glyph
                            color: StyleTokens.textPrimary
                            font.pixelSize: 13
                            font.family: controlCenter.iconFontFamily
                        }

                        Rectangle {
                            visible: headerButton.modelData.action === "notifications"
                                && controlCenter.unreadNotificationCount > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 2
                            anchors.rightMargin: 3
                            width: 6
                            height: 6
                            radius: 3
                            color: StyleTokens.accent
                        }

                        MouseArea {
                            id: headerButtonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: headerButton.modelData.action === "power"
                                ? controlCenter.powerMenuRequested()
                                : controlCenter.notificationCenterRequested()
                        }
                    }
                }
            }

            Rectangle {
                id: headerBatteryPill
                anchors.right: parent.right
                anchors.rightMargin: 0
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: headerBatteryRow.implicitWidth + 12
                radius: 12
                color: headerBatteryMouse.containsMouse
                    ? StyleTokens.withAlpha(StyleTokens.textPrimary, 0.12)
                    : (controlCenter.powerPanelOpen ? StyleTokens.withAlpha(cardAccent, 0.2) : StyleTokens.transparent)

                Behavior on color {
                    ColorAnimation { duration: 70 }
                }

                BatteryIndicator {
                    id: headerBatteryRow
                    anchors.centerIn: parent
                    capacity: controlCenter.effectiveBatteryCap
                    charging: controlCenter.effectiveCharging
                    iconFontFamily: controlCenter.iconFontFamily
                    textFontFamily: controlCenter.textFontFamily
                }

                MouseArea {
                    id: headerBatteryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controlCenter.toggleConnectivityOverlay("power")
                }
            }
        }

        Item {
            width: parent.width
            height: 80

            Row {
                id: connectivityCardsRow
                anchors.fill: parent
                spacing: 12

                Rectangle {
                    id: wifiCard
                    scale: wifiCardMouse.pressed ? 0.98 : 1

                    Behavior on scale {
                        NumberAnimation { duration: Math.round(StyleTokens.durationFast * 0.6); easing.type: Easing.OutCubic }
                    }
                    width: (connectivityCardsRow.width - connectivityCardsRow.spacing) / 2
                    height: connectivityCardsRow.height
                    radius: 10
                    color: StyleTokens.clearBlack
                    clip: true

                    MatteSurface {
                        anchors.fill: parent
                        radius: parent.radius
                        hovered: wifiCardMouse.containsMouse || wifiPanelOpen
                    }

                    MouseArea {
                        id: wifiCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        text: wifiGlyph
                        color: wifiEnabled ? cardAccent : StyleTokens.textDisabled
                        font.pixelSize: 18
                        font.family: iconFontFamily
                    }

                    Rectangle {
                        id: wifiSwitchTrack
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 34
                        height: 20
                        radius: 10
                        color: wifiEnabled ? StyleTokens.success : StyleTokens.switchOff

                        Behavior on color {
                            ColorAnimation {
                                duration: Math.round(StyleTokens.durationFast * 0.6)
                            }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: wifiEnabled ? 16 : 2
                            color: StyleTokens.white

                            Behavior on x {
                                NumberAnimation {
                                    duration: 80
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: wifiToggleArea
                            anchors.fill: parent
                            enabled: wifiSupported && wifiAvailable && !wifiBusy
                            onClicked: controlCenter.toggleWifiEnabled()
                        }
                    }

                    Item {
                        id: wifiDetailButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: wifiChevron.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "Wi-Fi"
                            color: textPrimary
                            font.pixelSize: 13
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: wifiChevron.left
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            text: wifiStatusText
                            color: StyleTokens.textMuted
                            font.pixelSize: 10
                            font.family: textFontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            id: wifiChevron
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: wifiPanelOpen ? StyleTokens.textPrimary : StyleTokens.textSubtle
                            font.pixelSize: 17
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: controlCenter.toggleConnectivityOverlay("wifi")
                        }
                    }
                }

                Rectangle {
                    id: bluetoothCard
                    scale: bluetoothCardMouse.pressed ? 0.98 : 1

                    Behavior on scale {
                        NumberAnimation { duration: Math.round(StyleTokens.durationFast * 0.6); easing.type: Easing.OutCubic }
                    }
                    width: (connectivityCardsRow.width - connectivityCardsRow.spacing) / 2
                    height: connectivityCardsRow.height
                    radius: 10
                    color: StyleTokens.clearBlack
                    clip: true

                    MatteSurface {
                        anchors.fill: parent
                        radius: parent.radius
                        hovered: bluetoothCardMouse.containsMouse || bluetoothPanelOpen
                    }

                    MouseArea {
                        id: bluetoothCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        text: bluetoothGlyph
                        color: bluetoothEnabled ? cardAccent : StyleTokens.textDisabled
                        font.pixelSize: 18
                        font.family: iconFontFamily
                    }

                    Rectangle {
                        id: bluetoothSwitchTrack
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 34
                        height: 20
                        radius: 10
                        color: bluetoothEnabled ? StyleTokens.success : StyleTokens.switchOff

                        Behavior on color {
                            ColorAnimation {
                                duration: Math.round(StyleTokens.durationFast * 0.6)
                            }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: bluetoothEnabled ? 16 : 2
                            color: StyleTokens.white

                            Behavior on x {
                                NumberAnimation {
                                    duration: 80
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: bluetoothToggleArea
                            anchors.fill: parent
                            enabled: bluetoothAvailable && !bluetoothBusy
                            onClicked: controlCenter.toggleBluetoothEnabled()
                        }
                    }

                    Item {
                        id: bluetoothDetailButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "Bluetooth"
                            color: textPrimary
                            font.pixelSize: 13
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            text: bluetoothStatusText
                            color: StyleTokens.textMuted
                            font.pixelSize: 10
                            font.family: textFontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            id: bluetoothChevron
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: bluetoothPanelOpen ? StyleTokens.textPrimary : StyleTokens.textSubtle
                            font.pixelSize: 17
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: controlCenter.toggleConnectivityOverlay("bluetooth")
                        }
                    }
                }
            }
        }

        Item {
            id: batteryDrawer
            readonly property real cardWidth: (width - connectivityCardsRow.spacing) / 2

            width: parent.width
            height: controlCenter.batteryModeCardHeight
            clip: true

            SystemTrayCard {
                id: drawerSystemTrayCard
                anchors.left: parent.left
                width: drawerRecorderCard.visible ? batteryDrawer.cardWidth : batteryDrawer.width
                height: controlCenter.batteryModeCardHeight
                y: 0
                clip: true
            }

            DrawerRecorderCard {
                id: drawerRecorderCard
                x: batteryDrawer.cardWidth + connectivityCardsRow.spacing
                y: drawerSystemTrayCard.y
                width: batteryDrawer.cardWidth
                height: controlCenter.batteryModeCardHeight
                clip: true
            }
        }

        PlayerCard {
            id: playerCard
            width: parent.width
            height: 76
            visible: controlCenter.playerCardVisible
            title: controlCenter.playerTitle
            artist: controlCenter.playerArtist
            artUrl: controlCenter.playerArtUrl
            playing: controlCenter.playerPlaying
            progress: controlCenter.playerProgress
            iconFontFamily: controlCenter.iconFontFamily
            textFontFamily: controlCenter.textFontFamily
            onPreviousRequested: controlCenter.playerPreviousRequested()
            onPlayPauseRequested: controlCenter.playerPlayPauseRequested()
            onNextRequested: controlCenter.playerNextRequested()
            onDismissRequested: controlCenter.playerDismissRequested()
        }

        ScreenRecorderCard {
            id: activeScreenRecorderCard
            width: parent.width
            readonly property bool shouldBeVisible: controlCenter.isRecording || controlCenter.isReplayActive
            visible: shouldBeVisible || height > 0.5
            height: shouldBeVisible ? (controlCenter.isReplayActive ? 116 : 98) : 0
            opacity: shouldBeVisible ? 1 : 0
            clip: true

            Behavior on height {
                enabled: controlCenter.readyForCardAnimations
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                enabled: controlCenter.readyForCardAnimations
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
        }

        ControlSliderCard {
            id: brightnessCard
            width: parent.width
            height: 76
            title: "Display"
            iconText: controlCenter.currentBrightnessGlyph(controlCenter.displayedBrightness)
            iconFontFamily: controlCenter.iconFontFamily
            textFontFamily: controlCenter.textFontFamily
            value: controlCenter.displayedBrightness
            knobSize: controlCenter.sliderKnobSize
            accentColor: controlCenter.cardAccent
            moduleColor: controlCenter.moduleColor
            moduleHover: controlCenter.moduleHover
            trackColor: controlCenter.trackColor
            textPrimary: controlCenter.textPrimary
            textSecondary: controlCenter.textSecondary

            onInteractionStarted: {
                if (controlCenter.sliderIntroPending) {
                    sliderIntroTimer.stop();
                    controlCenter.sliderIntroPending = false;
                    controlCenter.displayedBrightness = controlCenter.localBrightness;
                    controlCenter.displayedVolume = controlCenter.localVolume;
                    controlCenter.displayedMicVolume = controlCenter.localMicVolume;
                }
            }
            onValueMoved: function(value) {
                controlCenter.queueBrightness(value);
            }
            onCommitRequested: {
                brightnessApplyTimer.stop();
                controlCenter.flushBrightness(true);
            }
            onCancelRequested: SystemServices.requestBrightness()
            onIconClicked: controlCenter.cycleBrightnessPreset()
            // Idle inhibit: coffee cup, filled while inhibiting
            secondaryIconText: controlCenter.idleInhibitCommand === ""
                ? ""
                : (controlCenter.idleInhibitOn ? "\u{F0176}" : "\u{F06CA}")
            secondaryActive: controlCenter.idleInhibitOn
            secondaryBusy: controlCenter.idleInhibitBusy
            onSecondaryIconClicked: controlCenter.toggleIdleInhibit()
        }

        ControlSliderCard {
            id: volumeCard
            width: parent.width
            height: 76
            title: controlCenter.volumeMuted ? "Sound (Muted)" : "Sound"
            iconText: controlCenter.volumeMuted ? controlCenter.volumeMuteIconGlyph : controlCenter.volumeIconGlyph
            iconFontFamily: controlCenter.iconFontFamily
            textFontFamily: controlCenter.textFontFamily
            value: controlCenter.displayedVolume
            knobSize: controlCenter.sliderKnobSize
            accentColor: controlCenter.volumeMuted ? StyleTokens.withAlpha(controlCenter.cardAccent, 0.45) : controlCenter.cardAccent
            moduleColor: controlCenter.moduleColor
            moduleHover: controlCenter.moduleHover
            trackColor: controlCenter.trackColor
            textPrimary: controlCenter.textPrimary
            textSecondary: controlCenter.textSecondary
            showFlyoutChevron: true
            flyoutOpen: controlCenter.audioOutputPanelOpen

            onInteractionStarted: {
                if (controlCenter.sliderIntroPending) {
                    sliderIntroTimer.stop();
                    controlCenter.sliderIntroPending = false;
                    controlCenter.displayedBrightness = controlCenter.localBrightness;
                    controlCenter.displayedVolume = controlCenter.localVolume;
                    controlCenter.displayedMicVolume = controlCenter.localMicVolume;
                }
            }
            onValueMoved: function(value) {
                controlCenter.queueVolume(value);
            }
            onCommitRequested: {
                volumeApplyTimer.stop();
                controlCenter.flushVolume(true);
            }
            onCancelRequested: SystemServices.requestVolume()
            onIconClicked: SystemServices.toggleVolumeMute()
            onFlyoutClicked: controlCenter.toggleConnectivityOverlay("audio_output")
        }

        ControlSliderCard {
            id: micCard
            width: parent.width
            height: 76
            title: controlCenter.micMuted ? "Mic (Muted)" : "Microphone"
            iconText: controlCenter.micMuted ? controlCenter.micMuteIconGlyph : controlCenter.micIconGlyph
            iconFontFamily: controlCenter.iconFontFamily
            textFontFamily: controlCenter.textFontFamily
            value: controlCenter.displayedMicVolume
            knobSize: controlCenter.sliderKnobSize
            accentColor: controlCenter.micMuted ? StyleTokens.withAlpha(controlCenter.cardAccent, 0.45) : controlCenter.cardAccent
            moduleColor: controlCenter.moduleColor
            moduleHover: controlCenter.moduleHover
            trackColor: controlCenter.trackColor
            textPrimary: controlCenter.textPrimary
            textSecondary: controlCenter.textSecondary
            showFlyoutChevron: true
            flyoutOpen: controlCenter.audioInputPanelOpen

            onInteractionStarted: {
                if (controlCenter.sliderIntroPending) {
                    sliderIntroTimer.stop();
                    controlCenter.sliderIntroPending = false;
                    controlCenter.displayedBrightness = controlCenter.localBrightness;
                    controlCenter.displayedVolume = controlCenter.localVolume;
                    controlCenter.displayedMicVolume = controlCenter.localMicVolume;
                }
            }
            onValueMoved: function(value) {
                controlCenter.queueMicVolume(value);
            }
            onCommitRequested: {
                micApplyTimer.stop();
                controlCenter.flushMicVolume(true);
            }
            onCancelRequested: SystemServices.requestMicVolume()
            onIconClicked: SystemServices.toggleMicMute()
            onFlyoutClicked: controlCenter.toggleConnectivityOverlay("audio_input")
        }
    }
    Item {
        anchors.fill: parent
        visible: controlCenter.powerViewActive

        Behavior on opacity {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 26

            Repeater {
                model: [
                    { glyph: "\uf023", action: "triggerLock" },
                    { glyph: "\uf186", action: "triggerSleep" },
                    { glyph: "\uf021", action: "triggerRestart" },
                    { glyph: "\uf011", action: "triggerShutdown" }
                ]

                delegate: Item {
                    width: 56
                    height: 56
                    scale: powerMouse.pressed ? 0.90 : (powerMouse.containsMouse ? 1.10 : 1.0)

                    Behavior on scale {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        color: powerMouse.containsMouse ? StyleTokens.accent : StyleTokens.textPrimary
                        font.pixelSize: 38
                        font.family: controlCenter.iconFontFamily

                        Behavior on color {
                            ColorAnimation { duration: 70 }
                        }
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (controlCenter[modelData.action])
                                controlCenter[modelData.action]();
                        }
                    }
                }
            }
        }
    }
}
