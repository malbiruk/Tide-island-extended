pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import IslandBackend
import "../common"

// A tray item's menu, drawn by the shell: quickshell runs without QApplication, so it has no
// platform menus. Submenus replace the list in place, under a Back row.
Item {
    id: root

    // An entry was picked; the control center closes so whatever the app opens is in view.
    signal entryTriggered()

    // The card keeps this far inside this item, which also catches the clicks that dismiss it.
    property real margin: 12

    property SystemTrayItem trayItem: null
    // The clicked icon, in this item's coordinates.
    property rect anchorRect
    // Submenus opened from the root one, innermost last.
    property var menuStack: []

    // The root menu arrives over D-Bus after opening; nothing shows until it has.
    readonly property bool shown: trayItem !== null && rootOpener.children.values.length > 0
    readonly property QsMenuOpener currentOpener: menuStack.length > 0 ? levelOpener : rootOpener
    readonly property var entries: Array.from(currentOpener.children.values)
    // Shared columns keep the labels aligned when only some entries have a toggle or an icon.
    readonly property bool anyToggle: entries.some(entry => entry.buttonType !== QsMenuButtonType.None)
    readonly property bool anyIcon: entries.some(entry => entry.icon !== "")

    readonly property int fontSize: UserConfig.bodyFontSize - 1
    readonly property real rowHeight: fontSize + 14
    readonly property real padding: 6
    readonly property real rowInset: 10
    readonly property real labelX: rowInset + (anyToggle ? 24 : 0) + (anyIcon ? 24 : 0)

    function openFor(item, anchorItem) {
        menuStack = [];
        // Its geometry in its parent, so a press or hover scale on the icon doesn't shift the card.
        anchorRect = mapFromItem(anchorItem.parent, anchorItem.x, anchorItem.y, anchorItem.width, anchorItem.height);
        trayItem = item;
    }

    function close() {
        menuStack = [];
        trayItem = null;
    }

    function activate(entry) {
        if (entry.hasChildren) {
            menuStack = menuStack.concat([entry]);
            return;
        }
        entry.triggered();
        close();
        entryTriggered();
    }

    function toggleGlyph(entry) {
        if (entry.buttonType === QsMenuButtonType.CheckBox) {
            if (entry.checkState === Qt.Checked)
                return "\uf046";
            return entry.checkState === Qt.PartiallyChecked ? "\uf147" : "\uf096";
        }
        if (entry.buttonType === QsMenuButtonType.RadioButton)
            return entry.checkState === Qt.Unchecked ? "\uf10c" : "\uf192";
        return "";
    }

    onMenuStackChanged: entryFlickable.contentY = 0

    // Keeps the whole menu loaded while it is open; a submenu is one of its entries.
    QsMenuOpener {
        id: rootOpener
        menu: root.trayItem ? root.trayItem.menu : null
    }

    QsMenuOpener {
        id: levelOpener
        menu: root.menuStack.length > 0 ? root.menuStack[root.menuStack.length - 1] : null
    }

    // A press anywhere else closes the menu and reaches nothing under it; wheel and hover stop too.
    MouseArea {
        anchors.fill: parent
        enabled: root.shown || pressed
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.close()
        onWheel: wheel => wheel.accepted = true
    }

    Item {
        id: card

        readonly property real gap: 6
        readonly property real naturalHeight: entryColumn.implicitHeight + 2 * root.padding
        readonly property real roomBelow: root.height - root.margin - (root.anchorRect.y + root.anchorRect.height + gap)
        readonly property real roomAbove: root.anchorRect.y - gap - root.margin
        readonly property bool below: naturalHeight <= roomBelow || roomBelow >= roomAbove

        visible: root.shown
        width: Math.min(Math.max(entryColumn.implicitWidth + 2 * root.padding, 160), root.width - 2 * root.margin)
        height: Math.min(naturalHeight, below ? roomBelow : roomAbove)
        x: Math.max(root.margin, Math.min(root.anchorRect.x + (root.anchorRect.width - width) / 2,
            root.width - root.margin - width))
        y: below ? root.anchorRect.y + root.anchorRect.height + gap : root.anchorRect.y - gap - height

        GlassSurface {
            anchors.fill: parent
        }

        // Clicks on the padding, separators and disabled entries stay on the card.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        Flickable {
            id: entryFlickable
            anchors.fill: parent
            anchors.margins: root.padding
            contentHeight: entryColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Rows keep their natural width, which sizes the card; highlights span the column.
            Column {
                id: entryColumn
                width: entryFlickable.width

                Item {
                    visible: root.menuStack.length > 0
                    width: root.rowInset * 2 + backLabel.implicitWidth
                    height: root.rowHeight + 9

                    Rectangle {
                        width: entryColumn.width
                        height: root.rowHeight
                        radius: 6
                        color: backMouse.containsMouse ? StyleTokens.moduleHover : StyleTokens.transparent
                    }

                    Text {
                        id: backLabel
                        x: root.rowInset
                        height: root.rowHeight
                        verticalAlignment: Text.AlignVCenter
                        text: "\u2039 Back"
                        color: StyleTokens.textSecondary
                        font.pixelSize: root.fontSize
                        font.family: UserConfig.textFontFamily
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        x: 4
                        y: root.rowHeight + 4
                        width: entryColumn.width - 8
                        height: 1
                        color: StyleTokens.track
                    }

                    MouseArea {
                        id: backMouse
                        width: entryColumn.width
                        height: root.rowHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.menuStack = root.menuStack.slice(0, -1)
                    }
                }

                Repeater {
                    model: root.currentOpener.children

                    delegate: Item {
                        id: entryRow

                        required property QsMenuEntry modelData
                        readonly property color labelColor: modelData.enabled ? StyleTokens.textPrimary : StyleTokens.textMuted

                        // Never 0: the Column skips zero-width items.
                        width: modelData.isSeparator ? 2 * root.rowInset : root.labelX + label.implicitWidth
                            + (modelData.hasChildren ? 8 + chevron.implicitWidth : 0) + root.rowInset
                        height: modelData.isSeparator ? 9 : root.rowHeight

                        Rectangle {
                            visible: entryRow.modelData.isSeparator
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: entryColumn.width - 8
                            height: 1
                            color: StyleTokens.track
                        }

                        Rectangle {
                            visible: !entryRow.modelData.isSeparator
                            width: entryColumn.width
                            height: parent.height
                            radius: 6
                            color: entryMouse.containsMouse ? StyleTokens.moduleHover : StyleTokens.transparent
                        }

                        Text {
                            visible: root.anyToggle && !entryRow.modelData.isSeparator
                            x: root.rowInset
                            width: 16
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.toggleGlyph(entryRow.modelData)
                            color: entryRow.labelColor
                            font.pixelSize: root.fontSize
                            font.family: UserConfig.iconFontFamily
                        }

                        Image {
                            visible: root.anyIcon && !entryRow.modelData.isSeparator
                            x: root.rowInset + (root.anyToggle ? 24 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            source: entryRow.modelData.icon
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            opacity: entryRow.modelData.enabled ? 1 : 0.5
                        }

                        Text {
                            id: label
                            visible: !entryRow.modelData.isSeparator
                            x: root.labelX
                            width: Math.min(implicitWidth, entryColumn.width - x - root.rowInset
                                - (entryRow.modelData.hasChildren ? 8 + chevron.implicitWidth : 0))
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: entryRow.modelData.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: entryRow.labelColor
                            font.pixelSize: root.fontSize
                            font.family: UserConfig.textFontFamily
                            font.weight: Font.Medium
                        }

                        Text {
                            id: chevron
                            visible: entryRow.modelData.hasChildren && !entryRow.modelData.isSeparator
                            x: entryColumn.width - root.rowInset - implicitWidth
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "\u203a"
                            color: entryRow.modelData.enabled ? StyleTokens.textSubtle : StyleTokens.textMuted
                            font.pixelSize: root.fontSize + 3
                            font.family: UserConfig.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: entryMouse
                            width: entryColumn.width
                            height: parent.height
                            enabled: entryRow.modelData.enabled && !entryRow.modelData.isSeparator
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(entryRow.modelData)
                        }
                    }
                }
            }
        }
    }
}
