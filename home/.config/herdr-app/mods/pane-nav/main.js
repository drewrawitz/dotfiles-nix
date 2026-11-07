// Ctrl+h/j/k/l moves between panes, like the is_vim bindings in ~/.tmux.conf: when the focused
// pane's foreground program is Neovim/Vim/fzf, the key goes to that program instead (Neovim
// moves between its own splits and calls `herdr-app do pane.go` at the edge; see
// home/.config/nvim/lua/plugins/tmux-navigator.lua in the dotfiles repo).
// Bound in keys.json as "ctrl-h": "pane-nav.left".
//
// Commands only reach a shown copy, so the layout keeps a 0px block of this mod (id "pane-nav").

import { View, div } from "gpui-kit";
import { exec, focused, hc, home, nextCommand, panes, run } from "herdr";

// Same programs as tmux's is_vim regex.
const VIM = /^g?(view|l?n?vim?x?|fzf)(diff)?$/i;
const LETTER = { left: "h", down: "j", up: "k", right: "l" };

// Neovim gets the key over the socket it opens for its Herdr terminal (tmux-navigator.lua). Not
// `hc keys`: herdr-core holds typed-in input back while the person is pressing keys in that
// terminal, so it lands seconds late, all at once. `hc keys` stays the fallback for programs
// without the socket (Vim, fzf, a Neovim started some other way). Sends go one at a time so
// fast presses keep their order.
let sending = Promise.resolve();
function toProgram(pane, direction) {
  const letter = LETTER[direction];
  sending = sending.then(async () => {
    if (pane.program?.key === "nvim") {
      const sock = `${home()}/.cache/herdr-nvim/${pane.terminal}.sock`;
      const r = await exec("nvim", ["--server", sock, "--remote-send", `<C-${letter}>`]).catch(() => null);
      if (r?.code === 0) return;
    }
    hc(["keys", pane.terminal, `ctrl+${letter}`]).catch(() => {});
  });
}

// Decided from Herdr's live pane data (program follows the terminal's foreground process), so
// each press is handled the moment it arrives.
function handle(direction) {
  const id = focused()?.pane;
  const pane = id ? panes().find((p) => p.pane === id) : null;
  const program = pane?.program;
  const vim = !!pane?.terminal && [program?.key, program?.name].some((n) => n && VIM.test(n));
  if (vim) toProgram(pane, direction);
  else run("pane.go", { direction });
}

export default class PaneNav extends View {
  init(_props, cx) {
    cx.spawn(async () => {
      for (;;) {
        const direction = (await nextCommand()).replace(/^pane-nav[.:]/, "");
        if (LETTER[direction]) handle(direction);
      }
    });
  }

  render() {
    return div().size_full();
  }
}
