# Primary user identity and state version values, shared across nixos/darwin/home.
# The option declarations live in options/shared/identity.nix.
{ lib, ... }:
let
  identity.custom = {
    user = {
      name = "Mirko Lenz";
      mail = "mirko@mirkolenz.com";
      # mkDefault so per-configuration logins (standalone home, children) win
      login = lib.mkDefault "mlenz";
      # https://github.com/mirkolenz.keys
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFT0P6ZLB5QOtEdpPHCF0frL3WJEQQGEpMf2r010gYH3 mlenz@macbook"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPg/jZmSr0LiCm5FKAcF54UJXK8GNgDO4op0MiASNadb mlenz@iphone"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTD8HTidTJM3RLmU+WW7tBlDz6L2x8zoHJhqzA6m3+B mlenz@1password"
      ];
    };
    stateVersions = {
      linux = "26.05";
      darwin = 7;
      home = "26.05";
    };
  };
in
{
  flake.modules.nixos.base = identity;
  flake.modules.nixos.installer = identity;
  flake.modules.darwin.base = identity;
  flake.modules.homeManager.default = identity;
}
