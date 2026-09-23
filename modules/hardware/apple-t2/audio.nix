# Speaker and microphone support for the t2bce audio driver: KaiT2en supplies
# both the use case profiles and the DSP graphs the internal speakers need.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      ucm2Dir = "${pkgs.kait2en.ucm}/share/alsa/ucm2";
      # Systemd services do not inherit `environment.variables`.
      # https://github.com/nix-community/nixos-apple-silicon/blob/66d8dd2c27f99bd5420c99938b60695aac1785c4/apple-silicon-support/modules/sound/default.nix#L46
      audioServices = lib.genAttrs [ "pipewire" "pipewire-pulse" "wireplumber" ] (_: {
        environment.ALSA_CONFIG_UCM2 = ucm2Dir;
      });
    in
    lib.mkMerge [
      {
        # nix build .#.packages.x86_64-linux.kait2en-ucm
        # nix build .#.packages.x86_64-linux.kait2en-dsp
        environment.variables.ALSA_CONFIG_UCM2 = ucm2Dir;

        # Renames the ALSA card after the DMI model, which is how the graphs
        # below find their machine.
        services.udev.packages = [ pkgs.kait2en.dsp ];
      }

      (lib.mkIf config.services.pipewire.enable {
        systemd = {
          services = audioServices;
          user.services = audioServices;
        };

        # The quantum is a pipewire fragment, the filter definitions a
        # wireplumber one.
        services.pipewire = {
          configPackages = [ pkgs.kait2en.dsp ];
          wireplumber.configPackages = [ pkgs.kait2en.dsp ];
        };
      })
    ];
}
