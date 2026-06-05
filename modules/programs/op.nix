{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      programs._1password-gui.enable = true;
    };

  flake.modules.nixos.default =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      programs._1password-gui.polkitPolicyOwners = [ config.custom.user.login ];

      environment.etc."1password/custom_allowed_browsers" = {
        text = ''
          vivaldi-bin
        '';
        mode = "0755";
      };
    };

  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      programs.op = {
        enable = true;
        sshAgent = {
          enable = true;
          settings = {
            ssh-keys = [
              {
                vault = "Mirko";
                item = "mlenz@1password";
              }
              {
                vault = "Mirko";
                item = "mlenz@git";
              }
            ]
            ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin {
              vault = "Mirko";
              item = "mlenz@macbook";
            };
          };
        };
        gitSign = {
          enable = false;
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdqY/FHF8Q2QGhE84GswFe6r1g4+nCPR+yTGaStVi4Q mlenz@git";
        };
      };
    };
}
