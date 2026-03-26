require("messages_vim").setup({
    -- Modifier key: "ctrl" | "cmd" | "alt"
    mod = "ctrl",

    -- Override any key, or set to false to disable.
    -- Per-key modifier: { mod = "alt", key = "f" }
    --
    -- keys = {
    --     -- Navigation
    --     conv_down      = "j",       -- next conversation        (Cmd+Shift+])
    --     conv_up        = "k",       -- previous conversation    (Cmd+Shift+[)
    --     focus_search   = "f",       -- focus search field       (AX click)
    --     focus_input    = "i",       -- focus compose box        (AX click)
    --     scroll_up      = "u",       -- scroll messages up       (hold to accelerate)
    --     scroll_down    = "d",       -- scroll messages down     (hold to accelerate)
    --
    --     -- Message actions
    --     tapback        = "t",       -- tapback picker           (Cmd+T, then 1-6)
    --     reply          = "r",       -- reply to last received   (Cmd+R)
    --     edit           = "e",       -- edit last sent           (Cmd+E)
    --
    --     -- Conversation management
    --     info           = "g",       -- conversation details     (Opt+Cmd+I)
    --     mark_read      = "m",       -- toggle read/unread       (Shift+Cmd+U)
    --     delete_conv    = "x",       -- delete conversation      (Cmd+Delete)
    --
    --     -- Window
    --     close          = "w",       -- close panel / hide app
    --     open_in_panel  = "space",   -- open in separate window  (double-click)
    -- },
})
