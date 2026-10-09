# fish, the way angelOS's screenshots show it: the pure prompt, fastfetch as the greeting,
# eza for ls, done and autopair. On CachyOS one package brings it all (cachyos-fish-config);
# elsewhere the fallback below gives the same look with what packages/fish.txt installed.
# Change it as you like: updates merge the author's changes in, and where you both changed
# the same lines yours stay. Or put your lines in ~/.config/fish/user.fish (read last,
# never touched).
# angelOS's own bits live in conf.d/angelos-tools.fish.

if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
else if status is-interactive
    # fastfetch says hello (its config: ~/.config/fastfetch, angelOS's logo)
    function fish_greeting
        type -q fastfetch; and fastfetch
    end
    if type -q eza
        alias ls 'eza -al --color=always --group-directories-first --icons=always'
        alias la 'eza -a --color=always --group-directories-first --icons=always'
        alias ll 'eza -l --color=always --group-directories-first --icons=always'
        alias lt 'eza -aT --color=always --group-directories-first --icons=always'
    end
    # man pages through bat, as on CachyOS
    type -q bat; and set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# the author's: n = nvim, the angelOS tools in ~/.local/bin first
alias n nvim
fish_add_path -g ~/.local/bin

# yours: never overwritten
test -f ~/.config/fish/user.fish; and source ~/.config/fish/user.fish
