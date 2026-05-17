{
  user,
  lib,
  pkgs,
  ...
}:
{
  users.users = {
    mirko = {
      description = "Mirko Lenz";
      uid = lib.mkDefault 1000;
      isNormalUser = true;
      openssh.authorizedKeys.keys = user.sshKeys;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };
    mila = {
      description = "Mila Lenz";
      uid = lib.mkDefault 1001;
      isNormalUser = true;
    };
    levi = {
      description = "Levi Lenz";
      uid = lib.mkDefault 1002;
      isNormalUser = true;
    };
  };

  # Hide /nix/store directory listing from child accounts.
  # Removes read (list) but keeps execute (traverse), so programs still work.
  system.activationScripts.nixStoreAcl.text = ''
    ${pkgs.acl}/bin/setfacl -m u:mila:--x -m u:levi:--x /nix/store
  '';
}
