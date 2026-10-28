{
  mkPythonApp,
  gitMinimal,
  gh,
  gh-actions-lock-bin,
}:
# The home-manager option `custom.bump` passes its package managers through `withConfig`.
mkPythonApp {
  script = "bumpctl";
  description = "Update and commit the dependencies of projects, or bump their dependency ranges";
  # the GitHub API and the relocking of `actions.lock` for the ranges of `actions`
  runtimeInputs = [
    gitMinimal
    gh
    gh-actions-lock-bin
  ];
}
