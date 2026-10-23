{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      programs._1password-gui.enable = true;
    };

  flake.modules.nixos.default =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      programs._1password-gui.polkitPolicyOwners = [ config.custom.user.login ];
      # The SSH config points every host at the 1Password agent, so this one would idle.
      services.gnome.gcr-ssh-agent.enable = false;
    };

  # The SSH agent and git signing rely on the 1Password app installed by the
  # host (programs._1password-gui on NixOS, homebrew on Darwin). Standalone
  # home-manager has no host config, so skip the integration.
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }@args:
    lib.mkIf (config.custom.features.graphical.enable && !config.custom.standalone) {
      # The SSH agent only runs while the app does, and the "Start at login" setting
      # of the app does not create its autostart entry on Linux.
      systemd.user.services."1password" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "1Password";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe args.osConfig.programs._1password-gui.package} --silent";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

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
