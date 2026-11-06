{ lib, pkgs, ... }:

let
  profile = "Library/Application Support/net.imput.helium";

  # Chrome Web Store ids Helium installs on its own. The id is the last part of the store URL.
  extensions = {
    aeblfdkhhhdcdjpifhhbdiojplfjncoa = "1Password";
  };

  # Written once into a fresh Helium profile, so a new Mac starts with my layout.
  # Helium owns the file after that; changes made in the browser don't flow back here.
  preferences = pkgs.writeText "helium-preferences.json" (builtins.toJSON {
    helium = {
      completed_onboarding = true;
      services = { schema_version = 1; user_consented = true; };
      browser = {
        layout = 2;  # vertical tabs
        centered_location_bar = true;
        minimal_location_bar = true;
        vertical_right_aligned = false;
        zen_mode = true;
        zen_mode_sidebar_pinned = true;
        zen_mode_top_chrome_pinned = true;
      };
    };
    browser.theme.is_grayscale2 = true;
    vertical_tabs = { collapsed_state = false; expand_on_hover = false; uncollapsed_width = 200; };
    extensions = {
      pinned_extensions = [
        "blockjmkbacgjkknlgpkjjiijinjdanf"  # uBlock Origin, built into Helium
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa"  # 1Password
      ];
      commands."mac:Command+Shift+X" = {
        command_name = "_execute_action";  # open 1Password
        extension = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";
        global = false;
      };
    };
  });
in

{
  home.file = lib.mapAttrs' (id: _name:
    # Helium installs these from the Web Store on its next launch, then asks me to enable each one once.
    # The URL carries prodversion because Helium strips it from requests for privacy,
    # and without it the store answers that there is nothing to install.
    lib.nameValuePair "${profile}/External Extensions/${id}.json" {
      text = builtins.toJSON {
        external_update_url = "https://clients2.google.com/service/update2/crx?prodversion=999.0.0.0";
      };
    }) extensions // {
    # 1Password only installs its native messaging manifest for browsers it knows,
    # so Helium needs a copy or the extension can't reach the desktop app.
    # Helium also still has to be added under 1Password > Settings > Browser.
    "${profile}/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
      name = "com.1password.1password";
      description = "1Password BrowserSupport";
      path = "/Applications/1Password.app/Contents/Library/LoginItems/1Password Browser Helper.app/Contents/MacOS/1Password-BrowserSupport";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
        "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
        "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
        "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
        "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
        "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
      ];
    };
  };

  home.activation.seedHeliumPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    prefs="$HOME/${profile}/Default/Preferences"
    if [[ ! -e "$prefs" ]]; then
      run mkdir -p "$(dirname "$prefs")"
      run install -m 600 ${preferences} "$prefs"
    fi
  '';
}
