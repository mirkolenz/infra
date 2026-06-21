# Editor policy: nvim is the terminal EDITOR everywhere; zed/zeditor is the GUI
# VISUAL editor where a display is available. Set explicitly instead of relying
# on programs.*.defaultEditor, for full control.
#   - nvim is available system-wide via programs.neovim on NixOS, via the neovim
#     package on darwin, and in every home via nixvim.
#   - zed is the GUI editor: the homebrew `zed` CLI on darwin, the nixpkgs
#     `zeditor` binary on Linux desktops.
let
  systemEditor = {
    environment.variables.EDITOR = "nvim";
  };
in
{
  flake.modules.nixos.base = systemEditor;
  flake.modules.nixos.installer = systemEditor;

  # nix-darwin has no system neovim, so install it to back EDITOR=nvim for root.
  flake.modules.darwin.default =
    { pkgs, ... }:
    {
      imports = [ systemEditor ];
      environment.systemPackages = [ pkgs.neovim ];
    };

  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      ...
    }:
    {
      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL =
          if pkgs.stdenv.isDarwin then
            "zed --wait"
          else if config.programs.zed-editor.enable then
            "zeditor --wait"
          else
            "nvim";
      };
    };
}
