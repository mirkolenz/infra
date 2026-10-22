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

      # the absolute paths of the sandbox and of every harness
      readPaths =
        sandbox.paths.read
        ++ fromHarnesses [
          "paths"
          "read"
        ];
      writePaths =
        sandbox.paths.write
        ++ fromHarnesses [
          "paths"
          "write"
        ];
      nono = config.programs.nono.finalPackage;
      osConfig = args.osConfig or { };

      # Seatbelt filters. Seatbelt misses anchored alternatives within one regex,
      # so every rule combines plain filters instead, each regex holding at most one anchor.
      subpath = path: "(subpath ${lib.toJSON path})";
      regex = pattern: ''(regex #"${pattern}")'';

      # Lists the directory at the JSON-encoded path itself, not the content of what it holds.
      # TODO: the list-only grant of nono once it has one, https://github.com/nolabs-ai/nono/issues/457
      listable = encoded: "(allow file-read-data (literal ${encoded}))";

      # The ancestors of an absolute path, except for `/`, which nono grants in full.
      ancestors = path: lib.optionals (dirOf path != "/") (ancestors (dirOf path) ++ [ (dirOf path) ]);

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

      # nono cannot make a path read-only within a writable one, a grant takes the access of every covering one.
      readOnlyPaths = within writePaths readPaths;

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
      # Without `O_PATH`, Nix and Bun open every ancestor of a path they resolve,
      # `nono-launch` adds those of the working directory and the added ones.
      seatbeltRules =
        map (path: listable (lib.toJSON path)) (
          lib.unique (lib.concatMap ancestors (readPaths ++ writePaths))
        )
        ++ map (workspaceRule "file-write*") workspace.read
        ++ map (workspaceRule "file-read-data file-write*") workspace.deny
        ++ map (
          path: deny "file-write*" (subpath path) (map subpath (within [ path ] writePaths))
        ) readOnlyPaths
        ++ [
          # Keeps the `.git` of every repository in place, a rename covers the source as well.
          (deny "file-write-unlink" (regex ''/\.git$'') scratch)
        ];

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
      bwrap = {
        inherit workspace;
        read = readOnlyPaths;
        write = within readOnlyPaths writePaths;
        bwrap = lib.getExe pkgs.bubblewrap;
        git = lib.getExe pkgs.gitMinimal;
      };

      # the nono profile of the agents, extended by the session profile of the launcher
      profile = "agents";

      # Runs the harness within nono, or directly when inside it already,
      # winning `bin/<name>` over the harness.
      # Executables go in as absolute paths, since `PATH` reaches the harness.
      wrapperPackage =
        harness: name: package:
        let
          launchConfig = {
            harness = lib.getExe package;
            nono = lib.getExe nono;
            bwrap = if isLinux then bwrap else null;
            inherit profile;
            herdr_agent = harness.herdrAgent;
            sandbox_args = harness.sandboxArgs;
            trailing_args = harness.trailingSandboxArgs;
            add_dir_flag = harness.addDirFlag;
            # Lists the ancestors of the working directory and the added ones, see `seatbeltRules`.
            ancestor_rule = if isDarwin then listable "{}" else null;
          };
        in
        # named after the harness, so the OS and herdr show its name for the process
        lib.hiPrio ((pkgs.nono-launch.withName name).withConfig launchConfig);
    in
    lib.mkIf config.programs.agents.enable {
      programs.nono = {
        enable = true;
        environment.NONO_PROFILE = profile;
        profiles.${profile} = {
          extends = "default";
          # No groups beyond those of `default`, `programs.agents.sandbox.paths` grants the git config,
          # nix and the toolchain caches instead, so the native sandboxes of the harnesses get them too.
          workdir.access = "readwrite";
          filesystem = {
            allow = writePaths ++ [
              # the main repository of a linked worktree, which commits write to
              "@git:common-dir"
              drafts
            ];
            # managed files may be granted already, such as the git config
            read = lib.unique (
              readPaths
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
          }
          # Port 0 is a wildcard on localhost for macOS, which caps port ranges.
          # Landlock on Linux needs it separately for binding to an ephemeral port, such as the OAuth callback.
          // lib.optionalAttrs sandbox.localhost (
            {
              open_port = [ 0 ];
            }
            // lib.optionalAttrs (!isDarwin) {
              open_port_range = [
                [
                  1024
                  65535
                ]
              ];
            }
          );
          # Opened in the browser of the host by nono after checking the origin, for logins and dev servers.
          # Unlike `allow_launch_services`, this cannot open files or apps.
          open_urls = {
            allow_origins = map (domain: "https://${domain}") harnessDomains;
            allow_localhost = true;
          };
          environment = {
            deny_vars = sandbox.environment.unset;
            set_vars = sandbox.environment.set;
          };
          unsafe_macos_seatbelt_rules = lib.mkIf isDarwin seatbeltRules;
          # makes `unix_socket` an allowlist on Linux as well, refusing every abstract socket
          linux.af_unix_mediation = "pathname";
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
