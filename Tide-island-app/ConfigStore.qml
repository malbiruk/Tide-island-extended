pragma Singleton
import QtQuick

QtObject {
    readonly property string path: backend.userConfigPath
    readonly property string errorString: backend.errorString
    property var map: backend.userConfig
    // Edits not yet written; save() sends only these keys, so values changed
    // outside the app (e.g. doNotDisturb from the island) are left alone.
    property var pendingChanges: ({})
    property var pendingRemovals: ({})

    function value(key, fallback) {
        if (pendingRemovals[key] === true)
            return fallback;
        const currentValue = Object.prototype.hasOwnProperty.call(pendingChanges, key) ? pendingChanges[key] : map[key];
        return currentValue === undefined || currentValue === null ? fallback : currentValue;
    }

    function setValue(key, value) {
        pendingChanges[key] = value;
        delete pendingRemovals[key];
    }

    function remove(key) {
        delete pendingChanges[key];
        pendingRemovals[key] = true;
    }

    function save() {
        if (!backend.save(pendingChanges, Object.keys(pendingRemovals)))
            return false;
        pendingChanges = {};
        pendingRemovals = {};
        return true;
    }
}
