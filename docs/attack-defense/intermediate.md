# Intermediate 3-Person Attack-Defense Playbook

For teams past the basics. Adds on top of [beginner.md](beginner.md) (still
applies: snapshot discipline, checker protection, dry run, emergency cards):
**parallel patch+exploit, traffic-driven defense, a real farm, point-rate
prioritization.** Phase-0/1 fundamentals below only where they change.

## Doctrine

- Phase 2 runs on rails built in phase 1: exploit modules, patch harness, farm
  loop, monitoring. Building any of them after unlock is a failure of phase 1.
- Every enemy attack seen in our pcap is a free 0-day: replicate → patch →
  weaponize → add to farm. This loop is the highest-ROI activity in the game.

## Roles (functional, people rotate through them)

| Role | Owns | Success metric |
|---|---|---|
| **Vuln lead** | audit, weaponization, exploit modules | new farmed vuln every 2–4 h |
| **Defense lead** | patch harness, pcap triage, SLA | enemy exploit reproduced+patched < 30 min from pcap hit |
| **Infra lead** | farm, submitter, monitoring, images | farm uptime ≈ 100 %, zero missed ticks |

Pairing: with only 3 people, infra lead doubles as second auditor when the farm
is stable; defense lead doubles as submitter when pcaps are quiet.

## Phase 1 — locked (what changes vs beginner)

Same opening (rules → snapshot → inventory → flags/ids → capture), then:

### Patch harness (defense lead, build by hour 2)

A script, run before **every** deploy:

```
patch-test <service>:
  1. docker/VM: spin a scratch copy of the CURRENT patched image
  2. apply candidate patch
  3. functional test: replay checker-like requests (recorded in phase 1) + manual happy path
  4. attack test: our exploit (and any enemy pcap payload) must now FAIL
  5. exit green → deploy to live box; exit red → patch never touches the gamebox
```

- Record the checker's request sequence once (from logs/pcap) — that recording
  *is* your regression suite.
- Keep per-patch backups; `changes.md` gets one line per hunk (id, file, diff,
  test result). Rollback = stop at any step.

### Farm architecture (infra lead, built in phase 1)

```
farm loop, every tick:
  for each exploit module (ordered by yield):
    for each team (parallel, cap concurrency):
      run exploit(team's flag-id) → flag | error
  submitter: post new flags (hash-dedup store), retry-once on 5xx, cooldown on repeated failures
  report: per-module success rate → dashboard pane
```

- Exploit module contract: `exploit(host, flag_id) -> flag or raise`, pure
  function, no interactive state, 10 s timeout. Written the moment a vuln is
  confirmed — not "later".
- Dedupe: never resubmit a flag hash; keep `flag_id → last flag, tick` state.
- Failure policy: a module failing >30 % of teams gets quarantined and debugged
  **locally**; the farm keeps running the rest.
- Farm must survive its own crash: idempotent, stateless between ticks except
  the dedupe store.

### Audit split (vuln lead + infra lead when free)

- Split by service, not by vuln class — one brain holds one service's full
  attack surface.
- Timebox per service: 45 min deep audit, then triage mode (checklist greps,
  route handling, auth surfaces) and move on; return only if nothing else left.
- Every finding: `vulns.md` row = `id | service | class | root cause | exploit
  cmd | patched (commit) | farmed (module) | notes`.

## Phase 2 — unlocked

### Tick rhythm

- **Every tick**: farm fires; submitter posts; health check (SLA column +
  service probes); pcap delta triage.
- **Every 30 min**: 3-way sync (2 min, standing): new vulns? new enemy attacks?
  anything red? Re-split work.
- **Every 3–4 h**: rotate roles; break. Tired teammate = broken patch.

### Pcap triage workflow (defense lead)

```sh
# enemy traffic on service port = not checker, not our subnets:
tshark -r svc-<port>.pcap -Y "!(ip.addr==CHECKER_IP) && !(ip.addr==OUR_SUBNET)" \
       -T fields -e frame.time -e ip.src -e tcp.stream
# pull the suspicious streams:
tshark -r svc-<port>.pcap -q -z follow,tcp,ascii,<stream#>
```

- Anything anomalous → replay payload against local replica → if it pops:
  patch (harness), weaponize (module), notify vuln lead for farm insertion.
- Track enemy team signatures (source IP patterns, tooling quirks) — a team
  that hit us with vuln X has X on their *own* box too. Their attack is our
  exploit roadmap.

### Patch decision tree

| Situation | Patch type |
|---|---|
| Source available, vuln understood | minimal source fix (input validation at the sink) |
| Fix risky/large | validating proxy in front (reject only exploit-shaped input) |
| Binary-only service | binary patch if rules allow; else proxy |
| Patch breaks functional test | narrower fix, or proxy; never deploy red |

### Prioritization (point-rate math)

- Value of a vuln ≈ (N−1 teams) × ticks remaining × P(exploit holds). A vuln
  found at hour 2 of an 8 h game with 20 teams ≈ 19 × 36 ticks — this is the
  whole attack game; act like it.
- Order: (1) vuln already being used against us (patch first, then weaponize),
  (2) high-yield farmed vuln improvements (evade enemy patches), (3) new
  service audit.
- Watch enemy patches: a module's success rate dropping for one team = they
  patched. Don't burn time re-auditing what their patch tells you exists.

## Failure modes beyond the beginner list

1. Farm built after unlock — every minute is lost recurring income.
2. Patch harness skipped "just this once" → checker break discovered 2 ticks later.
3. Exploit modules with shared state → one timeout poisons the whole tick.
4. Pcap triage deferred to "later" → free 0-days expire with rotation.
5. Defense lead also weaponizing → patches stall; keep the roles split in time
   even if the same person holds both.
