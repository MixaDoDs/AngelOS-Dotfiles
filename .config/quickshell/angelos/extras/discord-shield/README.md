# discord-shield

Discord's Go Live with sound ("screen + sound") records every program's playback stream on its
own and now and then crashes (SIGTRAP in its Voice thread) when one of them goes away: a click
sound, a browser tab that plays something every minute.

With a mixer whose virtual outputs carry all the sound — a RØDECaster, GoXLR, Wave Link and the
like, set up so that the default output is a PipeWire loopback (a virtual sink looped to the
device) — everything already reaches Discord through those loopbacks, which live as long as
PipeWire does. `discord-shield.lua` then hides single programs' playback streams from Discord's
PipeWire clients: the stream sounds the same, but nothing in it comes and goes. Without such a
mixer it does nothing. Nothing is rerouted, only what Discord may see.

- installed by `install.sh` (step `install_discord_shield`): links in
  `~/.local/share/wireplumber/scripts/angelos/` and `~/.config/wireplumber/wireplumber.conf.d/`,
  read at WirePlumber's next start (`systemctl --user restart wireplumber`, not during a call);
  `DISCORD_SHIELD=0` or `~/.config/angelos/discord-shield.off` leaves it out
- `journalctl --user -u wireplumber -g "Discord client"` — shielded, and how many streams hidden
- `./test.sh` — an isolated PipeWire (temp HOME, no ALSA, no D-Bus) with a stand-in "discord":
  `NOMIXER=1` and `NOSHIELD=1` are the cases where it must hear every stream
