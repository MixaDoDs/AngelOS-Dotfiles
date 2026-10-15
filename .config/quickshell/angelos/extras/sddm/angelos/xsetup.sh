#!/bin/sh
# angelOS: SDDM's display setup (X11 greeter), set as [X11] DisplayCommand in
# /etc/sddm.conf.d/zz-angelos.conf. First the system's own Xsetup (whatever it does: screens
# turned and placed), then the main screen picked in angelOS becomes X's primary and the
# pointer goes to its middle, where the password field is (xsetup.py). Never fails the login.
here="$(dirname "$0")"
if [ -x /usr/share/sddm/scripts/Xsetup ]; then
    /usr/share/sddm/scripts/Xsetup || true
fi
if command -v python3 >/dev/null 2>&1; then
    python3 -I "$here/xsetup.py" >/dev/null 2>/var/log/sddm-xsetup-angelos.log || true
fi
exit 0
