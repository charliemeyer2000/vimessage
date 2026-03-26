{
  description = "vimessage — vim-style hotkeys for macOS Messages.app via Hammerspoon";

  outputs = {self, ...}: {
    homeManagerModules.default = import ./nix/hm-module.nix self;
  };
}
