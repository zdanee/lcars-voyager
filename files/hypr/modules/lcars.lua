-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   L C A R S   C O N S O L E                                              │
-- │   keyboard and touchpad extras for the Voyager desk                      │
-- │                                                                          │
-- │   Kept out of impasto's own keybinds.lua so the LCARS pass is one file:  │
-- │   hyprland.lua requires this after every stock module.                    │
-- ╰──────────────────────────────────────────────────────────────────────────╯

local programs = require("modules.programs")


-- ── KEYS ─────────────────────────────────────────────────────────────────────

-- Plain `hl.bind`, not the profile-key helper: these are this desk's keys,
-- not a profile's rebindable set. descriptions still show in the key sheet.
hl.bind("ALT + Space", hl.dsp.global("quickshell:launcher"),
        { description = "LCARS · Open the launcher from Alt+Space" })

hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(programs.terminal),
        { description = "LCARS · Open a terminal from Ctrl+Alt+T" })

-- The dedicated calculator key: the shell has no calculator panel, so it
-- opens the launcher on its calculate mode (the "=" sigil).
hl.bind("XF86Calculator", hl.dsp.global("quickshell:calculator"),
        { locked = true, description = "LCARS · Calculator" })


-- ── TOUCHPAD ─────────────────────────────────────────────────────────────────
--
-- input.lua already binds three fingers horizontal to the workspaces; these
-- add the four-finger swipe, and the swipe-up that opens the app overview.
-- `action` may be a plain function — the wiki's own examples use one.

hl.gesture({
    fingers   = 4,
    direction = "horizontal",
    action    = "workspace",
})

local overview = function()
    hl.dispatch(hl.dsp.global("quickshell:overview"))
end

hl.gesture({ fingers = 3, direction = "up", action = overview })
hl.gesture({ fingers = 4, direction = "up", action = overview })
