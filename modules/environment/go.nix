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
        go-outline
        goreleaser
      ];
      custom.bump.go = {
        pathspecs = [
          "go.mod"
          "go.sum"
        ];
        text = ''
          ${go} get -u -t ./...
          ${go} mod tidy
        '';
      };
    };
}
