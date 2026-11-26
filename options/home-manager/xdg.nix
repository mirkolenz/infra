# https://github.com/nix-community/home-manager/blob/master/modules/misc/xdg.nix
# https://specifications.freedesktop.org/basedir/latest/
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  cfg = config.xdg;

  # Checked out repositories, grouped by owner, in the Developer directory on darwin
  # and in XDG_PROJECTS_DIR, added in xdg-user-dirs 0.20, everywhere else.
  projects = if pkgs.stdenv.hostPlatform.isDarwin then "Developer" else "Projects";

  fileType =
    (import "${modulesPath}/lib/file-type.nix" {
      inherit (config.home) homeDirectory;
      inherit lib pkgs;
    }).fileType;
in
{
  options.custom.privateProjects = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Private";
    defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Private"'';
    description = ''
      Confidential checked out repositories, grouped by owner like those of `xdg.userDirs.projects`,
      which agents reach only when started in one or granted it explicitly.
      Named after the private visibility of GitHub and GitLab.
    '';
  };

  options.xdg = {
    binFile = lib.mkOption {
      type = fileType "xdg.binFile" "{var}`xdg.binHome`" cfg.binHome;
      default = { };
      description = ''
        Attribute set of files to link into the user's XDG bin home.
      '';
    };
  };

  config = lib.mkMerge [
    {
      xdg.userDirs.projects = lib.mkDefault "${config.home.homeDirectory}/${projects}";
      home.sessionVariables.XDG_PROJECTS_DIR = cfg.userDirs.projects;
      # mode 700, so other users cannot read the confidential projects
      home.activation.private-projects = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run install -d -m 700 $VERBOSE_ARG ${lib.escapeShellArg config.custom.privateProjects}
      '';
    }

    (lib.mkIf cfg.enable {
      home.file = lib.mapAttrs' (name: file: lib.nameValuePair "${cfg.binHome}/${name}" file) cfg.binFile;
    })
  ];
}
