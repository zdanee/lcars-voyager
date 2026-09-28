// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W I N D O W   C O N T R O L S                                          │
// │   the bar's own switch for whichever window has the keyboard             │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"

// One orange pill in the strip at the top right next to the frame's arch:
// the window's name in black across the left of it, then the keys — close,
// the context menu (the task selector's own — one menu for the shell), the
// float/tile switch — and the grip.
//
// Furniture of the bar, not of the window: what it acts on is simply the
// window with the keyboard (`HyprlandService.focusedClient`), so there is
// one of these instead of a small pill on every window, and it never sits
// on top of what a window is showing.
//
// ── DRAG ────────────────────────────────────────────────────────────────────
//
// The name and the grip are both grab handles: press, carry the outline
// down into the screen, let go. Nothing is moved under the pointer and no
// pointer is warped anywhere — the grab lives on the bar's surface, whose
// input mask takes the whole screen while it lasts, so motion and the
// release keep arriving here wherever the hand goes over the windows.
//
// Landing inside another window's space swaps the two in the tile grid; on
// empty space a tiled window floats where it landed, and an already
// floating one simply drops there.
Item {
    id: root

    // { x, y, w, h } in surface coordinates, from the bar's frame constants.
    required property var box

    // The window the buttons act on, or null on an empty workspace.
    property var client: null

    // Hidden from the menu: only the circle the box has become, with the
    // name and the keys gone. Its click opens the same menu, which offers
    // to show the pill again.
    property bool hidden: false

    // Opened by the arrow: `client` and the pill's own rect, so the bar can
    // anchor the menu under it.
    signal menuRequested(var client, var rect)

    // The compositor's border (`look.lua`, `border_size`), which the frame
    // rect and the ghost are measured across.
    readonly property int frame: 4
    readonly property bool live: root.client !== null && root.client !== undefined

    // The window's frame: where the pointer goes and what the ghost draws.
    readonly property var frameRect: !root.live || !root.client.at || !root.client.size
        ? null
        : ({
            x: root.client.at[0] - root.frame,
            y: root.client.at[1] - root.frame,
            w: root.client.size[0] + root.frame * 2,
            h: root.client.size[1] + root.frame * 2
        })

    x: root.box.x
    y: root.box.y
    width: root.box.w
    height: root.box.h
    // Hidden, the circle is furniture of the strip rather than a control of
    // a window, so it stays lit even on an empty workspace.
    opacity: root.hidden ? 1 : (root.live ? 1 : 0.45)

    Behavior on opacity {
        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
    }

    // ── ONE BUTTON OF THE PILL ──────────────────────────────────────────────

    component Key: Item {
        id: key

        property string glyph: ""
        property int glyphSize: 13
        property bool bold: false

        // The handle is drawn as two bars instead of a glyph.
        property bool handle: false

        signal tapped()

        readonly property bool lit: hove.hovered || tap.pressed

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.island
            visible: key.lit
        }

        Text {
            anchors.centerIn: parent
            visible: !key.handle
            text: key.glyph
            font.family: Theme.fontFamily
            font.pixelSize: key.glyphSize
            font.weight: key.bold ? Font.Bold : Font.Normal
            color: key.lit ? Theme.accent : Theme.island
        }

        Column {
            anchors.centerIn: parent
            spacing: 3
            visible: key.handle

            Rectangle {
                width: 14
                height: 2
                radius: 1
                color: key.lit ? Theme.accent : Theme.island
            }
            Rectangle {
                width: 14
                height: 2
                radius: 1
                color: key.lit ? Theme.accent : Theme.island
            }
        }

        HoverHandler { id: hove; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: key.tapped() }
    }

    // ── THE PILL ────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.accent
    }

    // Hidden, the whole circle is the one key: no name, no keys, no grab —
    // a click opens the menu that brings the pill back.
    MouseArea {
        anchors.fill: parent
        visible: root.hidden
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.menuRequested(root.client, root.box)
    }

    // ── THE WINDOW'S NAME ────────────────────────────────────────────────────
    //
    // Black on the orange at the pill's left end, elided to whatever room
    // there is. Also the wide half of the grab handle: carrying a window
    // down by its name beats hunting for the grip at the far end.
    //
    // Its own MouseArea, because a drag needs the press, the motion and the
    // release rather than a tap.

    MouseArea {
        id: name

        x: 0
        width: root.hidden ? 0 : Math.max(0, root.box.w - root.keysWidth)
        height: root.height
        visible: !root.hidden
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        // The pill's plate under it while it is held, as for the grip.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.island
            visible: name.pressed
        }

        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 32)
            text: root.live
                ? (root.client.title || root.client.class || "") : ""
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.island
        }

        onPressed: mouse => {
            const point = name.mapToItem(null, mouse.x, mouse.y)
            root.beginDrag(point.x, point.y)
        }

        onPositionChanged: mouse => {
            const point = name.mapToItem(null, mouse.x, mouse.y)
            root.dragTo(point.x, point.y)
        }

        onReleased: root.drop()
        onCanceled: root.drop()
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.hidden

        // Close, with the keyboard on it: the window, not the app.
        Key {
            width: 26
            height: root.height
            glyph: "\u2715"
            glyphSize: 12

            onTapped: {
                if (root.live)
                    HyprlandService.closeWindow(root.client.address)
            }
        }

        // The same context menu the task selector's right-click opens.
        Key {
            width: 22
            height: root.height
            glyph: "\u25be"
            glyphSize: 13

            onTapped: {
                if (root.live)
                    root.menuRequested(root.client, root.box)
            }
        }

        // Free-floating or back into the tile grid. Floating starts centred
        // with 150 px around it, so every edge can be grabbed at once.
        Key {
            width: 22
            height: root.height
            glyph: "\u25a0"
            glyphSize: 12
            bold: true

            onTapped: {
                if (!root.live)
                    return
                if (root.client.floating)
                    HyprlandService.toggleFloating(root.client.address)
                else
                    HyprlandService.floatCentered(root.client.address)
            }
        }

        // The grip: same grab as the name, at the pill's far end.
        MouseArea {
            id: hand

            width: 30
            height: root.height
            hoverEnabled: true
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            // The pill's plate under it while it is held.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.island
                visible: hand.pressed
            }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Rectangle {
                    width: 14
                    height: 2
                    radius: 1
                    color: hand.pressed ? Theme.accent : Theme.island
                }
                Rectangle {
                    width: 14
                    height: 2
                    radius: 1
                    color: hand.pressed ? Theme.accent : Theme.island
                }
            }

            onPressed: mouse => {
                const point = hand.mapToItem(null, mouse.x, mouse.y)
                root.beginDrag(point.x, point.y)
            }

            onPositionChanged: mouse => {
                const point = hand.mapToItem(null, mouse.x, mouse.y)
                root.dragTo(point.x, point.y)
            }

            onReleased: root.drop()
            onCanceled: root.drop()
        }
    }

    // ── THE GRAB AND THE DROP ──────────────────────────────────────────────────

    property bool dragging: false
    property bool moved: false

    // Where the press landed, in surface coordinates: the distance from it
    // is what tells a drag from a click.
    property real pressX: 0
    property real pressY: 0

    // The keys' own width — everything left of them is the name.
    readonly property int keysWidth: 100

    // Both handles start the same grab. The outline takes the window's frame
    // where the window actually is; the first real motion puts it under the
    // pointer, centred, so what sits under the outline's middle is what the
    // drop acts on.
    function beginDrag(px: real, py: real): void {
        if (!root.live || !root.frameRect)
            return

        const frame = root.frameRect
        const local = root.mapFromItem(null, frame.x, frame.y)

        root.dragging = true          // mask first: the pointer leaves next
        root.moved = false
        root.pressX = px
        root.pressY = py

        ghost.client = root.client
        ghost.floating = root.client.floating
        ghost.x = local.x
        ghost.y = local.y
        ghost.width = frame.w
        ghost.height = frame.h

        DockService.closeMenu()
    }

    function dragTo(px: real, py: real): void {
        if (!root.dragging)
            return

        // The first motion past a threshold shows the outline; a press that
        // only trembles is still a click.
        if (!root.moved) {
            if (Math.abs(px - root.pressX) < 3 && Math.abs(py - root.pressY) < 3)
                return
            root.moved = true
        }

        const local = root.mapFromItem(null, px, py)
        ghost.x = Math.round(local.x - ghost.width / 2)
        ghost.y = Math.round(local.y - ghost.height / 2)

        // A floating window is carried as it is dragged; a tiled one is
        // placed by the layout and only previews until the drop.
        if (ghost.floating) {
            const at = root.mapToItem(null, ghost.x, ghost.y)
            HyprlandService.moveFloating(ghost.client.address,
                Math.round(at.x), Math.round(at.y))
        }
    }

    function drop(): void {
        if (!root.dragging)
            return

        const client = ghost.client
        const moved = root.moved

        root.dragging = false

        // A press with no drag only focuses: the hand rested on the name of
        // a window, which reads as "this one".
        if (!moved) {
            if (client)
                HyprlandService.focusWindow(client.address)
            return
        }

        if (!client)
            return

        // The outline's own place, back in surface coordinates: what is
        // drawn is where the window lands.
        const at = root.mapToItem(null, ghost.x, ghost.y)
        const x = Math.round(at.x)
        const y = Math.round(at.y)

        if (client.floating) {
            HyprlandService.moveFloating(client.address, x, y)
            return
        }

        // Tiled: onto another tiled window swaps the two in the grid, onto
        // empty space it floats where it landed.
        const under = HyprlandService.clientAt(x + ghost.width / 2,
            y + ghost.height / 2, client.address)
        if (under && !under.floating) {
            HyprlandService.swapWindows(client.address, under.address)
            return
        }
        HyprlandService.floatAt(client.address, x, y)
    }

    // The window's outline, carried under the pointer while it is dragged:
    // the frame's own size, centred on the hand, so the drop lands where it
    // looks like it will. Hidden for a floating window, which is already
    // following the hand.
    Rectangle {
        id: ghost

        visible: root.dragging && root.moved && !ghost.floating
        color: Theme.island
        opacity: 0.9
        radius: 12
        border.width: 2
        border.color: Theme.accent

        property var client: null
        property bool floating: false
    }
}
