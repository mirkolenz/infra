{
  self,
  inputs,
  lib',
  ...
}:
{
  flake = {
    # available during import
    specialModuleArgs = {
      inherit self inputs lib';
    };

    # can be overridden in module
    moduleArgs = {
      stateVersions = {
        linux = "26.05";
        darwin = 7;
        home = "26.05";
      };
      user = {
        name = "Mirko Lenz";
        mail = "mirko@mirkolenz.com";
        login = "mlenz";
        # https://github.com/mirkolenz.keys
        sshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFT0P6ZLB5QOtEdpPHCF0frL3WJEQQGEpMf2r010gYH3 mlenz@macbook"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPg/jZmSr0LiCm5FKAcF54UJXK8GNgDO4op0MiASNadb mlenz@iphone"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTD8HTidTJM3RLmU+WW7tBlDz6L2x8zoHJhqzA6m3+B mlenz@1password"
        ];
      };
    };
  };
}
