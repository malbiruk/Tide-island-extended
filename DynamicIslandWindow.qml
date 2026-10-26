import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import IslandBackend
import "qml/common"
import "qml/controlcenter"
import "qml/connectivity"
import "qml/island"

PanelWindow {
    id: root
    property var shellRootController: null

    // The screen edge the island lives on. At the bottom everything mirrors vertically: the
    // capsule rests on the bottom margin and grows upward, side popups align with its bottom
    // edge, auto-hide slides it down, the reveal strip sits at the bottom edge and the drag that
    // opens the Glance goes up. Panel content keeps its own top-down order.
    readonly property bool atBottom: userConfig.islandEdge === "bottom"
    // y of an item `itemHeight` tall that keeps `offset` px from the island's edge.
    function edgeY(offset, itemHeight) {
        return atBottom ? root.height - offset - itemHeight : offset;
    }
    // A vertical drag measured toward the middle of the screen.
    function inwardDelta(dy) {
        return atBottom ? -dy : dy;
    }
    // Shell-wide unread notifications (shell.qml); shown on the resting island and the CC bell.
    readonly property int unreadNotificationCount: shellRootController && shellRootController.unreadNotificationCount
        ? shellRootController.unreadNotificationCount
        : 0
    readonly property string screenOutputName: screen && screen.name !== undefined ? String(screen.name) : ""
    readonly property bool connectivityPromptActive: controlCenterLoader.item
        ? controlCenterLoader.item.hasConnectivityPrompt
        : false
    readonly property var controlCenterRef: controlCenterLoader.item
    readonly property bool screenRecordingActive: shellRootController
        && shellRootController.screenRecordingActive !== undefined
        ? !!shellRootController.screenRecordingActive
        : false
    readonly property bool micActive: shellRootController
        && shellRootController.micActive !== undefined
        ? !!shellRootController.micActive
        : SystemServices.micActive
    readonly property bool cameraActive: shellRootController
        && shellRootController.cameraActive !== undefined
        ? !!shellRootController.cameraActive
        : SystemServices.cameraActive
    readonly property bool privacyActive: shellRootController
        && shellRootController.privacyActive !== undefined
        ? !!shellRootController.privacyActive
        : SystemServices.privacyActive
    property bool autoHideVisible: false
    // The pointer over any island surface (capsule and its content, satellites, detail popups)
    // or the reveal strip. Comes from the layer-wide HoverHandler, which child content cannot
    // obscure the way it does a MouseArea's containsMouse.
    readonly property bool autoHidePointerInside: root.pointerOverIsland() || autoHideRevealArea.containsMouse
        || autoHideRevealDropArea.containsDrag || islandFileDropArea.containsDrag
    onAutoHidePointerInsideChanged: {
        if (!autoHidePointerInside)
            scheduleAutoHide();
    }
    property bool autoHideForcedHidden: false
    property string autoHideRevealSource: "none"

    readonly property var userConfig: UserConfig

    Loader {
        id: fallbackWeatherServiceLoader
        active: (!root.shellRootController || !root.shellRootController.weatherService)
            && (userConfig ? userConfig.weatherEnabled : true)
        sourceComponent: Component {
            WeatherService {
                weatherEnabled: true
            }
        }
    }

    readonly property var weatherService: (root.shellRootController && root.shellRootController.weatherService)
        ? root.shellRootController.weatherService
        : (fallbackWeatherServiceLoader.item || null)

    color: StyleTokens.transparent
    WlrLayershell.namespace: "tide-island"
    anchors { top: !root.atBottom; bottom: root.atBottom; left: true; right: true }

    // Blur only the visible material, never the full-width layer surface or
    // the invisible gesture strip. The input mask remains independent.
    BackgroundEffect.blurRegion: root.userConfig.islandBlurEnabled ? nativeBlurRegion : null

    readonly property Region nativeBlurRegions: Region {
        id: nativeBlurRegion

        InsetBlurRegion {
            surface: mainCapsule
            active: mainCapsule.opacity > 0.01 && root.userConfig.islandBackgroundOpacity > 0
                && root.userConfig.islandBackgroundOpacity < 100
            surfaceRadius: mainCapsule.radius
        }
        InsetBlurRegion {
            surface: fileShelfBubble
            active: fileShelfBubble.visible && fileShelfBubble.opacity > 0.01
            surfaceRadius: fileShelfBubble.width / 2
        }
        InsetBlurRegion {
            surface: bluetoothEarphoneBubble
            active: bluetoothEarphoneBubble.visible && bluetoothEarphoneBubble.opacity > 0.01
            surfaceRadius: bluetoothEarphoneBubble.width / 2
            transformDependencies: [bluetoothEarphoneBubble.x, bluetoothEarphoneBubble.y, bluetoothEarphoneBubble.scale]
        }
        InsetBlurRegion {
            surface: cameraBubble
            active: cameraBubble.visible && cameraBubble.opacity > 0.01
            surfaceRadius: cameraBubble.width / 2
            transformDependencies: [cameraBubble.x, cameraBubble.y, cameraBubble.scale]
        }
        InsetBlurRegion {
            surface: micBubble
            active: micBubble.visible && micBubble.opacity > 0.01
            surfaceRadius: micBubble.width / 2
            transformDependencies: [micBubble.x, micBubble.y, micBubble.scale]
        }
        InsetBlurRegion {
            surface: timerBubble
            active: timerBubble.visible && timerBubble.opacity > 0.01
            surfaceRadius: timerBubble.width / 2
            transformDependencies: [timerBubble.x, timerBubble.y, timerBubble.scale]
        }
        InsetBlurRegion {
            surface: wifiConnectivityDetailShell.surfaceItem
            active: wifiConnectivityDetailShell.visible && wifiConnectivityDetailShell.opacity > 0.01
            surfaceRadius: 10
            transformDependencies: [wifiConnectivityDetailShell.x, wifiConnectivityDetailShell.y,
                wifiConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: bluetoothConnectivityDetailShell.surfaceItem
            active: bluetoothConnectivityDetailShell.visible && bluetoothConnectivityDetailShell.opacity > 0.01
            surfaceRadius: 10
            transformDependencies: [bluetoothConnectivityDetailShell.x, bluetoothConnectivityDetailShell.y,
                bluetoothConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: powerConnectivityDetailShell.surfaceItem
            active: powerConnectivityDetailShell.visible && powerConnectivityDetailShell.opacity > 0.01
            surfaceRadius: 10
            transformDependencies: [powerConnectivityDetailShell.x, powerConnectivityDetailShell.y,
                powerConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: audioConnectivityDetailShell.surfaceItem
            active: audioConnectivityDetailShell.visible && audioConnectivityDetailShell.opacity > 0.01
            surfaceRadius: 10
            transformDependencies: [audioConnectivityDetailShell.x, audioConnectivityDetailShell.y,
                audioConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: calendarNoteShell.surfaceItem
            active: calendarNoteShell.visible && calendarNoteShell.opacity > 0.01
            surfaceRadius: 10
            transformDependencies: [calendarNoteShell.x, calendarNoteShell.y, calendarNoteShell.panelScale]
        }
        // Clip the completed union before sending it to the compositor. During
        // auto-hide the capsule leaves the window before its opacity reaches
        // zero. A compositor may treat a nonempty, wholly offscreen blur region as
        // unrestricted blur after clipping it, flashing the full layer surface.
        Region {
            intersection: Intersection.Intersect
            width: root.width
            height: root.height
        }
    }
    mask: Region {
        // Input is the union of the island's visible surfaces plus, with auto-hide, the edge
        // strip that reveals it (pointer or file drag). The strip never grows with content.
        Region {
            x: Math.floor(root.autoHideRevealX)
            y: Math.floor(root.autoHideRevealY)
            width: Math.ceil(root.autoHideRevealWidth)
            height: Math.ceil(root.autoHideRevealHeight)
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(mainCapsule.x)
            y: Math.floor(mainCapsule.y)
            width: Math.ceil(mainCapsule.width)
            height: Math.ceil(mainCapsule.height)
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(fileShelfBubble.x)
            y: Math.floor(fileShelfBubble.y)
            width: fileShelfBubble.visible ? Math.ceil(fileShelfBubble.width) : 0
            height: fileShelfBubble.visible ? Math.ceil(fileShelfBubble.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(bluetoothEarphoneBubble.x)
            y: Math.floor(bluetoothEarphoneBubble.y)
            width: bluetoothEarphoneBubble.visible ? Math.ceil(bluetoothEarphoneBubble.width) : 0
            height: bluetoothEarphoneBubble.visible ? Math.ceil(bluetoothEarphoneBubble.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(cameraBubble.x)
            y: Math.floor(cameraBubble.y)
            width: cameraBubble.visible ? Math.ceil(cameraBubble.width) : 0
            height: cameraBubble.visible ? Math.ceil(cameraBubble.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(micBubble.x)
            y: Math.floor(micBubble.y)
            width: micBubble.visible ? Math.ceil(micBubble.width) : 0
            height: micBubble.visible ? Math.ceil(micBubble.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(timerBubble.x)
            y: Math.floor(timerBubble.y)
            width: timerBubble.visible ? Math.ceil(timerBubble.width) : 0
            height: timerBubble.visible ? Math.ceil(timerBubble.height) : 0
        }
        
        // Add existing detail shells
        Region {
            intersection: Intersection.Combine
            x: Math.floor(wifiConnectivityDetailShell.x)
            y: Math.floor(wifiConnectivityDetailShell.y)
            width: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.width) : 0
            height: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(bluetoothConnectivityDetailShell.x)
            y: Math.floor(bluetoothConnectivityDetailShell.y)
            width: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.width) : 0
            height: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(powerConnectivityDetailShell.x)
            y: Math.floor(powerConnectivityDetailShell.y)
            width: powerConnectivityDetailShell.visible ? Math.ceil(powerConnectivityDetailShell.width) : 0
            height: powerConnectivityDetailShell.visible ? Math.ceil(powerConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(audioConnectivityDetailShell.x)
            y: Math.floor(audioConnectivityDetailShell.y)
            width: audioConnectivityDetailShell.visible ? Math.ceil(audioConnectivityDetailShell.width) : 0
            height: audioConnectivityDetailShell.visible ? Math.ceil(audioConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(calendarNoteShell.x)
            y: Math.floor(calendarNoteShell.y)
            width: calendarNoteShell.visible ? Math.ceil(calendarNoteShell.width) : 0
            height: calendarNoteShell.visible ? Math.ceil(calendarNoteShell.height) : 0
        }

        // While a dismissible panel is open, take the whole surface so outside clicks reach us.
        Region {
            intersection: Intersection.Combine
            width: root.outsideClickDismissActive ? Math.ceil(root.width) : 0
            height: root.outsideClickDismissActive ? Math.ceil(root.height) : 0
        }
    }
    // Panels that close on a click outside them. While one is open the surface grows to the
    // full output height and its input mask covers it (outsideClickDismissArea). The file
    // shelf is excluded so drags out of it can still drop onto other windows.
    readonly property bool outsideClickDismissActive: !root.connectivityPromptActive
        && (["control_center", "notification_center", "calendar", "weather", "glance",
            "clipboard", "privacy_hud"]
            .indexOf(islandContainer.islandState) !== -1
            || (root.powerDetailStandalone && root.powerConnectivityDetailMounted))
    readonly property real outsideClickDismissWindowHeight: root.outsideClickDismissActive && root.screen
        ? root.screen.height
        : 0
    readonly property real capsuleWindowHeight: Math.ceil(
        islandContainer.effectiveTopMargin + mainCapsule.targetHeight + 12
    )
    readonly property real connectivityDetailWindowHeight: !root.anyConnectivityDetailMounted
        ? 0
        : root.powerDetailStandalone
            ? Math.ceil(islandContainer.effectiveTopMargin + mainCapsule.targetHeight + root.connectivityDetailGap
                + root.connectivityDetailHeight + 12)
            : Math.ceil(islandContainer.effectiveTopMargin + root.connectivityDetailHeight + 12)
    readonly property real requestedWindowHeight: Math.max(
        root.notificationCenterWindowHeight,
        root.capsuleWindowHeight,
        root.connectivityDetailWindowHeight,
        root.outsideClickDismissWindowHeight,
        Math.ceil(root.controlCenterWindowHeight)
    )
    // Grow the layer surface immediately, but keep the old extent while the
    // capsule finishes its collapse animation. A later expansion interrupts
    // the pending shrink instead of letting a stale timer clip new content.
    property real retainedWindowHeight: 0
    implicitHeight: Math.max(root.requestedWindowHeight, root.retainedWindowHeight)

    function reconcileWindowHeight() {
        if (root.requestedWindowHeight >= root.retainedWindowHeight) {
            windowShrinkTimer.stop();
            root.retainedWindowHeight = root.requestedWindowHeight;
            return;
        }

        windowShrinkTimer.restart();
    }

    onRequestedWindowHeightChanged: root.reconcileWindowHeight()
    Component.onCompleted: root.retainedWindowHeight = root.requestedWindowHeight

    exclusiveZone: Math.ceil(root.baseExclusiveZone * root.exclusiveZoneProgress)
    WlrLayershell.layer: islandContainer.fileShelfLayerVisible
        || islandContainer.clipboardLayerVisible
        || islandContainer.weatherLayerVisible
        || islandContainer.calendarLayerVisible
        || islandContainer.privacyHudLayerVisible
        || islandContainer.glanceLayerVisible
        || islandContainer.notificationCenterLayerVisible
        ? WlrLayer.Overlay
        : WlrLayer.Top
    WlrLayershell.keyboardFocus: {
        if (islandContainer.controlCenterLayerVisible
                || islandContainer.notificationCenterLayerVisible
                || islandContainer.fileShelfLayerVisible
                || islandContainer.clipboardLayerVisible
                || islandContainer.weatherLayerVisible
                || islandContainer.calendarLayerVisible
                || islandContainer.privacyHudLayerVisible
                || islandContainer.glanceLayerVisible
                || islandContainer.notificationCenterLayerVisible)
            return WlrKeyboardFocus.Exclusive;
        if (root.powerDetailStandalone && root.powerConnectivityDetailMounted)
            return WlrKeyboardFocus.Exclusive;
        if (islandContainer.notificationLayerVisible)
            return WlrKeyboardFocus.OnDemand;
        if (islandContainer.expandedPlayerKeyboardFocusRequested)
            return WlrKeyboardFocus.Exclusive;
        return WlrKeyboardFocus.None;
    }
    readonly property string iconFontFamily: userConfig.iconFontFamily
    readonly property string textFontFamily: userConfig.textFontFamily
    readonly property string heroFontFamily: userConfig.heroFontFamily
    readonly property string timeFontFamily: userConfig.timeFontFamily
    readonly property int bodyFontSize: userConfig.bodyFontSize
    readonly property int titleFontSize: userConfig.titleFontSize
    readonly property int iconFontSize: userConfig.iconFontSize
    readonly property string defaultSplitIcon: "\ud83c\udfa7"
    readonly property string notificationStatusIcon: "\uf0f3"
    readonly property int dynamicIslandAcceptedButtons: userConfig.mouseButtonsMask([
        1,
        2,
        userConfig.dynamicIslandPrimaryButton,
        userConfig.dynamicIslandSecondaryButton,
        userConfig.dynamicIslandMiddleButton
    ])
    readonly property int configuredHoverExpandAction: {
        const action = Number(userConfig.hoverExpandAction);
        return isNaN(action) ? 0 : Math.max(0, Math.min(2, Math.round(action)));
    }
    readonly property real baseExclusiveZone: userConfig.islandExclusiveZone
    readonly property bool hoverExpandEnabled: configuredHoverExpandAction > 0
    readonly property bool autoHideRuntimeEnabled: !shellRootController
        || shellRootController.islandAutoHideRuntimeEnabled === undefined
        || !!shellRootController.islandAutoHideRuntimeEnabled
    readonly property bool autoHideEnabled: userConfig.islandAutoHideEnabled && autoHideRuntimeEnabled
    readonly property bool autoHideRestingState: islandContainer.islandState === "normal"
        || islandContainer.islandState === "custom"
        || islandContainer.islandState === "lyrics"
    // With islandAutoHideKeepActivities, the music or battery section keeps the island revealed.
    readonly property bool restingActivityPinned: userConfig.islandAutoHideKeepActivities
        && islandContainer.islandState === "normal"
        && (islandContainer.restingMusicVisible || islandContainer.restingBatteryVisible)
    readonly property bool autoHideCanHideNow: autoHideEnabled
        && !restingActivityPinned
        && autoHideRestingState
        && !root.connectivityPromptActive
        && !root.anyConnectivityDetailMounted
    readonly property bool autoHideMustShow: (!autoHideRestingState && !islandContainer.transientSlideOut)
        || restingActivityPinned
        || root.connectivityPromptActive
        || root.anyConnectivityDetailMounted
    readonly property bool autoHideTargetVisible: autoHideMustShow
        || (!autoHideForcedHidden && (!autoHideEnabled || autoHideVisible))
    readonly property bool autoHideSuppressesTransientReveal: (autoHideEnabled || autoHideForcedHidden)
        && !autoHideTargetVisible
    property real autoHideProgress: autoHideTargetVisible ? 1 : 0
    readonly property bool exclusiveZoneTargetActive: (!autoHideEnabled && autoHideTargetVisible)
        || (autoHideRevealSource === "edge" && autoHideTargetVisible)
        || islandContainer.notificationLayerVisible
    property real exclusiveZoneProgress: exclusiveZoneTargetActive ? 1 : 0
    readonly property real autoHideRevealWidth: autoHideEnabled ? Math.min(root.width, Math.max(userConfig.islandWidth + 120, 240)) : 0
    readonly property real autoHideRevealHeight: autoHideEnabled ? 10 : 0
    readonly property real autoHideRevealY: root.edgeY(0, autoHideRevealHeight)
    readonly property real autoHideRevealX: Math.max(
        0,
        Math.min(root.width - autoHideRevealWidth, root.width * userConfig.islandPositionX / 100 - autoHideRevealWidth / 2)
    )
    property bool wifiConnectivityDetailOpen: false
    property bool wifiConnectivityDetailMounted: false
    property bool bluetoothConnectivityDetailOpen: false
    property bool bluetoothConnectivityDetailMounted: false
    property bool powerConnectivityDetailOpen: false
    property bool powerConnectivityDetailMounted: false
    property bool audioConnectivityDetailOpen: false
    property bool audioConnectivityDetailMounted: false
    property string audioConnectivityDetailKind: "audio_output"
    readonly property bool anyConnectivityDetailMounted: wifiConnectivityDetailMounted || bluetoothConnectivityDetailMounted || powerConnectivityDetailMounted || audioConnectivityDetailMounted
    readonly property real connectivityDetailWidth: 318
    readonly property real connectivityDetailHeight: 404
    readonly property bool controlCenterActiveRecording: ScreenRecorder ? ScreenRecorder.isRecording : false
    readonly property real controlCenterActiveRecorderHeight: controlCenterActiveRecording ? 98 : 0
    readonly property real controlCenterActiveRecorderExtraHeight: controlCenterActiveRecording
        ? controlCenterActiveRecorderHeight + 10
        : 0
    readonly property real defaultControlCenterExtraHeight: 92 + controlCenterActiveRecorderExtraHeight
    readonly property real defaultControlCenterMaximumExtraHeight: 92 + controlCenterActiveRecorderExtraHeight

    readonly property real controlCenterMaximumExtraHeight: controlCenterLoader.item
        ? controlCenterLoader.item.controlCenterMaximumExtraHeight
        : root.defaultControlCenterMaximumExtraHeight
    readonly property real controlCenterWindowHeight: islandContainer.controlCenterLayerVisible
        ? islandContainer.effectiveTopMargin + 406 + root.controlCenterMaximumExtraHeight + 12
        : 0

    readonly property real notificationCenterWindowHeight: islandContainer.notificationCenterLayerVisible
        ? islandContainer.effectiveTopMargin + (notificationCenterLoader.item ? notificationCenterLoader.item.contentHeight : 400) + 6
        : 0
    readonly property real connectivityDetailGap: 12
    readonly property int connectivityDetailAnimationDuration: 220

    Behavior on autoHideProgress {
        NumberAnimation {
            duration: root.autoHideTargetVisible ? 70 : 180
            easing.type: root.autoHideTargetVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    Behavior on exclusiveZoneProgress {
        NumberAnimation {
            duration: root.exclusiveZoneTargetActive ? 70 : 180
            easing.type: root.exclusiveZoneTargetActive ? Easing.OutCubic : Easing.InCubic
        }
    }

    function setAutoHideRevealSource(source) {
        if (source === undefined || source === null)
            return;

        const nextSource = String(source);
        autoHideRevealSource = ["edge", "state", "manual", "drag"].indexOf(nextSource) !== -1
            ? nextSource
            : "manual";
    }

    function showAutoHiddenIsland(source) {
        // Revealed (hover, edge, IPC...) while an OSD slides away: back to the resting layout.
        if (islandContainer.transientSlideOut)
            islandContainer.cancelTransientSlideOut();
        setAutoHideRevealSource(source);
        autoHideForcedHidden = false;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            autoHideVisible = true;
            return;
        }

        autoHideHideTimer.stop();
        autoHideVisible = true;
    }

    function scheduleAutoHide() {
        if (islandContainer.transientSlideOut)
            return;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            autoHideVisible = true;
            return;
        }

        if (!autoHideCanHideNow) {
            autoHideHideTimer.stop();
            showAutoHiddenIsland("state");
            return;
        }

        if (autoHidePointerInside) {
            autoHideHideTimer.stop();
            return;
        }

        autoHideHideTimer.interval = Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs));
        autoHideHideTimer.restart();
    }

    function hideAutoHiddenIsland(force) {
        if (force === undefined) force = false;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            if (!force && autoHideMustShow)
                return;
            autoHideForcedHidden = true;
            autoHideRevealSource = "none";
            autoHideVisible = false;
            return;
        }

        if (!force && (!autoHideCanHideNow || autoHidePointerInside))
            return;

        autoHideHideTimer.stop();
        autoHideForcedHidden = false;
        autoHideRevealSource = "none";
        autoHideVisible = false;
    }

    // Whether the island would hide as soon as it is back at rest; then an OSD that revealed it
    // can slide it away directly instead of morphing back to the clock first.
    function transientCanSlideOut() {
        return (autoHideEnabled || autoHideForcedHidden)
            && !autoHidePointerInside
            && !root.connectivityPromptActive
            && !root.anyConnectivityDetailMounted
            && !(userConfig.islandAutoHideKeepActivities
                && (islandContainer.restingMusicVisible || islandContainer.restingBatteryVisible));
    }

    onAutoHideProgressChanged: {
        if (islandContainer.transientSlideOut && autoHideProgress <= 0.001)
            islandContainer.finishTransientSlideOut();
    }

    function toggleAutoHiddenIsland() {
        if (autoHideTargetVisible)
            hideAutoHiddenIsland(false);
        else
            showAutoHiddenIsland("manual");
    }

    function showIslandWindow() {
        showAutoHiddenIsland("manual");
    }

    // An explicit hide request wins over the pointer resting on the island.
    function hideIslandWindow() {
        hideAutoHiddenIsland(autoHideEnabled && autoHideCanHideNow);
    }

    function toggleIslandWindow() {
        toggleAutoHiddenIsland();
    }

    function refreshAutoHideWindow() {
        if (autoHideEnabled)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("manual");
    }

    function setConnectivityDetailVisible(kind, open) {
        const nextOpen = !!open;

        if (nextOpen) {
            if (kind !== "wifi" && (wifiConnectivityDetailMounted || wifiConnectivityDetailOpen)) {
                wifiConnectivityDetailOpen = false;
                wifiConnectivityDetailCleanupTimer.restart();
            }
            if (kind !== "power" && (powerConnectivityDetailMounted || powerConnectivityDetailOpen)) {
                powerConnectivityDetailOpen = false;
                powerConnectivityDetailCleanupTimer.restart();
            }
            if (kind !== "bluetooth" && (bluetoothConnectivityDetailMounted || bluetoothConnectivityDetailOpen)) {
                bluetoothConnectivityDetailOpen = false;
                bluetoothConnectivityDetailCleanupTimer.restart();
            }
            if (!kind.startsWith("audio") && (root.audioConnectivityDetailMounted || root.audioConnectivityDetailOpen)) {
                root.audioConnectivityDetailOpen = false;
                audioConnectivityDetailCleanupTimer.restart();
            }
        }

        if (kind === "wifi") {
            if (nextOpen) {
                wifiConnectivityDetailCleanupTimer.stop();
                wifiConnectivityDetailMounted = true;
                wifiConnectivityDetailOpen = true;
            } else {
                if (!wifiConnectivityDetailMounted && !wifiConnectivityDetailOpen)
                    return;
                wifiConnectivityDetailOpen = false;
                wifiConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "power") {
            if (nextOpen) {
                powerConnectivityDetailCleanupTimer.stop();
                powerConnectivityDetailMounted = true;
                powerConnectivityDetailOpen = true;
            } else {
                if (!powerConnectivityDetailMounted && !powerConnectivityDetailOpen)
                    return;
                powerConnectivityDetailOpen = false;
                powerConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "bluetooth") {
            if (nextOpen) {
                bluetoothConnectivityDetailCleanupTimer.stop();
                bluetoothConnectivityDetailMounted = true;
                bluetoothConnectivityDetailOpen = true;
            } else {
                if (!bluetoothConnectivityDetailMounted && !bluetoothConnectivityDetailOpen)
                    return;
                bluetoothConnectivityDetailOpen = false;
                bluetoothConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "audio_output" || kind === "audio_input" || kind.startsWith("audio")) {
            root.audioConnectivityDetailKind = kind;
            if (nextOpen) {
                audioConnectivityDetailCleanupTimer.stop();
                root.audioConnectivityDetailMounted = true;
                root.audioConnectivityDetailOpen = true;
            } else {
                if (!root.audioConnectivityDetailMounted && !root.audioConnectivityDetailOpen)
                    return;
                root.audioConnectivityDetailOpen = false;
                audioConnectivityDetailCleanupTimer.restart();
            }
        }
    }

    // The battery section of the resting island opens the battery popup on its own, under the
    // capsule, without the control center.
    property bool powerDetailStandalone: false

    // The control center stays hidden but is loaded as the popup's provider; it owns the panel
    // state (and Escape), as when the popup is opened from its header.
    function toggleStandalonePowerDetail() {
        if (powerDetailStandalone && powerConnectivityDetailOpen) {
            closeConnectivityOverlays();
            return;
        }
        powerDetailStandalone = true;
        powerConnectivityDetailMounted = true;
        const controlCenter = controlCenterLoader.item;
        if (controlCenter)
            controlCenter.toggleConnectivityOverlay("power");
        else
            setConnectivityDetailVisible("power", true);
    }

    function closeConnectivityOverlays() {
        if (controlCenterLoader.item && controlCenterLoader.item.closeConnectivityPanels)
            controlCenterLoader.item.closeConnectivityPanels();
        closeAllConnectivityDetails();
    }

    function closeAllConnectivityDetails() {
        setConnectivityDetailVisible("wifi", false);
        setConnectivityDetailVisible("bluetooth", false);
        setConnectivityDetailVisible("power", false);
        setConnectivityDetailVisible("audio_output", false);
        setConnectivityDetailVisible("audio_input", false);
    }

    // Called by the notification daemon in shell.qml with a record and a mode:
    // "popup" (show + history), "update" (refresh in place), "history" (record only).
    function presentNotificationRecord(record, mode) {
        islandContainer.presentNotificationRecord(record, mode);
    }

    function removeNotification(id) {
        islandContainer.removeNotificationById(id);
    }

    function clearNotificationHistory() {
        islandContainer.notificationHistoryModel.clear();
    }

    // The daemon lives in shell.qml (shellRootController); it owns the Notification objects.
    function dismissNotification(id) {
        if (shellRootController && shellRootController.dismissNotification)
            shellRootController.dismissNotification(id);
        else
            islandContainer.removeNotificationById(id);
    }

    // The action runs shortly after, once the app has its activation token (see shell.qml).
    function invokeNotificationAction(id, actionKey) {
        return !!(shellRootController && shellRootController.invokeNotificationAction
            && shellRootController.invokeNotificationAction(id, actionKey, islandContainer.Window.window));
    }

    // The Open pill and history clicks: run the app's default action (if it has one; invoking
    // closes a non-resident notification, and its activation token lets the app raise its
    // window). `details` is captured by the caller beforehand, because the popup may be cleared
    // in the meantime.
    function activateNotification(details, dismissAfter) {
        const invoked = root.invokeNotificationAction(details.id, "default");
        const resident = !!(shellRootController && shellRootController.notificationIsResident
            && shellRootController.notificationIsResident(details.id));
        if (dismissAfter && !invoked && !resident)
            root.dismissNotification(details.id);
    }

    function showClockWindow() {
        islandContainer.showTimeCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }
    function showCustomInfoWindow() {
        islandContainer.showCustomCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }
    function showLyricsWindow() {
        islandContainer.showLyricsCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeRightWindow() {
        if (islandContainer.restingState === "lyrics")
            islandContainer.showTimeCapsule();
        else if (islandContainer.restingState === "normal") {
            if (islandContainer.hasCustomLeftItems)
                islandContainer.showCustomCapsule();
            else
                islandContainer.showLyricsCapsule();
        }
        else
            islandContainer.showLyricsCapsule();

        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeLeftWindow() {
        if (islandContainer.restingState === "custom")
            islandContainer.showTimeCapsule();
        else if (islandContainer.restingState === "normal")
            islandContainer.showLyricsCapsule();
        else if (islandContainer.hasCustomLeftItems)
            islandContainer.showCustomCapsule();
        else
            islandContainer.showTimeCapsule();

        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function togglePlayerWindow() {
        if (islandContainer.islandState === "expanded")
            islandContainer.smartRestoreState();
        else
            islandContainer.showExpandedPlayer(false);
    }

    function showTimerWindow() {
        islandContainer.showExpandedTimerPage();
    }

    function toggleControlCenterWindow() {
        if (islandContainer.islandState === "control_center") {
            if (controlCenterLoader.item && controlCenterLoader.item.powerViewActive) {
                controlCenterLoader.item.powerViewActive = false;
            } else {
                islandContainer.smartRestoreState();
            }
        } else {
            islandContainer.powerMenuRequested = false;
            islandContainer.showControlCenter();
            if (controlCenterLoader.item)
                controlCenterLoader.item.powerViewActive = false;
        }
    }

    function togglePowerMenuWindow() {
        if (islandContainer.islandState === "control_center"
                && controlCenterLoader.item
                && controlCenterLoader.item.powerViewActive) {
            islandContainer.smartRestoreState();
            return;
        }

        islandContainer.powerMenuRequested = true;
        islandContainer.showControlCenter();
        if (controlCenterLoader.item) {
            controlCenterLoader.item.powerViewActive = true;
            islandContainer.powerMenuRequested = false;
        }
    }

    function toggleNotificationCenterWindow() {
        if (islandContainer.islandState === "notification_center")
            islandContainer.smartRestoreState();
        else
            islandContainer.showNotificationCenter();
    }

    function toggleFileShelfWindow() {
        if (islandContainer.islandState === "file_shelf")
            islandContainer.smartRestoreState();
        else
            islandContainer.showFileShelf(true);
    }

    function toggleClipboardWindow() {
        if (islandContainer.islandState === "clipboard")
            islandContainer.smartRestoreState();
        else
            islandContainer.showClipboard();
    }

    function showClipboardWindow() {
        islandContainer.showClipboard();
    }

    function closeClipboardWindow() {
        if (islandContainer.islandState === "clipboard")
            islandContainer.smartRestoreState();
    }

    function toggleWeatherWindow() {
        if (islandContainer.islandState === "weather")
            islandContainer.smartRestoreState();
        else
            islandContainer.showWeather();
    }

    function showWeatherWindow() {
        islandContainer.showWeather();
    }

    function closeWeatherWindow() {
        if (islandContainer.islandState === "weather")
            islandContainer.smartRestoreState();
    }

    function toggleCalendarWindow() {
        if (islandContainer.islandState === "calendar")
            islandContainer.smartRestoreState();
        else
            islandContainer.showCalendar();
    }

    function showCalendarWindow() {
        islandContainer.showCalendar();
    }

    function closeCalendarWindow() {
        if (islandContainer.islandState === "calendar")
            islandContainer.smartRestoreState();
    }

    function togglePrivacyHudWindow() {
        if (islandContainer.islandState === "privacy_hud")
            islandContainer.smartRestoreState();
        else {
            islandContainer.showPrivacyHud();
            showIslandWindow();
        }
    }

    function showPrivacyHudWindow() {
        islandContainer.showPrivacyHud();
        showIslandWindow();
    }

    function closePrivacyHudWindow() {
        if (islandContainer.islandState === "privacy_hud")
            islandContainer.smartRestoreState();
    }

    function toggleGlanceWindow() {
        if (islandContainer.islandState === "glance")
            islandContainer.smartRestoreState();
        else {
            islandContainer.showGlance();
            showIslandWindow();
        }
    }

    function showGlanceWindow() {
        islandContainer.showGlance();
        showIslandWindow();
    }

    function closeGlanceWindow() {
        if (islandContainer.islandState === "glance")
            islandContainer.smartRestoreState();
    }
    onConnectivityPromptActiveChanged: {
        if (connectivityPromptActive)
            showAutoHiddenIsland("state");
        else
            scheduleAutoHide();
    }
    onAutoHideEnabledChanged: {
        if (autoHideEnabled)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("manual");
    }
    onAutoHideCanHideNowChanged: {
        if (autoHideCanHideNow)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("state");
    }

    Timer {
        id: connectivityPromptFocusTimer
        interval: 0
        repeat: false
        onTriggered: islandContainer.forceActiveFocus()
    }

    Timer {
        id: expandedPlayerFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusExpandedPlayer()
    }

    Timer {
        id: windowShrinkTimer
        interval: 600
        repeat: false
        onTriggered: root.retainedWindowHeight = root.requestedWindowHeight
    }

    Timer {
        id: autoHideHideTimer
        interval: Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs))
        repeat: false
        onTriggered: root.hideAutoHiddenIsland(false)
    }

    function focusExpandedPlayer() {
        islandContainer.requestExpandedPlayerKeyboardFocus();
        if (expandedPlayerLoader.item && expandedPlayerLoader.item.grabKeyboardFocus)
            expandedPlayerLoader.item.grabKeyboardFocus();
    }

    function focusFileShelf() {
        islandContainer.forceActiveFocus();
        if (fileShelfLoader.item && fileShelfLoader.item.grabKeyboardFocus)
            fileShelfLoader.item.grabKeyboardFocus();
    }

    function focusClipboard() {
        islandContainer.forceActiveFocus();
        if (clipboardLoader.item && clipboardLoader.item.grabKeyboardFocus)
            clipboardLoader.item.grabKeyboardFocus();
    }

    function dragCarriesFiles(dragEvent) {
        if (!dragEvent)
            return false;
        if (dragEvent.hasUrls)
            return true;

        const formats = dragEvent.formats || [];
        return formats.indexOf("text/uri-list") >= 0
            || formats.indexOf("x-special/gnome-copied-files") >= 0;
    }

    function addFilesFromDrop(dropEvent) {
        if (!dropEvent)
            return 0;

        let added = 0;
        if (dropEvent.hasUrls)
            added += FileShelf.addUrls(dropEvent.urls);

        const formats = dropEvent.formats || [];
        if (added === 0 && formats.indexOf("text/uri-list") >= 0)
            added += FileShelf.addUriList(dropEvent.getDataAsString("text/uri-list"));
        if (added === 0 && formats.indexOf("x-special/gnome-copied-files") >= 0)
            added += FileShelf.addUriList(dropEvent.getDataAsString("x-special/gnome-copied-files"));
        return added;
    }

    Timer {
        id: wifiConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.wifiConnectivityDetailMounted = false
    }

    Timer {
        id: bluetoothConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.bluetoothConnectivityDetailMounted = false
    }

    Timer {
        id: powerConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: {
            root.powerConnectivityDetailMounted = false;
            root.powerDetailStandalone = false;
        }
    }

    Timer {
        id: audioConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.audioConnectivityDetailMounted = false
    }

    IslandClock {
        id: timeObj
        clockFormat: userConfig.clockFormat
    }

    // --- 灵动岛主容器与全局状态 ---
    FocusScope {
        id: islandContainer
        anchors.fill: parent
        focus: controlCenterLayerVisible
            || notificationCenterLayerVisible
            || fileShelfLayerVisible
            || clipboardLayerVisible
            || weatherLayerVisible
            || calendarLayerVisible
            || notificationCenterLayerVisible
            || notificationLayerVisible
            || expandedPlayerKeyboardFocusRequested

        property bool powerMenuRequested: false
        property string islandState: "normal"
        property string splitIcon: root.defaultSplitIcon
        property real osdProgress: -1.0
        property bool osdProgressAnimationEnabled: true
        property string osdCustomText: ""
        readonly property int batteryCapacity: systemState.batteryCapacity
        readonly property bool isCharging: systemState.isCharging

        // Unified resting island: music (while playing, with a short grace period so track
        // changes don't flicker), clock, battery (islandBatteryMode: "low" = below 40 %,
        // charging or not; "always"; "never").
        readonly property bool musicPlaying: !!mediaController.activePlayer
            && mediaController.activePlayer.playbackState === MprisPlaybackState.Playing
        property bool restingMusicVisible: false
        readonly property bool restingBatteryVisible: {
            const mode = userConfig.islandBatteryMode;
            if (mode === "never" || batteryCapacity <= 0)
                return false;
            return mode === "always" || batteryCapacity < 40;
        }
        readonly property real restingCapsuleWidth: restingLayer.leftSectionWidth
            + restingLayer.centerSectionWidth + restingLayer.rightSectionWidth

        // Control-center player card: shown while a player has a track (playing or paused);
        // the card's close button hides it until playback starts again or the track changes.
        readonly property bool playerHasTrack: !!mediaController.activePlayer
            && mediaController.playerHasTrackInfo(mediaController.activePlayer)
            && (mediaController.activePlayer.playbackState === MprisPlaybackState.Playing
                || mediaController.activePlayer.playbackState === MprisPlaybackState.Paused)
        property bool playerCardDismissed: false
        readonly property bool playerCardVisible: playerHasTrack && !playerCardDismissed

        onMusicPlayingChanged: {
            if (musicPlaying) {
                restingMusicHideTimer.stop();
                restingMusicVisible = true;
                playerCardDismissed = false;
            } else {
                restingMusicHideTimer.restart();
            }
        }

        Timer {
            id: restingMusicHideTimer
            interval: 2000
            onTriggered: islandContainer.restingMusicVisible = false
        }

        Component.onCompleted: restingMusicVisible = musicPlaying
        readonly property real currentVolume: systemState.currentVolume
        readonly property bool isMuted: systemState.isMuted
        readonly property real currentMicVolume: systemState.currentMicVolume
        readonly property bool isMicMuted: systemState.isMicMuted
        readonly property real currentBrightness: systemState.currentBrightness
        readonly property real currentCpuUsage: systemState.currentCpuUsage
        readonly property real currentRamUsage: systemState.currentRamUsage
        property int notificationId: 0
        property int internalNotificationSerial: 0
        property string notificationAppName: ""
        property string notificationAppIcon: ""
        property string notificationSummary: ""
        property string notificationBody: ""
        property var notificationActions: []
        property string notificationImagePath: ""
        property int notificationUrgency: 1
        property int notificationExpireTimeoutMs: -1
        property bool notificationExpanded: false
        property bool isEmergencyAlert: false
        property real customCapsuleWidth: userConfig.islandWidth
        property real lyricsCapsuleWidth: userConfig.islandWidth
        property string transientCapsuleIcon: ""
        property real transientCapsuleProgress: -1.0
        property string transientCapsuleText: ""
        property string restingState: normalizeRestingState(userConfig.dynamicIslandRestingState)
        property string splitOriginSide: "none"
        property var notificationHistoryModel: ListModel {}
        readonly property var cavaLevels: systemState.cavaLevels
        property real swipeTransitionProgress: 0
        property bool expandedByPlayerAutoOpen: false
        property bool sideSwipeSettling: false
        property bool hoverExpandedActive: false
        onIslandStateChanged: {
            if (islandState === "normal" || islandState === "custom" || islandState === "lyrics")
                hoverExpandedActive = false;
            if (root.powerDetailStandalone && islandState !== "normal")
                root.closeConnectivityOverlays();
            if (islandState !== "split") {
                osdRevealedHiddenIsland = false;
                if (transientSlideOut) {
                    // Something else (e.g. a notification) took over during the slide-out.
                    transientSlideOut = false;
                    root.showAutoHiddenIsland("state");
                }
            }
            if (islandState === "notification_center" && root.shellRootController
                    && root.shellRootController.markNotificationsRead)
                root.shellRootController.markNotificationsRead();
        }

        // Pointer position over the whole layer surface. Hover-collapse uses it instead of
        // capsuleMouseArea.containsMouse, which turns false whenever the pointer is over
        // hover-enabled panel content and made a hover-opened control center close and reopen.
        HoverHandler {
            id: islandHoverTracker
            onHoveredChanged: islandContainer.updateHoverCollapse()
            onPointChanged: islandContainer.updateHoverCollapse()
        }

        // The pointer over a notification popup (any of its content) holds the popup's timeout;
        // leaving restarts it with what was left, but at least notificationResumeMinimumMs.
        readonly property bool notificationPopupHovered: islandState === "notification"
            && islandHoverTracker.hovered
            && islandHoverTracker.point.position.x >= mainCapsule.x
            && islandHoverTracker.point.position.x < mainCapsule.x + mainCapsule.width
            && islandHoverTracker.point.position.y >= mainCapsule.y
            && islandHoverTracker.point.position.y < mainCapsule.y + mainCapsule.height
        readonly property int notificationResumeMinimumMs: 2000
        property bool notificationTimeoutPaused: false
        property int notificationTimeoutRemaining: 0
        property real autoHideTimerStartedAt: 0

        onNotificationPopupHoveredChanged: {
            if (notificationPopupHovered) {
                if (!autoHideTimer.running)
                    return;
                notificationTimeoutRemaining = Math.max(0, autoHideTimer.interval - (Date.now() - autoHideTimerStartedAt));
                autoHideTimer.stop();
                notificationTimeoutPaused = true;
            } else if (notificationTimeoutPaused) {
                notificationTimeoutPaused = false;
                if (islandState === "notification")
                    restartAutoHideTimer(Math.max(notificationTimeoutRemaining, notificationResumeMinimumMs));
            }
        }

        // Resting-island section under the pointer; hover-expand only starts over the clock.
        readonly property string hoveredRestingSection: {
            if (islandState !== "normal" || !islandHoverTracker.hovered)
                return "";
            const point = restingLayer.mapFromItem(islandContainer,
                islandHoverTracker.point.position.x, islandHoverTracker.point.position.y);
            if (point.x < 0 || point.y < 0 || point.x > restingLayer.width || point.y > restingLayer.height)
                return "";
            return restingLayer.sectionAt(point.x, point.y);
        }
        onHoveredRestingSectionChanged: {
            if (!root.hoverExpandEnabled)
                return;
            if (hoveredRestingSection === "clock") {
                hoverCollapseDelayTimer.stop();
                hoverExpandDelayTimer.restart();
            } else {
                hoverExpandDelayTimer.stop();
            }
        }

        function updateHoverCollapse() {
            if (!hoverExpandedActive)
                return;
            if (root.pointerOverIsland())
                hoverCollapseDelayTimer.stop();
            else if (!hoverCollapseDelayTimer.running)
                hoverCollapseDelayTimer.restart();
        }
        property bool expandedPlayerKeyboardFocusRequested: false
        property bool openTimerPageWhenExpanded: false
        property int timerSelectedHours: 0
        property int timerSelectedMinutes: 5
        property int timerTotalSeconds: 300
        property int timerRemainingSeconds: 0
        property bool timerRunning: false
        property bool timerActive: false
        property bool timerCompletionAnimating: false
        property real timerCompletionPulse: 0
        property real timerCompletionFlash: 0
        property bool fileShelfOpenedManually: false
        readonly property int defaultAutoHideInterval: 1250
        readonly property int swipeAnimationDuration: 130
        readonly property bool showsMediaInNormal: restingState === "lyrics"
            || (restingState === "normal" && !!currentTrack)
            || (restingState === "custom" && !hasCustomLeftItems && !!currentTrack)
        readonly property bool fileShelfLayerInteractive: (islandState === "file_shelf" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool clipboardLayerInteractive: (islandState === "clipboard" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool weatherLayerInteractive: (islandState === "weather" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool calendarLayerInteractive: (islandState === "calendar" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfOverlayActive: Boolean(fileShelfLayerInteractive && fileShelfLoader.item && fileShelfLoader.item.hasVisibleCards)
        readonly property bool fileShelfAcceptingDrop: islandFileDropArea.containsDrag
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property real timerProgress: timerActive && timerTotalSeconds > 0
            ? Math.max(0, Math.min(1, timerRemainingSeconds / timerTotalSeconds))
            : 0
        readonly property bool timerBubbleWanted: (timerActive && timerRemainingSeconds > 0 || timerCompletionAnimating)
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfBubbleWanted: FileShelf.count > 0
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property var connectedEarphoneDevice: bluetoothConnectionTracker.activeEarphoneDevice
        readonly property bool bluetoothEarphoneBubbleWanted: !!connectedEarphoneDevice
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property real effectiveTopMargin: userConfig.islandTopMargin
        readonly property int privacyBubbleSize: 36
        readonly property int privacyBubbleGap: 8
        readonly property int privacyBubbleStep: privacyBubbleSize + privacyBubbleGap
        readonly property real bubblesBaseX: mainCapsule.x + mainCapsule.width + privacyBubbleGap
        readonly property bool cameraBubbleWanted: userConfig.privacyCameraBubbleEnabled
            && cameraActive
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool micBubbleWanted: userConfig.privacyMicBubbleEnabled
            && micActive
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property real privacyBubblesOffset: (cameraBubble.mounted ? privacyBubbleStep : 0) + (micBubble.mounted ? privacyBubbleStep : 0)
        readonly property bool fileShelfCanAutoOpen: (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool blocksTransientSplit: islandState === "expanded"
            || islandState === "control_center"
            || islandState === "notification"
            || islandState === "file_shelf"
            || islandState === "clipboard"
            || islandState === "weather"
            || islandState === "calendar"
            || islandState === "privacy_hud"
            || islandState === "glance"
            || islandState === "notification_center"
        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: splitShowsProgress ? 248 : (splitShowsText ? 220 : userConfig.islandWidth)
        readonly property bool canShowSideSwipe: islandState === "normal"
            || islandState === "custom"
            || islandState === "lyrics"
        readonly property real rightSwipeProgress: Math.max(0, swipeTransitionProgress)
        readonly property var customLeftItems: systemState.customLeftItems
        readonly property bool hasCustomLeftItems: systemState.hasCustomLeftItems
        readonly property bool customSwipeVisible: hasCustomLeftItems
            && (
                capsuleMouseArea.sideSwipeInteractive
                ? swipeTransitionProgress < 0
                : (
                    islandState === "custom"
                    || (islandState === "normal" && swipeTransitionProgress < 0)
                    || (islandState === "split" && splitOriginSide === "left")
                )
            )
        readonly property bool lyricsSwipeVisible: (
            capsuleMouseArea.sideSwipeInteractive
            ? swipeTransitionProgress >= 0
            : (
                islandState === "lyrics"
                || (islandState === "normal" && swipeTransitionProgress >= 0)
                || (islandState === "split" && splitOriginSide === "right")
            )
        )
        readonly property bool expandedLayerVisible: islandState === "expanded"
        readonly property bool notificationLayerVisible: islandState === "notification"
        readonly property bool controlCenterLayerVisible: islandState === "control_center"
        readonly property bool notificationCenterLayerVisible: islandState === "notification_center"
        readonly property bool fileShelfLayerVisible: islandState === "file_shelf"
        readonly property bool clipboardLayerVisible: islandState === "clipboard"
        readonly property bool weatherLayerVisible: islandState === "weather"
        readonly property bool calendarLayerVisible: islandState === "calendar"
        readonly property bool privacyHudLayerVisible: islandState === "privacy_hud"
        readonly property bool glanceLayerVisible: islandState === "glance"
        readonly property var activePlayer: mediaController.activePlayer
        readonly property string lyricsDisplayText: mediaController.displayText
        readonly property string currentTrack: mediaController.currentTrack
        readonly property string currentArtist: mediaController.currentArtist
        readonly property string currentArtUrl: mediaController.currentArtUrl
        readonly property real trackProgress: mediaController.trackProgress
        readonly property string timePlayed: mediaController.timePlayed
        readonly property string timeTotal: mediaController.timeTotal
        readonly property bool screenRecordingActive: root.screenRecordingActive
        readonly property bool micActive: root.micActive
        readonly property bool cameraActive: root.cameraActive
        readonly property bool privacyActive: root.privacyActive
        readonly property var bluetoothDevices: bluetoothConnectionTracker.devices

        onExpandedLayerVisibleChanged: {
            if (expandedLayerVisible)
                requestExpandedPlayerKeyboardFocus();
            else
                expandedPlayerKeyboardFocusRequested = false;
        }

        onControlCenterLayerVisibleChanged: {
            if (!controlCenterLayerVisible) {
                // The shells belong to this window, so close them even if
                // clearing a provider's prompts or backend messages fails.
                root.closeAllConnectivityDetails();
                if (controlCenterLoader.item)
                    controlCenterLoader.item.closeConnectivityPanels();
            }
        }

        onFileShelfLayerVisibleChanged: {
            if (!fileShelfLayerVisible)
                fileShelfOpenedManually = false;
        }

        onCustomLeftItemsChanged: {
            if (restingState === "custom" && !hasCustomLeftItems) {
                restingState = "normal";

                if (islandState === "custom"
                        || (islandState === "split" && splitOriginSide === "left")) {
                    restoreRestingCapsule(true);
                } else {
                    applyRestingVisuals();
                }
            }
        }

        IslandMprisController {
            id: mediaController

            expanded: islandContainer.islandState === "expanded"
                || (islandContainer.controlCenterLayerVisible && islandContainer.playerCardVisible)
            clientId: "island-mpris-" + root.screenOutputName
        }

        BluetoothConnectionTracker {
            id: bluetoothConnectionTracker
        }

        IslandSystemState {
            id: systemState

            weatherService: root.weatherService
            configuredLeftSwipeItems: userConfig.dynamicIslandLeftSwipeItems
            timeText: timeObj.currentTime
            dateText: timeObj.currentDateLabel
            currentTrack: islandContainer.currentTrack
            currentArtUrl: islandContainer.currentArtUrl
            customSwipeActive: false
            statsVisible: false
            lyricsCavaActive: islandContainer.restingMusicVisible && restingLayer.visible
                && root.autoHideProgress > 0.001

            onTransientRequested: function(icon, progress, text) {
                islandContainer.showTransientCapsule(icon, progress, text);
            }
        }

        Behavior on osdProgress {
            enabled: islandContainer.osdProgressAnimationEnabled

            SmoothedAnimation { velocity: 2.0; duration: 110; easing.type: Easing.InOutQuad }
        }
        Behavior on swipeTransitionProgress {
            NumberAnimation {
                duration: capsuleMouseArea.sideSwipeInteractive ? 0 : islandContainer.swipeAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.connectivityPromptActive) {
                    if (controlCenterLoader.item) {
                        if (controlCenterLoader.item.wifiPendingPasswordSsid.length > 0)
                            controlCenterLoader.item.clearWifiPrompt();
                        else if (controlCenterLoader.item.bluetoothPairingActive)
                            controlCenterLoader.item.cancelBluetoothPairing();
                    }
                    event.accepted = true;
                    return;
                }

                if (root.anyConnectivityDetailMounted) {
                    root.closeConnectivityOverlays();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.islandState !== islandContainer.restingState) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.notificationCenterLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }
            }
        }

        function handleConfiguredClickAction(actionName) {
            switch (actionName) {
            case "":
            case "none":
                return;
            case "toggleExpandedPlayer":
                if (islandState === "expanded") {
                    autoHideTimer.stop();
                    smartRestoreState();
                } else {
                    showExpandedPlayer(false);
                }
                return;
            case "openExpandedPlayer":
                showExpandedPlayer(false);
                return;
            case "closeExpandedPlayer":
                if (islandState === "expanded")
                    smartRestoreState();
                return;
            case "toggleNotificationCenter":
                if (islandState === "notification_center")
                    smartRestoreState();
                else
                    showNotificationCenter();
                return;
            case "openNotificationCenter":
                showNotificationCenter();
                return;
            case "closeNotificationCenter":
                if (islandState === "notification_center")
                    smartRestoreState();
                return;
            case "toggleControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                else
                    showControlCenter();
                return;
            case "openControlCenter":
                showControlCenter();
                return;
            case "closeControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                return;
            case "toggleRecording":
                ScreenRecorder.toggleRecording();
                return;
            case "toggleLyrics":
                if (restingState === "lyrics")
                    showTimeCapsule();
                else
                    showLyricsCapsule();
                return;
            case "showLyrics":
                showLyricsCapsule();
                return;
            case "showTime":
                showTimeCapsule();
                return;
            case "restoreRestingCapsule":
                smartRestoreState();
                return;
            case "toggleClipboard":
                if (islandState === "clipboard")
                    smartRestoreState();
                else
                    showClipboard();
                return;
            case "openClipboard":
            case "showClipboard":
                showClipboard();
                return;
            case "closeClipboard":
                if (islandState === "clipboard")
                    smartRestoreState();
                return;
            case "toggleWeather":
                if (islandState === "weather")
                    smartRestoreState();
                else
                    showWeather();
                return;
            case "openWeather":
            case "showWeather":
                showWeather();
                return;
            case "closeWeather":
                if (islandState === "weather")
                    smartRestoreState();
                return;
            case "toggleCalendar":
                if (islandState === "calendar")
                    smartRestoreState();
                else
                    showCalendar();
                return;
            case "openCalendar":
            case "showCalendar":
                showCalendar();
                return;
            case "closeCalendar":
                if (islandState === "calendar")
                    smartRestoreState();
                return;
            case "togglePrivacyHud":
                if (islandState === "privacy_hud")
                    smartRestoreState();
                else
                    showPrivacyHud();
                return;
            case "openPrivacyHud":
            case "showPrivacyHud":
                showPrivacyHud();
                return;
            case "closePrivacyHud":
                if (islandState === "privacy_hud")
                    smartRestoreState();
                return;
            case "toggleGlance":
            case "toggleDashboard":
                if (islandState === "glance")
                    smartRestoreState();
                else
                    showGlance();
                return;
            case "openGlance":
            case "showGlance":
            case "openDashboard":
            case "showDashboard":
                showGlance();
                return;
            case "closeGlance":
            case "closeDashboard":
                if (islandState === "glance")
                    smartRestoreState();
                return;
            default:
            }
        }

        function clamp01(value) {
            return Math.max(0, Math.min(1, value));
        }

        // The custom and lyrics pages are gone: every resting state is the unified clock island.
        function normalizeRestingState(nextState) {
            return "normal";
        }

        function restingStateProgress(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function restingStateSide(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            default:
                return "none";
            }
        }

        function swipeRestProgressForState() {
            switch (islandState) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function currentTransientOriginSide() {
            switch (islandState) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            case "split":
                return splitOriginSide;
            default:
                return "none";
            }
        }

        function setOsdProgress(nextProgress, animate) {
            osdProgressAnimationReset.stop();
            osdProgressAnimationEnabled = animate;
            osdProgress = nextProgress;
            if (!animate) osdProgressAnimationReset.restart();
        }

        function abortSideTransientMode() {
            sideTransientRestoreTimer.stop();
            splitOriginSide = "none";
        }

        function clearTransientCapsule() {
            setOsdProgress(-1.0, false);
            osdCustomText = "";
            notificationAppName = "";
            notificationSummary = "";
            notificationBody = "";
            notificationExpanded = false;
        }

        function codePointText(entity, codePoint) {
            return codePoint > 0 && codePoint <= 0x10FFFF ? String.fromCodePoint(codePoint) : entity;
        }

        // Plain text from a (possibly marked-up) notification string. Entities are decoded with
        // &amp; last, so "&amp;lt;" stays "&lt;" instead of turning into "<".
        function cleanNotificationText(text) {
            return String(text === undefined || text === null ? "" : text)
                .replace(/<[^>]*>/g, " ")
                .replace(/&nbsp;/g, " ")
                .replace(/&quot;/g, "\"")
                .replace(/&#39;|&apos;/g, "'")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/&#(\d+);/g, (match, code) => codePointText(match, Number(code)))
                .replace(/&#x([0-9a-fA-F]+);/g, (match, code) => codePointText(match, parseInt(code, 16)))
                .replace(/&amp;/g, "&")
                .replace(/\s+/g, " ")
                .trim();
        }

        function applyRestingVisuals() {
            swipeTransitionProgress = restingStateProgress(restingState);
        }

        function sideSwipeRestProgressForProgress(progressValue) {
            if (progressValue <= -0.5) return -1;
            if (progressValue >= 0.5) return 1;
            return 0;
        }

        function sideSwipeRestWidthForProgress(progressValue) {
            if (progressValue <= -0.5) return customCapsuleWidth;
            if (progressValue >= 0.5) return lyricsCapsuleWidth;
            return restingCapsuleWidth;
        }

        function advanceSideSwipeProgress(currentProgress, deltaX) {
            // No side pages at rest: horizontal drags/scrolls don't move anything.
            return 0;
        }

        function resolveSideSwipeSettle(startProgress, finalProgress) {
            let settleAction = "";
            let settleProgress = sideSwipeRestProgressForProgress(startProgress);
            let settleWidth = sideSwipeRestWidthForProgress(startProgress);

            if (finalProgress >= 0.56) {
                settleAction = "lyrics";
                settleProgress = 1;
                settleWidth = lyricsCapsuleWidth;
            } else if (hasCustomLeftItems && finalProgress <= -0.56) {
                settleAction = "custom";
                settleProgress = -1;
                settleWidth = customCapsuleWidth;
            } else if (startProgress <= -0.5) {
                if (finalProgress >= -0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = restingCapsuleWidth;
                }
            } else if (startProgress >= 0.5) {
                if (finalProgress <= 0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = restingCapsuleWidth;
                }
            } else {
                settleAction = "time";
                settleProgress = 0;
                settleWidth = restingCapsuleWidth;
            }

            return {
                action: settleAction,
                progress: settleProgress,
                width: settleWidth
            };
        }

        function beginSideSwipeSettle(targetWidth) {
            sideSwipeSettling = true;
            mainCapsule.displayedWidth = targetWidth;
            sideSwipeSettleReset.restart();
        }

        function cancelSideSwipeSettle() {
            sideSwipeSettleReset.stop();
            sideSwipeSettling = false;
        }

        function finishSideSwipeSettle() {
            sideSwipeSettling = false;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        }

        // A volume/brightness OSD that revealed the hidden island slides it away still showing
        // the OSD and only switches to the resting layout once it is out of sight.
        property bool osdRevealedHiddenIsland: false
        property bool transientSlideOut: false

        function handleAutoHideTimeout() {
            if (islandState === "split" && osdRevealedHiddenIsland && root.transientCanSlideOut()) {
                transientSlideOut = true;
                root.hideAutoHiddenIsland(true);
                return;
            }
            smartRestoreState();
        }

        function finishTransientSlideOut() {
            transientSlideOut = false;
            osdRevealedHiddenIsland = false;
            restoreRestingCapsule(true);
        }

        function cancelTransientSlideOut() {
            transientSlideOut = false;
            osdRevealedHiddenIsland = false;
            restoreRestingCapsule();
        }

        function restartAutoHideTimer(duration) {
            const interval = duration === undefined ? defaultAutoHideInterval : duration;
            if (notificationPopupHovered) {
                autoHideTimer.stop();
                notificationTimeoutRemaining = interval;
                notificationTimeoutPaused = true;
                return;
            }
            autoHideTimer.interval = interval;
            autoHideTimerStartedAt = Date.now();
            autoHideTimer.restart();
        }

        function stopAutoHideTimer() {
            notificationTimeoutPaused = false;
            autoHideTimer.stop();
            autoHideTimer.interval = defaultAutoHideInterval;
        }

        function requestExpandedPlayerKeyboardFocus() {
            const shouldGrabFocus = !expandedPlayerKeyboardFocusRequested;
            expandedPlayerKeyboardFocusRequested = true;
            if (shouldGrabFocus)
                expandedPlayerFocusTimer.restart();
        }

        function releaseExpandedPlayerKeyboardFocus() {
            expandedPlayerKeyboardFocusRequested = false;
        }

        function clampTimerInput(value, minValue, maxValue) {
            const parsed = parseInt(value, 10);
            if (isNaN(parsed)) return minValue;
            return Math.max(minValue, Math.min(maxValue, parsed));
        }

        function syncTimerDuration(hours, minutes) {
            cancelTimerCompletionAnimation();
            timerSelectedHours = clampTimerInput(hours, 0, 23);
            timerSelectedMinutes = clampTimerInput(minutes, 0, 59);
            timerTotalSeconds = timerSelectedHours * 3600 + timerSelectedMinutes * 60;
            timerRemainingSeconds = 0;
            timerRunning = false;
            timerActive = false;
        }

        function toggleTimer(hours, minutes) {
            if (timerCompletionAnimating)
                cancelTimerCompletionAnimation();

            if (timerRunning) {
                timerRunning = false;
                return;
            }

            if (!timerActive || timerRemainingSeconds <= 0) {
                syncTimerDuration(hours, minutes);
                timerRemainingSeconds = timerTotalSeconds;
                timerActive = timerRemainingSeconds > 0;
            }

            if (timerRemainingSeconds > 0)
                timerRunning = true;
        }

        function resetTimer() {
            cancelTimerCompletionAnimation();
            timerRemainingSeconds = 0;
            timerRunning = false;
            timerActive = false;
        }

        function startTimerCompletionAnimation() {
            timerCompletionPulse = 0;
            timerCompletionFlash = 0;
            timerCompletionAnimating = true;
        }

        function cancelTimerCompletionAnimation() {
            timerCompletionAnimating = false;
            timerCompletionPulse = 0;
            timerCompletionFlash = 0;
        }

        function showExpandedTimerPage() {
            openTimerPageWhenExpanded = true;
            showExpandedPlayer(false);
            if (expandedPlayerLoader.item && expandedPlayerLoader.item.openTimerPage) {
                expandedPlayerLoader.item.openTimerPage();
                openTimerPageWhenExpanded = false;
            }
        }

        function showTransientCapsule(icon, progress, customText) {
            if (progress === undefined)    progress = -1.0;
            if (customText === undefined)  customText = "";

            // Volume/mute/brightness OSDs may reveal an auto-hidden island; other transients stay suppressed.
            if (root.autoHideSuppressesTransientReveal
                    && icon !== systemState.volumeStatusIcon
                    && icon !== systemState.muteStatusIcon
                    && icon !== systemState.brightnessStatusIcon(progress)) return;
            if (blocksTransientSplit) return;

            if (transientSlideOut) {
                // A new value while the previous OSD slides away: bring it back, still the OSD
                // that revealed a hidden island.
                transientSlideOut = false;
                root.showAutoHiddenIsland("state");
            } else if (islandState !== "split") {
                osdRevealedHiddenIsland = !root.autoHideTargetVisible;
            }

            const nextProgress = progress >= 0 ? progress : -1.0;
            const animateProgress = islandState === "split" && osdProgress >= 0 && nextProgress >= 0;
            const animateFromSide = currentTransientOriginSide();

            abortSideTransientMode();
            splitIcon = icon;
            osdCustomText = customText;
            setOsdProgress(nextProgress, animateProgress);
            splitOriginSide = animateFromSide;
            islandState = "split";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        // Normalizes a notification record (from the daemon or tide itself) for display.
        function normalizeNotification(raw) {
            const actions = [];
            const rawActions = raw.actions || [];
            for (let i = 0; i < rawActions.length; i++)
                actions.push(rawActions[i]);

            const cleanedAppName = cleanNotificationText(raw.appName);
            const cleanedSummary = cleanNotificationText(raw.summary);
            const cleanedBody = cleanNotificationText(raw.body);
            return {
                id: typeof raw.id === "number" ? raw.id : 0,
                appName: cleanedAppName !== "" ? cleanedAppName : "Notification",
                appIcon: raw.appIcon || "",
                summary: cleanedSummary !== "" ? cleanedSummary : (cleanedBody !== "" ? cleanedBody : "New notification"),
                body: cleanedSummary !== "" ? cleanedBody : "",
                actions: actions,
                imagePath: raw.imagePath || "",
                urgency: typeof raw.urgency === "number" ? raw.urgency : 1,
                expireTimeoutMs: typeof raw.expireTimeoutMs === "number" ? raw.expireTimeoutMs : -1,
                transient: !!raw.transient
            };
        }

        // Tide's own short feedback notices; their ids come from one shell-wide counter.
        function showNotificationCapsule(appName, summary, body) {
            const id = root.shellRootController && root.shellRootController.nextInternalNotificationId
                ? root.shellRootController.nextInternalNotificationId()
                : -(++internalNotificationSerial);
            presentNotificationRecord({ id: id, appName: appName, summary: summary, body: body }, "popup");
        }

        function presentNotificationRecord(raw, mode) {
            const record = normalizeNotification(raw);
            if (mode === "update") {
                updateNotificationRecord(record);
                return;
            }

            const popupBlocked = mode !== "popup" || islandState === "control_center"
                || islandState === "expanded" || islandState === "file_shelf";
            // Real notifications always reach the history (transient ones never); tide's own
            // feedback (negative ids) is dropped when it can't be shown.
            if (!record.transient && (!popupBlocked || record.id >= 0))
                addNotificationToHistory(record);
            if (popupBlocked)
                return;

            abortSideTransientMode();
            clearTransientCapsule();
            setNotificationPopupContent(record);
            notificationExpanded = false;
            islandState = "notification";
            startNotificationTimeout();
        }

        // How long the popup stays: never for critical urgency, the app's expire_timeout when it
        // gives one (0 = never), otherwise the configured default for its urgency. 0 = no timeout.
        function notificationTimeoutMs(urgency, expireTimeoutMs) {
            if (urgency === 2 || expireTimeoutMs === 0)
                return 0;
            if (expireTimeoutMs > 0)
                return expireTimeoutMs;
            return (urgency === 0 ? userConfig.notificationTimeoutLow : userConfig.notificationTimeout) * 1000;
        }

        function startNotificationTimeout() {
            const timeout = notificationTimeoutMs(notificationUrgency, notificationExpireTimeoutMs);
            if (timeout > 0)
                restartAutoHideTimer(timeout);
            else
                stopAutoHideTimer();
        }

        function setNotificationPopupContent(record) {
            notificationId = record.id;
            notificationAppName = record.appName;
            notificationAppIcon = record.appIcon;
            notificationSummary = record.summary;
            notificationBody = record.body;
            notificationActions = record.actions;
            notificationImagePath = record.imagePath;
            notificationUrgency = record.urgency;
            notificationExpireTimeoutMs = record.expireTimeoutMs;
        }

        function notificationDetails() {
            return {
                id: notificationId,
                appName: notificationAppName,
                summary: notificationSummary,
                body: notificationBody
            };
        }

        // replaces_id update: refresh the history entry in place, and the popup only if it is
        // currently showing this notification.
        function updateNotificationRecord(record) {
            if (notificationHistoryModel && !record.transient) {
                for (let i = 0; i < notificationHistoryModel.count; i++) {
                    const item = notificationHistoryModel.get(i);
                    if (item && item.id === record.id) {
                        notificationHistoryModel.set(i, notificationHistoryEntry(record, item.count || 1));
                        break;
                    }
                }
            }
            if (islandState === "notification" && notificationId === record.id) {
                setNotificationPopupContent(record);
                if (!notificationExpanded)
                    startNotificationTimeout();
            }
        }

        function notificationHistoryEntry(record, count) {
            return {
                id: record.id,
                appName: record.appName,
                appIcon: record.appIcon,
                summary: record.summary,
                body: record.body,
                actions: record.actions,
                imagePath: record.imagePath,
                urgency: record.urgency,
                timestamp: new Date(),
                count: count
            };
        }

        // Store in notification history: an update of the same id replaces its entry; identical
        // content is aggregated with a count (inspired by ChillPill).
        function addNotificationToHistory(record) {
            if (!notificationHistoryModel)
                return;

            let existingIndex = -1;
            let count = 1;
            for (let i = 0; i < notificationHistoryModel.count; i++) {
                const item = notificationHistoryModel.get(i);
                if (item && record.id !== 0 && item.id === record.id) {
                    existingIndex = i;
                    count = item.count || 1;
                    break;
                }
                if (existingIndex === -1 && item && item.appName === record.appName
                        && item.summary === record.summary && item.body === record.body) {
                    existingIndex = i;
                    count = (item.count || 1) + 1;
                }
            }
            if (existingIndex !== -1)
                notificationHistoryModel.remove(existingIndex);

            notificationHistoryModel.insert(0, notificationHistoryEntry(record, count));

            if (notificationHistoryModel.count > 50)
                notificationHistoryModel.remove(50, notificationHistoryModel.count - 50);
        }

        // The notification was dismissed or closed by its sender: drop it everywhere.
        function removeNotificationById(notifId) {
            if (notificationHistoryModel) {
                for (let i = notificationHistoryModel.count - 1; i >= 0; i--) {
                    const item = notificationHistoryModel.get(i);
                    if (item && item.id === notifId)
                        notificationHistoryModel.remove(i);
                }
            }
            if (islandState === "notification" && notificationId === notifId)
                smartRestoreState();
        }

        function toggleNotificationExpansionIfNeeded() {
            if (islandState !== "notification" || !notificationLoader.item || !notificationLoader.item.hasOverflowContent)
                return false;

            if (notificationExpanded) {
                notificationExpanded = false;
                startNotificationTimeout();
                return true;
            }

            notificationExpanded = true;
            stopAutoHideTimer();
            return true;
        }

        function suppressCapsuleClick() {
            capsuleMouseArea.suppressNextClick = true;
            swipeSuppressReset.restart();
        }

        function restoreRestingCapsule(forceImmediate) {
            if (forceImmediate === undefined) forceImmediate = false;
            const normalizedRestingState = normalizeRestingState(restingState);
            const targetSide = restingStateSide(normalizedRestingState);
            const shouldAnimateToSide = targetSide !== "none"
                && islandState === "split" && splitOriginSide === targetSide;

            if (!forceImmediate && shouldAnimateToSide) {
                expandedByPlayerAutoOpen = false;
                swipeTransitionProgress = restingStateProgress(normalizedRestingState);
                stopAutoHideTimer();
                sideTransientRestoreTimer.restart();
                return;
            }

            abortSideTransientMode();
            islandState = normalizedRestingState;
            clearTransientCapsule();
            applyRestingVisuals();
            expandedByPlayerAutoOpen = false;
            stopAutoHideTimer();
        }

        function setRestingState(nextState) {
            restingState = normalizeRestingState(nextState);
        }

        function smartRestoreState() {
            restoreRestingCapsule();
        }

        function showRestingCapsule(nextState) {
            setRestingState(nextState);
            restoreRestingCapsule();
            stopAutoHideTimer();
        }

        function showExpandedPlayer(autoOpened) {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened) restartAutoHideTimer();
            else stopAutoHideTimer();
        }

        function showControlCenter() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "control_center";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showNotificationCenter() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "notification_center";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }


        function showFileShelf(manuallyOpened) {
            const manual = manuallyOpened === true;
            if (islandState === "file_shelf") {
                if (manual)
                    fileShelfOpenedManually = true;
                return;
            }

            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            fileShelfOpenedManually = manual;
            islandState = "file_shelf";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function closeAutoOpenedFileShelf() {
            if (islandState === "file_shelf" && !fileShelfOpenedManually)
                smartRestoreState();
        }

        function showClipboard() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "clipboard";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showWeather() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "weather";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showCalendar() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "calendar";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showPrivacyHud() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "privacy_hud";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showGlance() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "glance";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showCustomCapsule() {
            if (!hasCustomLeftItems) {
                showTimeCapsule();
                return;
            }

            systemState.refreshMissingValues();
            showRestingCapsule("custom");
        }

        function showLyricsCapsule() {
            showRestingCapsule("lyrics");
        }

        function showTimeCapsule() {
            showRestingCapsule("normal");
        }

        Timer { id: autoHideTimer; interval: islandContainer.defaultAutoHideInterval; onTriggered: islandContainer.handleAutoHideTimeout() }
        Timer {
            id: islandTimerTick
            interval: 1000
            repeat: true
            running: islandContainer.timerRunning
            onTriggered: {
                const nextRemainingSeconds = Math.max(0, islandContainer.timerRemainingSeconds - 1);
                if (nextRemainingSeconds <= 0) {
                    islandContainer.startTimerCompletionAnimation();
                    islandContainer.timerRemainingSeconds = 0;
                    islandContainer.timerRunning = false;
                    islandContainer.timerActive = false;
                } else {
                    islandContainer.timerRemainingSeconds = nextRemainingSeconds;
                }
            }
        }
        Timer {
            id: osdProgressAnimationReset
            interval: 0
            onTriggered: islandContainer.osdProgressAnimationEnabled = true
        }
        Timer {
            id: sideTransientRestoreTimer
            interval: islandContainer.swipeAnimationDuration
            onTriggered: {
                islandContainer.splitOriginSide = "none";
                islandContainer.islandState = islandContainer.normalizeRestingState(islandContainer.restingState);
                islandContainer.clearTransientCapsule();
                islandContainer.applyRestingVisuals();
                islandContainer.expandedByPlayerAutoOpen = false;
            }
        }
        Timer {
            id: sideSwipeSettleReset
            interval: mainCapsule.morphDuration
            onTriggered: islandContainer.finishSideSwipeSettle()
        }
        Timer {
            id: hoverExpandDelayTimer
            interval: 350
            repeat: false
            onTriggered: {
                if (!capsuleMouseArea.containsMouse) return;
                if (!root.hoverExpandEnabled) return;
                if (islandContainer.islandState === "normal" && islandContainer.hoveredRestingSection !== "clock") return;

                const current = islandContainer.islandState;
                const target = root.configuredHoverExpandAction === 2 ? "control_center" : "expanded";
                if (current === target) return;
                if (current !== "normal" && current !== "custom" && current !== "lyrics")
                    return;

                islandContainer.hoverExpandedActive = true;
                if (root.configuredHoverExpandAction === 2)
                    islandContainer.showControlCenter();
                else
                    islandContainer.showExpandedPlayer(false);
            }
        }
        Timer {
            id: hoverCollapseDelayTimer
            interval: 250
            repeat: false
            onTriggered: {
                if (root.pointerOverIsland()) return;
                if (!islandContainer.hoverExpandedActive) return;
                islandContainer.hoverExpandedActive = false;
                islandContainer.smartRestoreState();
            }
        }


        onCurrentTrackChanged: playerCardDismissed = false

        // --- UI 渲染：灵动岛主干 ---
        Rectangle {
            id: mainCapsule
            z: 5
            property int morphDuration: 170
            readonly property bool notificationHistorySurface: islandContainer.islandState === "notification_center"
            readonly property bool isCriticalNotification: islandContainer.islandState === "notification" && islandContainer.notificationUrgency === 2
            property real outlineWidth: 2
            property color outlineColor: isCriticalNotification ? StyleTokens.danger : StyleTokens.surfaceBorder
            property real displayedWidth: baseTargetWidth
            // At rest the clock sits on the island anchor and the capsule extends left for music
            // and right for battery: shift the capsule centre by half the difference.
            property real centerShift: islandContainer.islandState === "normal"
                ? (restingLayer.leftSectionWidth - restingLayer.rightSectionWidth) / 2
                : 0
            Behavior on centerShift {
                NumberAnimation {
                    duration: mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            readonly property real baseTargetWidth: {
                if (sideTransientRestoreTimer.running) {
                    if (islandContainer.restingState === "lyrics"
                            && islandContainer.islandState === "split" && islandContainer.splitOriginSide === "right") {
                        return islandContainer.lyricsCapsuleWidth;
                    }

                    if (islandContainer.restingState === "custom"
                            && islandContainer.islandState === "split" && islandContainer.splitOriginSide === "left") {
                        return islandContainer.customCapsuleWidth;
                    }
                }

                switch (islandContainer.islandState) {
                case "split":
                    return islandContainer.splitCapsuleWidth;
                case "custom":
                    return islandContainer.customCapsuleWidth;
                case "lyrics":
                    return islandContainer.lyricsCapsuleWidth;
                case "control_center":
                    return 420;
                case "notification_center":
                    return 410;
                case "file_shelf":
                    return 1100;
                case "clipboard":
                    return 520;
                case "weather":
                    return 460;
                case "calendar":
                    return 420;
                case "privacy_hud":
                    return 420;
                case "glance":
                    return 500;
                case "expanded":
                    return 410;
                case "notification":
                    if (!notificationLoader.item) return 272;
                    return Math.max(
                        notificationLoader.item.minimumWidth,
                        Math.min(root.width - 48, notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth)
                    );
                default:
                    return islandContainer.restingCapsuleWidth;
                }
            }
            readonly property real targetHeight: {
                switch (islandContainer.islandState) {
                case "control_center":
                    return controlCenterLoader.item && controlCenterLoader.item.powerViewActive
                        ? 150
                        : 406 + (controlCenterLoader.item ? controlCenterLoader.item.controlCenterExtraHeight : root.defaultControlCenterExtraHeight);
                case "notification_center":
                    return notificationCenterLoader.item ? notificationCenterLoader.item.contentHeight : 200;
                case "file_shelf":
                    return 260;
                case "clipboard":
                    return clipboardLoader.item && clipboardLoader.item.imgFullPreview ? 400 : 350;
                case "weather":
                case "calendar":
                    return 340;
                case "privacy_hud":
                    return privacyHudLoader.item ? privacyHudLoader.item.contentHeight : 200;
                case "glance":
                    return glanceLoader.item ? glanceLoader.item.contentHeight : 292;
                case "expanded":
                    return 165;
                case "notification":
                    return notificationLoader.item
                        ? Math.max(56, notificationLoader.item.preferredHeight)
                        : 56;
                default:
                    return userConfig.islandHeight;
                }
            }
            readonly property real targetRadius: 10
            function sideSwipeWidthForProgress(progressValue) {
                const restingW = islandContainer.restingCapsuleWidth;
                if (progressValue < 0)
                    return restingW + (islandContainer.customCapsuleWidth - restingW)
                        * islandContainer.clamp01(-progressValue);
                if (progressValue > 0)
                    return restingW + (islandContainer.lyricsCapsuleWidth - restingW)
                        * islandContainer.clamp01(progressValue);
                return restingW;
            }
            readonly property real sideSwipePreviewWidth: mainCapsule.sideSwipeWidthForProgress(
                islandContainer.swipeTransitionProgress
            )
            color: Qt.rgba(StyleTokens.panel.r, StyleTokens.panel.g, StyleTokens.panel.b, userConfig.islandBackgroundOpacity / 100.0)
            y: root.edgeY(islandContainer.effectiveTopMargin
                - (1 - root.autoHideProgress) * (targetHeight + islandContainer.effectiveTopMargin + 8), height)
            x: parent ? parent.width * userConfig.islandPositionX / 100 - width / 2 - centerShift : 0
            clip: true
            width: displayedWidth
            height: targetHeight
            radius: targetRadius
            topLeftRadius: targetRadius
            topRightRadius: targetRadius
            bottomLeftRadius: targetRadius
            bottomRightRadius: targetRadius
            opacity: root.autoHideProgress
            scale: 0.96 + root.autoHideProgress * 0.04
            transformOrigin: Item.Top

            onBaseTargetWidthChanged: {
                if (!capsuleMouseArea.sideSwipeInteractive && !islandContainer.sideSwipeSettling)
                    displayedWidth = baseTargetWidth;
            }

            Behavior on displayedWidth  {
                NumberAnimation {
                    duration: capsuleMouseArea.sideSwipeInteractive ? 0 : mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on radius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on topLeftRadius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on topRightRadius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on bottomLeftRadius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on bottomRightRadius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 170; easing.type: Easing.InOutQuad } }
            Behavior on outlineWidth { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }
            Behavior on outlineColor { ColorAnimation { duration: 160; easing.type: Easing.InOutQuad } }
            border.width: outlineWidth
            border.color: outlineColor

            antialiasing: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Math.max(parent.radius - 2, 0)
                topLeftRadius: Math.max(parent.topLeftRadius - 2, 0)
                topRightRadius: Math.max(parent.topRightRadius - 2, 0)
                bottomLeftRadius: Math.max(parent.bottomLeftRadius - 2, 0)
                bottomRightRadius: Math.max(parent.bottomRightRadius - 2, 0)
                color: StyleTokens.transparent
                border.width: 1
                border.color: StyleTokens.overviewInnerBorder
                antialiasing: true
            }

            // Horizontal two-finger swipe flips between control center and glance (one flip per swipe).
            // Vertical-dominant wheel events are passed through to the panel content.
            MouseArea {
                id: panelPageSwipeArea

                property real accumulatedDelta: 0
                property bool flipped: false

                anchors.fill: parent
                z: 9000
                enabled: (islandContainer.islandState === "control_center" || islandContainer.islandState === "glance")
                    && !root.connectivityPromptActive
                acceptedButtons: Qt.NoButton

                onWheel: (wheel) => {
                    // touchpads report gesture phases; a new gesture may flip again right away
                    if (wheel.phase === Qt.ScrollBegin) {
                        accumulatedDelta = 0;
                        flipped = false;
                    }
                    const deltaX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x / 4;
                    const deltaY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 4;
                    if (Math.abs(deltaX) <= Math.abs(deltaY)) {
                        wheel.accepted = false;
                        return;
                    }

                    pageSwipeSettleTimer.restart();
                    if (flipped)
                        return;
                    accumulatedDelta += deltaX;
                    if (Math.abs(accumulatedDelta) < 80)
                        return;

                    flipped = true;
                    if (islandContainer.islandState === "glance")
                        root.toggleControlCenterWindow();
                    else
                        root.toggleGlanceWindow();
                }

                Timer {
                    id: pageSwipeSettleTimer
                    interval: 400
                    onTriggered: {
                        panelPageSwipeArea.accumulatedDelta = 0;
                        panelPageSwipeArea.flipped = false;
                    }
                }
            }

            MouseArea {
                id: capsuleMouseArea
                anchors.fill: parent
                z: -1
                enabled: twoFingerTouchArea.touchPoints.length < 2
                acceptedButtons: root.dynamicIslandAcceptedButtons
                preventStealing: true
                hoverEnabled: root.hoverExpandEnabled || root.autoHideEnabled
                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property real swipeLastX: 0
                readonly property real sideSwipeVerticalTolerance: 24
                property bool swipeArmed: false
                property bool swipeMoved: false
                property bool sideSwipeInteractive: false
                property bool suppressNextClick: false
                property bool swipeDownDetected: false
                property bool swipeUpDetected: false

                Timer {
                    id: swipeSuppressReset
                    interval: 180
                    repeat: false
                    onTriggered: capsuleMouseArea.suppressNextClick = false
                }

                onEntered: {
                    if (root.autoHideEnabled) {
                        root.showAutoHiddenIsland();
                    }
                    // Hovering a notification popup never expands the island.
                    if (root.hoverExpandEnabled && islandContainer.islandState !== "notification") {
                        hoverCollapseDelayTimer.stop();
                        hoverExpandDelayTimer.restart();
                    }
                }

                onExited: {
                    if (root.autoHideEnabled) {
                        root.scheduleAutoHide();
                    }
                    if (root.hoverExpandEnabled)
                        hoverCollapseDelayTimer.restart();
                }

                onPressed: (mouse) => {
                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    swipeStartX = mappedPoint.x;
                    swipeStartY = mappedPoint.y;
                    swipeDownDetected = false;
                    swipeUpDetected = false;
                    islandContainer.cancelSideSwipeSettle();
                    swipeArmed = mouse.button === Qt.LeftButton
                        && islandContainer.canShowSideSwipe;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeLastX = mappedPoint.x;
                    swipeMoved = false;
                    sideSwipeInteractive = swipeArmed;
                    islandContainer.swipeTransitionProgress = swipeStartProgress;
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || !swipeArmed || suppressNextClick || twoFingerTouchArea.touchPoints.length >= 2) return;

                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    // "Down" below means toward the middle of the screen (up when at the bottom).
                    const dy = root.inwardDelta(mappedPoint.y - swipeStartY);
                    const dx = Math.abs(mappedPoint.x - swipeStartX);
                    if (dy > 30 && dx < 35) {
                        swipeDownDetected = true;
                        swipeMoved = true;
                    } else if (dy < -25 && dx < 35) {
                        swipeUpDetected = true;
                        swipeMoved = true;
                    }

                    const deltaX = mappedPoint.x - swipeLastX;
                    const deltaY = Math.abs(dy);
                    const adjustedDeltaX = deltaY < sideSwipeVerticalTolerance ? deltaX : 0;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        islandContainer.swipeTransitionProgress,
                        adjustedDeltaX
                    );

                    swipeMoved = swipeMoved || Math.abs(nextProgress - swipeStartProgress) > 0.03 || deltaY > 6;
                    swipeLastX = mappedPoint.x;
                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (swipeMoved) {
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                    }

                    if (swipeDownDetected) {
                        swipeDownDetected = false;
                        swipeUpDetected = false;
                        swipeArmed = false;
                        swipeMoved = false;
                        sideSwipeInteractive = false;
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                        islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                        if (islandContainer.islandState === "glance")
                            islandContainer.smartRestoreState();
                        else
                            islandContainer.showGlance();
                        return;
                    }

                    if (swipeUpDetected) {
                        swipeDownDetected = false;
                        swipeUpDetected = false;
                        swipeArmed = false;
                        swipeMoved = false;
                        sideSwipeInteractive = false;
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                        islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                        if (islandContainer.islandState === "glance")
                            islandContainer.smartRestoreState();
                        return;
                    }

                    let settleResult = {
                        action: "",
                        progress: islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress),
                        width: islandContainer.sideSwipeRestWidthForProgress(swipeStartProgress)
                    };

                    if (swipeArmed)
                        settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                    sideSwipeInteractive = false;

                    if (swipeArmed)
                        islandContainer.beginSideSwipeSettle(settleResult.width);
                    else
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;

                    if (swipeArmed) {
                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = settleResult.progress;
                    }
                    swipeArmed = false;
                    swipeMoved = false;
                }

                onCanceled: {
                    swipeArmed = false;
                    swipeMoved = false;
                    swipeDownDetected = false;
                    swipeUpDetected = false;
                    sideSwipeInteractive = false;
                    suppressNextClick = false;
                    swipeSuppressReset.stop();
                    mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                    islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                }

                onClicked: (mouse) => {
                    islandContainer.hoverExpandedActive = false;
                    hoverExpandDelayTimer.stop();
                    hoverCollapseDelayTimer.stop();

                    if (suppressNextClick) {
                        swipeSuppressReset.stop();
                        suppressNextClick = false;
                        return;
                    }

                    if (islandContainer.islandState === "privacy_hud") {
                        islandContainer.smartRestoreState();
                        return;
                    }

                    // A notification popup handles every click itself; never fall through to the
                    // configured island click actions (e.g. toggling the control center).
                    if (islandContainer.islandState === "notification") {

                        // Only a plain left click activates; right and middle do nothing here.
                        if (mouse.button !== Qt.LeftButton)
                            return;

                        // Body click: just close the popup; the entry stays in the history, read.
                        // Opening is the Open pill's job, expanding the chevron's.
                        if (root.shellRootController && root.shellRootController.setNotificationUnread)
                            root.shellRootController.setNotificationUnread(islandContainer.notificationId, false);
                        islandContainer.smartRestoreState();
                        return;
                    }

                    // Resting island: a left click on the bell, battery or music opens that directly;
                    // the clock and the rest of the capsule follow the configured mapping.
                    if (mouse.button === Qt.LeftButton && islandContainer.islandState === "normal") {
                        const point = restingLayer.mapFromItem(capsuleMouseArea, mouse.x, mouse.y);
                        const section = restingLayer.sectionAt(point.x, point.y);
                        if (section !== "clock") {
                            if (section === "bell")
                                islandContainer.showNotificationCenter();
                            else if (section === "battery")
                                root.toggleStandalonePowerDetail();
                            else
                                islandContainer.showExpandedPlayer(false);
                            return;
                        }
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {

                        if (islandContainer.toggleNotificationExpansionIfNeeded()) {
                            return;
                        }

                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandPrimaryAction);
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandSecondaryAction);
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandMiddleButton)) {
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandMiddleAction);
                        return;
                    }
                }
            }

            MultiPointTouchArea {
                id: twoFingerTouchArea
                anchors.fill: parent
                z: 0
                mouseEnabled: false
                minimumTouchPoints: 2
                maximumTouchPoints: 2

                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property bool swipeMoved: false
                property bool touchSwipeDown: false
                property bool touchSwipeUp: false

                onPressed: (touchPoints) => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea, 
                        (touchPoints[0].x + touchPoints[1].x) / 2,
                        (touchPoints[0].y + touchPoints[1].y) / 2);
                    swipeStartX = centerPoint.x;
                    swipeStartY = centerPoint.y;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeMoved = false;
                    touchSwipeDown = false;
                    touchSwipeUp = false;
                    islandContainer.cancelSideSwipeSettle();
                }

                onUpdated: (touchPoints) => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea, 
                        (touchPoints[0].x + touchPoints[1].x) / 2,
                        (touchPoints[0].y + touchPoints[1].y) / 2);
                    
                    const deltaX = centerPoint.x - swipeStartX;
                    const deltaY = root.inwardDelta(centerPoint.y - swipeStartY);
                    if (deltaY > 30 && Math.abs(deltaX) < 35) {
                        touchSwipeDown = true;
                        swipeMoved = true;
                    } else if (deltaY < -25 && Math.abs(deltaX) < 35) {
                        touchSwipeUp = true;
                        swipeMoved = true;
                    }

                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        swipeStartProgress,
                        deltaX
                    );

                    if (Math.abs(nextProgress - swipeStartProgress) > 0.03) {
                        swipeMoved = true;
                    }

                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (touchSwipeDown) {
                        touchSwipeDown = false;
                        touchSwipeUp = false;
                        swipeMoved = false;
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                        islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                        if (islandContainer.islandState === "glance")
                            islandContainer.smartRestoreState();
                        else
                            islandContainer.showGlance();
                        return;
                    }

                    if (touchSwipeUp) {
                        touchSwipeDown = false;
                        touchSwipeUp = false;
                        swipeMoved = false;
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                        islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                        if (islandContainer.islandState === "glance")
                            islandContainer.smartRestoreState();
                        return;
                    }

                    if (swipeMoved) {
                        const settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                        islandContainer.beginSideSwipeSettle(settleResult.width);

                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress);
                    }
                    swipeMoved = false;
                }
            }



            RestingIslandLayer {
                id: restingLayer
                showCondition: islandContainer.islandState === "normal"
                timeText: timeObj.currentTime
                timeFontFamily: root.timeFontFamily
                textFontFamily: root.textFontFamily
                iconFontFamily: root.iconFontFamily
                textPixelSize: root.bodyFontSize
                minimumCenterWidth: userConfig.islandWidth
                centerShift: mainCapsule.centerShift
                musicVisible: islandContainer.restingMusicVisible
                musicText: mediaController.restingText
                artUrl: islandContainer.currentArtUrl
                cavaLevels: islandContainer.cavaLevels
                batteryVisible: islandContainer.restingBatteryVisible
                batteryCapacity: islandContainer.batteryCapacity
                batteryCharging: islandContainer.isCharging
                unreadVisible: root.unreadNotificationCount > 0
            }

            Loader {
                id: splitIconLoader
                anchors.fill: parent
                active: islandContainer.splitShowsIconOnly
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    SplitIconLayer {
                        iconText: islandContainer.splitIcon
                        iconFontFamily: root.iconFontFamily
                        transitionProgress: islandContainer.swipeTransitionProgress
                        slideDirection: islandContainer.splitOriginSide
                        showCondition: true
                    }
                }
            }

            Loader {
                id: osdLayerLoader
                anchors.fill: parent
                active: islandContainer.splitUsesExtendedLayout
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    OsdLayer {
                        iconText: islandContainer.splitIcon
                        muted: islandContainer.splitIcon === systemState.muteStatusIcon
                        progress: islandContainer.osdProgress
                        customText: islandContainer.osdCustomText
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        transitionProgress: islandContainer.swipeTransitionProgress
                        slideDirection: islandContainer.splitOriginSide
                        showCondition: true
                    }
                }
            }

            Loader {
                id: expandedPlayerLoader
                anchors.fill: parent
                active: islandContainer.expandedLayerVisible
                asynchronous: false
                visible: active
                onLoaded: {
                    if (islandContainer.openTimerPageWhenExpanded
                            && item && item.openTimerPage) {
                        item.openTimerPage();
                        islandContainer.openTimerPageWhenExpanded = false;
                    }
                    root.focusExpandedPlayer();
                }

                sourceComponent: Component {
                    ExpandedPlayerLayer {
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        timePlayed: islandContainer.timePlayed
                        timeTotal: islandContainer.timeTotal
                        trackProgress: islandContainer.trackProgress
                        activePlayer: islandContainer.activePlayer
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        timerSelectedHours: islandContainer.timerSelectedHours
                        timerSelectedMinutes: islandContainer.timerSelectedMinutes
                        timerTotalSeconds: islandContainer.timerTotalSeconds
                        timerRemainingSeconds: islandContainer.timerRemainingSeconds
                        timerRunning: islandContainer.timerRunning
                        timerActive: islandContainer.timerActive
                        showCondition: islandContainer.expandedLayerVisible
                        onControlPressed: islandContainer.suppressCapsuleClick()
                        onBackgroundClicked: islandContainer.smartRestoreState()
                        onCloseRequested: islandContainer.smartRestoreState()
                        onKeyboardFocusRequested: islandContainer.requestExpandedPlayerKeyboardFocus()
                        onKeyboardFocusReleased: islandContainer.releaseExpandedPlayerKeyboardFocus()
                        onPreviousRequested: mediaController.previous()
                        onTimerToggleRequested: function(hours, minutes) {
                            islandContainer.toggleTimer(hours, minutes);
                        }
                        onTimerResetRequested: islandContainer.resetTimer()
                        onTimerDurationRequested: function(hours, minutes) {
                            if (!islandContainer.timerActive)
                                islandContainer.syncTimerDuration(hours, minutes);
                        }
                    }
                }
            }

            Loader {
                id: notificationLoader
                anchors.fill: parent
                active: islandContainer.notificationLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    NotificationLayer {
                        notificationId: islandContainer.notificationId
                        appName: islandContainer.notificationAppName
                        appIcon: islandContainer.notificationAppIcon
                        summary: islandContainer.notificationSummary
                        body: islandContainer.notificationBody
                        actions: islandContainer.notificationActions
                        imagePath: islandContainer.notificationImagePath
                        urgency: islandContainer.notificationUrgency
                        expanded: islandContainer.notificationExpanded
                        iconText: root.notificationStatusIcon
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: true
                        onExpansionToggleRequested: {
                            islandContainer.suppressCapsuleClick();
                            islandContainer.toggleNotificationExpansionIfNeeded();
                        }
                        onActionTriggered: function(actionKey) {
                            // Capture first: invoke() may close the notification and clear the popup.
                            const details = islandContainer.notificationDetails();
                            if (actionKey === "dismiss" || actionKey === "close")
                                root.dismissNotification(details.id);
                            else if (actionKey === "default")
                                root.activateNotification(details, false);
                            else
                                root.invokeNotificationAction(details.id, actionKey);
                            if (islandContainer.islandState === "notification")
                                islandContainer.smartRestoreState();
                        }
                        onCloseRequested: islandContainer.smartRestoreState()
                        onDismissRequested: {
                            root.dismissNotification(islandContainer.notificationId);
                            if (islandContainer.islandState === "notification")
                                islandContainer.smartRestoreState();
                        }
                    }
                }
            }

            Loader {
                id: controlCenterLoader
                anchors.fill: parent
                active: islandContainer.controlCenterLayerVisible || root.anyConnectivityDetailMounted
                asynchronous: false
                visible: active
                onLoaded: {
                    if (islandContainer.powerMenuRequested && item) {
                        item.powerViewActive = true;
                        islandContainer.powerMenuRequested = false;
                    }
                    if (item)
                        item.forceActiveFocus();
                }

                sourceComponent: Component {
                    ControlCenterLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        playerCardVisible: islandContainer.playerCardVisible
                        unreadNotificationCount: root.unreadNotificationCount
                        playerTitle: islandContainer.currentTrack
                        playerArtist: islandContainer.currentArtist
                        playerArtUrl: islandContainer.currentArtUrl
                        playerPlaying: islandContainer.musicPlaying
                        playerProgress: islandContainer.trackProgress
                        onPlayerPreviousRequested: mediaController.previous()
                        onPlayerPlayPauseRequested: {
                            const player = mediaController.activePlayer;
                            if (player && player.canTogglePlaying)
                                player.togglePlaying();
                        }
                        onPlayerNextRequested: {
                            const player = mediaController.activePlayer;
                            if (player && player.canGoNext)
                                player.next();
                        }
                        onPlayerDismissRequested: islandContainer.playerCardDismissed = true
                        sliderIntroDelay: 0
                        currentTime: timeObj.currentTime
                        currentDateLabel: timeObj.currentDateLabel
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        volumeLevel: islandContainer.currentVolume
                        volumeMuted: islandContainer.isMuted
                        brightnessLevel: islandContainer.currentBrightness
                        micLevel: islandContainer.currentMicVolume
                        micMuted: islandContainer.isMicMuted
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        showCondition: islandContainer.controlCenterLayerVisible
                        onRequestNotification: function(appName, summary, body) {
                            islandContainer.showNotificationCapsule(appName, summary, body);
                        }
                        onConnectivityPanelRequested: function(kind, open) {
                            root.setConnectivityDetailVisible(kind, open);
                        }
                        weatherService: root.weatherService
                        onWeatherRequested: islandContainer.showWeather()
                        onCalendarRequested: islandContainer.showCalendar()
                        onTimerRequested: islandContainer.showExpandedTimerPage()
                        onNotificationCenterRequested: islandContainer.showNotificationCenter()
                        onPowerMenuRequested: root.togglePowerMenuWindow()
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: notificationCenterLoader
                anchors.fill: parent
                active: islandContainer.notificationCenterLayerVisible
                asynchronous: false
                visible: active
                onLoaded: {
                    if (item)
                        item.forceActiveFocus();
                    else
                        islandContainer.forceActiveFocus();
                }

                sourceComponent: Component {
                    NotificationCenterLayer {
                        notificationModel: islandContainer.notificationHistoryModel
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily

                        onClearAllRequested: {
                            if (root.shellRootController && root.shellRootController.clearAllNotifications)
                                root.shellRootController.clearAllNotifications();
                            else
                                islandContainer.notificationHistoryModel.clear();
                        }
                        onNotificationDismissRequested: function(id) {
                            root.dismissNotification(id);
                        }
                        onNotificationActivated: function(id) {
                            root.activateNotification({ id: id }, true);
                            islandContainer.smartRestoreState();
                        }
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: fileShelfLoader
                anchors.fill: parent
                active: islandContainer.fileShelfLayerVisible
                asynchronous: false
                visible: islandContainer.fileShelfLayerVisible
                onLoaded: root.focusFileShelf()

                sourceComponent: Component {
                    FileShelfLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.fileShelfLayerVisible
                        dropPreviewOnly: !islandContainer.fileShelfOpenedManually
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: clipboardLoader
                anchors.fill: parent
                active: islandContainer.clipboardLayerVisible
                asynchronous: false
                visible: islandContainer.clipboardLayerVisible
                onLoaded: root.focusClipboard()

                sourceComponent: Component {
                    ClipboardLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.clipboardLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: weatherLoader
                anchors.fill: parent
                active: islandContainer.weatherLayerVisible
                asynchronous: false
                visible: islandContainer.weatherLayerVisible
                onLoaded: islandContainer.forceActiveFocus()

                sourceComponent: Component {
                    WeatherLayer {
                        weatherService: root.weatherService
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: islandContainer.weatherLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: calendarLoader
                anchors.fill: parent
                active: islandContainer.calendarLayerVisible
                asynchronous: false
                visible: islandContainer.calendarLayerVisible
                onLoaded: islandContainer.forceActiveFocus()

                sourceComponent: Component {
                    CalendarLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: islandContainer.calendarLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: privacyHudLoader
                anchors.fill: parent
                active: islandContainer.privacyHudLayerVisible
                asynchronous: false
                visible: islandContainer.privacyHudLayerVisible
                onLoaded: {
                    islandContainer.forceActiveFocus();
                    if (item) item.forceActiveFocus();
                }

                sourceComponent: Component {
                    PrivacyHudLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        isMicMuted: islandContainer.isMicMuted
                        showCondition: islandContainer.privacyHudLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: glanceLoader
                anchors.fill: parent
                active: islandContainer.glanceLayerVisible
                asynchronous: false
                visible: islandContainer.glanceLayerVisible
                onLoaded: {
                    islandContainer.forceActiveFocus();
                    if (item) item.forceActiveFocus();
                }

                sourceComponent: Component {
                    SystemGlanceLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: islandContainer.glanceLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                        onOpenCalendarRequested: {
                            islandContainer.smartRestoreState();
                            root.showCalendarWindow();
                        }
                        onOpenWeatherRequested: {
                            islandContainer.smartRestoreState();
                            root.showWeatherWindow();
                        }
                    }
                }
            }

            DropArea {
                id: islandFileDropArea
                z: 10000
                anchors.fill: parent
                enabled: islandContainer.fileShelfLayerVisible
                    || islandContainer.fileShelfCanAutoOpen

                onEntered: drag => {
                    if (!root.dragCarriesFiles(drag)) {
                        drag.accepted = false;
                        return;
                    }

                    drag.accept(Qt.CopyAction);
                    if (!islandContainer.fileShelfLayerVisible)
                        islandContainer.showFileShelf(false);
                    root.showAutoHiddenIsland("state");
                }

                onExited: fileDragLeaveTimer.restart()

                onDropped: drop => root.acceptFileDrop(drop)
            }

            Rectangle {
                z: 9999
                anchors.fill: parent
                radius: mainCapsule.radius
                color: StyleTokens.clearBlack
                border.width: islandFileDropArea.containsDrag ? 2 : 0
                border.color: StyleTokens.accent
                visible: islandFileDropArea.containsDrag
            }

        }

        BluetoothEarphoneBubble {
            id: bluetoothEarphoneBubble

            device: islandContainer.connectedEarphoneDevice
            active: islandContainer.bluetoothEarphoneBubbleWanted
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            bubbleSize: 36
            shownX: mainCapsule.x - bubbleSize - 8
            hiddenX: mainCapsule.x + 8
            centerY: mainCapsule.y + mainCapsule.height / 2 - height / 2
            autoHideProgress: root.autoHideProgress
            autoHideEnabled: root.autoHideEnabled
            onEntered: {
                if (root.autoHideEnabled) {
                    root.showAutoHiddenIsland();
                }
            }
            onExited: {
                if (root.autoHideEnabled) {
                    root.scheduleAutoHide();
                }
            }
        }

        Item {
            id: fileShelfBubble

            readonly property int bubbleSize: 36

            width: bubbleSize
            height: bubbleSize
            x: mainCapsule.x - width - 8 - (bluetoothEarphoneBubble.mounted ? (bluetoothEarphoneBubble.bubbleSize + 6) : 0)
            Behavior on x {
                NumberAnimation {
                    duration: 190
                    easing.type: Easing.OutQuint
                }
            }
            y: mainCapsule.y + mainCapsule.height / 2 - height / 2
            z: 6
            visible: islandContainer.fileShelfBubbleWanted
            opacity: root.autoHideProgress
            scale: 0.96 + root.autoHideProgress * 0.04
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation { duration: Math.round(StyleTokens.durationFast * 0.6) }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: StyleTokens.panel
                border.width: 2
                border.color: StyleTokens.surfaceBorder

                antialiasing: true
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    text: "\uf08d"
                    color: StyleTokens.textPrimary
                    font.family: root.iconFontFamily
                    font.pixelSize: 13
                    rotation: -18
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -2
                    anchors.bottomMargin: -2
                    width: Math.max(17, countText.implicitWidth + 8)
                    height: 17
                    radius: height / 2
                    color: StyleTokens.accent
                    border.width: 2
                    border.color: StyleTokens.panel

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: FileShelf.count > 99 ? "99+" : String(FileShelf.count)
                        color: StyleTokens.textOnAccent
                        font.family: root.textFontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: fileShelfBubble.visible && root.autoHideProgress > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    islandContainer.showFileShelf(true);
                    root.showAutoHiddenIsland("state");
                }
            }
        }

        PrivacyBubble {
            id: cameraBubble

            active: islandContainer.cameraBubbleWanted
            accentColor: "#30d158"
            iconText: "\uf03d"
            iconFontFamily: root.iconFontFamily
            iconFontSize: 13
            bubbleSize: islandContainer.privacyBubbleSize
            shownX: islandContainer.bubblesBaseX
            hiddenX: mainCapsule.x + mainCapsule.width - width * 0.62
            centerY: mainCapsule.y + mainCapsule.height / 2 - height / 2
            autoHideProgress: root.autoHideProgress
            autoHideEnabled: root.autoHideEnabled
            onClicked: root.togglePrivacyHudWindow()
            onEntered: {
                if (root.autoHideEnabled) {
                    root.showAutoHiddenIsland();
                }
            }
            onExited: {
                if (root.autoHideEnabled) {
                    root.scheduleAutoHide();
                }
            }
        }

        PrivacyBubble {
            id: micBubble

            active: islandContainer.micBubbleWanted
            accentColor: islandContainer.isMicMuted ? "#ff453a" : "#ff9f0a"
            iconText: islandContainer.isMicMuted ? "\uf131" : "\uf130"
            iconFontFamily: root.iconFontFamily
            iconFontSize: 13
            bubbleSize: islandContainer.privacyBubbleSize
            shownX: islandContainer.bubblesBaseX + (cameraBubble.mounted ? islandContainer.privacyBubbleStep : 0)
            hiddenX: mainCapsule.x + mainCapsule.width - width * 0.62
            centerY: mainCapsule.y + mainCapsule.height / 2 - height / 2
            autoHideProgress: root.autoHideProgress
            autoHideEnabled: root.autoHideEnabled
            onClicked: root.togglePrivacyHudWindow()
            onEntered: {
                if (root.autoHideEnabled) {
                    root.showAutoHiddenIsland();
                }
            }
            onExited: {
                if (root.autoHideEnabled) {
                    root.scheduleAutoHide();
                }
            }
        }

        Item {
            id: timerBubble

            property bool mounted: islandContainer.timerBubbleWanted
            property real reveal: islandContainer.timerBubbleWanted ? 1 : 0
            readonly property int bubbleSize: 34
            readonly property real hiddenX: mainCapsule.x + mainCapsule.width - width * 0.62
            property real shownX: islandContainer.bubblesBaseX + islandContainer.privacyBubblesOffset
            Behavior on shownX {
                NumberAnimation {
                    duration: 190
                    easing.type: Easing.OutQuint
                }
            }
            readonly property real centerY: mainCapsule.y + mainCapsule.height / 2 - height / 2

            width: bubbleSize
            height: bubbleSize
            x: hiddenX + (shownX - hiddenX) * reveal
            y: centerY + (1 - reveal) * (root.atBottom ? -10 : 10)
            z: 6
            visible: mounted
            opacity: reveal * root.autoHideProgress
            scale: (0.55 + reveal * 0.45) * (0.96 + root.autoHideProgress * 0.04) * (1 + islandContainer.timerCompletionPulse * 0.12)
            transformOrigin: Item.Center

            Connections {
                target: islandContainer

                function onTimerBubbleWantedChanged() {
                    timerBubbleShowAnimation.stop();
                    timerBubbleHideAnimation.stop();

                    if (islandContainer.timerBubbleWanted) {
                        timerBubble.mounted = true;
                        timerBubbleShowAnimation.restart();
                    } else {
                        timerBubbleHideAnimation.restart();
                    }
                }

                function onTimerProgressChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerRemainingSecondsChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerTotalSecondsChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerCompletionAnimatingChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerCompletionFlashChanged() {
                    timerBubbleRing.requestPaint();
                }
            }

            NumberAnimation {
                id: timerBubbleShowAnimation

                target: timerBubble
                property: "reveal"
                from: timerBubble.reveal
                to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: timerBubbleHideAnimation

                target: timerBubble
                property: "reveal"
                from: timerBubble.reveal
                to: 0
                duration: 170
                easing.type: Easing.InCubic
                onStopped: {
                    if (!islandContainer.timerBubbleWanted && timerBubble.reveal <= 0.001)
                        timerBubble.mounted = false;
                }
            }

            SequentialAnimation {
                id: timerBubbleCompletionAnimation

                running: islandContainer.timerCompletionAnimating

                onStarted: {
                    timerBubbleShowAnimation.stop();
                    timerBubbleHideAnimation.stop();
                    timerBubble.mounted = true;
                    timerBubble.reveal = 1;
                }

                onStopped: {
                    if (islandContainer.timerCompletionAnimating)
                        islandContainer.timerCompletionAnimating = false;
                    islandContainer.timerCompletionPulse = 0;
                    islandContainer.timerCompletionFlash = 0;
                    timerBubbleRing.requestPaint();
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionPulse"
                        from: 0
                        to: 1
                        duration: 80
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionFlash"
                        from: 0
                        to: 1
                        duration: 80
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionPulse"
                        from: 1
                        to: 0
                        duration: 230
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionFlash"
                        from: 1
                        to: 0
                        duration: 230
                        easing.type: Easing.InOutQuad
                    }
                }

                PauseAnimation {
                    duration: 380
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: StyleTokens.panel
                border.width: 2
                border.color: StyleTokens.surfaceBorder
                antialiasing: true
            }

            Canvas {
                id: timerBubbleRing

                anchors.fill: parent
                anchors.margins: 1

                Component.onCompleted: requestPaint()
                onVisibleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    const centerX = width / 2;
                    const centerY = height / 2;
                    const completionActive = islandContainer.timerCompletionAnimating;
                    const flash = Math.max(0, Math.min(1, islandContainer.timerCompletionFlash));
                    const lineWidth = completionActive ? 3 + flash : 3;
                    const radius = Math.min(width, height) / 2 - lineWidth / 2;
                    const progress = Math.max(0, Math.min(1, islandContainer.timerProgress));
                    const startAngle = -Math.PI / 2;
                    const endAngle = startAngle - Math.PI * 2 * progress;

                    ctx.clearRect(0, 0, width, height);
                    ctx.lineCap = "round";
                    ctx.lineWidth = lineWidth;

                    ctx.beginPath();
                    ctx.strokeStyle = StyleTokens.track;
                    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    if (completionActive) {
                        if (flash > 0) {
                            ctx.beginPath();
                            ctx.lineWidth = lineWidth + 1.5;
                            ctx.strokeStyle = StyleTokens.withAlpha(StyleTokens.warning, 0.18 * flash);
                            ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                            ctx.stroke();
                        }

                        ctx.beginPath();
                        ctx.lineWidth = lineWidth;
                        ctx.strokeStyle = StyleTokens.withAlpha(StyleTokens.warning, 0.72 + 0.28 * flash);
                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                        ctx.stroke();
                    } else if (progress > 0) {
                        ctx.beginPath();
                        ctx.strokeStyle = StyleTokens.warning;
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle, true);
                        ctx.stroke();
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                text: "󰔛"
                color: StyleTokens.textPrimary
                font.pixelSize: root.iconFontSize - 1
                font.family: root.iconFontFamily
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                enabled: timerBubble.mounted && root.autoHideProgress > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (root.autoHideEnabled) {
                        root.showAutoHiddenIsland();
                    }
                }
                onExited: {
                    if (root.autoHideEnabled) {
                        root.scheduleAutoHide();
                    }
                }
                onClicked: islandContainer.showExpandedTimerPage()
            }
        }

        ConnectivityDetailShell {
            id: wifiConnectivityDetailShell

            open: root.wifiConnectivityDetailOpen
            mounted: root.wifiConnectivityDetailMounted
            rightSide: false
            panelKind: "wifi"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            atBottom: root.atBottom
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: bluetoothConnectivityDetailShell

            open: root.bluetoothConnectivityDetailOpen
            mounted: root.bluetoothConnectivityDetailMounted
            rightSide: true
            panelKind: "bluetooth"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            atBottom: root.atBottom
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: powerConnectivityDetailShell

            open: root.powerConnectivityDetailOpen
            mounted: root.powerConnectivityDetailMounted
            rightSide: true
            below: root.powerDetailStandalone
            panelKind: "power"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            atBottom: root.atBottom
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: audioConnectivityDetailShell

            open: root.audioConnectivityDetailOpen
            mounted: root.audioConnectivityDetailMounted
            rightSide: true
            panelKind: root.audioConnectivityDetailKind
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            atBottom: root.atBottom
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        CalendarNoteShell {
            id: calendarNoteShell

            open: islandContainer.calendarLayerVisible
                && calendarLoader.item !== null
                && calendarLoader.item.noteOpen
            provider: calendarLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }
    }

    // Below all island content: presses that land outside every island surface close the panel.
    MouseArea {
        id: outsideClickDismissArea

        anchors.fill: parent
        z: -1
        enabled: root.outsideClickDismissActive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: (mouse) => {
            if (root.islandSurfaceAt(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            if (root.powerDetailStandalone)
                root.closeConnectivityOverlays();
            else
                islandContainer.smartRestoreState();
        }
    }

    // True if (x, y) in window coordinates lies on a visible island surface (capsule, bubbles, side panels).
    function islandSurfaceAt(x, y) {
        const surfaces = [mainCapsule, fileShelfBubble, bluetoothEarphoneBubble, cameraBubble, micBubble,
            timerBubble, wifiConnectivityDetailShell, bluetoothConnectivityDetailShell,
            powerConnectivityDetailShell, audioConnectivityDetailShell, calendarNoteShell];
        return surfaces.some(s => s.visible
            && x >= s.x && x < s.x + s.width
            && y >= s.y && y < s.y + s.height);
    }

    function pointerOverIsland() {
        return islandHoverTracker.hovered
            && root.islandSurfaceAt(islandHoverTracker.point.position.x, islandHoverTracker.point.position.y);
    }

    MouseArea {
        id: autoHideRevealArea

        x: root.autoHideRevealX
        y: root.autoHideRevealY
        z: 20
        width: root.autoHideRevealWidth
        height: root.autoHideRevealHeight
        enabled: root.autoHideEnabled
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.showAutoHiddenIsland("edge");
        }

        onExited: {
            root.scheduleAutoHide();
        }
    }

    // A file drag reaching the edge strip reveals the hidden island and opens the shelf (Wayland
    // drags send no hover). A drop on the strip itself also goes to the shelf.
    DropArea {
        id: autoHideRevealDropArea

        x: root.autoHideRevealX
        y: root.autoHideRevealY
        z: 21
        width: root.autoHideRevealWidth
        height: root.autoHideRevealHeight
        enabled: root.autoHideEnabled

        onEntered: drag => {
            if (!root.dragCarriesFiles(drag)) {
                drag.accepted = false;
                return;
            }
            drag.accept(Qt.CopyAction);
            root.showAutoHiddenIsland("drag");
            if (islandContainer.fileShelfCanAutoOpen && !islandContainer.fileShelfLayerVisible)
                islandContainer.showFileShelf(false);
        }
        onExited: fileDragLeaveTimer.restart()
        onDropped: drop => root.acceptFileDrop(drop)
    }

    // Moving between the strip and the capsule leaves one drop area for the other; only close an
    // auto-opened shelf when the drag has left both.
    Timer {
        id: fileDragLeaveTimer
        interval: 150
        onTriggered: {
            if (!autoHideRevealDropArea.containsDrag && !islandFileDropArea.containsDrag)
                islandContainer.closeAutoOpenedFileShelf();
        }
    }

    function acceptFileDrop(drop) {
        if (!root.dragCarriesFiles(drop)) {
            drop.accepted = false;
            return;
        }
        root.addFilesFromDrop(drop);
        drop.accept(Qt.CopyAction);
        islandContainer.closeAutoOpenedFileShelf();
    }
}
