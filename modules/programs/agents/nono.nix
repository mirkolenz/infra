{
  flake.modules.homeManager.default =
    {
      lib,
      lib',
      config,
      pkgs,
      ...
    }:
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

      mediateCommands = isDarwin && blockedCommands != [ ];

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
      # Seatbelt sees canonical paths, `/tmp` and `$TMPDIR` resolve below `/private`.
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

      # The absolute `write` paths below `path`.
      writableBelow = path: lib.filter (lib.hasPrefix "${path}/") writePaths;

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
        ++ map (path: deny "file-write*" (subpath path) (map subpath (writableBelow path))) readPaths
        ++ [
          # Keeps the `.git` of every repository in place, a rename covers the source as well.
          (deny "file-write-unlink" (regex ''/\.git$'') scratch)
        ];

      # agents may write drafts, which only `nono profile promote` outside of nono applies
      profiles = "${config.xdg.configHome}/nono/profiles";
      drafts = "${config.xdg.configHome}/nono/profile-drafts";

      bwrapPolicy = pkgs.writers.writeJSON "nono-bwrap-policy.json" {
        inherit relative;
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
          groups.include = [ "git_config" ];
          workdir.access = "readwrite";
          filesystem = {
            # the main repository of a linked worktree, which commits write to
            allow =
              writePaths
              ++ [
                "@git:common-dir"
                drafts
              ]
              ++ fromHarnesses "stateDirs";
            # the base of a draft
            read = readPaths ++ [ profiles ];
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
