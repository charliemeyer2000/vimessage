# vimessage

Vim-style hotkeys for macOS Messages.app via [Hammerspoon](https://www.hammerspoon.org/). No UI, no modes — just modifier+key when Messages is focused.

> **Unstable.** Tested on macOS Sequoia 15.7.4 only. Messages is a Catalyst app with undocumented AX internals that may change between versions. PRs welcome if something breaks on yours.

## Shortcuts

Default modifier: `ctrl`

| Key | Action |
|-----|--------|
| `j` / `k` | Next / previous conversation |
| `f` | Focus search field |
| `i` | Focus compose box |
| `u` / `d` | Scroll messages up / down (hold to accelerate) |
| `t` | Tapback (then 1-6 to react) |
| `r` | Reply to last received |
| `e` | Edit last sent |
| `g` | Conversation details |
| `m` | Toggle read/unread |
| `x` | Delete conversation |
| `w` | Close panel / hide app |
| `space` | Open in separate window |

## Install

Requires [Hammerspoon](https://www.hammerspoon.org/) with Accessibility permissions (System Settings > Privacy & Security > Accessibility).

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
})
```

## Contributing

Test on your macOS version and open a PR if something breaks. The AX element IDs and built-in shortcuts in `messages_vim.lua` are the most likely things to change between versions.

## Requirements

- macOS Sequoia (15.7.4 tested)
- Hammerspoon with Accessibility permissions
