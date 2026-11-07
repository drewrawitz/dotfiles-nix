{ config, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  imports = [ ./helium.nix ];

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
    tree-sitter  # LazyVim compiles treesitter parsers with it
    tmux
    gh        # github cli
    git-lfs   # the filter.lfs config in programs.git calls it from PATH
    google-cloud-sdk  # gcloud, bundles its own python
    fnm       # node version manager
    pnpm      # node package manager
    skillshare  # syncs agent skills across AI CLIs (from the skillshare flake's overlay)
  ];
  home.sessionVariables.EDITOR = "nvim";
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Claude Code's native installer self-updates, so only run it when claude is missing.
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/claude" ]; then
      run /bin/bash -c 'PATH=/usr/bin:/bin:/usr/sbin:$PATH; curl -fsSL https://claude.ai/install.sh | bash' \
        || echo "Claude Code install failed; run: curl -fsSL https://claude.ai/install.sh | bash"
    fi
  '';

  # Give a fresh machine a default Node; after that, fnm owns which versions are installed.
  home.activation.installDefaultNode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.fnm}/bin/fnm exec --using=default true >/dev/null 2>&1; then
      { run ${pkgs.fnm}/bin/fnm install --lts && run ${pkgs.fnm}/bin/fnm default lts-latest; } \
        || echo "Default Node install failed; run: fnm install --lts && fnm default lts-latest"
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
        eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
        take() { mkdir -p "$1" && cd "$1"; }
      ''
    ];
    shellAliases = {
      ".." = "cd ..";
      c = "clear";
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
		# GitHub Desktop runs `git lfs install` on launch, which tries to write these into
		# this read-only file unless they already match exactly. So they are plain
		# `git-lfs ...` commands rather than lfs.enable's /nix/store paths.
		settings.filter.lfs = {
			clean = "git-lfs clean -- %f";
			smudge = "git-lfs smudge -- %f";
			process = "git-lfs filter-process";
			required = true;
		};
	};

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  # The whole directory, not settings.json alone, so Tinycast's saves land in the repo
  # even if it replaces the file rather than writing through a file symlink.
  home.file.".config/tinycast".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/tinycast";
  # The wizard resolves this symlink before rewriting, so `p10k configure` saves into the repo.
  home.file.".p10k.zsh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.p10k.zsh";
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.tmux.conf";
  # Herdr writes a default keys.json whenever it finds none (first launch, or the moment the old
  # file is moved away), so force lets activation replace that copy with the link.
  # Herdr only watches its own folder, so after editing these in the repo, nudge it:
  # `touch -h ~/.config/herdr-app/keys.json` (or the mod folder), or restart Herdr.
  home.file.".config/herdr-app/keys.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr-app/keys.json";
    force = true;
  };
  home.file.".config/herdr-app/mods/pane-nav".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr-app/mods/pane-nav";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
