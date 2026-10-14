# Discord call widgets with alternative clients

The Discord widget and DiscordCrew share `scripts/discord-voice.py`. Official Discord
(Stable, PTB, Canary, including installations with Vencord or BetterDiscord) uses its
local voice RPC and the existing StreamKit authorization flow.

Vesktop and other clients using arRPC expose Rich Presence, which does **not** provide
the authenticated voice RPC. The optional DevTools reader instead reads the current
call from Discord's in-memory stores. It supports Vencord/Equicord's Webpack API,
BetterDiscord's store API, and Discord's Webpack module cache as a fallback. This
covers Electron clients using the Discord web app, including Vesktop, Equibop and
Legcord. Native clients with their own UI and stores are not covered by this bridge.

## Enable the optional bridge

Quit the client, then start it with a loopback debugging port. For example:

```sh
flatpak run dev.vencord.Vesktop \
  --remote-debugging-address=127.0.0.1 --remote-debugging-port=9234
# Native example (use your client's executable):
vesktop --remote-debugging-address=127.0.0.1 --remote-debugging-port=9234
```

For a persistent app-menu launch, enable a user desktop override. This keeps the
vendor's original command and URL forwarding while adding the debugging flags:

```sh
python3 ~/.config/quickshell/angelos/scripts/discord-voice-launcher.py enable \
  /var/lib/flatpak/exports/share/applications/dev.vencord.Vesktop.desktop 9234
angelos reload
```

For a native client, pass its desktop file from `/usr/share/applications/` instead.
The launcher refuses to overwrite an existing custom user entry. The wrapper is
stored in `$XDG_DATA_HOME/angelos/discord-voice/` and the selected port in
`$XDG_CONFIG_HOME/angelos/discord-voice.json` (defaults: `~/.local/share` and
`~/.config`). Package updates do not replace these user files. Enable the bridge
once, then use the normal application menu after each login. Close a running client
before opening it from the new entry, so Electron accepts the debugging flags.

For temporary use, set `ANGELOS_DISCORD_CDP_PORT=9234` in the shell process's
environment or put `{"port": 9234}` in
`$XDG_RUNTIME_DIR/angelos-discord-voice.json`. The environment takes precedence,
followed by the runtime file, then the persistent config. Use a free port and the
same number in the client and reader settings.

The shell-side reader is part of this change and will be installed by AngelOS
updates that include it. Updating to an older AngelOS revision that predates this
change can replace `discord-voice.py` and remove its bridge hook; the persistent
launcher settings alone cannot add missing support to that older shell.

Enabling DevTools lets other local processes control this client, including its
messages. Keep it on loopback; do not use `--remote-allow-origins=*` or expose the port
to the network. The bridge itself reads only call state and avatars, and uses the
client's own actions for local mute/volume. It does not read account tokens or chats.
Only exact Discord HTTPS hostnames and local debugging WebSockets are accepted.

To disable a menu override:

```sh
python3 ~/.local/share/angelos/discord-voice/launcher.py disable dev.vencord.Vesktop.desktop
```

Remove the persistent config (if no other client uses it) and any runtime or
environment override, then restart the client without the debugging flags.
Ordinary Discord RPC continues to work without this opt-in.

## Validation

```sh
python3 .config/quickshell/angelos/tests/discord/test_discord_voice.py
python3 .config/quickshell/angelos/tests/discord/test_discord_cdp.py
```

The second command tests endpoint restrictions, configuration, call snapshots,
command validation, and the arRPC regression. Snapshot tests use Node.js when
available. Live verification was performed with Vesktop Flatpak; the other client
adapters are tested with stand-in stores, not installed clients.
