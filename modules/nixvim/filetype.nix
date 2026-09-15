{
  flake.modules.nixvim.default = {
    # Neovim has no .mdx rule and falls back to content detection, which lands on
    # `conf`. The compound filetype also pulls in the markdown ftplugin (soft
    # wrap, see files.nix), matching Zed's MDX setup.
    filetype.extension.mdx = "markdown.mdx";
  };
}
