{ pkgs, user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      ApplePressAndHoldEnabled = false;  # holding a key repeats it instead of showing the accent picker
      _HIHideMenuBar = false;  # menu bar always visible (macOS still hides it in full screen)
      AppleShowAllExtensions = true;
      "com.apple.swipescrolldirection" = false;  # Apple's "Natural scrolling" off: swipe down scrolls down
    };
    dock.autohide = true;
    dock.magnification = true;             # icons grow on hover
    dock.largesize = 88;                   # hover size (16-128); unset means 128, which is "Large"
    dock.show-recents = false;             # no suggested/recent apps in the Dock
    dock.wvous-tr-corner = 4;              # hot corner: top right shows desktop
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
    trackpad.TrackpadRightClick = true;    # two-finger tap to right click
    # System Settings > Menu Bar > "Show menu bar background". nix-darwin has no typed option for it yet.
    CustomUserPreferences.NSGlobalDomain.SLSMenuBarUseBlurredAppearance = true;
    # Tinycast > Settings > "Sync settings file", so it reads ~/.config/tinycast/settings.json (linked in home.nix).
    CustomUserPreferences."com.tinycast.app".settingsFileEnabled = true;
  };
  # Mission Control mouse shortcuts: button 5 = Mission Control (id 38), button 4 = Application windows (id 39).
  # Spotlight's cmd+space (id 64) is off so Tinycast can have it.
  # -dict-add merges into the existing hotkeys, so shortcuts set in System Settings survive.
  system.activationScripts.postActivation.text =
    let
      button = mask: "<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>button</string><key>parameters</key><array><integer>${toString mask}</integer><integer>${toString mask}</integer><integer>0</integer></array></dict></dict>";
      spotlightOff = "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array></dict></dict>";
    in ''
      sudo -u ${user} defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
        38 '${button 16}' \
        39 '${button 8}' \
        64 '${spotlightOff}'
      sudo -u ${user} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      # Same notification System Settings posts, so a _HIHideMenuBar change applies without logging out.
      launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- /usr/bin/osascript -l JavaScript -e \
        'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("AppleInterfaceMenuBarHidingChangedNotification", $(), $(), true)' \
        >/dev/null
    '';

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Touch ID for sudo, in tmux too (reattach), via /etc/pam.d/sudo_local, which survives macOS updates.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # The font everything renders in. Installed system-wide, not through home-manager,
  # because fontd starts at login and never watches ~/Library/Fonts if the first switch
  # is what creates it, so WezTerm can't find the font on a new Mac. /Library/Fonts always exists.
  fonts.packages = [ pkgs.nerd-fonts.hack ];

  # Cloudflare DNS instead of whatever the router hands out; macOS upgrades it to encrypted DNS.
  # Services missing on a machine are skipped (see `networksetup -listallnetworkservices`).
  networking.knownNetworkServices = [ "Ethernet" "Wi-Fi" ];
  networking.dns = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];

  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    taps = [
      "abue-ammar/tinycast"
      "anomalyco/tap"
      "oven-sh/bun"
    ];
    brews = [
      "mole"            # mac cleaner (nixpkgs' "mole" is an unrelated ssh tool)
      "oven-sh/bun/bun" # runs Shepherdr's herdr service; nixpkgs' bun is too old for its lockfile
    ];
    casks = [
      "wezterm"
      "1password"
      "github"          # GitHub Desktop
      "helium-browser"
      "slack"
      "claude"          # Claude desktop app
      "shottr"
      "temurin@17"      # Eclipse Temurin JDK 17
      "abue-ammar/tinycast/tinycast"
      "anomalyco/tap/hex"
    ];
  };
}
