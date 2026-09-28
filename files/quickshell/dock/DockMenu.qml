// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   M E N U                                                      │
// │   one application's windows · and what can be done to it                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"

// Right-click menu for a dock icon: the application's windows by title, with
// the focused one marked and each one's workspace, then the application's own
// actions.
//
// ── LAYOUT ──────────────────────────────────────────────────────────────────
//
// Drawn inside the dock's surface, not a new one: same-layer surfaces stack in
// creation order, so one created on demand would cover the dock and take its
// clicks. While it is open the dock's input region is the whole screen, so a
// click outside closes it.
//
// No keyboard focus, so no Escape: right-click, click outside, or choose an
// item.
//
// Fixed width: fitting the content would make the rows' width and the plate's
// depend on each other, and window titles need eliding anyway.
Item {
    id: root

    required property var item

    signal closed()

    readonly property bool multiple: root.item.windows.length > 1

    // A window with no matching desktop entry: nothing to launch or pin, only
    // its windows.
    readonly property bool known: root.item.id !== ""

    // The window the desktop chips act on: the front one, which is the window
    // a pill names for itself — both pass the same shape in.
    readonly property var target: root.item.windows.find(window => window.front)
        || root.item.windows[0] || null

    // The window controls' own menu (`controls:…`): about the pill, not one
    // application, so it carries the row that hides it — or, opened from the
    // circle it becomes, shows it again.
    readonly property bool controlsMenu: root.item.key.startsWith("controls:")

    // The desktops to offer: the fixed slots, plus any workspace beyond them
    // that holds a window or is on screen — a window may have been sent to a
    // workspace past the count and still needs a way back.
    readonly property var desktops: HyprlandService.visibleIds

    // Application actions, below the windows.
    readonly property var actions: {
        const rows = []
        if (root.known) {
            rows.push({
                id: "launch",
                label: root.item.running ? Tr.t("New window") : Tr.t("Open"),
                warn: false
            })
            rows.push({
                id: "pin",
                label: root.item.pinned
                    ? Tr.t("Remove from the dock")
                    : Tr.t("Keep in the dock"),
                warn: false
            })
        }
        if (root.item.running) {
            rows.push({
                id: "close",
                label: root.multiple ? Tr.t("Close all windows") : Tr.t("Close"),
                warn: true
            })
        }
        if (root.controlsMenu) {
            // The label itself is not in the row: `actions` must not depend
            // on `controlsHidden`, or toggling it (below, in the click)
            // rebuilds this very row mid-press and the delegate is gone
            // before `root.closed()` runs. The Text reads the flag instead.
            rows.push({
                id: "controls",
                label: "",
                warn: false
            })
        }
        return rows
    }

    implicitWidth: Theme.dockMenuWidth
    implicitHeight: column.implicitHeight + 2 * Theme.dockMenuPadding
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Theme.dockMenuPadding
        spacing: 0

        // ── WINDOWS ─────────────────────────────────────────────────────────

        Repeater {
            model: root.item.windows

            Rectangle {
                id: window

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dockMenuRow
                radius: Theme.radiusSmall
                color: windowMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Marks the focused window; hyprctl's order carries no
                    // meaning.
                    Rectangle {
                        Layout.preferredWidth: Theme.dockDot
                        Layout.preferredHeight: Theme.dockDot
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.radiusPill
                        color: Theme.accent
                        opacity: window.modelData.front ? 1 : 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.modelData.title
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    // The window's workspace, since choosing it also switches
                    // workspace.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: `${window.modelData.workspace}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: windowMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        HyprlandService.focusWindow(window.modelData.address)
                        root.closed()
                    }
                }
            }
        }

        // ── SEND TO A DESKTOP ────────────────────────────────────────────────
        //
        // The bar's own dots: lit where the window already is, solid where a
        // window waits, dim where the desktop is empty. One click sends it and
        // closes the menu — the desktop it lands on comes with it.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.item.running && root.target !== null

            Text {
                Layout.fillWidth: true
                text: Tr.t("Send to desktop")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.desktops

                    Rectangle {
                        id: chip

                        required property var modelData

                        readonly property bool here: root.target !== null
                            && root.target.workspace === chip.modelData
                        readonly property bool occupied:
                            HyprlandService.isOccupied(chip.modelData)

                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.dockMenuRow - 8
                        radius: Theme.radiusSmall
                        color: chipMouse.containsMouse
                            ? (chip.here ? Theme.accentHover : Theme.islandSurfaceHover)
                            : (chip.here ? Theme.accent : "transparent")
                        border.width: chip.here ? 0 : 1
                        border.color: Theme.hairline

                        Text {
                            anchors.centerIn: parent
                            text: `${chip.modelData}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: chip.here ? Theme.accentText
                                : (chip.occupied ? Theme.accent : Theme.textMuted)
                        }

                        MouseArea {
                            id: chipMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                HyprlandService.moveClient(
                                    root.target.address, chip.modelData)
                                root.closed()
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            visible: root.item.running && root.actions.length > 0
            color: Theme.hairline
        }

        // ── APPLICATION ─────────────────────────────────────────────────────

        Repeater {
            model: root.actions

            Rectangle {
                id: action

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dockMenuRow
                radius: Theme.radiusSmall
                color: actionMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    // Aligned with the window titles, not the dots.
                    anchors.leftMargin: 16 + Theme.dockDot
                    // The controls row names itself from live state (see the
                    // `actions` getter): hidden or shown, not both rows.
                    text: action.modelData.id === "controls"
                        ? (DockService.controlsHidden
                            ? Tr.t("Show window controls")
                            : Tr.t("Hide window controls"))
                        : action.modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    // Closing cannot be undone, so it turns red on hover
                    // instead of asking for confirmation.
                    color: action.modelData.warn && actionMouse.containsMouse
                        ? Theme.red : Theme.text
                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch (action.modelData.id) {
                        case "launch":
                            DockService.launch(root.item)
                            break
                        case "pin":
                            DockService.togglePin(root.item.id)
                            break
                        case "close":
                            DockService.closeAll(root.item)
                            break
                        case "controls":
                            DockService.controlsHidden = !DockService.controlsHidden
                            break
                        }
                        root.closed()
                    }
                }
            }
        }
    }
}
