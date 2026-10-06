# Golden Gate system sounds

Original sounds for the Golden Gate skin, synthesised by `scripts/mac-sounds.py`
(numpy waveforms, encoded by ffmpeg). No Apple sound or sample is used or shipped.
They are original works of angelOS, dedicated to the public domain: CC0 1.0.

| file             | plays when                                   |
|------------------|----------------------------------------------|
| `notify.ogg`     | a notification arrives                       |
| `error.ogg`      | a critical notification / an error           |
| `volume.ogg`     | the volume changes (the "pop")               |
| `screenshot.ogg` | a screenshot is taken (the shutter)          |
| `trash.ogg`      | the Trash is emptied                         |
| `usbIn.ogg`      | a USB device is plugged in                   |
| `usbOut.ogg`     | a USB device is unplugged                    |
| `power.ogg`      | a charger is connected                       |
| `lock.ogg`       | the session locks                            |
| `login.ogg`      | you log in or unlock                         |

Your own: put a file with the same name (any of .ogg .oga .opus .wav .flac .aiff
.aif .caf .mp3) into `~/.local/share/angelos/sounds/macos/` — it is played instead
of the one here. Sounds copied from your own Mac (`/System/Library/Sounds/*.aiff`)
work as they are once renamed, e.g. `Funk.aiff` → `error.aiff`.

Regenerate: `python3 scripts/mac-sounds.py` (writes this folder).
