# vimessage

Vim-style hotkeys for macOS Messages.app via [Hammerspoon](https://www.hammerspoon.org/).

> **Unstable.** Tested on macOS Sequoia 15.7.4 only. Messages has entirely undocumented internals, so this was hacked together. Feel free to ship a PR for another version. 

https://github.com/user-attachments/assets/c2a91963-d8f3-4250-a4ae-f655e5108828

## Shortcuts

Default modifier: `ctrl`

| Key | Action |
|-----|--------|
| `j` / `k` | Next / previous conversation (arrow-navigates search results when search is open) |
| `f` | Focus search field |
| `i` | Focus compose box |
| `u` / `d` | Scroll messages up / down (hold to accelerate) |
| `t` | Tapback (then 1-6 to react) |
| `r` | Reply to last received |
| `e` | Edit last sent |
| `n` | New message |
| `g` | Conversation details |
| `m` | Toggle read/unread |
| `x` | Delete conversation |
| `w` | Close panel / hide app |
| `space` | Open in separate window |

## Install

Requires [Hammerspoon](https://www.hammerspoon.org/) with Accessibility permissions (System Settings > Privacy & Security > Accessibility). Do that. You can do that programatically via nix if you have SIP disabled; otherwise, just gotta do it yourself. 

### Nix (home-manager)

Add to your flake inputs:

```nix
vimessage.url = "github:charliemeyer2000/vimessage";
```

Import the module and enable:

```nix
# In your home-manager config
programs.vimessage = {
  enable = true;
  mod = "ctrl";
  keys = {
    tapback = false;            # disable a key
    info = { mod = "alt"; key = "i"; };  # per-key modifier
  };
};
```

### Manual

```
git clone https://github.com/charliemeyer2000/vimessage.git ~/.hammerspoon
```

Or add to an existing Hammerspoon config:

```lua
package.path = package.path .. ";/path/to/vimessage/?.lua"
require("messages_vim").setup({})
```

## Configuration (Lua)

```lua
require("messages_vim").setup({
    mod = "alt",                              -- change modifier
    keys = {
        focus_search = "s",                   -- override a key
        tapback      = false,                 -- disable a key
        info = { mod = "alt", key = "i" },    -- per-key modifier
    },
    scroll = {
        max_speed = 80,                       -- max px/frame at 60fps
        accel     = 5,                        -- px/frame² acceleration while held
        friction  = 0.88,                     -- velocity multiplier per frame on release (0-1)
        initial   = 4,                        -- starting velocity on first press
    },
})
```

`u`/`d` use a velocity-based scroll engine at 60fps. Holding the key accelerates up to `max_speed`, releasing applies `friction` per frame until stopped. Increase `accel` and `max_speed` for faster scrolling, lower `friction` for quicker deceleration.

## Not Controlled

There are various features we don't control since they're already well(ish) designed 

## Contributing

Test on your macOS version and open a PR if something breaks. The AX element IDs and built-in shortcuts in `messages_vim.lua` are the most likely things to change between versions.

## Requirements

- Hammerspoon with Accessibility permissions enabled (Kind of annoying to enable, so just make sure it's actually enabled. Start and restart hammerspoon too just in case)
