{ config, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    tmux
    gh        # github cli
    fnm       # node version manager
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Claude Code's native installer self-updates, so only run it when claude is missing.
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/claude" ]; then
      run /bin/bash -c 'PATH=/usr/bin:/bin:/usr/sbin:$PATH; curl -fsSL https://claude.ai/install.sh | bash' \
        || echo "Claude Code install failed; run: curl -fsSL https://claude.ai/install.sh | bash"
    fi
  '';

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    plugins = [{
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }];
    initContent = lib.mkMerge [
      # p10k instant prompt has to run before everything else in .zshrc
      (lib.mkBefore ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''
        bindkey '^f' autosuggest-accept
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        eval "$(fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --shell zsh)"
      ''
    ];
    shellAliases = {
      ".." = "cd ..";
      gst = "git status";
    };
  };

  programs.zoxide.enable = true;  # `z` to jump to frecent dirs

	programs.git = {
		enable = true;
		settings.user = {
			name = "Drew Rawitz";
			email = "email@drewrawitz.com";
		};
	};

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.tmux.conf";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # 1Password only installs its native messaging manifest for browsers it knows,
  # so Helium needs a copy or the extension can't reach the desktop app.
  # Helium also still has to be added under 1Password > Settings > Browser.
  home.file."Library/Application Support/net.imput.helium/NativeMessagingHosts/com.1password.1password.json".text =
    builtins.toJSON {
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
}
