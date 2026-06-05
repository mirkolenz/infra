{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      mkNodeApp =
        name: values:
        pkgs.writeShellApplication {
          inherit name;
          text = ''
            exec ${lib.getExe' pkgs.nodejs "npx"} \
              ${toString (map (v: "--package ${v}") values)} \
              ${name} "$@"
          '';
        };
      mkPythonApp =
        name: values:
        pkgs.writeShellApplication {
          inherit name;
          text = ''
            exec ${lib.getExe' config.programs.uv.package "uvx"} \
              --python ${lib.getExe pkgs.python3} \
              ${toString (map (v: "--from ${v}") values)} \
              ${name} "$@"
          '';
        };
    in
    lib.mkIf config.custom.features.withOptionals {
      home.packages =
        (lib.mapAttrsToList mkNodeApp {
          gemini = [ "@google/gemini-cli" ];
          icloud-photos-sync = [ "icloud-photos-sync" ];
          mcp-inspector = [ "@modelcontextprotocol/inspector" ];
          shadcn = [ "shadcn" ];
          ccusage = [ "ccusage" ];
        })
        ++ (lib.mapAttrsToList mkPythonApp {
          arguebuf = [ "arguebuf[cli]" ];
          ast-grep-server = [ "git+https://github.com/ast-grep/ast-grep-mcp" ];
        });
    };
}
