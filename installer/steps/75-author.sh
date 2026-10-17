# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── The author's tools (optional) ───────────────────────────────────────────

# Only the author of angelOS has use for this: when the GitHub account logged in through gh
# can see the author's private repository, the chapter editor (and the owner's Dotfiles
# tools) are fetched into the shell's owner/ folder (scripts/author-tools.sh). GitHub
# decides — the repository is private; for everyone else nothing is fetched and nothing
# changes. angelOS keeps no token: gh keeps its own login, with its usual permissions.
offer_author_tools() {
  [[ "$DESKTOP_SHELL" == angelos ]] || return 0
  local script="$HOME_DIR/.config/quickshell/angelos/scripts/author-tools.sh" want="${GITHUB_LOGIN:-}"
  [[ -f "$script" ]] || return 0
  # only the author needs it (a private repository): never asked, GITHUB_LOGIN=1 or
  # `angelos author login` later
  [[ "$want" == 1 ]] || return 0
  if ! command -v gh >/dev/null 2>&1; then
    warn "$(_ 'gh (github-cli) is not installed: install it, then run `angelos author login`' \
              'gh (github-cli) не установлен: поставьте его и выполните `angelos author login`')"
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    if ! ((INTERACTIVE)); then
      warn "$(_ 'No gh login, and no terminal to log in: `angelos author login` later' \
                'gh не залогинен, а войти без терминала нельзя: позже `angelos author login`')"
      return 0
    fi
    gh auth login --hostname github.com --git-protocol https --web ||
      { warn "$(_ 'GitHub login did not finish' 'Вход в GitHub не завершился')"; return 0; }
  fi
  sh "$script" fetch || true
}
