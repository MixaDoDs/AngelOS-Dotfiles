# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── The devices' charge ──────────────────────────────────────────────────────

# The bar's ampoules ask a wireless mouse's dongle how much is left, over hidraw — root's alone
# on a fresh system, so the charge never showed. extras/hid-access is a udev rule and the helper
# it asks: only the makers angelOS can ask, of their devices only the configuration interface
# that carries no input or output report (the dongle's keyboard and mouse interfaces stay
# root's: nothing typed or moved can be read through the rule), and only to the user sitting at
# this computer (logind's ACL, uaccess) — never MODE=0666 and never a group. Headsets need
# nothing here: the headsetcontrol package brings its own rules.
HID_ACCESS="$ROOT/.config/quickshell/angelos/extras/hid-access/install.sh"
# missing | old | ok, "" when this checkout has no such thing or it is switched off
hid_access_state() {
  [[ "$DESKTOP_SHELL" == angelos && -f "$HID_ACCESS" ]] || return 0
  ANGELOS_SYSROOT="$SYSROOT" sh "$HID_ACCESS" --status 2>/dev/null || true
}
device_access() {
  [[ "$DEVICE_ACCESS" == 1 ]] || return 0
  local state
  state="$(hid_access_state)"
  [[ -n "$state" && "$state" != ok ]] || return 0
  if [[ -n "$SYSROOT" ]]; then
    ANGELOS_SYSROOT="$SYSROOT" sh "$HID_ACCESS" >/dev/null
  elif ((EUID == 0)); then
    sh "$HID_ACCESS" >/dev/null
  elif command -v sudo >/dev/null 2>&1 && { [[ -t 0 ]] || sudo -n true 2>/dev/null; }; then
    sudo sh "$HID_ACCESS" >/dev/null
  else
    false
  fi || {
    warn "$(_ "the devices' charge: the udev rule was not installed (no admin password here) — Settings → Devices → Device charge offers it" \
             "заряд устройств: правило udev не поставлено (здесь не спросить пароль администратора) — его предложат Настройки → Устройства → Заряд устройств")"
    return 0
  }
  say "$(_ "the devices' charge: a mouse's dongle may be asked — its service interface only, by the user at the seat only" \
          "заряд устройств: донгл мыши можно спрашивать — только служебный интерфейс и только пользователю за этим компьютером")"
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 60 device_access "the devices' charge" "заряд устройств"
