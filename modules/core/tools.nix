# Shared system CLI tools installed on both NixOS and nix-darwin.
let
  system =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        perl
        python3
        rsync
      ];
    };
in
{
  flake.modules.nixos.default = system;
  flake.modules.darwin.default = system;
}
