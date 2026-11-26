{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }@args:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
      inherit (config.programs.agents) sandbox;
      inherit (sandbox) workspace;

      harnesses = lib.attrValues config.programs.agents.harnesses;
      fromHarnesses = path: lib.concatMap (lib.getAttrFromPath path) harnesses;
      harnessDomains = lib.unique (fromHarnesses [ "domains" ]);

      # the installation of a launcher, `default` for the regular one
      installationOf = package: package.installation or "default";
      installations = lib.unique (
        lib.concatMap (harness: map installationOf (lib.attrValues harness.launchers)) harnesses
      );

      # the absolute paths of every harness for `installation`
      harnessPaths =
        installation: access:
        lib.concatMap (harness: harness.paths.${installation}.${access} or [ ]) harnesses;

      # and those of the sandbox along with them, by installation
      installationPaths = lib.genAttrs installations (installation: rec {
        read = sandbox.paths.read ++ harnessPaths installation "read";
        write = sandbox.paths.write ++ harnessPaths installation "write";
        # nono cannot make a path read-only within a writable one, a grant takes the access of every covering one.
        readOnly = within write read;
      });
      nono = config.programs.nono.finalPackage;
      osConfig = args.osConfig or { };

      # Seatbelt filters. Seatbelt misses anchored alternatives within one regex,
      # so every rule combines plain filters instead, each regex holding at most one anchor.
      subpath = path: "(subpath ${lib.toJSON path})";
      regex = pattern: ''(regex #"${pattern}")'';

      # Denies `operations` on the paths matching `filter`, except for those matching any of `exceptions`.
      deny =
        operations: filter: exceptions:
        "(deny ${operations} (require-all ${filter}${
          lib.concatMapStrings (exception: " (require-not ${exception})") exceptions
        }))";

      # Throwaway clones and caches, where a fresh repository needs its git config.
      # Seatbelt sees canonical paths, `/tmp` and the temporary directory of the host resolve below `/private`.
      scratch = map subpath [
        "/private/tmp"
        "/private/var/folders"
        config.xdg.cacheHome
        "${config.home.homeDirectory}/Library/Caches"
      ];

      # A workspace key as a regex, `**/` matching any directories and `*` within a path segment.
      keyRegex =
        key:
        lib.concatMapStringsSep "(.*/)?" (
          part: lib.concatMapStringsSep "[^/]*" lib.escapeRegex (lib.splitString "*" part)
        ) (lib.splitString "**/" key);

      # A path at or below a match of `key`, at any depth or directly within `root`.
      keyFilter = key: regex "/${keyRegex key}(/|$)";
      rootedKeyFilter = root: key: regex "^${lib.escapeRegex root}/${keyRegex key}(/|$)";

      # The ones of `paths` below any of `roots`.
      within = roots: lib.filter (path: lib.any (root: lib.hasPrefix "${root}/" path) roots);

      # The `write` workspace keys equal to or below the matches of `key`.
      exemptions =
        key: lib.filter (write: lib.match "${keyRegex key}(/.*)?" write != null) workspace.write;

      # Workspace keys apply at any depth, so repositories added later are covered as well.
      # The home directory holds the state of the agents.
      workspaceRule =
        operations: key:
        deny operations (keyFilter key) (
          scratch ++ [ (rootedKeyFilter config.home.homeDirectory key) ] ++ map keyFilter (exemptions key)
        );

      # Platform rules come last in the nono policy, so these denies win over its grants.
      # Metadata stays readable, so listing a directory or `git status` keeps working.
      seatbeltRules =
        map (workspaceRule "file-write*") workspace.read
        ++ map (workspaceRule "file-read-data file-write* process-exec* file-map-executable") workspace.deny
        ++ [
          # Keeps the `.git` of every repository in place, a rename covers the source as well.
          (deny "file-write-unlink" (regex ''/\.git$'') scratch)
        ];
      readOnlyRules =
        paths:
        map (
          path: deny "file-write*" (subpath path) (map subpath (within [ path ] paths.write))
        ) paths.readOnly;

      # agents may write drafts, which only `nono profile promote` outside of nono applies
      profiles = "${config.xdg.configHome}/nono/profiles";
      drafts = "${config.xdg.configHome}/nono/profile-drafts";

      # The absolute targets of the enabled `files` matching `pred`, below `root`.
      targets =
        root: pred: files:
        map (file: "${root}/${file.target}") (
          lib.filter (file: file.enable && pred file) (lib.attrValues files)
        );

      # The files home-manager links into the store, so tools find their config, ripgrep among them,
      # except for those within a denied directory, such as `.ssh/rc`.
      # nono grants every hop of a symlink, so an out-of-store link grants its target as well.
      # A recursive directory holds unmanaged files too.
      homeFiles = targets config.home.homeDirectory (file: !file.recursive) config.home.file;
      managedFiles = lib.subtractLists (within sandbox.paths.deny homeFiles) homeFiles;

      # The copied files of the system config, none for a standalone home, which nono on Linux
      # keeps unreadable apart from a few. Symlinked ones resolve into the readable store,
      # and macOS reads all of `/etc` anyway.
      etcFiles =
        targets "/etc" (file: file.mode or "symlink" != "symlink") (osConfig.environment.etc or { })
        # determinate-nixd writes it itself, outside of `environment.etc`
        ++ lib.optional (osConfig.determinate.enable or osConfig.determinateNix.enable or false
        ) "/etc/nix/nix.conf";

      # The bubblewrap sandbox around nono on Linux, see `infra_apps.bwrap`.
      bwrap = paths: {
        inherit workspace;
        read = paths.readOnly;
        write = within paths.readOnly paths.write;
        bwrap = lib.getExe pkgs.bubblewrap;
        projects = lib.optionals sandbox.projects.enable sandbox.projects.dirs;
        git = lib.getExe pkgs.gitMinimal;
        fd = lib.getExe pkgs.fd;
        # the global gitignore, out of reach of the agents unlike the ignore files of the projects
        ignore = pkgs.writeText "agents-ignore" (lib.concatLines config.programs.git.ignores);
      };

      # The nono profile of the agents, extended by one per installation, which the session profile
      # of a launcher extends in turn.
      profile = "agents";
      installationProfile = installation: "${profile}-${installation}";

      # The paths of an installation on top of the base profile, so the launchers of one installation
      # never reach those of another one. The managed files and the keychain of the base profile
      # stay readable to every installation.
      installationProfiles = lib.genAttrs' installations (
        installation:
        lib.nameValuePair (installationProfile installation) {
          extends = profile;
          filesystem = {
            allow = harnessPaths installation "write";
            read = harnessPaths installation "read";
            allow_file = harnessPaths installation "files";
          };
          unsafe_macos_seatbelt_rules = lib.mkIf isDarwin (readOnlyRules installationPaths.${installation});
        }
      );

      # Runs the harness within nono, or directly when inside it already,
      # winning `bin/<name>` over the harness.
      # Executables go in as absolute paths, since `PATH` reaches the harness.
      wrapperPackage =
        harness: name: package:
        let
          installation = installationOf package;
          paths = installationPaths.${installation};
          launchConfig = {
            harness = lib.getExe package;
            nono = lib.getExe nono;
            bwrap = if isLinux then bwrap paths else null;
            profile = installationProfile installation;
            herdr_agent = harness.herdrAgent;
            sandbox_args = harness.sandboxArgs;
            trailing_args = harness.trailingSandboxArgs;
            add_dir_flag = harness.addDirFlag;
            env_files = sandbox.environment.files;
            env_templates = sandbox.environment.templates;
            granted = paths.read ++ paths.write;
          };
        in
        # named after the harness, so the OS and herdr show its name for the process
        lib.hiPrio ((pkgs.nono-launch.withName name).withConfig launchConfig);
    in
    lib.mkIf config.programs.agents.enable {
      programs.nono = {
        enable = true;
        environment.NONO_PROFILE = installationProfile "default";
        profiles = installationProfiles // {
          ${profile} = {
            extends = "default";
            # No groups beyond those of `default`, `programs.agents.sandbox.paths` grants the git config,
            # nix and the toolchain caches instead, so the native sandboxes of the harnesses get them too.
            workdir.access = "readwrite";
            filesystem = {
              allow = sandbox.paths.write ++ [
                # the main repository of a linked worktree, which commits write to
                "@git:common-dir"
                drafts
              ];
              # managed files may be granted already, such as the git config
              read = lib.unique (
                sandbox.paths.read
                ++ managedFiles
                ++ etcFiles
                ++ [
                  # the base of a draft
                  profiles
                ]
              );
              # Exempts the generated files, such as `.npmrc` or the shell configs, from the deny groups of nono,
              # their content sits in the readable store anyway.
              bypass_protection = managedFiles;
              unix_socket = sandbox.unixSockets;
              unix_socket_dir = fromHarnesses [ "unixSocketDirs" ];
              # On Linux nono refuses to start with a deny within a granted directory,
              # so denied paths stay outside of every grant.
              deny = sandbox.paths.deny;
            };
            network = {
              allow_domain = lib.unique (sandbox.domains.allow ++ harnessDomains);
              deny_domain = sandbox.domains.deny;
              # Every localhost port of the host, such as the ssh tunnels to remote models.
              # Port 0 is the wildcard on macOS, where binding is unfiltered anyway.
              open_port = lib.mkIf (isDarwin && sandbox.localhost) [ 0 ];
              # seccomp keeps the range on loopback, but binding to port 0 stays denied
              open_port_range = lib.mkIf (isLinux && sandbox.localhost) [
                [
                  1
                  65535
                ]
              ];
            };
            # Opened in the browser of the host by nono after checking the origin, for logins and dev servers.
            # Unlike `allow_launch_services`, this cannot open files or apps.
            open_urls = {
              allow_origins = map (domain: "https://${domain}") harnessDomains;
              allow_localhost = sandbox.localhost;
            };
            environment = {
              # A missing source must never expose the inherited value.
              deny_vars = lib.unique (
                sandbox.environment.unset
                ++ lib.attrNames sandbox.environment.files
                ++ lib.attrNames sandbox.environment.templates
              );
              set_vars = sandbox.environment.set;
            };
            unsafe_macos_seatbelt_rules = lib.mkIf isDarwin seatbeltRules;
            linux = {
              # makes `unix_socket` an allowlist on Linux as well, refusing every abstract socket
              af_unix_mediation = "pathname";
              # Namespaces apart from the host. A network one would only leave through the proxy,
              # with a loopback of its own that cannot reach the host, so it is left out for localhost.
              isolate = {
                network = !sandbox.localhost;
                ipc = true;
                uts = true;
              };
            };
          };
        };
      };

      home.activation.nono-profile-drafts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg drafts}
      '';

      home.packages = lib.concatMap (
        harness: lib.mapAttrsToList (wrapperPackage harness) harness.launchers
      ) harnesses;
    };
}
