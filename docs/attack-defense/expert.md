# Expert 3-Person Attack-Defense Playbook

For teams where audit speed and tooling are not the bottleneck. Adds on top of
[intermediate.md](intermediate.md) (all of it still applies): **three parallel
pipelines, exploit-as-code from hour one, detection engineering, target
modeling, sustained ops.** This doc only covers deltas.

## Doctrine

- The game is an expected-points optimization under time and fatigue. Every
  hour, the team should be able to say which activity had the highest
  points/hour and be doing it.
- Phase 1 produces *systems*: exploit framework with per-service modules, patch
  pipeline with regression + attack tests, detection stack, farm with
  scheduling. Phase 2 produces *iterations* on those systems only.

## Pipelines (not roles — people are interchangeable cogs)

| Pipeline | Input | Output | Cadence |
|---|---|---|---|
| **Audit** | service source/binaries, enemy pcaps | exploit module + test vector + patch candidate | continuous |
| **Defense eng** | patch candidates, enemy payloads | deployed patches passing harness | per finding, <20 min |
| **Platform** | modules, flags, health | farm ticks, submissions, alerts, images | every tick |

With 3 people: 2 on audit+defense eng pairing per finding (one patches while
the other weaponizes the same vuln), 1 on platform. Rotate every 3–4 h;
hard-rotate at hour 8 in overnight events.

## Phase 1 deltas

- **Exploit-as-code from hour one**: every confirmed vuln lands as a module in
  the shared repo with (a) exploit, (b) unit test against local replica,
  (c) regression input for our own patch harness, (d) patch candidate. The vuln
  tracker is the repo issue; no prose outside it.
- **Test vectors are the currency**: the same payload file tests the exploit
  (must pop), the patch (must block), and detection (must alert). One artifact,
  three consumers.
- **Detection stack on our box** (where rules allow): app-level request logging
  with body capture; per-service alert when a request matches any *known*
  exploit vector (start with our own modules — they are the signature corpus);
  optionally a canary record/flag-id that no legitimate client ever touches —
  any read of it is an enemy, instantly.
- **Fingerprint enemy checkers now**: from phase-1 captures, know exactly what
  the checker's legal traffic looks like (user-agent, ordering, timing) so
  phase-2 pcap triage is a one-line filter, not an investigation.
- **Farm scheduling**: not just "every tick" — spread per-team hits across the
  tick to avoid burst signatures; jitter per module; per-team backoff. Rehit
  every service every tick (defense patch detection doubles as our patch
  oracle for *their* boxes: module that starts failing on team X only = X
  patched, note it, move on).

## Phase 2 deltas

### Enemy intelligence loop

- Module success-rate deltas per team are a live map of who patched what:
  - team-level failure of one module → they patched; try variant/bypass.
  - global failure of one module → organizer rotated the service or a global
    patch campaign; re-audit diff.
- When our box is hit: payload → replica → if new: patch, weaponize, ship to
  farm *in the same tick cycle*. Enemy creativity is our audit backlog;
  process it faster than they produce it.
- Diff their services when an exploit grants read: fetching a rival's service
  source through your own exploit is usually legal (it's exploitation of an
  in-scope instance) and is the richest intel in the game — their patches
  directly reveal the vuln classes they found.

### Defense engineering depth

- **Validating reverse proxy** (in front of the service) as the default patch
  substrate for anything but trivial fixes: keeps the binary untouched
  (no patch-policy risk), centralizes logging, and turns patch iteration into
  config reloads.
- **Patch subtlety**: reject with responses indistinguishable from normal
  errors — an enemy farm that can detect "patched" from a signature knows the
  vuln exists elsewhere; make them burn audits.
- **Second-order review**: every deployed patch gets a 2-minute "what did this
  introduce" pass (new validation bug? new reflection? checker interaction?)
  by the person who did *not* write it.
- **Restore drills**: platform pipeline keeps pre-patch images at every deploy;
  a red harness at any point = minute-scale rollback, no discussion.

### Target model (points/hour)

- Rank enemy teams by (our module success rate × their flag value) minus
  (their observed patch speed). Farm scheduler weights targets accordingly.
- Late game shifts: patches compound (defense points accrue per remaining
  tick); attack decays as teams patch. Concretely: last 25 % of the event,
  spend on patch verification + SLA unless a fresh high-yield vuln exists.
- First hours: attack dominates (full tick runway). This asymmetry should be
  visible in who is doing what at hour 2 vs the final hour.

## Sustained ops (24–48 h events)

- Shift table written at start: 3 slots (audit/defense/platform) × 3 people ×
  4 h rotations, with forced 4 h off per person per 12 h. Fatigue errors
  (broken checker, rm -rf on the wrong box) cost more than the lost hours.
- Standing 2-min sync every 30 min; full handoff notes in the tracker at every
  rotation — the tracker, not memory, is the team's state.
- Platform owns a "game clock" pane: tick countdown, SLA status, farm rates,
  alert feed. Anyone red-flagged there interrupts anyone.
- Pre-commit the emergency ladder (from beginner.md) — same cards, faster
  hands: down service → pre-patch image; bad patch → one-step rollback;
  corrupted box → redeploy + replay `changes.md`.

## Expert failure modes

1. Over-engineering the farm while modules starve — platform exists to deliver
   modules; cap its hours.
2. Clever patches that break the checker in a way the harness didn't model —
   extend the harness with every miss; the harness is never done.
3. Hoarding a 0-day "for later" — a vuln unexploited for k ticks costs k×(N−1)
   flags. Farm it immediately; variants survive patches.
4. Detection tuned to our own exploit styles only — enemies find different
   bugs; treat every unknown anomaly as a payload until proven otherwise.
5. Skipping rotation because "in the middle of something" — that is exactly
   when the expensive mistake happens.
