{
  flake.modules.darwin.default = {
    system.defaults = {
      # keep-sorted start block=yes
      ".GlobalPreferences" = {
        # keep-sorted start
        "com.apple.mouse.scaling" = null;
        "com.apple.sound.beep.sound" = null;
        # keep-sorted end
      };
      ActivityMonitor = {
        # keep-sorted start
        IconType = 0;
        OpenMainWindow = true;
        ShowCategory = 100;
        SortColumn = null;
        SortDirection = null;
        # keep-sorted end
      };
      CustomSystemPreferences = { };
      CustomUserPreferences = {
        # keep-sorted start block=yes
        "com.apple.ActivityMonitor" = {
          UpdatePeriod = 1;
        };
        "com.apple.Music" = {
          userWantsPlaybackNotifications = false;
        };
        "com.apple.TextEdit" = {
          RichText = false;
          SmartQuotes = false;
        };
        NSGlobalDomain = {
          NSCloseAlwaysConfirmsChanges = false;
        };
        # keep-sorted end
      };
      LaunchServices = {
        LSQuarantine = true;
      };
      NSGlobalDomain = {
        # keep-sorted start
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
        AppleIconAppearanceTheme = "RegularAutomatic";
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleKeyboardUIMode = null;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        ApplePressAndHoldEnabled = false;
        AppleReduceDesktopTinting = false;
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
        NSAutomaticInlinePredictionEnabled = true;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = true;
        NSDisableAutomaticTermination = null;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSScrollAnimationEnabled = true;
        NSStatusItemSelectionPadding = null;
        NSStatusItemSpacing = null;
        NSTableViewDefaultSizeMode = 2;
        NSTextShowsControlCharacters = false;
        NSUseAnimatedFocusRing = true;
        NSWindowResizeTime = 2.0e-2;
        NSWindowShouldDragOnGesture = false;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        _HIHideMenuBar = false;
        # keep-sorted end
      };
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };
      WindowManager = {
        # keep-sorted start
        AppWindowGroupingBehavior = true;
        AutoHide = false;
        EnableStandardClickToShowDesktop = false;
        EnableTiledWindowMargins = false;
        EnableTilingByEdgeDrag = true;
        EnableTilingOptionAccelerator = true;
        EnableTopTilingByEdgeDrag = true;
        GloballyEnabled = false;
        HideDesktop = false;
        StageManagerHideWidgets = false;
        StandardHideDesktopIcons = false;
        StandardHideWidgets = false;
        # keep-sorted end
      };
      controlcenter = {
        # keep-sorted start
        AirDrop = null;
        BatteryShowPercentage = null;
        Bluetooth = null;
        Display = null;
        FocusModes = null;
        NowPlaying = null;
        Sound = null;
        # keep-sorted end
      };
      dock = {
        # keep-sorted start block=yes
        appswitcher-all-displays = true;
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.2;
        dashboard-in-overlay = false;
        enable-spring-load-actions-on-all-items = false;
        expose-animation-duration = 0.2;
        expose-group-apps = false;
        largesize = 96;
        launchanim = true;
        magnification = false;
        mineffect = "genie";
        minimize-to-application = false;
        mouse-over-hilite-stack = true;
        mru-spaces = false;
        orientation = "bottom";
        persistent-apps = [
          "/System/Applications/App Store.app"
          "/System/Applications/Music.app"
          "/Applications/DEVONthink.app"
          "/Applications/Obsidian.app"
          # "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
          "/Applications/Orion.app"
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
        persistent-others = null;
        scroll-to-open = false;
        show-process-indicators = true;
        show-recents = true;
        showAppExposeGestureEnabled = true;
        showDesktopGestureEnabled = false;
        showLaunchpadGestureEnabled = false;
        showMissionControlGestureEnabled = true;
        showhidden = true;
        slow-motion-allowed = false;
        static-only = false;
        tilesize = 48;
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
        # keep-sorted end
      };
      finder = {
        # keep-sorted start
        AppleShowAllExtensions = true;
        AppleShowAllFiles = false;
        CreateDesktop = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "clmv";
        FXRemoveOldTrashItems = false;
        NewWindowTarget = "Home";
        NewWindowTargetPath = null;
        QuitMenuItem = false;
        ShowExternalHardDrivesOnDesktop = false;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = false;
        ShowPathbar = true;
        ShowRemovableMediaOnDesktop = false;
        ShowStatusBar = false;
        _FXEnableColumnAutoSizing = false;
        _FXShowPosixPathInTitle = false;
        _FXSortFoldersFirst = true;
        _FXSortFoldersFirstOnDesktop = true;
        # keep-sorted end
      };
      hitoolbox = {
        AppleFnUsageType = "Show Emoji & Symbols";
      };
      iCal = {
        # keep-sorted start
        "TimeZone support enabled" = false;
        "first day of week" = "System Setting";
        CalendarSidebarShown = true;
        # keep-sorted end
      };
      loginwindow = {
        # keep-sorted start
        DisableConsoleAccess = false;
        GuestEnabled = false;
        HideUserAvatarAndName = false;
        LoginwindowText = null;
        PowerOffDisabledWhileLoggedIn = false;
        RestartDisabled = false;
        RestartDisabledWhileLoggedIn = false;
        SHOWFULLNAME = false;
        ShutDownDisabled = false;
        ShutDownDisabledWhileLoggedIn = false;
        SleepDisabled = false;
        autoLoginUser = null;
        # keep-sorted end
      };
      magicmouse = {
        MouseButtonMode = "TwoButton";
      };
      menuExtraClock = {
        # keep-sorted start
        FlashDateSeparators = false;
        IsAnalog = false;
        Show24Hour = true;
        ShowAMPM = false;
        ShowDate = 1;
        ShowDayOfMonth = true;
        ShowDayOfWeek = true;
        ShowSeconds = true;
        # keep-sorted end
      };
      screencapture = {
        # keep-sorted start
        disable-shadow = true;
        include-date = true;
        location = "~/Downloads";
        save-selections = true;
        show-thumbnail = true;
        target = "file";
        type = "png";
        # keep-sorted end
      };
      screensaver = {
        # keep-sorted start
        askForPassword = false;
        askForPasswordDelay = null;
        # keep-sorted end
      };
      smb = {
        # keep-sorted start
        NetBIOSName = null;
        ServerDescription = null;
        # keep-sorted end
      };
      spaces = {
        spans-displays = false;
      };
      trackpad = {
        # keep-sorted start
        ActuateDetents = true;
        ActuationStrength = 0;
        Clicking = true;
        DragLock = false;
        Dragging = true;
        FirstClickThreshold = 0;
        ForceSuppressed = null;
        SecondClickThreshold = 0;
        TrackpadCornerSecondaryClick = 0;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadMomentumScroll = true;
        TrackpadPinch = true;
        TrackpadRightClick = true;
        TrackpadRotate = true;
        TrackpadThreeFingerDrag = true;
        TrackpadThreeFingerHorizSwipeGesture = 0;
        TrackpadThreeFingerTapGesture = 0;
        TrackpadThreeFingerVertSwipeGesture = 0;
        TrackpadTwoFingerDoubleTapGesture = true;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 0;
        # keep-sorted end
      };
      universalaccess = {
        # keep-sorted start
        closeViewScrollWheelToggle = false;
        closeViewZoomFollowsFocus = false;
        mouseDriverCursorSize = 1.0;
        reduceMotion = false;
        reduceTransparency = false;
        # keep-sorted end
      };
      # keep-sorted end
    };
    system.startup = {
      chime = false;
    };
  };
}
