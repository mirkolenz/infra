{
  flake.modules.darwin.default = {
    system.defaults = {
      CustomUserPreferences = {
        NSGlobalDomain = {
          NSCloseAlwaysConfirmsChanges = false;
          AppleSpacesSwitchOnActivate = true;
        };
        "com.apple.Music" = {
          userWantsPlaybackNotifications = false;
        };
        "com.apple.ActivityMonitor" = {
          UpdatePeriod = 1;
        };
        "com.apple.TextEdit" = {
          SmartQuotes = false;
          RichText = false;
        };
        "com.apple.spaces" = {
          "spans-displays" = false;
        };
        "com.apple.menuextra.clock" = {
          DateFormat = "EEE d MMM HH:mm:ss";
          FlashDateSeparators = false;
        };
      };
      dock = {
        appswitcher-all-displays = true;
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.2;
        dashboard-in-overlay = false;
        enable-spring-load-actions-on-all-items = false;
        expose-animation-duration = 0.2;
        expose-group-apps = false;
        launchanim = true;
        mineffect = "genie";
        minimize-to-application = false;
        mouse-over-hilite-stack = true;
        mru-spaces = false;
        orientation = "bottom";
        show-process-indicators = true;
        show-recents = true;
        showhidden = true;
        static-only = false;
        tilesize = 48;
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
        persistent-apps = [
          "/System/Applications/App Store.app"
          "/System/Applications/Music.app"
          "/Applications/DEVONthink.app"
          "/Applications/Obsidian.app"
          # "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
          "/Applications/Orion RC.app"
          "/Applications/Vivaldi.app"
          "/Applications/Firefox.app"
          "/Applications/1Password.app"
          "/Applications/ChatGPT.app"
          "/Applications/Claude.app"
          "/System/Applications/Messages.app"
          "/Applications/WhatsApp.app"
          "/System/Applications/Mail.app"
          "/Applications/zoom.us.app"
          "/Applications/Microsoft Teams.app"
          "/Applications/Todoist.app"
          "/System/Applications/Calendar.app"
          "/Applications/Zed.app"
          "/Applications/Ghostty.app"
          "/Applications/OrbStack.app"
          "/Applications/Zotero.app"
          "/Applications/PDF Expert.app"
          "/Applications/Skim.app"
          "/Applications/Microsoft Word.app"
          "/Applications/Microsoft Excel.app"
          "/Applications/Microsoft PowerPoint.app"
          "/Applications/Home Assistant.app"
          "/System/Applications/Utilities/Activity Monitor.app"
          "/System/Applications/System Settings.app"
        ];
        # persistent-others = [ "${userHome}/Downloads/" ];
      };
      finder = {
        _FXShowPosixPathInTitle = false;
        _FXSortFoldersFirst = true;
        AppleShowAllExtensions = true;
        AppleShowAllFiles = false;
        CreateDesktop = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "clmv";
        QuitMenuItem = false;
        ShowPathbar = true;
        ShowStatusBar = false;
      };
      loginwindow = {
        autoLoginUser = null;
        DisableConsoleAccess = false;
        GuestEnabled = false;
        LoginwindowText = null;
        PowerOffDisabledWhileLoggedIn = false;
        RestartDisabled = false;
        RestartDisabledWhileLoggedIn = false;
        SHOWFULLNAME = false;
        ShutDownDisabled = false;
        ShutDownDisabledWhileLoggedIn = false;
        SleepDisabled = false;
      };
      magicmouse = {
        MouseButtonMode = "TwoButton";
      };
      screencapture = {
        disable-shadow = true;
        location = "~/Downloads";
        show-thumbnail = true;
        type = "png";
        target = "file";
      };
      smb = {
        NetBIOSName = null;
        ServerDescription = null;
      };
      spaces = {
        spans-displays = false;
      };
      trackpad = {
        ActuationStrength = 0;
        Clicking = true;
        Dragging = true;
        FirstClickThreshold = 0;
        SecondClickThreshold = 0;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
        TrackpadThreeFingerTapGesture = 0;
      };
      universalaccess = {
        closeViewScrollWheelToggle = false;
        closeViewZoomFollowsFocus = false;
        reduceTransparency = false;
        mouseDriverCursorSize = 1.0;
      };
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };
      LaunchServices = {
        LSQuarantine = true;
      };
      WindowManager = {
        AppWindowGroupingBehavior = true;
        AutoHide = false;
        EnableStandardClickToShowDesktop = false;
        EnableTiledWindowMargins = false;
        GloballyEnabled = false;
        HideDesktop = false;
        StageManagerHideWidgets = false;
        StandardHideDesktopIcons = false;
        StandardHideWidgets = false;
      };
      ".GlobalPreferences" = {
        "com.apple.mouse.scaling" = null;
        "com.apple.sound.beep.sound" = null;
      };
      NSGlobalDomain = {
        _HIHideMenuBar = false;
        "com.apple.keyboard.fnState" = false;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.springing.delay" = 1.0;
        "com.apple.springing.enabled" = null;
        "com.apple.swipescrolldirection" = true;
        "com.apple.trackpad.enableSecondaryClick" = true;
        "com.apple.trackpad.forceClick" = false;
        "com.apple.trackpad.scaling" = null;
        "com.apple.trackpad.trackpadCornerClickBehavior" = null;
        AppleEnableMouseSwipeNavigateWithScrolls = true;
        AppleEnableSwipeNavigateWithScrolls = true;
        AppleFontSmoothing = null;
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleKeyboardUIMode = null;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        ApplePressAndHoldEnabled = false;
        AppleScrollerPagingBehavior = true;
        AppleShowAllExtensions = true;
        AppleShowAllFiles = false;
        AppleShowScrollBars = "WhenScrolling";
        AppleSpacesSwitchOnActivate = true;
        AppleTemperatureUnit = "Celsius";
        AppleWindowTabbingMode = "always";
        InitialKeyRepeat = 15; # slider values: 120, 94, 68, 35, 25, 15
        KeyRepeat = 2; # slider values: 120, 90, 60, 30, 12, 6, 2
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = true;
        NSDisableAutomaticTermination = null;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSScrollAnimationEnabled = true;
        NSTableViewDefaultSizeMode = 2;
        NSTextShowsControlCharacters = false;
        NSUseAnimatedFocusRing = true;
        NSWindowResizeTime = 2.0e-2;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
      };
    };
    system.startup = {
      chime = false;
    };
  };
}
