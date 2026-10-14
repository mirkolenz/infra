{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      go = lib.getExe config.programs.go.package;
    in
    lib.mkIf config.custom.features.extras.enable {
      programs.go.enable = true;
      home.packages = with pkgs; [
        gopls
        delve
        goreleaser
      ];
      custom.bump.go = {
        # modules without dependencies have no go.sum, but nothing to update either
        lockfile = "go.sum";
        pathspecs = [ "go.mod" ];
        text = ''
          ${go} get -u -t ./...
          ${go} mod tidy
        '';
      };
    };
}
