#!/usr/bin/env bash
# Runs inside the build container (iso/build.sh): Arch's releng profile + angelOS's overlay → mkarchiso.
set -Eeuo pipefail

[[ -s /stage/mirrorlist ]] && cp /stage/mirrorlist /etc/pacman.d/mirrorlist
pacman -Syu --noconfirm --needed archiso git >/dev/null

P=/work/profile
rm -rf /work/*
cp -r /usr/share/archiso/configs/releng "$P"
cp /etc/pacman.d/mirrorlist "$P/airootfs/etc/pacman.d/mirrorlist"

# releng's live is root on tty1 with the install guide; ours is the angel user's angelOS session
rm -f "$P/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf" \
      "$P/airootfs/root/.zlogin" "$P/airootfs/root/.automated_script.sh" \
      "$P/airootfs/etc/motd"
sed -i '/automated_script\|livecd-sound\|Installation_guide/d' "$P/profiledef.sh"
# releng's rescue services out: ours is a desktop (NetworkManager, no sshd, no cloud-init, no VM tools of
# other hypervisors); the installed system is a copy of this one, so nothing rescue-only may stay
S="$P/airootfs/etc/systemd/system"
rm -rf "$S"/{cloud-init,network-online,sockets,sound}.target.wants "$S"/systemd-networkd-wait-online.service.d \
       "$S"/livecd-*.service "$S"/dbus-org.freedesktop.{ModemManager1,network1}.service \
       "$P/airootfs/etc/systemd/network" "$P/airootfs/usr/local/bin"/{livecd-sound,Installation_guide} \
       "$P/airootfs/usr/local/share/livecd-sound"
find "$S/multi-user.target.wants" -mindepth 1 ! -name pacman-init.service ! -name choose-mirror.service \
     ! -name systemd-resolved.service -delete

cp -rT /stage/profile/airootfs "$P/airootfs"
cp /stage/profile/packages.x86_64 "$P/packages.x86_64"   # ours replaces releng's rescue set
# the live only runs the installer (the installed system is built afresh by install.sh): no docs, en/ru only
sed -i '/^\[options\]/a NoExtract = usr/share/doc/* usr/share/man/* usr/share/info/* usr/share/help/* usr/share/gtk-doc/*\nNoExtract = usr/share/locale/* !usr/share/locale/ru/* !usr/share/locale/en*' "$P/pacman.conf"
# a tarball: mkarchiso copies airootfs with --no-preserve=mode, the scripts would lose their x bit
tar -C /stage/src -cf "$P/airootfs/root/angelos-src.tar" .
cat /stage/profile/profiledef.override >>"$P/profiledef.sh"   # name, label, permissions

mkarchiso -v -w /work/w -o /work/out "$P"

# every machine makes its own keys: none may ship in the image (a shared pacman key = anyone signs for everyone)
R=/work/w/x86_64/airootfs
leak=$(find "$R/etc/pacman.d/gnupg" "$R/etc/ssh" -maxdepth 1 \( -name 'private-keys*' -o -name 'secring*' -o -name 'ssh_host_*' \) 2>/dev/null || true)
# empty or "uninitialized" = systemd makes a new one on the first boot
[[ ! -s "$R/etc/machine-id" || "$(<"$R/etc/machine-id")" == uninitialized ]] || leak+=" $R/etc/machine-id"
[[ -z "${leak// }" ]] || { echo "✕ machine-specific secrets in the image: $leak" >&2; exit 1; }
iso=$(ls /work/out/*.iso)
install -o "$HOST_UID" -g "$HOST_GID" -m 644 "$iso" /out/
echo "ISO: /out/$(basename "$iso") $(du -h "$iso" | cut -f1)"
