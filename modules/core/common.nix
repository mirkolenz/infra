# Shared nixos + darwin base: timezone, default shells, 1password/opnix.
let
  shared =
    { lib, pkgs, ... }:
    {
      time.timeZone = "Europe/Berlin";
      environment = {
        defaultPackages = lib.mkForce [ ];
        systemPackages = [ pkgs.opnix ];
      };
      programs = {
        _1password.enable = true;
        bash.enable = true;
        fish.enable = true;
        zsh.enable = true;
      };
    };
in
{
  flake.modules.nixos.base = shared;
  flake.modules.darwin.base = shared;
}
