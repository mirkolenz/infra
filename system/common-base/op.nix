{ pkgs, ... }:
{
  programs = {
    _1password.enable = true;
  };

  environment.systemPackages = with pkgs; [
    opnix
  ];
}
