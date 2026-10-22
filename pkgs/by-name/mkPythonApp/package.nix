{
  lib,
  python3Packages,
  python3Minimal,
  infra-apps,
  runCommand,
  writeText,
  writers,
  lndir,
  removeReferencesTo,
  makeBinaryWrapper,
  installShellFiles,
}:
# Packages a script of `infra-apps` as an app, with the libraries of its extra.
# The man page and shell completions come from the `parser()` function of its module,
# with the completions answered by `apptools.complete`.
let
  inherit (python3Packages) python argcomplete argparse-manpage;
  inherit (python3Minimal) sitePackages;

  inherit (infra-apps.meta) homepage maintainers;

  # The standard library of the minimal interpreter with its bytecode, which nixpkgs leaves out,
  # so that no app compiles it again on every start.
  stdlib = runCommand "${python3Minimal.name}-stdlib" { nativeBuildInputs = [ lndir ]; } ''
    mkdir -p $out/lib
    lndir -silent ${python3Minimal}/lib $out/lib
    rm $out/${sitePackages}/README.txt
    ${python3Minimal.interpreter} -m compileall -q $out/lib/${python3Minimal.libPrefix}
  '';

  # The standard library with copies of the libraries, named after the extra of `infra-apps`,
  # which keeps the closure lean: the libraries of nixpkgs reference their full interpreter,
  # which on darwin references the compiler toolchain. The bytecode of the copies gets
  # compiled anew for their paths.
  runtime =
    extra: libraries:
    runCommand "${infra-apps.pname}${lib.optionalString (extra != null) "-${extra}"}-python"
      {
        nativeBuildInputs = [
          lndir
          removeReferencesTo
        ];
        disallowedReferences = [ python ];
      }
      ''
        mkdir -p $out/lib
        lndir -silent ${stdlib}/lib $out/lib

        for library in ${lib.escapeShellArgs (lib.remove python (python3Packages.requiredPythonModules libraries))}; do
          cp -rL --no-preserve=mode "$library/${sitePackages}/." $out/${sitePackages}
        done

        find $out/${sitePackages} -name __pycache__ -prune -exec rm -r {} +
        # the shebangs of the scripts of libraries, which the apps never run
        grep -rlZ "^#!${python}/" $out/${sitePackages} | xargs -0r remove-references-to -t ${python}
        ${python3Minimal.interpreter} -m compileall -q $out/${sitePackages}
      '';

  mkPythonApp =
    {
      # the name of the app in the scripts of `infra-apps`
      script,
      pname ? script,
      description,
      # tools prepended to the PATH of the app, which the commands it runs inherit
      runtimeInputs ? [ ],
      # GNU-style flags passed before the arguments of every invocation, e.g. paths of files
      flags ? { },
      # arguments passed after the flags and before those of every invocation, e.g. `--`
      leadingArgs ? [ ],
      # whether people run the app themselves, which installs its man page and shell completions
      interactive ? true,
      passthru ? { },
    }@args:
    let
      # the app with further persistent flags, e.g. `flakectl.withFlags { flake = "..."; }`
      withFlags = extraFlags: mkPythonApp (args // { flags = flags // extraFlags; });
      # the `module:function` of the script
      entry = lib.splitString ":" infra-apps.scripts.${script};
      module = lib.head entry;
      function = lib.last entry;
      # the extra of the script, if it has libraries of its own
      extra = if infra-apps.optional-dependencies ? ${script} then script else null;
      libraries = [
        infra-apps
      ]
      ++ lib.optionals (extra != null) infra-apps.optional-dependencies.${extra};
      launcher = writeText "${pname}-launcher" ''
        from ${module} import ${function}

        ${function}()
      '';
      docsEnv = python.withPackages (_: [ argparse-manpage ] ++ libraries);
      register =
        shell: "${lib.getExe' argcomplete "register-python-argcomplete"} --shell ${shell} ${pname}";
      # The interpreter runs as a copy named after the app, which the OS shows for its process,
      # a symlink would show the name of its target. It finds its libraries through `lib`.
      # It lives in a derivation of its own, which keeps the wrapper free of references to its own
      # output, whose hash rewriting makes the code signature of the wrapper non-reproducible,
      # and does not depend on the flags, so the variants of `withFlags` share it.
      unwrapped =
        runCommand "${pname}-unwrapped"
          {
            nativeBuildInputs = [ installShellFiles ];
            disallowedReferences = [ python ];
          }
          (
            ''
              install -Dm755 ${python3Minimal.interpreter} $out/bin/${pname}
              ln -s ${runtime extra libraries}/lib $out/lib
              install -Dm644 ${launcher} $out/libexec/${pname}
            ''
            + lib.optionalString interactive ''
              ${lib.getExe' docsEnv "argparse-manpage"} --module ${module} --function parser \
                --prog ${pname} --description ${lib.escapeShellArg description} --url ${homepage} \
                --output ${pname}.1
              installManPage ${pname}.1
              installShellCompletion --cmd ${pname} \
                --bash <(${register "bash"}) \
                --fish <(${register "fish"}) \
                --zsh <(${register "zsh"})
            ''
          );
      wrapperArgs = [
        "--add-flags"
        # without user site-packages, and without the directory of the launcher on `sys.path`
        "-sP ${unwrapped}/libexec/${pname}"
      ]
      ++ lib.optionals (runtimeInputs != [ ]) [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath runtimeInputs)
      ]
      ++ lib.concatMap (arg: [
        "--add-flag"
        arg
      ]) (lib.cli.toCommandLineGNU { } flags ++ leadingArgs);
    in
    runCommand pname
      {
        nativeBuildInputs = [ makeBinaryWrapper ];

        passthru = {
          inherit unwrapped withFlags;
          # the app with a JSON file of the value as `--config`
          withConfig = value: withFlags { config = writers.writeJSON "${pname}.json" value; };
          # the app under another name, e.g. that of the agent it launches
          withName = name: mkPythonApp (args // { pname = name; });
        }
        // passthru;

        meta = {
          inherit description homepage maintainers;
          mainProgram = pname;
          inherit (python3Minimal.meta) platforms;
        };
      }
      (
        ''
          makeBinaryWrapper ${unwrapped}/bin/${pname} $out/bin/${pname} ${lib.escapeShellArgs wrapperArgs}
        ''
        + lib.optionalString interactive ''
          ln -s ${unwrapped}/share $out/share
        ''
      );
in
mkPythonApp
