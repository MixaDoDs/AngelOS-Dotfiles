# The installer, inside

`install.sh` is the entry (Settings → Updates and `.install` run it too). It keeps the settings
(the environment switches, listed in its header and by `./install.sh --help`), the language,
the self-update block (`scripts/check.sh` cuts it out by its markers) and the order of the run;
the rest is sourced from here in name order:

```
installer/
  lib/core.sh       step(), cleanup, --help, confirm, preflight (no root, sudo once and kept fresh)
  lib/show.sh       pictures (chafa → kitty / sixel / blocks; .ans frames without it), sounds, music
  lib/tui.sh        gum menus with plain-prompt fallbacks, frames, the hearts bar, the chat
  steps/NN-*.sh     the work, one topic a file: questions, packages, configs, SDDM, fish…
  art/              angel.gif, demon.gif and their .ans frames, the chest — made by scripts/installer-art.py
```

## A new step

A new file `installer/steps/NN-name.sh` (NN keeps definitions in order) with its function and one
line that puts it in the run:

```bash
my_step() {
  [[ "$MY_SWITCH" == 1 ]] || return 0      # a step decides itself when it has nothing to do
  say "$(_ 'Doing the thing' 'Делаю штуку')"
}
step 65 my_step 'the thing' 'штука'         # 65: after the devices (60), before «as the author has it» (70)
```

A question for it goes into `ask_profile` (steps/15-questions.sh), asked only when the switch was
not given (`given MY_SWITCH`), and what it changes on the system goes into `review` — the screen
before the start says everything that will happen. Without a terminal nothing is asked, the
defaults and what was given win, and no picture or sound is made (the log of Settings → Updates
stays plain text).

## The show

- Pictures: `pic FILE ROWS`, `anim angel|demon SECONDS`, `anim chest 0 once`, `billboard` (a demo
  of `docs/demo` while the packages download). They write to /dev/tty, never into a log.
- Sounds: `sfx pc2k/startup` (any `.ogg` of `data/sounds`), `music_start` / `music_stop` (the
  intro's loop, from after the packages: a fresh system has no sound server before them). Silent
  with `NO_MUSIC=1`, over SSH, without a sound server and on the author's own machine (a stream).
- References: the first screen is Windows XP's text setup in blue; «Present day. Present time.» opens
  and «Close the world, open the nExt.» closes it (Serial Experiments Lain); the billboards are the
  ones of an old Windows setup; the hard disk of a PC from 2000 spins up.
- The Linux console (`TERM=linux`): 16 colours, plain glyphs (`*`, `#`, `+--+`), the cyr-sun16 font
  for Cyrillic when the system set none.

Sprites changed? `python3 scripts/installer-art.py` (needs Pillow) remakes `art/`.
