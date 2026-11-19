# Tooling isolation — .venv vs podman vs distrobox/toolbox

Default: heavy, hostile, or footprint-heavy tooling does NOT run on the main host.
Three tiers, pick the lowest that fits:

| Tier | Where | Use for | Examples |
|---|---|---|---|
| 0 | repo `.venv` (Python 3.12) | pure-python CLIs that integrate with repo scripts | impacket examples, netexec, certipy, pwntools, mitm6 |
| 1 | `podman run --rm` (ephemeral) | one-shot scanners/parsers on engagement dirs | trivy, nuclei, single-binary go tools, untrusted challenge binaries |
| 2 | distrobox / toolbox (persistent) | full toolchains, GUI apps, apt/pacman-package-heavy stacks | metasploit, burpsuite, BloodHound+neo4j, gdb+pwndbg, wordlist installs |

Rules that hold in every tier: run from repo root so `skills/pentest/scripts/scope.py`
and relative paths work; the scope gate applies before a container touches a client
target; evidence lands in `work/<eng>/evidence/` (mount it in). Containers isolate
the HOST, not the client from noise — rates and lockout rules still apply.

## Agent ↔ container communication

No daemon, no SSH, no new protocol. The agent session runs on the host;
containers are tool executors. Three channels, in order of preference:

| Channel | Tier 1 (podman) | Tier 2 (distrobox) |
|---|---|---|
| Files (default) | bind-mount the workspace: `-v "$PWD:/work:Z" --userns=keep-id` | `$HOME` is shared by default — workspace is already visible |
| Process I/O (one-shots) | agent shell runs `podman run --rm ...` sync; stdout/stderr/exit code are the result — drop `-it` when agent-driven | `distrobox-enter offsec -- <cmd>`; same sync semantics |
| Loopback TCP (services) | publish explicitly: `-p 127.0.0.1:8080:8080` | box shares the host netns — a service in the box is already on `localhost`, no `-p` |

Discipline:

- The workspace path is the contract: tools take inputs from and write outputs
  to `work/<eng>/` (evidence via `tee`), so provenance survives regardless of
  where the tool ran. `podman cp` is a smell — mount instead.
- Long-runners (responder, mitm6, msf handlers): hold them in the agent's pty
  shell via `distrobox-enter offsec -- responder -I eth0 ... 2>&1 | tee
  work/<eng>/evidence/responder-<date>.log` — evidence capture doubles as the
  output channel. Don't daemonize what you can't read.
- GUIs are for the human (`distrobox-export --app`); the agent drives the same
  stack through CLI/API: `msfconsole -q -r batch.rc` (resource files = files as
  IPC), Burp's REST API on the published loopback port, BloodHound CE API.
- Anti-patterns: SSH into boxes, `podman exec` into a sleeping daemon for
  one-shots, tmux-inside-the-box as the agent's channel (the agent's own shell
  is already persistent), sockets/FIFOs in the workspace.

## Tier 1 — podman one-shots

```bash
# scanner over an engagement dir; :Z handles SELinux relabeling, --userns=keep-id keeps file ownership sane
podman run --rm -it -v "$PWD:/work:Z" --userns=keep-id \
  docker.io/aquasec/trivy:latest fs --scanners vuln,secret,misconfig /work/client-source

# untrusted challenge binary (CTF arm): no network by default
podman run --rm -it -v "$PWD:/work:Z" --network none localhost/offsec-sandbox:latest /work/chal

# network tools that must reach the client: host network + minimal caps, target still scope-gated first
podman run --rm -it --network host --cap-add NET_RAW --cap-add NET_ADMIN \
  localhost/offsec-nmap:latest -sV -p 80,443 --max-rate 100 <target>
```

## Why not MCP

An MCP server per tool would re-wrap CLIs the shell already runs, freeze flag
surfaces that change upstream, and add a standing process with its own network
path — one that can be invoked without the `scope.py check` precondition. MCP
pays off when the runtime can't shell out, the tool surface is stable and
schema-worthy, or several agent sessions share one service; here the shell is
the tool protocol, files are the data plane, and skills document the interface.
The host-side agent-browser MCP already covers the one genuinely stateful GUI
surface (web), reaching containerized Burp via the loopback port. If agents
ever run in a terminal-less runtime, add ONE wrapper exposing the tier-1
`podman run` entrypoint — not per-tool adapters.

Pin images by digest for repeatability on real engagements (report lists exact
tool versions): `docker.io/aquasec/trivy@sha256:<digest>`. Build tiny local images
for go tools when upstream publishes none (most projectdiscovery tools): a 6-line
Containerfile on `docker.io/library/golang` with `go install` beats chasing distro
packages. Raw-socket and link-local work (nmap -sS, responder, mitm6, DHCPv6 races)
does not fit one-shot podman well — use tier 2.

## Tier 2 — distrobox (persistent box, Kali or Arch image)

```bash
sudo pacman -S distrobox                                        # one-time
distrobox create --name offsec --image docker.io/kalilinux/kali-rolling
distrobox enter offsec
# inside (home is shared with the host by default):
sudo apt update && sudo apt install -y metasploit-framework burpsuite seclists
distrobox-export --bin /usr/bin/msfconsole --export-path ~/.local/bin   # host-side launcher
distrobox-export --app burpsuite                                        # GUI app menu entry
```

- GUI works (Wayland/X11 sockets forwarded) — Burp, BloodHound, ghidra run fine.
- Home is shared host↔box: engagement loot stays in `work/<eng>/` (still the only
  place credentials live), but assume anything in $HOME is reachable from inside.
- Use `--unshared` (`distrobox create --unshared`) when the box should NOT see
  host home — then mount only the repo dir explicitly.
- Optional teardown: `distrobox rm offsec` (+ `podman image rm docker.io/kalilinux/kali-rolling`). Keeping the box costs disk only.
- toolbox (`sudo pacman -S toolbox`): same idea, Arch-native image; fine for
  host-distro tooling, distrobox wins when you need Kali/Debian packages.

BloodHound stack example (GUI tier 2): neo4j + BloodHound CE via upstream compose
or AUR inside the box; collectors stay tier 0 (`bloodhound-python` in `.venv`) —
collectors touch the client, GUI doesn't, so the split keeps the noisy part lean.

## Why not devcontainer

devcontainer is editor-centric (VS Code session lifecycle). This suite is driven
by the agent + shell; a persistent distrobox gives the same isolation with less
machinery. If a repo ships `.devcontainer/` anyway, `podman compose` or
`devcontainer` CLI against podman works, but don't add one for this suite.

## Lifecycle — nothing to uninstall

Dormant tooling is inert: no autostart, no services — disk is the only cost.
Default is keep everything; removal, when wanted, is wholesale per layer, never
per-tool `pacman -R` archaeology:

| Layer | Holds | Optional wholesale removal |
|---|---|---|
| `.venv` | every Python tool (pwntools, impacket, netexec, certipy...) | `rm -rf .venv` — `scripts/setup.sh` rebuilds |
| podman images | scanners, go tools, sandbox images | `podman image prune` (dangling) or `podman image rm <img>` |
| distrobox `offsec` | the whole apt stack (msf, burp, seclists) | `distrobox rm offsec` — host untouched |

- Host pacman installs are the one exception: they persist until removed by
  hand. Skill toolbox rows list host installs for convenience; the decision
  rule is — host only what you use day-to-day (nmap, gdb, file, rlwrap), park
  event-only heavyweights (sagemath, metasploit, hashcat) in tier 2 so the
  event ends with `distrobox rm` … or nothing.
- `work/<eng>/` workspaces stay until you delete them. For pentest engagements
  only the contractual client-data destruction clause forces deletion of raw
  loot/creds — on the contract's schedule, not as post-event housekeeping.
- Record image digests used in the report (methodology section).
- Never bake client data, creds, or engagement artifacts into images.
