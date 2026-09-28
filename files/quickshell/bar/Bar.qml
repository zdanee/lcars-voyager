// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R                                                                  │
// │   the bar · the island and its two sides, in three styles                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../theme"
import "../services"
import "./widgets"
import "./modules"
import "./island"
import "./island/controls"
import "../components"
// The menu is the dock's own (`DockMenu`) and the bar draws it, so the task
// selector and the window controls offer the same one (`DockService`).
import "../dock"

// The island in the middle and the two sides (`SettingsService.barZone`), in
// one of three styles:
//
//   grouped   the sides sit against the island and move aside as it grows
//   spread    the sides sit at the screen edges and hold still
//   island    everything in one capsule; the band morphs into whatever the
//             island opens
//
// Every detail opens in the island. The window is full-screen and never
// resizes; the input mask covers the bar and the island, and a focus grab
// closes the island on any click outside it.
//
// ── ONE PER SCREEN, ONE LIVE ────────────────────────────────────────────────
//
// There is one of these on every screen and exactly one of them is `live`:
// the screen being worked on. The live bar opens panels, holds the keyboard
// and shows whatever arrives; the rest are the same bar with the island at
// rest, which is what the other screens were already drawing. So the island
// crossing screens is a flag changing hands — nothing is built, nothing is
// torn down, and what is under the pointer is always the one that answers it.
PanelWindow {
    id: root

    readonly property alias island: island

    // Whether this is the screen being worked on (`shell.qml`). Everything
    // below that touches state the whole shell shares is gated on it, because
    // every screen runs a copy of this file.
    required property bool live

    // Whether this one is drawn at all. The surface is on every screen
    // either way and the reserve is `BarReserve`'s, which never moves, so a
    // desk set to one bar costs no window a re-tile when a hand crosses.
    readonly property bool painted: root.live || SettingsService.barEverywhere

    // The compositor's focus follows the pointer, so by the time anything here
    // is clicked this screen is already the live one. Said outright for the
    // case that is not a journey across the screen: a pointer warped onto the
    // bar, or a compositor not set to follow it.
    signal claimed()

    // Distance from the screen edge to the ends. Matches the compositor's
    // outer gap so the bar lines up with tiled windows.
    readonly property int edgeMargin: SettingsService.barSideMargin

    readonly property string style: SettingsService.barStyle
    readonly property bool spread: root.style === "spread"
    readonly property bool unified: root.style === "island"
    readonly property bool grouped: !root.spread && !root.unified

    // Stretch the band across the screen instead of fitting its contents.
    // Only the one-capsule style has a band.
    readonly property bool fullWidth: root.unified && SettingsService.barFullWidth

    readonly property bool holding: island.expanded

    // Maximum panel width. Spread, the sides stay put, so a panel gets the room
    // between them; otherwise the sides move aside and it gets the whole bar.
    readonly property int panelRoom: root.spread
        ? root.width - 2 * (root.edgeMargin
            + Math.max(leftZone.width, rightZone.width) + Theme.capsuleSpacing)
        : root.width - 2 * root.edgeMargin

    // Computed rather than read from `island.x`, which comes from an anchor
    // resolved during layout and would lag a frame behind the width.
    readonly property real islandLeft: (root.width - island.width) / 2
    readonly property real islandRight: root.islandLeft + island.width

    // ── ONE CAPSULE ─────────────────────────────────────────────────────────
    //
    // A band a capsule tall, with the sides at its ends and the island in the
    // middle. When the island shows anything beyond the clock, the band morphs
    // into it and the sides are clipped by its closing ends.

    // Inset of each side from the band's edge, clear of the curve.
    readonly property int hostedInset: 12

    // One slot per end, sized for that side's own width: the band's left
    // end must stay clear of the LCARS top-left button tile (x 138..600),
    // so a wide piece on the right must not widen the left end as well.
    // The clock stays centred either way — the island is anchored to the
    // screen, not to the band. Animated with the rest width, so a piece
    // appearing (the titlebar on focus) grows the band as one motion.
    readonly property real naturalSlotLeft: root.hostedInset
        + leftZone.width + Theme.capsuleSpacing * 2

    // LCARS: the left slot is pulled out until the band's left end meets the
    // right edge of the CAPTAIN'S LOG tile (x 600), so the workspaces sit
    // right after the blue and the band's rounded end — and the shadow it
    // casts across the tile — close the blue off with a gentle arch. The
    // extra length widens the slot rather than the band's span, so the right
    // end and the clock stay exactly where they are.
    readonly property real lcarsTileEnd: 600
    readonly property real leadSlot: Math.max(0,
        (root.width - root.restWidth) / 2 - root.lcarsTileEnd
        - root.naturalSlotLeft)

    property real slotLeft: root.unified
        ? root.naturalSlotLeft + root.leadSlot
        : 0
    property real slotRight: root.unified
        ? root.hostedInset + rightZone.width + Theme.capsuleSpacing * 2
        : 0

    Behavior on slotLeft {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }
    Behavior on slotRight {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The island's width inside the band, animated on the island's clock so
    // the band widens with it. An OSD is wider than the clock and pushes the
    // sides out rather than overlapping them.
    property real restWidth: island.state.layer === island.state.layerOsd
        ? Math.max(ModuleService.restWidth, island.size.width)
        : ModuleService.restWidth

    Behavior on restWidth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The band at rest: the island's rest width plus a slot for each side.
    readonly property real bodyWidth: {
        if (!root.unified)
            return island.width
        if (root.fullWidth)
            return root.width - 2 * root.edgeMargin
        return root.slotLeft + root.restWidth + root.slotRight
    }

    readonly property real bandRow: Theme.capsuleHeight + island.notchPad

    // The island is showing more than the clock: a panel, a detail, the
    // glance or a notification. An OSD fits in the band and does not count.
    readonly property bool islandTaken: island.expanded
        || island.state.layer === island.state.layerSummary
        || island.state.layer === island.state.layerNotification
    // The band's left end at rest: the island's rest centre, one left slot
    // further out.
    readonly property real bodyX: root.fullWidth
        ? root.edgeMargin
        : (root.width - root.restWidth) / 2 - root.slotLeft

    // 0 at rest, 1 once the island has taken over the band. Animated on the
    // island's clock and curve so the two land together.
    property real bandInto: root.unified && root.islandTaken ? 1 : 0

    Behavior on bandInto {
        enabled: island.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The band's ends, interpolated from its rest span (bodyX..bodyWidth,
    // one slot outside each side) to the island's animated rectangle as
    // `bandInto` goes from 0 to 1. Both run on the same curve, so this is
    // one morph with no clock of its own; at 1 the band *is* the island.
    // The span is no longer centred on the screen — the slots are sized per
    // side — but the island is, so the clock never moves. Off one capsule
    // there is no band, and the mask below wants the island's own rectangle.
    readonly property real bandMix: root.unified ? root.bandInto : 1
    readonly property real bandX: root.bodyX + (island.x - root.bodyX) * root.bandMix
    readonly property real bandRight: (root.bodyX + root.bodyWidth)
        + ((island.x + island.width) - (root.bodyX + root.bodyWidth)) * root.bandMix
    readonly property real bandWidth: root.bandRight - root.bandX

    // Attached (notch mode), only the island reaches the screen edge; the
    // sides stay capsules, centred on `laneY`.
    readonly property int islandTopMargin: SettingsService.islandAttached ? 0 : Theme.barTopMargin

    // The line everything on the bar is centred on. Attached, the island
    // reaches the screen edge, so its centre is half a margin higher and the
    // sides move up to match.
    readonly property real laneY: SettingsService.islandAttached
        ? Theme.barTopMargin / 2 : Theme.barTopMargin

    readonly property int collapsedHeight: Theme.barBand

    // Grouped, the sides make room for a module detail but hide for a panel.
    // In one capsule they hide whenever the island takes the band.
    readonly property bool sidesAway: root.unified
        ? root.islandTaken
        : island.expanded && root.grouped && island.state.openPanel !== "module"

    anchors {
        top: true
        left: true
        right: true
    }

    // ── WINDOW CONTROLS ──────────────────────────────────────────────────────
    //
    // One orange pill in the strip at the top right, in the black before the
    // frame's arch — the lavender elbow, whose left edge is `lcarsArch` — on
    // the same line and the same height as the other LCARS items. The window's
    // name takes the left of it, in black; the keys keep their place at the
    // right end, next to the arch.
    //
    // It acts on the window with the keyboard rather than sitting on every
    // window: furniture of the bar. A corner pill per window covered what a
    // window was showing and stacked over the band's own strips.
    readonly property int lcarsArch: 1792

    // The name's own room: wide enough for a title to read, and still clear
    // of the right-hand widgets, which end near x = 1407 on this screen.
    readonly property int controlsTitle: 240
    readonly property int controlsKeys: 100
    readonly property int controlsWidth: root.controlsKeys + root.controlsTitle
    readonly property int controlsHeight: 30

    // `{ x, y, w, h }`, the shape the pills used: a plain object, since the
    // `rect` type spells its size `width` / `height` and every consumer here
    // reads `w` / `h`. Hidden, the pill is only a circle: one key wide, at
    // the same right-hand end of the strip, whose click opens the menu that
    // offers the pill back.
    readonly property bool controlsHidden: DockService.controlsHidden

    readonly property var controlsBox: ({
        x: root.lcarsArch - 12
            - (root.controlsHidden ? root.controlsHeight : root.controlsWidth),
        y: Math.round(root.laneY + (Theme.capsuleHeight - root.controlsHeight) / 2),
        w: root.controlsHidden ? root.controlsHeight : root.controlsWidth,
        h: root.controlsHeight
    })

    // The pill itself, read for the input mask: while it drags, the surface
    // takes the whole screen (below).
    readonly property alias controlsItem: controls

    function onThisScreen(client: var): bool {
        const list = HyprlandService.monitors
        if (list.length <= 1)
            return true
        const found = list.find(monitor => monitor.id === client.monitor)
        return found ? found.name === root.screen.name : false
    }

    // The window the controls act on: the one with the keyboard, and only
    // when it is on this screen — each screen's bar speaks for its own
    // windows. Null on an empty workspace, which dims the pill.
    readonly property var focusedHere: {
        const client = HyprlandService.focusedClient
        return client && root.onThisScreen(client) ? client : null
    }

    // The controls' menu: the shape the task selector hands `DockMenu`,
    // with the one window the controls are about, anchored under the pill.
    // A null client is the hidden circle on an empty workspace: a menu with
    // no window, whose one row brings the pill back.
    function openControlsMenu(client: var, rect: var): void {
        root.dismiss()

        const live = client !== null && client !== undefined

        DockService.openItemMenu({
            key: `controls:${live ? client.address : "pill"}`,
            id: "",
            name: live ? (client.class || "") : "",
            icon: live ? (client.class || "").toLowerCase() : "",
            pinned: false,
            running: live,
            active: live,
            windows: live ? [{
                address: client.address,
                title: client.title || client.class,
                workspace: client.workspace ? client.workspace.id : 0,
                front: true
            }] : []
        }, {
            x: Math.round(rect.x + rect.w),
            y: Math.round(rect.y + rect.h + 6),
            align: "under",
            screen: root.screen.name
        })
    }

    // The menu open on this screen. One menu for the shell, so it is drawn
    // only by the bar whose screen it was opened on, while every painted bar
    // takes the screen for it — a click anywhere outside closes it.
    readonly property bool menuHere: DockService.menu !== null
        && DockService.menuAnchor !== null
        && DockService.menuAnchor.screen === root.screen.name

    // Where it goes from its anchor (`{ x, y, align }`): beside the icon it
    // was opened from and centred on it (`after`, or `before` from a dock on
    // the right edge), above a dock on the bottom edge, or under and
    // right-aligned to the window controls. Clamped to the screen, as the
    // dock always clamped it.
    function menuX(anchor: var, menuWidth: real): real {
        const x = anchor.align === "after" ? anchor.x
            : anchor.align === "above" ? anchor.x - menuWidth / 2
            : anchor.x - menuWidth
        return Math.max(4, Math.min(root.width - menuWidth - 4, x))
    }

    function menuY(anchor: var, menuHeight: real): real {
        const y = anchor.align === "after" || anchor.align === "before"
            ? anchor.y - menuHeight / 2
            : anchor.align === "above" ? anchor.y - menuHeight
            : anchor.y
        return Math.max(4, Math.min(root.height - menuHeight - 4, y))
    }

    // ── SURFACE ─────────────────────────────────────────────────────────────
    //
    // The layer surface is full-screen and never resizes: resizing it on every
    // animation frame makes the bar jitter, because the compositor applies the
    // new size a frame before or after the matching buffer. Input is handled by
    // the mask, which is cheap to change per frame.
    implicitHeight: root.screen.height

    // Input region: the bar's band, plus the island's shape (the band's, in
    // one capsule) with 12 px below it so the bottom edge still counts. The
    // whole screen only while the control centre is being arranged, since
    // blocks are dragged out of the tray card, which moves. Outside clicks are
    // left to the focus grab, so windows under an open panel stay usable.
    readonly property real shapeLeft: root.unified
        ? Math.min(root.bandX, root.islandLeft) : root.islandLeft
    readonly property real shapeRight: root.unified
        ? Math.max(root.bandX + root.bandWidth, root.islandRight) : root.islandRight
    readonly property bool wholeScreen: root.holding && ControlsService.editing

    // No input at all while desktop widgets are being arranged: dragging one
    // over the bar would move the pointer to this surface, and the desktop
    // would drop the widget. None either where nothing is painted.
    readonly property bool inert: DesktopService.editing || !root.painted

    // The surface takes the whole screen while a menu is open — so a click
    // anywhere outside closes it, as the dock did — and while a window is
    // being dragged, so the pointer stays on this surface wherever the hand
    // carries it over the windows below, and the release comes back to the
    // grab that started the drag.
    readonly property bool covering: root.wholeScreen || DockService.menu !== null
        || root.controlsItem.dragging

    mask: Region {
        // The band's rect, not the full strip: outside the painted band the
        // top edge belongs to the surfaces below (the LCARS band buttons),
        // and a window always sits on top of those.
        x: root.inert || root.covering ? 0 : root.bandX
        width: root.inert ? 0
            : root.covering ? root.width : root.bandWidth
        height: root.inert ? 0
            : root.covering ? root.height : root.collapsedHeight

        Region {
            x: root.shapeLeft
            width: root.inert ? 0 : root.shapeRight - root.shapeLeft
            height: root.islandTopMargin + island.height + 12
        }

        // The window controls' own target, absolute like the shape above.
        Region {
            x: root.controlsBox.x
            y: root.controlsBox.y
            width: root.inert ? 0 : root.controlsBox.w
            height: root.inert ? 0 : root.controlsBox.h
        }
    }

    // The reserve is `BarReserve.qml`'s, one strip per screen that outlives
    // every bar, so a window holds still while the island changes screens.
    // Ignoring zones is what keeps the bar against the edge: a surface that
    // reserves nothing is pushed below whatever else reserved.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    // ── FOCUS ───────────────────────────────────────────────────────────────
    //
    // On-demand keyboard focus plus a Hyprland focus grab while the island is
    // open. The grab keeps the keyboard here when the pointer crosses a window
    // (with `follow_mouse`, on-demand focus alone loses it), and a click on any
    // other surface clears it, which closes the island. The compositor
    // restores focus when the grab ends. Both stand down while the capture
    // surface is up, so an open panel waits under it instead of closing.
    readonly property bool holdsKeyboard: root.live && island.expanded
        && !CaptureService.active

    WlrLayershell.keyboardFocus: root.holdsKeyboard
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.holdsKeyboard
        windows: [root]
        onCleared: root.dismiss()
    }

    HoverHandler {
        onHoveredChanged: if (hovered) root.claimed()
    }

    // ── OPENING A DETAIL ────────────────────────────────────────────────────
    //
    // Every activation on the bar comes through here
    // (`ModuleService.activate`). Clicking the open module again closes it; any
    // other replaces it.
    function activate(id: string): void {
        if (ModuleService.openId === id) {
            root.dismiss()
            return
        }

        // Always in the island, whatever the style or screen.
        ModuleService.openHost = "island"
        ModuleService.openId = id
        island.open("module")
    }

    function dismiss(): void {
        if (island.expanded)
            island.close()
        ModuleService.close()
    }

    // Every bar hears these; only the live one answers, since the panel opens
    // in its island.
    Connections {
        target: ModuleService
        enabled: root.live

        function onActivationRequested(id: string): void {
            root.activate(id)
        }

        // Bar buttons for panels (launcher, overview) toggle them.
        function onPanelToggled(panel: string): void {
            island.toggle(panel)
        }

        // The service closed the detail, e.g. the player went away.
        function onOpenIdChanged(): void {
            if (ModuleService.openId === "" && island.state.openPanel === "module")
                island.close()
        }
    }

    // Lets a bar button stay lit while its panel is open. One writer: the
    // live bar, since two bars binding the same property is a conflict.
    Binding {
        target: ModuleService
        property: "shownPanel"
        value: island.state.openPanel
        when: root.live
    }

    Connections {
        target: island.state

        // The island left the detail (Escape, a click outside, another panel).
        function onOpenPanelChanged(): void {
            if (island.state.openPanel !== "module" && ModuleService.openHost === "island")
                ModuleService.close()
        }
    }

    // Clicks on the bar outside the open island close it. The bar is inside
    // the focus grab, so the grab never sees them.
    MouseArea {
        anchors.fill: parent
        enabled: root.holding
        onClicked: root.dismiss()
    }

    // ── THE FACE ────────────────────────────────────────────────────────────
    //
    // Everything this bar draws. The surface stays on every screen whatever
    // `barEverywhere` says, so the reserve never moves and no window is ever
    // re-tiled by a hand crossing; what the setting decides is only whether
    // this is painted. Nothing is built or torn down either way.
    Item {
        id: face

        anchors.fill: parent
        visible: root.painted || face.opacity > 0
        opacity: root.painted ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        // ── SHADOW ──────────────────────────────────────────────────────────────
        //
        // Same numbers and setting as the window shadow. The band, the island and
        // the notch fillets touch, so they share one flattened layer; separate
        // shadows would draw a seam where they overlap. The side capsules cast
        // their own (`BarZone`).
        //
        // Cast from a copy of the shapes: layering the real bar would re-blur the
        // full-screen surface every time the clock or the spectrum repaints.
        //
        // The copy is grown by `Theme.shadowBarSpread` and blurred. MultiEffect's
        // `shadowEnabled` would also draw the source, showing the enlarged copy as
        // a black rim. `layer.effect` rather than a hidden `source` item, which
        // does not work inside a Repeater.
        Loader {
            anchors.fill: parent
            active: SettingsService.windowShadow
            sourceComponent: shadowBody
        }

        Component {
            id: shadowBody

            Item {
                id: caster

                anchors.fill: parent
                opacity: Theme.shadowOpacity

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: Theme.shadowBarRange - Theme.shadowBarSpread
                }

                readonly property int spread: Theme.shadowBarSpread

                Rectangle {
                    x: band.x - caster.spread
                    y: band.y - caster.spread
                    width: band.width + 2 * caster.spread
                    height: band.height + 2 * caster.spread
                    radius: band.radius + caster.spread
                    topLeftRadius: band.topLeftRadius > 0 ? band.topLeftRadius + caster.spread : 0
                    topRightRadius: band.topRightRadius > 0 ? band.topRightRadius + caster.spread : 0
                    visible: body.visible
                    color: Theme.shadowColor
                }

                Rectangle {
                    x: root.islandLeft - caster.spread
                    y: island.y - caster.spread
                    width: island.width + 2 * caster.spread
                    height: island.height + 2 * caster.spread
                    radius: island.radius + caster.spread
                    topLeftRadius: island.topLeftRadius > 0 ? island.topLeftRadius + caster.spread : 0
                    topRightRadius: island.topRightRadius > 0 ? island.topRightRadius + caster.spread : 0
                    color: Theme.shadowColor
                }

                Repeater {
                    model: [notchLeft, notchRight]

                    NotchFillet {
                        required property var modelData

                        x: modelData.x
                        y: modelData.y
                        width: modelData.width
                        height: modelData.height
                        visible: modelData.visible
                        opacity: modelData.opacity
                        mirrored: modelData.mirrored
                        color: Theme.shadowColor
                    }
                }

            }
        }

        // ── BAND ────────────────────────────────────────────────────────────────
        //
        // Two shapes of the same black: the band, and the island on top of it.
        // Neither has an outline, which would draw the seam between them.
        Item {
            id: body

            anchors.fill: parent
            visible: root.unified

            // Grows with the island; at rest both share height and radius.
            Rectangle {
                id: band

                x: root.bandX
                y: root.islandTopMargin
                width: root.bandWidth
                height: Math.max(root.bandRow, island.height)
                radius: island.radius
                topLeftRadius: SettingsService.islandAttached ? 0 : band.radius
                topRightRadius: SettingsService.islandAttached ? 0 : band.radius
                color: island.surfaceColor

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                // Clicking the band opens the island. The sides sit above it and
                // take their own clicks.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.open("controls")
                }
            }
        }

        // ── WINDOW CONTROLS ───────────────────────────────────────────────────
        //
        // Above the windows it speaks for and below the island: one surface,
        // so declaration order decides, and it comes before the island — a
        // wide island covers it instead of the other way round.
        WindowControls {
            id: controls

            box: root.controlsBox
            client: root.focusedHere
            hidden: root.controlsHidden
            onMenuRequested: (client, rect) => root.openControlsMenu(client, rect)
        }

        DynamicIsland {
            id: island

            active: root.live
            hosted: root.unified
            roomForPanel: root.panelRoom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.islandTopMargin

            Behavior on anchors.topMargin {
                enabled: island.animated
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
        }

        // The island's hairline, drawn round the band once it takes the island's
        // shape. Above both, since the opaque island covers the band's own edge.
        // None at rest and none in paper mode.
        Rectangle {
            id: outline

            x: band.x
            y: band.y
            width: band.width
            height: band.height
            radius: band.radius
            topLeftRadius: band.topLeftRadius
            topRightRadius: band.topRightRadius
            visible: root.unified && !island.paper
            color: "transparent"
            border.width: 1
            border.color: root.islandTaken ? Theme.islandBorder : "transparent"

            Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }
        }

        // The control centre's tray card while its grid is being arranged. On this
        // surface so blocks can be dragged from it onto the island; it fills the
        // surface and starts under the island.
        Item {
            id: overlay

            anchors.fill: parent
            z: 3

            Loader {
                anchors.fill: parent
                active: root.live && ControlsService.editing
                sourceComponent: ControlsTray {
                    host: overlay
                    homeTop: root.islandTopMargin + island.height + Theme.desktopGutter
                }
            }
        }

        // Notch fillets flaring from the island's edges out to the screen edge.
        // In one capsule they follow whichever edge is further out, the band's or
        // the island's, since a spring curve can push the island past the band.
        NotchFillet {
            id: notchLeft

            x: (root.unified ? Math.min(root.bandX, root.islandLeft) : root.islandLeft) - width
            anchors.top: parent.top
            visible: SettingsService.islandAttached
            mirrored: true
            color: island.surfaceColor
        }

        NotchFillet {
            id: notchRight

            x: root.unified ? Math.max(root.bandX + root.bandWidth, root.islandRight) : root.islandRight
            anchors.top: parent.top
            visible: SettingsService.islandAttached
            color: island.surfaceColor
        }

        // ── SIDES ───────────────────────────────────────────────────────────────
        //
        // Grouped, the sides are anchored to the island's animated edges, so they
        // move aside on its clock with nothing else to animate. Spread, they stay
        // in the corners. In one capsule they are the band's ends; while it morphs
        // they are clipped by it and fade out faster than it closes.
        Item {
            id: sides

            readonly property bool cropped: root.unified && root.bandInto > 0

            x: sides.cropped ? band.x : 0
            y: 0
            width: sides.cropped ? band.width : root.width
            height: root.height
            clip: sides.cropped

            BarZone {
                id: leftZone

                entries: SettingsService.barItems("left")
                chromeless: root.unified
                x: (root.unified ? root.bodyX + root.hostedInset
                    : root.spread ? root.edgeMargin
                    : root.islandLeft - Theme.capsuleSpacing - leftZone.width) - sides.x
                y: root.laneY
                opacity: root.sidesAway ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.unified && root.sidesAway ? Theme.durationFast : Theme.durationMedium
                        easing.type: Theme.easing
                    }
                }
            }

            BarZone {
                id: rightZone

                entries: SettingsService.barItems("right")
                chromeless: root.unified
                x: (root.unified ? root.bodyX + root.bodyWidth - root.hostedInset - rightZone.width
                    : root.spread ? root.width - root.edgeMargin - rightZone.width
                    : root.islandRight + Theme.capsuleSpacing) - sides.x
                y: root.laneY
                opacity: root.sidesAway ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.unified && root.sidesAway ? Theme.durationFast : Theme.durationMedium
                        easing.type: Theme.easing
                    }
                }
            }
        }

        // ── MENU ──────────────────────────────────────────────────────────────
        //
        // The one context menu (`DockService`): the task selector's and the
        // window controls' are the same menu, so there is one, and the bar
        // draws it — last, with z above the island and above the tray card,
        // on the top layer, so above every window too. Drawn on the dock's
        // own surface it fell behind the very windows it is beside.
        //
        // A click outside it is consumed here, which closes it; the second
        // one reaches whatever is under.

        MouseArea {
            id: menuCatch

            anchors.fill: parent
            z: 4
            enabled: DockService.menu !== null
            acceptedButtons: Qt.AllButtons
            onPressed: DockService.closeMenu()
        }

        Loader {
            id: menu

            z: 5
            active: root.painted && root.menuHere

            width: item ? item.width : Theme.dockMenuWidth
            height: item ? item.height : 0

            x: DockService.menuAnchor ? root.menuX(DockService.menuAnchor, width) : 0
            y: DockService.menuAnchor ? root.menuY(DockService.menuAnchor, height) : 0

            sourceComponent: DockMenu {
                item: DockService.menu
                onClosed: DockService.closeMenu()
            }
        }
    }
}
