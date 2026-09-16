{
  flake.modules.nixvim.default = {
    clipboard.register = "";
    opts = {
      autoindent = true;
      breakindent = true;
      cmdheight = 0; # only really usable under ui2, see lua/ui2.lua
      confirm = true;
      cursorline = true;
      expandtab = true;
      foldenable = false;
      guifont = "JetBrainsMono_Nerd_Font:h13";
      ignorecase = true;
      inccommand = "split";
      laststatus = 3;
      linebreak = true;
      # `wait:0` replaces `hit-enter`, which no longer applies under ui2.
      messagesopt = "history:500,wait:0,progress:c,maxheight:50,pager:<CR>,timeout:4000";
      mouse = "a";
      number = true;
      relativenumber = true;
      scrolloff = 10;
      scrolloffpad = 1; # keep 'scrolloff' honoured at the end of the buffer
      shiftwidth = 2;
      showmode = false;
      signcolumn = "yes";
      smartcase = true;
      softtabstop = -1; # follow shiftwidth
      spell = true;
      spelllang = "en_us,de_de";
      spelloptions = "camel";
      splitbelow = true;
      splitright = true;
      tabstop = 2;
      winborder = "rounded";
    };
    globals = {
      mapleader = " ";
      maplocalleader = " ";
      # netrw still claims directory buffers on BufEnter, so unloading it is what
      # leaves `:edit <dir>` and `-` to the builtin browser in plugin/dir.lua.
      # https://neovim.io/doc/user/pi_netrw.html#netrw-noload
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
      # neovide
      neovide_input_macos_option_key_is_meta = "both";
    };
  };
}
