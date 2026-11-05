#!/usr/bin/env bash
# mkarchiso runs this in the image's chroot (as root): angelOS is installed by its own install.sh,
# as the live user angel, exactly as on a user's machine. Nothing machine-specific may stay behind:
# inside.sh fails the build when a keyring, SSH host keys or a machine-id are left in the image.
# shortcut: customize_airootfs.sh is deprecated in archiso 92 (still supported), move to a pacman hook if it goes
set -Eeuo pipefail

# pacstrap -G leaves the chroot without a keyring: a temporary one for install.sh's pacman, removed below
pacman-key --init >/dev/null
pacman-key --populate archlinux >/dev/null
# the chroot is no mount point: pacman can't size its cache dir and refuses ("not enough free disk space")
sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

useradd -m -u 1000 -G wheel,video,audio,input -s /bin/bash angel
passwd -d angel >/dev/null
# the live user is root without a password (the installer needs it); the installed system gets a real one
printf 'angel ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/00-live
chmod 440 /etc/sudoers.d/00-live

mkdir /home/angel/AngelOS-Dotfiles
tar -xf /root/angelos-src.tar -C /home/angel/AngelOS-Dotfiles
rm /root/angelos-src.tar
git -c safe.directory='*' -C /home/angel/AngelOS-Dotfiles remote set-url origin https://github.com/MixaDoDs/AngelOS-Dotfiles.git
chown -R angel:angel /home/angel

# shortcut: no CachyOS repos, apps, games, voice model or wallpaper packs yet (size first), revisit with the size budget
su - angel -c 'cd ~/AngelOS-Dotfiles && INTERACTIVE=0 NO_MUSIC=1 NO_ANIM=1 ANGELOS_SELF_UPDATE=0 \
  CACHYOS_REPOS=0 INSTALL_APPS=0 INSTALL_GAMING=0 GITHUB_LOGIN=0 \
  INSTALL_VOXTYPE=0 DOWNLOAD_VOXTYPE_MODEL=0 WALLPAPER_PACKS=none FISH_DEFAULT=0 \
  ./install.sh </dev/null'
# install.sh only warns when pacman fails (a user's next update retries); an image without them is broken
pacman -Q quickshell sddm niri >/dev/null
[[ -x /home/angel/.local/bin/niri ]]   # angel-niri (scripts/angel-niri-install.sh links it there)
sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf
# a user's machine has its network up before install.sh; here nothing would bring it up
systemctl enable NetworkManager.service

# machine-specific state out: each boot / each installed system makes its own
rm -rf /etc/pacman.d/gnupg /etc/ssh/ssh_host_* /var/cache/pacman/pkg/* /home/angel/.cache
: >/etc/machine-id
