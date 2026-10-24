#!/bin/bash
# Isolated test of discord-shield.lua: its own PipeWire + WirePlumber + pipewire-pulse in a temp
# HOME and runtime dir, ALSA/Bluetooth/cameras off, no D-Bus — the real sound is never touched.
# A copy of pactl named "discord" stands for Discord. With a mixer (the default output is the
# loopback mix_in → mix_out) it must never hear of other programs' playback streams (sink-input
# events), while mix_out stays visible; NOMIXER=1 (default output: a plain sink) — it hears all.
# NOSHIELD=1: without the script (it hears all).
set -u
D=$(dirname "$(readlink -f "$0")")
T=$(mktemp -d /tmp/claude-1000/dshield.XXXX); chmod 700 "$T"
mkdir -p "$T/home" "$T/run" "$T/cfg/wireplumber/wireplumber.conf.d" "$T/data/wireplumber/scripts/angelos" "$T/state" "$T/bin"
chmod 700 "$T/run"
cp "$D/discord-shield.lua" "$T/data/wireplumber/scripts/angelos/"
[ "${NOSHIELD:-}" ] || cp "$D/90-angelos-discord-shield.conf" "$T/cfg/wireplumber/wireplumber.conf.d/"
cat > "$T/cfg/wireplumber/wireplumber.conf.d/10-test.conf" <<'C'
wireplumber.profiles = { main = {
  monitor.alsa = disabled, monitor.alsa-midi = disabled, monitor.bluez = disabled,
  monitor.bluez.seat-monitoring = disabled, monitor.v4l2 = disabled, monitor.libcamera = disabled,
  support.logind = disabled, support.dbus = disabled, support.reserve-device = disabled,
  support.portal-permissionstore = disabled
} }
C
export HOME=$T/home XDG_RUNTIME_DIR=$T/run XDG_CONFIG_HOME=$T/cfg XDG_DATA_HOME=$T/data XDG_STATE_HOME=$T/state
export DBUS_SESSION_BUS_ADDRESS=unix:path=$T/nobus PULSE_SERVER=unix:$T/run/pulse/native
unset PIPEWIRE_REMOTE PULSE_RUNTIME_PATH
pipewire > "$T/pw.log" 2>&1 & P1=$!
sleep 0.5
wireplumber > "$T/wp.log" 2>&1 & P2=$!
pipewire-pulse > "$T/pp.log" 2>&1 & P3=$!
sleep 1.5
trap 'kill $P3 $P2 $P1 2>/dev/null; sleep 0.3; rm -rf "$T"' EXIT
pactl load-module module-null-sink sink_name=fakehw >/dev/null
pw-loopback --capture-props='{ node.name = mix_in media.class = Audio/Sink }' \
  --playback-props='{ node.name = mix_out target.object = fakehw }' & P4=$!
pactl set-default-sink "$([ "${NOMIXER:-}" ] && echo fakehw || echo mix_in)"
sleep 0.8
python3 -c "
import wave,struct
w=wave.open('$T/beep.wav','w');w.setnchannels(2);w.setsampwidth(2);w.setframerate(48000)
w.writeframes(b'\0\0\0\0'*2400)"
cp "$(command -v pactl)" "$T/bin/discord"
"$T/bin/discord" subscribe > "$T/discord.events" 2>&1 & P5=$!
sleep 0.8
echo "discord sees before:"; "$T/bin/discord" list sink-inputs | grep -E "node.name|application.name" | sed "s/^/   /"
PL=(); for i in $(seq 30); do paplay -d mix_in "$T/beep.wav" & PL+=($!); sleep 0.07; done; wait "${PL[@]}"
sleep 1
echo "others see: $(pactl list sink-inputs | grep -c 'Sink Input') now (paplay done)"
NEW=$(grep -c "'new' on sink-input" "$T/discord.events"); RM=$(grep -c "'remove' on sink-input" "$T/discord.events")
echo "discord heard: new sink-input $NEW, remove $RM (of 30 programs' streams)"
VISIBLE=$("$T/bin/discord" list sink-inputs | grep -c 'node.name = "mix_out"')
echo "discord sees the system mix loopback: $VISIBLE"
grep -h "Discord client" "$T/wp.log" | head -2
grep -iE "angelos|lua|error" "$T/wp.log" | head -5; pw-cli ls Client 2>/dev/null | grep -E "process.binary|pipewire.protocol|access" | sort | uniq -c | head; kill $P5 $P4 2>/dev/null
cp "$(command -v paplay)" "$T/bin/discord-play"
"$T/bin/discord-play" "$T/beep.wav"; PLAYED=$?
SINKS=$("$T/bin/discord" list short sinks | wc -l)
echo "discord plays its own sound: exit $PLAYED; sees sinks: $SINKS"
if [ "${NOMIXER:-}${NOSHIELD:-}" ]; then WANT=30; else WANT=0; fi
[ "$NEW" = "$WANT" ] && [ "$VISIBLE" -ge 1 ] && [ "$PLAYED" = 0 ] && [ "$SINKS" -ge 1 ] && echo OK || echo FAIL
