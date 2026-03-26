flake: {
  config,
  lib,
  ...
}: let
  cfg = config.programs.vimessage;

  keyType = lib.types.either lib.types.str (lib.types.submodule {
    options = {
      mod = lib.mkOption {type = lib.types.str;};
      key = lib.mkOption {type = lib.types.str;};
    };
  });

  toLuaValue = v:
    if v == false
    then "false"
    else if builtins.isString v
    then ''"${v}"''
    else if builtins.isAttrs v
    then ''{ mod = "${v.mod}", key = "${v.key}" }''
    else throw "unsupported key type";

  keysLua = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "    ${k} = ${toLuaValue v},") cfg.keys);

  keysBlock = lib.optionalString (cfg.keys != {}) ''
      keys = {
  ${keysLua}
      },
  '';

  initLua = ''
    package.path = package.path .. ";${flake}/?.lua"
    require("messages_vim").setup({
        mod = "${cfg.mod}",
    ${keysBlock}})
  '';
in {
  options.programs.vimessage = {
    enable = lib.mkEnableOption "vimessage — vim-style hotkeys for Messages.app";

    mod = lib.mkOption {
      type = lib.types.str;
      default = "ctrl";
      description = "Modifier key for all shortcuts.";
    };

    keys = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either (lib.types.enum [false]) keyType);
      default = {};
      description = "Override individual key bindings. Set to false to disable.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra Lua to append to Hammerspoon init.lua.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".hammerspoon/init.lua".text = initLua + cfg.extraConfig;
  };
}
