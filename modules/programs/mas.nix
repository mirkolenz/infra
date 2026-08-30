{
  flake.modules.darwin.default = {
    programs.mas = {
      enable = true;
      update = true;
      cleanup = true;
      # mas list
      # pdf-presenter = 6472296409;
      packages = {
        # keep-sorted start
        ausweisapp = 948660805;
        base = 6744867438;
        bitwarden = 1352778147;
        dropover = 1355679052;
        gapplin = 768053424;
        home-assistant = 1099568401;
        keka = 470158793;
        meeting-owl = 1219076447;
        mela = 1568924476;
        microsoft-excel = 462058435;
        microsoft-onedrive = 823766827;
        microsoft-powerpoint = 462062816;
        microsoft-word = 462054704;
        parallels = 1085114709;
        pdf-expert = 1055273043;
        qr-factory = 1609285899;
        reeder = 6475002485;
        safari-1password = 1569813296;
        safari-kagi = 1622835804;
        safari-raindropio = 1549370672;
        step-two = 1448916662;
        testflight = 899247664;
        todoist = 585829637;
        whatsapp = 310633997;
        # keep-sorted end
      };
    };
  };
}
