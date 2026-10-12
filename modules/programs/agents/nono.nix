{
  flake.modules.homeManager.default =
    {
      lib,
      lib',
      config,
      pkgs,
      ...
    }@args:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
      inherit (lib') namesWithValue;
      inherit (sandbox)
        relative
        readPaths
        writePaths
        deniedPaths
        blockedCommands
        ;

      sandbox = lib'.splitSandbox config.programs.agents.sandbox;
      harnesses = lib.attrValues config.programs.agents.harnesses;
      fromHarnesses = attr: lib.concatMap (harness: harness.${attr}) harnesses;
      nono = config.programs.nono.finalPackage;
      osConfig = args.osConfig or { };

      mediateCommands = isDarwin && blockedCommands != [ ];

      # Seatbelt filters. Seatbelt misses anchored alternatives within one regex,
      # so every rule combines plain filters instead, each regex holding at most one anchor.
      literal = path: "(literal ${lib.toJSON path})";
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

      # A relative key as a regex, `**/` matching any directories and `*` within a path segment.
      keyRegex =
        key:
        lib.concatMapStringsSep "(.*/)?" (
          part: lib.concatMapStringsSep "[^/]*" lib.escapeRegex (lib.splitString "*" part)
        ) (lib.splitString "**/" key);

      # A path at or below a match of `key`, at any depth or directly within `root`.
      keyFilter = key: regex "/${keyRegex key}(/|$)";
      rootedKeyFilter = root: key: regex "^${lib.escapeRegex root}/${keyRegex key}(/|$)";

      writeKeys = namesWithValue "write" relative;

      # The ones of `paths` below `path`.
      below = paths: path: lib.filter (lib.hasPrefix "${path}/") paths;

      # The relative `write` keys equal to or below the matches of `key`.
      exemptions = key: lib.filter (write: lib.match "${keyRegex key}(/.*)?" write != null) writeKeys;

      # Metadata stays readable, so listing a directory or `git status` keeps working.
      seatbeltOperations = {
        read = "file-write*";
        deny = "file-read-data file-write*";
      };

      # Relative keys apply at any depth, so repositories added later are covered as well.
      # The home directory holds the state of the agents.
      relativeRule =
        key: access:
        deny seatbeltOperations.${access} (keyFilter key) (
          scratch ++ [ (rootedKeyFilter config.home.homeDirectory key) ] ++ map keyFilter (exemptions key)
        );

      # Platform rules come last in the nono policy, so these denies win over its grants.
      # nono cannot make a path read-only within a writable one, a bypass takes the access of every covering grant.
      seatbeltRules =
        lib.mapAttrsToList relativeRule (lib.filterAttrs (_: access: access != "write") relative)
        ++ map (path: deny "file-write*" (subpath path) (map subpath (below writePaths path))) readPaths
        ++ [
          # Keeps the `.git` of every repository in place, a rename covers the source as well.
          (deny "file-write-unlink" (regex ''/\.git$'') scratch)
        ]
        # the denies of nono keep the metadata readable, so the content of the link is the only gap
        ++ map (file: "(allow file-read-data ${literal file})") exemptFiles;

      # agents may write drafts, which only `nono profile promote` outside of nono applies
      profiles = "${config.xdg.configHome}/nono/profiles";
      drafts = "${config.xdg.configHome}/nono/profile-drafts";

      # The absolute targets of the enabled `files` matching `pred`, below `root`.
      targets =
        root: pred: files:
        map (file: "${root}/${file.target}") (
          lib.filter (file: file.enable && pred file) (lib.attrValues files)
        );

      # The files home-manager links into the store, so tools find their config, ripgrep among them.
      # nono grants every hop of a symlink, so an out-of-store link grants its target as well.
      # A recursive directory holds unmanaged files too.
      managedFiles = targets config.home.homeDirectory (file: !file.recursive) config.home.file;

      # The copied files of the system config, none for a standalone home, which nono on Linux
      # keeps unreadable apart from a few. Symlinked ones resolve into the readable store,
      # and macOS reads all of `/etc` anyway.
      etcFiles =
        targets "/etc" (file: file.mode or "symlink" != "symlink") (osConfig.environment.etc or { })
        # determinate-nixd writes it itself, outside of `environment.etc`
        ++ lib.optional (
          osConfig.determinate.enable or osConfig.determinateNix.enable or false
        ) "/etc/nix/nix.conf";

      # the generated files within a denied directory, such as `.ssh/config`, which stay readable
      exemptFiles = lib.unique (lib.concatMap (below managedFiles) deniedPaths);

      bwrapPolicy = pkgs.writers.writeJSON "nono-bwrap-policy.json" {
        inherit relative;
        links = exemptFiles;
        deny = deniedPaths;
        read = readPaths;
        write = writePaths;
        blocked_commands = blockedCommands;
      };

      nonoCommand =
        lib.optionalString isLinux "${lib.getExe pkgs.nono-bwrap} --policy ${bwrapPolicy} -- "
        + lib.getExe nono;

      agentCommand = package: ''${lib.getExe package} "''${args[@]}" "$@"'';

      # Runs the harness within nono, or directly when inside it already,
      # winning `bin/<name>` over the harness.
      wrapperPackage =
        harness: name: package:
        lib.hiPrio (
          pkgs.writeShellApplication {
            inherit name;
            text = /* bash */ ''
              # the native sandbox of the harness instead, in case nono gets in the way
              if [[ -n ''${NO_NONO:-} ]]; then
                exec ${lib.getExe package} "$@"
              fi

              args=(${lib.escapeShellArgs harness.sandboxArgs})
              ${lib.optionalString (harness.addDirFlag != null) ''
                IFS=, read -ra dirs <<<"''${NONO_ALLOW:-}"

                for dir in "''${dirs[@]}"; do
                  args+=(${lib.escapeShellArg harness.addDirFlag} "$dir")
                done
              ''}
              # nono sets NONO_CAP_FILE in every sandbox it starts.
              if [[ -f ''${NONO_CAP_FILE:-} ]]; then
                exec ${agentCommand package}
              fi

              exec ${nonoCommand} run --no-audit --allow-cwd -- ${agentCommand package}
            '';
          }
        );
    in
    lib.mkIf config.programs.agents.enable {
      programs.nono = {
        enable = true;
        environment.NONO_PROFILE = "agents";
        profiles.agents = {
          extends = "default";
          # the toolchains, nono skips the groups of the other platform
          groups.include = [
            "git_config"
            "bun_runtime"
            "go_runtime"
            "go_runtime_linux"
            "go_runtime_macos"
            "java_runtime"
            "nix_runtime"
            "node_runtime"
            "python_runtime"
            "rust_runtime"
          ];
          workdir.access = "readwrite";
          filesystem = {
            allow =
              writePaths
              ++ [
                # the main repository of a linked worktree, which commits write to
                "@git:common-dir"
                drafts
              ]
              ++ fromHarnesses "stateDirs";
            read =
              readPaths
              ++ managedFiles
              ++ etcFiles
              ++ [
                # the base of a draft
                profiles
              ];
            # Exempts the generated files, such as `.npmrc` or the shell configs, from the deny groups of nono,
            # their content sits in the readable store anyway. The denies of `paths` only yield to `exemptFiles`.
            bypass_protection = managedFiles;
            unix_socket = sandbox.unixSockets;
            # sockets tools create for themselves, such as the forkserver of Python's multiprocessing
            unix_socket_subtree_bind = [
              "/tmp"
              "$TMPDIR"
            ];
            # on Linux nono refuses denies within granted directories, bubblewrap enforces them
            deny = lib.mkIf isDarwin deniedPaths;
          };
          network = {
            allow_domain = lib.unique (sandbox.allowedDomains ++ fromHarnesses "domains");
            deny_domain = sandbox.deniedDomains;
          };
          environment = {
            deny_vars = sandbox.unset;
            set_vars = sandbox.set;
          };
          unsafe_macos_seatbelt_rules = lib.mkIf isDarwin seatbeltRules;
          # makes `unix_socket` an allowlist on Linux as well, refusing every abstract socket
          linux.af_unix_mediation = "pathname";
          # Refuses a `block` command by its name and canonical path, unlisted commands run unmediated.
          # On Linux, mediation confines execution to the top level of the `PATH` directories
          # and `executable_dirs` rejects the group-writable `/nix/store`, so bubblewrap enforces them.
          command_policies = lib.mkIf mediateCommands {
            commands = lib.genAttrs blockedCommands (_: {
              from.session = "deny";
            });
          };
          # with command mediation active, nono would deny their commands, rm, mv and npm among them
          groups.exclude = lib.mkIf mediateCommands [
            "dangerous_commands"
            "dangerous_commands_macos"
            "dangerous_commands_linux"
          ];
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
