// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A L E T T E S                                                        │
// │   curated colour schemes · single source of truth                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick

// Curated palettes. This is the only place a palette is described: the
// customizer reads its label and swatches from here, and ThemeService reads
// the tokens from the same entry, so the two can never disagree.
QtObject {
    id: root

    // The rice ships one theme: LCARS Voyager. The stock palettes were
    // stripped from the selector, so this list is everything a chooser can
    // show and everything `byId` can find.
    readonly property var list: [
        {
            id: "lcars_voyager",
            name: "LCARS Voyager",
            badge: "Starfleet",
            swatches: ["#ff9c00", "#ffcc66", "#9999ff", "#cc99cc"],
            colors: {
                background: "#000000", surface: "#0a0a12", surfaceHover: "#161624",
                border: "#6681cc", text: "#ffe0b3", textMuted: "#9999cc",
                accent: "#ff9c00", accentHover: "#ffcc66", accentText: "#000000",
                red: "#ff5555", green: "#33cc55", yellow: "#ffcc00", blue: "#6699ff"
            }
        },
    ]

    function byId(paletteId: string): var {
        return root.list.find(palette => palette.id === paletteId) ?? null
    }
}
