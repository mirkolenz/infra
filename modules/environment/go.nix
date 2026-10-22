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
        delve
        goreleaser
      ];
      custom.bump.go = {
        lockfile = "go.mod";
        # the directories that go ignores when matching packages
        excludes = [
          "**/testdata/**"
          "**/vendor/**"
          "**/_*/**"
          "**/.*/**"
        ];
        pathspecs = [
          "go.sum"
          "vendor"
        ];
        # updates each module on its own, since a workspace would record its checksums in go.work.sum
        env.GOWORK = "off";
        commands = [
          [
            go
            "get"
            "-u"
            "-t"
            "./..."
          ]
          [
            go
            "mod"
            "tidy"
          ]
          {
            args = [
              go
              "mod"
              "vendor"
            ];
            ifExists = "vendor/modules.txt";
          }
        ];
      };
    };
}
