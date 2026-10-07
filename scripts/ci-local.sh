#!/usr/bin/env bash
# The GitHub check (.github/workflows/angelos.yml) run here, the way GitHub runs it:
# the job's container image as root, the tree as a fresh commit owned by another
# user, CI_CPUS CPUs (all by default), `bash -e` per step, the first failing step ends the job. The steps
# before actions/checkout set the machine up (packages) and are baked into a cached
# image — rebuilt when they change or when it is a week old, since the workflow
# installs from the rolling archlinux:latest. A tool the workflow doesn't install
# is missing here as well, so "passes on my machine, fails on GitHub" shows up
# before the push.
#
#   scripts/ci-local.sh [TREE]     TREE = a checkout of the repo (default: this one),
#                                  its files as `git add -A` would commit them
#   CI_ENGINE=docker|podman …      the container engine (default: whichever is found)
#   CI_IMAGE_MAX_AGE=168 …         hours before the package image is rebuilt (a rebuild takes minutes;
#                                  a changed package list rebuilds it at once)
#   CI_REBUILD=1 …                 rebuild the package image now
#   CI_CPUS=4 …                    CPUs for the job (default: all of this machine's; GitHub's
#                                  ubuntu-latest has 4 — CI_CPUS=4 for its pace)
#   CI_HISTORY=path …              a clone whose history the old-install update tests take their
#                                  old commits from (default: TREE's own .git) instead of GitHub
#   CI_MIRRORLIST=/etc/pacman.d/mirrorlist …   pacman mirrors for the package image (default:
#                                  this machine's, when it has one; "none" keeps the image's)
#   CI_NETWORK=host …              container network (host: a VPN's tun route on this
#                                  machine is used by the container as well)
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TREE="$(cd -- "${1:-$ROOT}" && pwd -P)"
WORKFLOW="$TREE/.github/workflows/angelos.yml"
say() { printf '[ci] %s\n' "$*"; }
die() { printf '[ci] FAIL %s\n' "$*" >&2; exit 1; }

[[ -f "$WORKFLOW" ]] || die "no workflow: $WORKFLOW"
ENGINE="${CI_ENGINE:-}"
if [[ -z "$ENGINE" ]]; then
  for e in docker podman; do command -v "$e" >/dev/null 2>&1 && { ENGINE="$e"; break; }; done
fi
[[ -n "$ENGINE" ]] || die "no docker or podman — the GitHub check can't be reproduced here"
"$ENGINE" info >/dev/null 2>&1 || die "$ENGINE doesn't answer (is the daemon running, is $(id -un) allowed to use it?)"

W="$(mktemp -d)"
CONTAINER="angelos-ci-$$"
cleanup() { "$ENGINE" rm -f "$CONTAINER" >/dev/null 2>&1 || true; rm -rf -- "$W"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

# ── the workflow → setup script, step scripts ───────────────────────────────
# Anything this can't do the way GitHub does (if:, other actions, expressions)
# is refused, so the local run never quietly differs from the real one.
python3 - "$WORKFLOW" "$W" <<'PY' || die "can't reproduce $WORKFLOW locally (see above)"
import json, pathlib, re, shlex, sys
try:
    import yaml
except ImportError:
    sys.exit("python-yaml is needed to read the workflow")
wf, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
doc = yaml.safe_load(wf.read_text())
WS = "/__w/AngelOS-Dotfiles/AngelOS-Dotfiles"
known = {"name", "run", "shell", "env", "working-directory", "uses", "with"}

def expand(text, where):
    def sub(m):
        expr = m.group(1).strip()
        if expr == "github.workspace":
            return WS
        sys.exit(f"{where}: expression ${{{{ {expr} }}}} is not supported by ci-local.sh")
    return re.sub(r"\$\{\{(.*?)\}\}", sub, text)

def exports(env, where):
    return "".join(f"export {k}={shlex.quote(expand(str(v), where))}\n" for k, v in (env or {}).items())

jobs = []
for jid, job in (doc.get("jobs") or {}).items():
    image = job.get("container")
    if isinstance(image, dict):
        image = image.get("image")
    if not image:
        sys.exit(f"job {jid}: no container: — only container jobs can be reproduced")
    for k in ("if", "strategy", "services", "defaults"):
        if k in job:
            sys.exit(f"job {jid}: '{k}' is not supported by ci-local.sh")
    base_env = exports(doc.get("env"), jid) + exports(job.get("env"), jid)
    setup, steps, checked_out = [], [], False
    for i, step in enumerate(job.get("steps") or []):
        name = step.get("name") or step.get("uses") or (step.get("run") or "").splitlines()[0]
        where = f"job {jid}, step {name!r}"
        extra = set(step) - known
        if extra:
            sys.exit(f"{where}: {', '.join(sorted(extra))} not supported by ci-local.sh")
        if "uses" in step:
            if not str(step["uses"]).startswith("actions/checkout@"):
                sys.exit(f"{where}: action {step['uses']} is not supported by ci-local.sh")
            checked_out = True
            continue
        shell = step.get("shell", "")
        if shell in ("", None):
            head = "set -e\n"
        elif shell == "bash":
            head = "set -eo pipefail\n"
        else:
            sys.exit(f"{where}: shell {shell!r} is not supported by ci-local.sh")
        body = head + base_env + exports(step.get("env"), where)
        if step.get("working-directory"):
            body += f"cd {shlex.quote(expand(step['working-directory'], where))}\n"
        body += expand(step["run"], where) + "\n"
        if checked_out:
            path = out / f"{jid}-{len(steps):02d}.sh"
            path.write_text(body)
            steps.append({"name": name, "script": path.name, "bash": "--noprofile --norc" if shell == "bash" else ""})
        else:
            setup.append(body)
    if not checked_out:
        sys.exit(f"job {jid}: no actions/checkout step")
    (out / f"{jid}-setup.sh").write_text("#!/bin/bash\n" + "\n".join(f"( {s} )" for s in setup))
    jobs.append({"id": jid, "image": image, "steps": steps})
(out / "jobs.json").write_text(json.dumps(jobs))
PY

ENGINE_FLAGS=(--network "${CI_NETWORK:-host}")
CPUS="${CI_CPUS:-$(nproc 2>/dev/null || echo 4)}"
# fewer CPUs than here: pinned to that many, so nproc inside says so too (as on GitHub)
(( CPUS < $(nproc 2>/dev/null || echo 4) )) && ENGINE_FLAGS+=(--cpuset-cpus "0-$((CPUS - 1))")
# the old commits scripts/test-update-old.sh installs from: lent read-only, not fetched from GitHub
HISTORY="$(git -C "${CI_HISTORY:-$TREE}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [[ -n "$HISTORY" && -d "$HISTORY/objects" ]]; then
  ENGINE_FLAGS+=(-v "$HISTORY:/ci-history:ro" -e UPDATE_OLD_REPO=/ci-history)
fi

WS=/__w/AngelOS-Dotfiles/AngelOS-Dotfiles
MAX_AGE_H="${CI_IMAGE_MAX_AGE:-168}"
start=$SECONDS
njobs=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$W/jobs.json")
for ((j = 0; j < njobs; j++)); do
  read -r JOB IMAGE < <(python3 -c 'import json,sys; j=json.load(open(sys.argv[1]))[int(sys.argv[2])]; print(j["id"], j["image"])' "$W/jobs.json" "$j")

  # ── the package image: FROM the job's image + the setup steps ──────────────
  key=$(cat <(printf '%s\n' "$IMAGE") "$W/$JOB-setup.sh" | sha256sum | cut -c1-12)
  TAG="angelos-ci:$JOB-$key"
  created=$("$ENGINE" image inspect -f '{{.Created}}' "$TAG" 2>/dev/null || true)
  age_h=999999
  [[ -n "$created" ]] && age_h=$(( ($(date +%s) - $(date -d "$created" +%s)) / 3600 ))
  if [[ "${CI_REBUILD:-0}" == 1 || "$age_h" -ge "$MAX_AGE_H" ]]; then
    say "job $JOB: building the package image $TAG from $IMAGE (setup steps, pacman -Syu)…"
    mkdir -p "$W/ctx"
    cp "$W/$JOB-setup.sh" "$W/ctx/setup.sh"
    printf 'FROM %s\nLABEL angelos-ci=1\n' "$IMAGE" >"$W/ctx/Containerfile"
    # the mirrors that work from here (the image's default ones may be slow or blocked
    # on this network); the packages are the same Arch packages either way
    mirrors="${CI_MIRRORLIST:-/etc/pacman.d/mirrorlist}"
    if [[ "$mirrors" != none && -f "$mirrors" ]] && grep -q '^Server' "$mirrors"; then
      grep '^Server' "$mirrors" >"$W/ctx/mirrorlist"
      printf 'COPY mirrorlist /etc/pacman.d/mirrorlist\n' >>"$W/ctx/Containerfile"
    fi
    printf 'COPY setup.sh /tmp/angelos-ci-setup.sh\nRUN bash -e /tmp/angelos-ci-setup.sh && rm -f /tmp/angelos-ci-setup.sh && rm -rf /var/cache/pacman/pkg/*\n' >>"$W/ctx/Containerfile"
    if ! "$ENGINE" build --network "${CI_NETWORK:-host}" --pull --force-rm -q -t "$TAG" -f "$W/ctx/Containerfile" "$W/ctx" >"$W/build.log" 2>&1; then
      tail -40 "$W/build.log" >&2
      die "job $JOB: the setup steps failed — a wrong package in the workflow fails on GitHub too, a mirror/network error doesn't (try again, or CI_MIRRORLIST=…)"
    fi
    # older package images of this job (other setup steps) are no longer needed
    "$ENGINE" images --format '{{.Repository}}:{{.Tag}}' angelos-ci 2>/dev/null | grep "^angelos-ci:$JOB-" | grep -vx "$TAG" \
      | xargs -r "$ENGINE" rmi -f >/dev/null 2>&1 || true
    "$ENGINE" image prune -f --filter label=angelos-ci=1 >/dev/null 2>&1 || true
  else
    say "job $JOB: package image $TAG (${age_h} h old)"
  fi

  # ── the job: the tree as a fresh commit, then the steps in order ───────────
  {
    printf 'set -e\nmkdir -p %s /github/home /__w/_temp\ncd %s\ntar -xf -\n' "$WS" "$WS"
    printf 'git -c init.defaultBranch=main init -q && git add -A && git -c user.name=ci -c user.email=ci@invalid -c commit.gpgsign=false commit -qm ci-local\n'
    # GitHub's checkout belongs to the runner (uid 1001), not to the container's root
    printf 'chown -R 1001:1001 /__w\nset +e\n'
    python3 - "$W/jobs.json" "$j" <<'PY'
import json, shlex, sys
job = json.load(open(sys.argv[1]))[int(sys.argv[2])]
for s in job["steps"]:
    n = shlex.quote(s["name"])
    print(f'printf "\\n[ci] ── %s\\n" {n}; t=$SECONDS')
    print(f'(cd "$GITHUB_WORKSPACE" && bash {s["bash"]} -e /ci/{s["script"]}); rc=$?')
    print(f'if [ $rc -ne 0 ]; then printf "[ci] FAIL step %s (exit %d)\\n" {n} $rc; exit $rc; fi')
    print(f'printf "[ci] OK   %s (%ds)\\n" {n} $((SECONDS - t))')
PY
  } >"$W/$JOB-run.sh"

  say "job $JOB: $(git -C "$TREE" ls-files -co --exclude-standard | wc -l) files, $(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))[int(sys.argv[2])]["steps"]))' "$W/jobs.json" "$j") steps, $CPUS CPUs"
  set +e
  git -C "$TREE" ls-files -co --exclude-standard -z \
    | while IFS= read -r -d '' f; do [[ -e "$TREE/$f" || -L "$TREE/$f" ]] && printf '%s\0' "$f"; done \
    | tar -C "$TREE" --null --no-recursion -T - -cf - \
    | "$ENGINE" run --rm -i --name "$CONTAINER" "${ENGINE_FLAGS[@]}" \
        --cpus "$CPUS" -v "$W:/ci:ro" -w "$WS" \
        -e CI=true -e GITHUB_ACTIONS=true -e GITHUB_WORKSPACE="$WS" -e HOME=/github/home -e RUNNER_TEMP=/__w/_temp \
        "$TAG" bash -c "bash /ci/$JOB-run.sh"
  rc=$?
  set -e
  if ((rc)); then
    die "job $JOB failed — GitHub would fail the same way ($((SECONDS - start)) s)"
  fi
done
say "OK   the GitHub check passes here ($((SECONDS - start)) s)"
