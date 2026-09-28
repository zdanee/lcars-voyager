-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   T I T L E B A R S                                                      │
-- │   hyprbars · a traditional titlebar over every window, in LCARS          │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- hyprbars, the official titlebar plugin (hyprwm/hyprland-plugins, via
-- `hyprpm add` / `hyprpm enable hyprbars`): a bar across the top of every
-- window with the title and the buttons, like a classic WM's frame.
--
-- Style B — the strip's own pill, on every window: a black bar (the band's
-- black), the title in orange at the left, orange chips with black glyphs
-- at the right, close last so it sits at the far right end (Breeze and
-- Windows both end in close). The 4 px Okuda border wraps the bar too.
--
-- The guard skips the block on the first parse, before hyprpm loads the
-- plugin, and it applies on the second — the same dance as hyprglass in
-- look.lua and dynamic_cursors in input.lua.

if hl.plugin.hyprbars ~= nil then
    hl.config({
        plugin = {
            hyprbars = {
                enabled    = true,
                bar_height = 30,                 -- the pill's own height

                bar_color      = "rgb(000000)",  -- Theme.island
                ["col.text"]   = "rgb(ff9c00)",  -- the accent, like the pill
                inactive_button_color = "rgb(382200)",  -- a dimmed chip

                -- Title at the left with the buttons at the right, so the
                -- bar reads like the pill: name first, keys at the end.
                bar_title_enabled     = true,
                bar_text_font         = "Antonio",
                bar_text_size         = 15,
                bar_text_align        = "left",
                bar_buttons_alignment = "right",

                bar_padding        = 12,
                bar_button_padding = 6,

                -- The bar is the window's own top: the rounded frame runs
                -- around it and the border wraps it, one shape.
                bar_part_of_window         = true,
                bar_precedence_over_border = true,

                -- Double-click the bar maximizes, as on a titlebar.
                on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
            },
        },
    })

    -- Buttons are registered right to left, so close is added first and
    -- ends up at the far right; maximise goes beside it. The glyph on an
    -- orange chip, black on orange — the pill's own keys.
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(ff9c00)",
        fg_color = "rgb(000000)",
        size     = 17,
        icon     = "✕",
        action   = [[hyprctl dispatch 'hl.dsp.window.close()']],
    })

    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(ff9c00)",
        fg_color = "rgb(000000)",
        size     = 17,
        icon     = "■",
        action   = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
    })
end
