import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import IslandBackend
import "qml/island"

Scope {
    id: shellRoot

    readonly property bool screenRecordingActive: SystemServices.screenRecordingActive
    readonly property bool micActive: SystemServices.micActive
    readonly property bool cameraActive: SystemServices.cameraActive
    readonly property bool privacyActive: SystemServices.privacyActive
    readonly property var activePrivacyApps: SystemServices.activePrivacyApps
    // Do-not-disturb, persisted in userconfig.json ("doNotDisturb").
    readonly property bool focusEnabled: UserConfig.doNotDisturb
    property bool shuttingDown: false
    property bool islandAutoHideRuntimeEnabled: true

    readonly property var userConfig: UserConfig
    readonly property string clipboardHelperScriptPath: {
        const candidate = Qt.resolvedUrl("scripts/cliphist-helper.sh").toString();
        return candidate.startsWith("file://")
            ? decodeURIComponent(candidate.substring(7))
            : "/usr/share/tide-island/scripts/cliphist-helper.sh";
    }

    // Keep clipboard history recording for the lifetime of the shell, even
    // while the clipboard panel is closed.
    Process {
        command: ["bash", shellRoot.clipboardHelperScriptPath, "watch"]
        running: true
    }

    WeatherService {
        id: globalWeatherService
    }
    readonly property var weatherService: globalWeatherService

    function forEachWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window)
                callback(window);
        }
    }

    // --- Notification daemon ---------------------------------------------------------------
    // tide-island owns org.freedesktop.Notifications. Every notification stays tracked (and in
    // the history) until it is dismissed in tide or closed by the sending app; a popup timing
    // out only hides the popup. Transient notifications only pop up and then expire.
    readonly property int maxTrackedNotifications: 50
    readonly property int transientNotificationLifetimeMs: 15000
    property var trackedNotifications: ({})
    property var notificationUpdatedAt: ({})
    property var transientNotificationShownAt: ({})
    property int internalNotificationSerial: 0
    // Action key per notification id, waiting for its activation token.
    property var pendingNotificationActions: ({})
    // Unread: notifications that reached the history since the notification center was last
    // opened (on any screen) and are still around. Transient ones and tide's own notices don't
    // count; ones held back by do-not-disturb do.
    property var unreadNotificationIds: ({})
    property int unreadNotificationCount: 0

    NotificationServer {
        id: notificationServer

        bodySupported: true
        // Markup is reduced to plain text (links stay clickable) before display.
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: function(notification) {
            shellRoot.receiveNotification(notification);
        }
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: SystemServices.logNotificationDaemonOwner()
    }

    Timer {
        id: transientNotificationExpiry
        interval: 2000
        repeat: true
        onTriggered: shellRoot.expireTransientNotifications()
    }

    Connections {
        target: NotificationActivation

        function onTokenReady(notificationId, token) {
            const actionKey = shellRoot.pendingNotificationActions[notificationId];
            if (actionKey === undefined)
                return;
            delete shellRoot.pendingNotificationActions[notificationId];
            const action = shellRoot.notificationAction(notificationId, actionKey);
            if (action)
                action.invoke();
        }
    }

    function setNotificationUnread(id, unread) {
        if (unread)
            unreadNotificationIds[id] = true;
        else
            delete unreadNotificationIds[id];
        unreadNotificationCount = Object.keys(unreadNotificationIds).length;
    }

    function markNotificationsRead() {
        unreadNotificationIds = ({});
        unreadNotificationCount = 0;
    }

    // Ids for tide's own feedback notices; negative so they never collide with daemon ids.
    function nextInternalNotificationId() {
        internalNotificationSerial += 1;
        return -internalNotificationSerial;
    }

    // Tide's own feedback (e.g. the recorder's), on every island like a notification.
    function showInternalNotice(appName, summary, body) {
        const record = { id: nextInternalNotificationId(), appName: appName, summary: summary, body: body };
        shellRoot.forEachWindow((window) => {
            if (window.presentNotificationRecord)
                window.presentNotificationRecord(record, "popup");
        });
    }

    Connections {
        target: ScreenRecorder

        function onNotificationRequested(title, message) {
            shellRoot.showInternalNotice("Screen Recorder", title, message);
        }
    }

    // The app's expire_timeout (D-Bus milliseconds; -1 = server default, 0 = never).
    function notificationExpireTimeoutMs(notification) {
        const value = Number(notification.expireTimeout);
        return Number.isFinite(value) ? Math.round(value) : -1;
    }

    // Local image paths only when they are regular files; icon names and image:// stay.
    function notificationImageSource(value) {
        const source = value || "";
        if (source.startsWith("/") || source.startsWith("file://"))
            return SystemServices.isRegularFile(source) ? source : "";
        return source;
    }

    function notificationRecord(notification) {
        const actions = [];
        const notificationActions = notification.actions || [];
        for (let i = 0; i < notificationActions.length; i++)
            actions.push({ id: notificationActions[i].identifier, text: notificationActions[i].text });

        return {
            id: notification.id,
            appName: notification.appName,
            appIcon: notificationImageSource(notification.appIcon),
            summary: notification.summary,
            body: notification.body,
            actions: actions,
            imagePath: notificationImageSource(notification.image),
            urgency: Number(notification.urgency),
            expireTimeoutMs: notificationExpireTimeoutMs(notification),
            transient: !!notification.transient
        };
    }

    function receiveNotification(notification) {
        notification.tracked = true;
        const id = notification.id;
        trackedNotifications[id] = notification;
        notificationUpdatedAt[id] = Date.now();

        notification.closed.connect(function() {
            shellRoot.forgetNotification(id);
        });

        // replaces_id updates the same object in place. Each notification gets its own closure,
        // so Qt.callLater coalesces one notification's burst of changes without dropping others.
        let shownUrgency = Number(notification.urgency);
        const update = function() {
            if (!shellRoot.trackedNotifications[id])
                return;
            shellRoot.notificationUpdatedAt[id] = Date.now();
            const urgency = Number(notification.urgency);
            const escalated = urgency > shownUrgency;
            shownUrgency = Math.max(shownUrgency, urgency);
            shellRoot.presentNotification(notification, escalated ? "popup" : "update");
        };
        const scheduleUpdate = function() {
            Qt.callLater(update);
        };
        notification.summaryChanged.connect(scheduleUpdate);
        notification.bodyChanged.connect(scheduleUpdate);
        notification.imageChanged.connect(scheduleUpdate);
        notification.actionsChanged.connect(scheduleUpdate);
        notification.urgencyChanged.connect(scheduleUpdate);
        notification.appIconChanged.connect(scheduleUpdate);
        notification.appNameChanged.connect(scheduleUpdate);

        // Notifications re-emitted after a Quickshell reload go to the history only.
        presentNotification(notification, notification.lastGeneration ? "history" : "popup");
        if (!notification.lastGeneration) {
            supersedeDuplicates(notification);
            if (!notification.transient)
                setNotificationUnread(id, true);
        }
        trimTrackedNotifications();
    }

    // mode: "popup" (new or escalated), "update" (content changed: refresh in place, no new
    // popup), "history" (record only).
    function presentNotification(notification, mode) {
        if (!trackedNotifications[notification.id])
            return;

        const record = notificationRecord(notification);
        // Do-not-disturb: no popups except critical ones; everything still goes to the history.
        if (mode === "popup" && focusEnabled && record.urgency !== NotificationUrgency.Critical)
            mode = "history";

        if (record.transient) {
            // Transient: a popup only, never history.
            if (mode === "history") {
                notification.expire();
                return;
            }
            if (mode === "popup") {
                transientNotificationShownAt[record.id] = Date.now();
                transientNotificationExpiry.start();
            }
        }

        shellRoot.forEachWindow((window) => {
            if (window.presentNotificationRecord)
                window.presentNotificationRecord(record, mode);
        });
    }

    function expireTransientNotifications() {
        const now = Date.now();
        const ids = Object.keys(transientNotificationShownAt);
        for (let i = 0; i < ids.length; i++) {
            if (now - transientNotificationShownAt[ids[i]] < transientNotificationLifetimeMs)
                continue;
            const notification = trackedNotifications[ids[i]];
            delete transientNotificationShownAt[ids[i]];
            if (notification)
                notification.expire();
        }
        if (Object.keys(transientNotificationShownAt).length === 0)
            transientNotificationExpiry.stop();
    }

    // A new notification with the same content as older ones replaces them in the history
    // (counted there), so close the superseded ones for their senders too, as expired: the
    // user did not dismiss them.
    function supersedeDuplicates(notification) {
        if (notification.transient)
            return;
        const ids = Object.keys(trackedNotifications);
        for (let i = 0; i < ids.length; i++) {
            const other = trackedNotifications[ids[i]];
            if (!other || other.id === notification.id || other.transient)
                continue;
            if (other.appName === notification.appName && other.summary === notification.summary
                    && other.body === notification.body)
                other.expire();
        }
    }

    function forgetNotification(id) {
        delete trackedNotifications[id];
        delete notificationUpdatedAt[id];
        delete transientNotificationShownAt[id];
        delete pendingNotificationActions[id];
        if (unreadNotificationIds[id])
            setNotificationUnread(id, false);
        shellRoot.forEachWindow((window) => {
            if (window.removeNotification)
                window.removeNotification(id);
        });
    }

    // Keep at most maxTrackedNotifications (transient ones don't count); the least recently
    // updated go first.
    function trimTrackedNotifications() {
        const ids = Object.keys(trackedNotifications)
            .filter((key) => !trackedNotifications[key].transient)
            .sort((a, b) => notificationUpdatedAt[a] - notificationUpdatedAt[b]);
        for (let i = 0; i < ids.length - maxTrackedNotifications; i++)
            expireNotification(Number(ids[i]));
    }

    // Closed by tide without the user (reason 1, expired); removed everywhere.
    function expireNotification(id) {
        const notification = trackedNotifications[id];
        if (notification)
            notification.expire();
        else
            forgetNotification(id);
    }

    // Dismiss in tide: tells the sender (NotificationClosed) and removes it everywhere.
    function dismissNotification(id) {
        const notification = trackedNotifications[id];
        if (notification)
            notification.dismiss();
        else
            forgetNotification(id);
    }

    function clearAllNotifications() {
        const ids = Object.keys(trackedNotifications);
        for (let i = 0; i < ids.length; i++)
            dismissNotification(Number(ids[i]));
        shellRoot.forEachWindow((window) => {
            if (window.clearNotificationHistory)
                window.clearNotificationHistory();
        });
    }

    function notificationAction(id, actionKey) {
        const notification = trackedNotifications[id];
        const notificationActions = notification ? notification.actions || [] : [];
        for (let i = 0; i < notificationActions.length; i++) {
            if (notificationActions[i].identifier === actionKey)
                return notificationActions[i];
        }
        return null;
    }

    // Runs an action once an xdg-activation token for `window` (the clicked island) has been
    // sent to the app, so the compositor lets the app raise its window. Returns whether the
    // notification has that action; the action itself runs a moment later.
    function invokeNotificationAction(id, actionKey, window) {
        if (!notificationAction(id, actionKey))
            return false;
        if (pendingNotificationActions[id] === undefined) {
            pendingNotificationActions[id] = actionKey;
            NotificationActivation.requestToken(window || null, id);
        }
        return true;
    }

    function notificationIsResident(id) {
        const notification = trackedNotifications[id];
        return !!(notification && notification.resident);
    }

    function anyIslandShown() {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && window.autoHideTargetVisible)
                return true;
        }

        return false;
    }

    function showIslandAll() {
        shellRoot.forEachWindow((window) => {
            if (window && window.showIslandWindow)
                window.showIslandWindow();
        });
    }

    function hideIslandAll() {
        shellRoot.forEachWindow((window) => {
            if (window && window.hideIslandWindow)
                window.hideIslandWindow();
        });
    }

    function toggleIslandAll() {
        if (shellRoot.anyIslandShown())
            shellRoot.hideIslandAll();
        else
            shellRoot.showIslandAll();
    }

    function refreshIslandAutoHideAll() {
        shellRoot.forEachWindow((window) => {
            if (window && window.refreshAutoHideWindow)
                window.refreshAutoHideWindow();
        });
    }

    // driftwm reports no focused output, so panels opened by IPC go to the first island.
    function forFocusedWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            if (windows[index]) {
                callback(windows[index]);
                return;
            }
        }
    }

    IpcHandler {
        target: "island"

        function show() {
            shellRoot.showIslandAll();
        }

        function open() {
            shellRoot.showIslandAll();
        }

        function reveal() {
            shellRoot.showIslandAll();
        }

        function hide() {
            shellRoot.hideIslandAll();
        }

        function toggle() {
            shellRoot.toggleIslandAll();
        }

        function enableAutoHide() {
            shellRoot.islandAutoHideRuntimeEnabled = true;
            shellRoot.refreshIslandAutoHideAll();
        }

        function disableAutoHide() {
            shellRoot.islandAutoHideRuntimeEnabled = false;
            shellRoot.showIslandAll();
        }
    }

    IpcHandler {
        target: "tide"

        function showClock() {
            shellRoot.forFocusedWindow((window) => window.showClockWindow());
        }

        function showTimer() {
            shellRoot.forFocusedWindow((window) => window.showTimerWindow());
        }

        function togglePlayer() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }

        function showPlayer() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }

        function toggleControlCenter() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }

        function showControlCenter() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }

        function togglePowerMenu() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }

        function showPowerMenu() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }

        function toggleNotificationCenter() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }

        function showNotificationCenter() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }

        function toggleFileShelf() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }

        function showFileShelf() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }

        function togglePrivacyHud() {
            shellRoot.forFocusedWindow((window) => window.togglePrivacyHudWindow());
        }

        function showPrivacyHud() {
            shellRoot.forFocusedWindow((window) => window.showPrivacyHudWindow());
        }

        function toggleRecording() {
            ScreenRecorder.toggleRecording();
        }

        function toggleRecorderMic() {
            ScreenRecorder.toggleMic();
        }

        function toggleClipboard() {
            shellRoot.forFocusedWindow((window) => window.toggleClipboardWindow());
        }

        function showClipboard() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function openClipboard() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function closeClipboard() {
            shellRoot.forFocusedWindow((window) => window.closeClipboardWindow ? window.closeClipboardWindow() : window.toggleClipboardWindow());
        }

        function toggleWeather() {
            shellRoot.forFocusedWindow((window) => window.toggleWeatherWindow());
        }

        function showWeather() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function openWeather() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function closeWeather() {
            shellRoot.forFocusedWindow((window) => window.closeWeatherWindow ? window.closeWeatherWindow() : window.toggleWeatherWindow());
        }

        function toggleCalendar() {
            shellRoot.forFocusedWindow((window) => window.toggleCalendarWindow());
        }

        function showCalendar() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function openCalendar() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function closeCalendar() {
            shellRoot.forFocusedWindow((window) => window.closeCalendarWindow ? window.closeCalendarWindow() : window.toggleCalendarWindow());
        }

        function togglePrivacy() {
            shellRoot.forFocusedWindow((window) => window.togglePrivacyHudWindow());
        }

        function showPrivacy() {
            shellRoot.forFocusedWindow((window) => window.showPrivacyHudWindow());
        }

        function openPrivacy() {
            shellRoot.forFocusedWindow((window) => window.showPrivacyHudWindow());
        }

        function closePrivacy() {
            shellRoot.forFocusedWindow((window) => window.closePrivacyHudWindow ? window.closePrivacyHudWindow() : window.togglePrivacyHudWindow());
        }

        function toggleGlance() {
            shellRoot.forFocusedWindow((window) => window.toggleGlanceWindow ? window.toggleGlanceWindow() : null);
        }

        function showGlance() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function openGlance() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function closeGlance() {
            shellRoot.forFocusedWindow((window) => window.closeGlanceWindow ? window.closeGlanceWindow() : null);
        }

        function toggleDashboard() {
            shellRoot.forFocusedWindow((window) => window.toggleGlanceWindow ? window.toggleGlanceWindow() : null);
        }

        function showDashboard() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function openDashboard() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function closeDashboard() {
            shellRoot.forFocusedWindow((window) => window.closeGlanceWindow ? window.closeGlanceWindow() : null);
        }

        function reloadTheme() {
            StyleTokens.reload();
        }

        function reloadColors() {
            StyleTokens.reload();
        }
    }

    IpcHandler {
        target: "theme"

        function reload() {
            StyleTokens.reload();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleClipboardWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeClipboardWindow ? window.closeClipboardWindow() : window.toggleClipboardWindow());
        }
    }

    IpcHandler {
        target: "weather"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleWeatherWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeWeatherWindow ? window.closeWeatherWindow() : window.toggleWeatherWindow());
        }

        function refresh() {
            if (shellRoot.weatherService)
                shellRoot.weatherService.refresh();
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleCalendarWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeCalendarWindow ? window.closeCalendarWindow() : window.toggleCalendarWindow());
        }
    }

    IpcHandler {
        target: "privacy"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.togglePrivacyHudWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showPrivacyHudWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showPrivacyHudWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closePrivacyHudWindow ? window.closePrivacyHudWindow() : window.togglePrivacyHudWindow());
        }
    }

    IpcHandler {
        target: "glance"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleGlanceWindow ? window.toggleGlanceWindow() : null);
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeGlanceWindow ? window.closeGlanceWindow() : null);
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleGlanceWindow ? window.toggleGlanceWindow() : null);
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showGlanceWindow ? window.showGlanceWindow() : null);
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeGlanceWindow ? window.closeGlanceWindow() : null);
        }
    }

    IpcHandler {
        target: "recorder"

        function toggle() {
            ScreenRecorder.toggleRecording();
        }

        function start() {
            ScreenRecorder.startRecording();
        }

        function stop() {
            ScreenRecorder.stopRecording();
        }

        function toggleMic() {
            ScreenRecorder.toggleMic();
        }

        function openRecordings() {
            ScreenRecorder.openRecordingsFolder();
        }
    }

    IpcHandler {
        target: "controlCenter"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }
    }

    IpcHandler {
        target: "player"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }
    }

    IpcHandler {
        target: "powerMenu"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }
    }

    IpcHandler {
        target: "notificationCenter"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }
    }

    IpcHandler {
        target: "fileShelf"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }
    }

    IpcHandler {
        target: "clock"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.showClockWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showClockWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showClockWindow());
        }
    }

    IpcHandler {
        target: "timer"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.showTimerWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showTimerWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showTimerWindow());
        }
    }

    Component.onDestruction: {
        shuttingDown = true;
    }

    Component.onCompleted: {
        SystemServices.ensureUserConfigAvailable();
        SystemServices.requestScreenRecordingSnapshot();
    }

    Variants {
        id: panelVariants

        model: Quickshell.screens

        DynamicIslandWindow {
            required property var modelData

            screen: modelData
            shellRootController: shellRoot
        }
    }
}
