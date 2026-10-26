import QtQuick
import "../controlcenter"

// Loaded by URL from DynamicIslandWindow so the layer's type is only compiled when it first opens.
NotificationCenterLayer {
    required property var host
    required property var island

    notificationModel: island.notificationHistoryModel
    iconFontFamily: host.iconFontFamily
    textFontFamily: host.textFontFamily
    heroFontFamily: host.heroFontFamily

    onClearAllRequested: {
        if (host.shellRootController && host.shellRootController.clearAllNotifications)
            host.shellRootController.clearAllNotifications();
        else
            island.notificationHistoryModel.clear();
    }
    onNotificationDismissRequested: function(id) {
        host.dismissNotification(id);
    }
    onNotificationActivated: function(id) {
        host.activateNotification({ id: id }, true);
        island.smartRestoreState();
    }
    onCloseRequested: island.smartRestoreState()
}
