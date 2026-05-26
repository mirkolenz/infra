{
  lib',
  pkgs,
  stateVersions,
  ...
}:
{
  imports = lib'.flocken.getModules ./.;

  environment.systemPackages = with pkgs; [
    libvirt
    virt-viewer
    virt-manager
    less
    perl
    python3
    rsync
    ghostty-bin.terminfo
  ];

  environment.variables = {
    EDITOR = "zed";
    VISUAL = "zed";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  system.stateVersion = stateVersions.darwin;
}
