// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L C A R S   C O N S O L E   B U T T O N S                              │
// │   the active edge: top band, left band, the bottom-left corner tile       │
// │                                                                          │
// │   Layout rule (the whole point of this file): active pieces live on the  │
// │   top and left, plus the bottom-left USS VOYAGER tile (quick settings,    │
// │   behind windows too); the rest of the bottom and the right are          │
// │   decorative and windows cover them. Geometry mirrors lcars_wallpaper.py  │
// │   halved — the wallpaper is 2x this panel — so each window sits exactly  │
// │   on its band.                                                            │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../services"

Item {
    id: root

    required property var screen

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    // The island's calendar widget (the same panel quickshell:board opens).
    function calendar() { ModuleService.requestPanel("board") }
    function terminal() { Quickshell.execDetached(["kitty"]) }
    function astrometrics() { ModuleService.requestPanel("stats") }

    // Quick settings: the island's control centre (the same panel
    // quickshell:controls opens).
    function quicksettings() { ModuleService.requestPanel("controls") }

    // ── THE LEFT RESERVE ────────────────────────────────────────────────────
    //
    // BarReserve's twin for the left edge: a strip that paints nothing and
    // takes no input, whose only job is the exclusive zone. Tiled windows
    // start at x=62 and may run flush into the bottom and right corners.

    PanelWindow {
        screen: root.screen

        anchors { top: true; left: true; bottom: true }
        implicitWidth: 62
        color: "transparent"
        exclusiveZone: 62

        WlrLayershell.layer: WlrLayer.Background
        mask: Region {}
    }

    // ── CORNER ARCH: THE ASTROMETRICS GAUGE ─────────────────────────────────
    //
    // The top-left elbow is the arch; two black rails sweep along it —
    // CPU on the inner rail, RAM on the outer — and the whole corner is
    // the astrometrics button (the stats panel).

    PanelWindow {
        id: corner

        screen: root.screen
        anchors { top: true; left: true }
        margins { top: 0; left: 0 }
        implicitWidth: 136
        implicitHeight: 136

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "impasto-lcars"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Canvas {
            id: gauge

            anchors.fill: parent

            property real cpuA: StatsService.cpu
            property real ramA: StatsService.memoryFraction * 100

            Behavior on cpuA {
                NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
            }
            Behavior on ramA {
                NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
            }

            onCpuAChanged: requestPaint()
            onRamAChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#000000"
                ctx.lineWidth = 14
                ctx.lineCap = "butt"

                // The elbow's centre in this window's logical pixels; the
                // arch's annulus runs radius 63..125, so rails at 78 and
                // 110 (±7 of stroke) sit fully inside the orange.
                const cx = 125, cy = 125
                const rail = (r, v) => {
                    ctx.beginPath()
                    const end = Math.PI
                        + (Math.PI / 2) * Math.min(100, Math.max(0, v)) / 100
                    ctx.arc(cx, cy, r, Math.PI, end, false)
                    ctx.stroke()
                }
                rail(78, gauge.cpuA)
                rail(110, gauge.ramA)
            }

            Component.onCompleted: requestPaint()
        }

        Rectangle {
            anchors.fill: parent
            color: pad.containsMouse ? "#33ffffff" : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        MouseArea {
            id: pad
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.astrometrics()
        }
    }

    // ── BANDS ───────────────────────────────────────────────────────────────
    //
    // One small layer surface per button: the input region is the window,
    // so clicks everywhere else fall through untouched. The top and left
    // sit inside areas the reserve strips keep window-free; the bottom one
    // deliberately sits behind windows too — that strip is not reserved.

    component TopBand: PanelWindow {
        id: band
        required property real atX
        required property real bandW
        required property var activate

        screen: root.screen

        anchors { top: true; left: true }
        margins { top: 0; left: atX }
        implicitWidth: bandW
        implicitHeight: 62

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "impasto-lcars"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: pad.containsMouse ? "#2e000000" : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        MouseArea {
            id: pad
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: band.activate()
        }
    }

    component SideBand: PanelWindow {
        id: band
        required property real atY
        required property real bandH
        required property var activate

        screen: root.screen

        anchors { top: true; left: true }
        margins { top: atY; left: 0 }
        implicitWidth: 62
        implicitHeight: bandH

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "impasto-lcars"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: pad.containsMouse ? "#2e000000" : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        MouseArea {
            id: pad
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: band.activate()
        }
    }

    component BottomBand: PanelWindow {
        id: band
        required property real atX
        required property real bandW
        required property var activate

        screen: root.screen

        anchors { bottom: true; left: true }
        margins { bottom: 0; left: atX }
        implicitWidth: bandW
        implicitHeight: 62

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "impasto-lcars"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: pad.containsMouse ? "#2e000000" : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        MouseArea {
            id: pad
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: band.activate()
        }
    }

    // Wallpaper geometry / 2 — see lcars_wallpaper.py for the source.

    // top: CAPTAIN'S LOG (steel, x 138..) — opens the calendar widget.
    TopBand { atX: 138; bandW: 462; activate: root.calendar }

    // left: STARFLEET COMMAND (peach, y 713..1138) — opens a terminal.
    SideBand { atY: 713; bandH: 425; activate: root.terminal }

    // bottom: USS VOYAGER (blue, x 0..560, y 1138..1200) — quick settings,
    // deliberately behind windows as well (nothing reserves the bottom).
    BottomBand { atX: 0; bandW: 560; activate: root.quicksettings }
}
