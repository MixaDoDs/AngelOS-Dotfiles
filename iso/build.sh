#!/usr/bin/env bash
# Builds the angelOS live ISO (the shell: GitHub's main; the image profile: this tree's iso/) in a throwaway Arch
# container: mkarchiso needs root, the host needs only docker. The system inside the image is
# installed by install.sh itself (iso/profile/airootfs/root/customize_airootfs.sh), so the ISO and
# the script never drift apart.
#
#   iso/build.sh                 → ~/Work/AngelOS/export/iso/angelos-<date>-x86_64.iso
#   OUT=/some/dir iso/build.sh
#   BRANCH=iso-1105 iso/build.sh  (the shell from a local branch, for tests)
#
# Packages are cached between builds in the docker volume angelos-iso-pkg; the work tree lives in
# the volume angelos-iso-work and is wiped at the start of every build.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO="$(cd -- "$HERE/.." && pwd -P)"
OUT="${OUT:-$HOME/Work/AngelOS/export/iso}"
die() { printf '✕ %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || die "no docker"
mkdir -p "$OUT"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/angelos-iso.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

# the source as a user gets it: a shallow clone of GitHub's main (Settings → Updates fetches main into it,
# and angelos-install-disk copies this clone onto the new disk). BRANCH=<local branch>: that branch's
# committed HEAD instead — for tests only, a system installed from it has no branch to update from
if [[ -n "${BRANCH:-}" ]]; then
  git clone -q --depth 1 --branch "$BRANCH" "file://$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" "$STAGE/src"
else
  git clone -q --depth 1 --branch main https://github.com/MixaDoDs/AngelOS-Dotfiles.git "$STAGE/src"
fi
cp -r "$HERE/profile" "$STAGE/profile"
grep '^Server' /etc/pacman.d/mirrorlist >"$STAGE/mirrorlist" 2>/dev/null || true

# --privileged: pacstrap mounts /proc, /dev… in the chroot; --network host: the VPN route, as ci-local.sh
docker run --rm --privileged --network host \
  -v "$STAGE:/stage:ro" -v "$OUT:/out" \
  -v angelos-iso-pkg:/var/cache/pacman/pkg -v angelos-iso-work:/work \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  archlinux:latest bash /stage/profile/inside.sh
