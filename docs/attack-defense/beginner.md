# Beginner 3-Person Attack-Defense Playbook

For teams in their first 1–3 A/D events. Optimized for: **don't lose points**.

## Doctrine

- Beginners lose far more points to broken checkers, broken patches, corrupted
  VMs, and a submitter that never ran than to not finding vulnerabilities.
- Event goal: **100 % SLA, zero panicked moments, one working farmed exploit by
  mid-game.** That alone finishes above half the field.
- Every checklist below is meant to be executed literally. When unsure between
  two actions, pick the one that is reversible.

## Roles (fixed, all event)

| Role | Person | Owns |
|---|---|---|
| **D** — Defense/Infra | most Linux-comfortable | VM, snapshots, capture, patches, monitoring |
| **A1** — Auditor | best code reader | service audit, exploits |
| **A2** — Auditor/Submitter | second reader | service audit, submitter, farm babysitting |

## Phase 0 — before the event

Setup checklist (per person, own laptop; brew works on macOS and Linux — on Arch
`pacman -S zellij btop htop docker` / `paru -S lazydocker` is the native path):

- [ ] brew (linuxbrew on Linux), zellij, btop/htop; lazydocker if the event uses Docker
- [ ] SSH client + VPN client (organizer's flavor) tested
- [ ] Team note repo (git) with `services.md`, `changes.md`, `vulns.md` created
- [ ] Scoreboard account verified; submission API/token tested with a fake flag
      (expected: "wrong flag" — proves the pipeline, costs nothing)
- [ ] Zellij layout: one pane ssh'd to gamebox, one for notes, one scratch

## Phase 1 — attack network locked

Work top-down; do not skip steps. Timestamps assume a 4–6 h locked phase.

| Time | Who | Task |
|---|---|---|
| 0:00–0:15 | all | **Rules read, together, out loud.** Write 5 facts into `services.md`: tick length, SLA weight, patch policy (source patches allowed? binary patching banned?), forbidden actions, scoreboard URL/token |
| 0:15–0:30 | D | **Snapshot the pristine VM** (§ snapshot card). Before any edit. No exceptions |
| 0:15–0:45 | D | **Service inventory table** (below) |
| 0:30–0:45 | all | **Flag + flag-id hunt** (below) |
| 0:45–1:00 | D | **Traffic capture on** (§ capture card) |
| 1:00–onward | A1, A2 | Audit services (§ beginner checklist); every finding → `vulns.md` |
| 1:00–onward | D | Baseline hardening + patch queue (§ hardening card) |
| last 45 min | all | **Dry run** (§ dry-run card) |

### Service inventory table (fill this in, it drives everything)

| Port | Process/binary | Source available? | Language | DB/store | Flag location | Flag-id input |
|---|---|---|---|---|---|---|
| | | | | | | |

Commands: `ss -tulpn` · `ps auxf` · `systemctl list-units --type=service` ·
`crontab -l` + `/etc/cron*` · `ls -la /opt /srv /app` · for each port:
`ls` the process's cwd and unit file.

### Flag + flag-id hunt

- Flag file: `ls -la /`, `/flag*`, `/root`, env (`cat /proc/*/environ`), any
  `get_flag`/`readflag` suid binaries.
- Flag ids: how does the checker tell your instance from others'? Usually an
  account name, a note ID, an order number listed per team on the scoreboard.
  Write the mapping `team → flag-id` for our services into `services.md`; the
  submitter/farm needs it later.
- Watch the checker hit your service once in the logs/pcap — that traffic is
  your template for "what legal traffic looks like".

### Beginner vulnerability checklist (audit with this open)

| Class | Grep for (source) | Quick test |
|---|---|---|
| SQL injection | `SELECT`, `query(`, `executemany`, string-concatenated SQL | `' OR 1=1--` in every input |
| Command injection | `system(`, `popen`, `subprocess`+`shell=True`, backticks | `;id`, `` `id` ``, `$(id)` |
| Path traversal | `open(`, `send_file`, `readFileSync` + user input | `../../../etc/passwd` |
| Auth bypass | session checks, `if user ==`, JWT verify calls | missing checks on /admin routes |
| Insecure deserialization | `pickle`, `unserialize`, `yaml.load` (no Loader), `ObjectInputStream` | craft payload locally |
| File upload | upload handlers, extension checks | upload `.php`/`.phtml`, double ext |
| SSRF | `requests.get(` + user URL | `http://localhost:PORT/` probes |

Rule: **validate every finding locally** (proof command + observed output into
`vulns.md`) before treating it as real. Half of beginner findings are misreads.

### Hardening card (D, phase 1)

- Change all passwords (`passwd`); check `/etc/passwd` for unknown UID-0 or
  stray accounts — **lock first** (`usermod -L x`), delete only if the game
  still works without them.
- SSH: no new keys we didn't add; organizer's checker access must survive.
- **Do not** firewall service ports or "harden" the service itself beyond the
  targeted patch — breaking reachability = failing SLA.
- Log every change in `changes.md`: time, file, before, after, why.
- Patch order: **config-level fix > minimal source fix**; one hunk per patch,
  pre-patch backup (`cp -a app /root/backups/app.pre-<vuln-id>`).
- After each patch: restart service, run the manual functional test, and if the
  organizer ships a checker — run the checker locally against our box.

### Snapshot card (D)

- VirtualBox/VMware: export appliance or clone → `golden-0` before first boot
  edit; tag again after patches: `patched-<n>`.
- Docker-based: `docker commit <id> golden-0` before editing containers;
  re-tag before every risky change.
- Keep the patch list in `changes.md` so a restored box can be re-patched by
  replaying the list in minutes.

### Capture card (D)

```sh
mkdir -p /root/capture
# one tcpdump per service port, rotated 100 MB files:
tcpdump -i any -s 0 -W 10 -C 100 -w /root/capture/svc-<port>.pcap port <port> &
```

- App logs: ensure the service logs requests (enable access log if off);
  `journalctl -u <svc> -f` in a zellij pane during phase 1.
- Verify: see the checker's requests in both pcap and logs. If capture can't
  see the checker, it won't see enemies either — fix placement now.
- Clocks: keep everything in event-local time; note the tick boundary times.

### Dry-run card (last 45 min, all)

- [ ] Every confirmed vuln: exploit runs against `localhost`, prints a flag —
      command saved in `vulns.md`
- [ ] Every patch applied → service restarts, functional test passes, checker
      (if shippable) passes
- [ ] Submitter: submits the locally-stolen flag once (a flag stolen from our
      own box is usually expired/invalid for scoring — fine, we're testing the
      pipeline, expect a clean "wrong/expired" response, not a crash)
- [ ] `golden-0` and `patched-<n>` images exist; `changes.md` is current
- [ ] Restore drill: restore snapshot on a scratch copy once, confirm boot

## Phase 2 — attack network unlocked

Rhythm = tick length. Every tick: farm fires, submitter posts, D checks health.

- **A1 (attack)**: one new vuln at a time: confirm locally → write exploit →
  add to farm → move on. Never debug against enemy boxes.
- **A2 (farm + audit)**: babysit farm runs; read failures; when stable, join
  A1's audit queue.
- **D (defense)**: each tick, in order: (1) scoreboard SLA status of our
  services, (2) `journalctl`/logs since last tick for anomalies, (3) new pcap
  around anomalies — filter out checker + own IPs; anything left is an enemy.
  On enemy hit: reproduce on local replica → patch (hardening card) → test →
  deploy → `vulns.md` + `changes.md` updated.

### Emergency card (tape this to the wall)

| Symptom | Action |
|---|---|
| Our service down | Restore from `patched-<n>` (minutes), not `golden-0` (loses patches); reboot timer running |
| Checker fails after our patch | Roll back that one patch (pre-patch backup), re-think off-box |
| VM corrupted/unbootable | Redeploy `patched-<n>`; if none, `golden-0` + replay `changes.md` |
| Farm erroring across all teams | Network/VPN issue — check that first; don't touch exploits |
| We find an org-backdoor user re-added | Lock it, snapshot diff what recreated it (cron? systemd timer?) |

## Top-10 beginner failure modes

1. No snapshot → one bad patch ends the event.
2. Patch breaks checker → SLA 0 for hours, unnoticed.
3. Nobody watches the scoreboard SLA column → dead service for N ticks.
4. Exploit "works" untested → first live run leaks a broken 0-day in enemy pcaps.
5. Submitter written at unlock → an hour of ticks with no attack points.
6. Capture never verified → pcaps exist but miss the exploit path.
7. Hardening that breaks reachability (firewall, service rewrite) — treated as defense, actually suicide.
8. Debugging exploits against enemy boxes → leaks + organizer warnings.
9. No `changes.md` → after a restore, nobody can reproduce yesterday's patches.
10. All three on one juicy vuln, zero coverage of the other services.

## Submitter policy

- Submit promptly; keep proof (exploit output, pcap snippet) per flag in case of
  disputes. Only flags from exploitation of in-scope instances — never guess
  formats or resubmit stale flags (some scoreboards penalize).
