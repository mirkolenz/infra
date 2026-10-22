{ mkPythonApp }:
# Takes `--config <file>` as written by modules/programs/agents/nono.nix,
# then `--` and the arguments of the harness.
mkPythonApp {
  script = "nono-launch";
  description = "Run an agent harness within nono, granting the directories it adds";
  # run by the agents and their harnesses, not by people
  interactive = false;
  # the arguments of the harness follow, so its flags never reach the launcher
  leadingArgs = [ "--" ];
}
