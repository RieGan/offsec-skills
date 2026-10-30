# Attack-Defense Team Guidelines (3-person)

Review of the team's draft strategy + three complete playbooks by skill level.

| Playbook | Use when |
|---|---|
| [beginner.md](beginner.md) | First 1–3 A/D events; team still learning service auditing |
| [intermediate.md](intermediate.md) | Played a few A/Ds; want parallel patch+exploit and traffic-driven defense |
| [expert.md](expert.md) | Comfortable auditing under time pressure; optimizing point rate |

## What the draft already gets right

- Splitting the event at the attack-network unlock — the two phases need different
  brain modes (audit/prepare vs. operate/iterate).
- Dedicated person for logging/traffic capture in phase 1 — most beginner teams
  never turn it on at all.
- VM hygiene (SSH, users in `/etc/passwd`) — backdoored accounts and reused
  passwords are real organizer traps.
- The patch/exploit role transition after finding vulns — correct instinct that
  one person can't do both at once.

## Gaps (each mapped to where it is fixed below)

| # | Missing from draft | Why it loses points | Fixed in |
|---|---|---|---|
| 1 | **Rules/scoring read** (tick length, SLA weight, patch policy, forbidden actions) | You can't prioritize what you haven't quantified; some events ban binary patching or DoS outright | all: Phase-1 step 1 |
| 2 | **Checker protection** — patches must keep the checker passing | #1 point sink for beginners: a "fixed" service that the checker can't use scores 0 SLA every tick and may void defense points | beginner §doctrine; intermediate §patch harness |
| 3 | **Flag/flag-id enumeration** (where flags live, what identifies each team's instance) | No flag ids → farm has no targets; unknown flag location → exploit has no payoff step | all: Phase-1 |
| 4 | **Pristine snapshot + pre-patch backups** | You WILL corrupt the VM or ship a broken patch; without a golden image you redeploy from scratch mid-game | beginner §snapshot card |
| 5 | **Service inventory table** (port → binary/source → language → DB → data dir) | Auditing blind wastes the locked phase; the table drives work split and patch planning | all: Phase-1 |
| 6 | **Local end-to-end exploit validation before unlock** | Exploits first run against other teams must already work; debugging against enemy boxes burns ticks and leaks your 0-day | beginner dry-run; expert exploit-as-code |
| 7 | **Submitter/farm skeleton built during phase 1**, not as a "when tired" fallback | At unlock you want to *press a button*, not write plumbing while ticks burn | intermediate §farm; expert §pipelines |
| 8 | **Capture placement spec** (per-service-port tcpdump, pcap rotation per tick, checker-vs-enemy traffic) | "Logging" without placement means pcaps that miss the exploit or can't be correlated to ticks | beginner phase-1; intermediate §pcap workflow |
| 9 | **Defender owns exploit replication** — draft routes enemy-attack reports to the *attacker* to replicate | Attacker context-switching off new vulns is the most expensive trade in the game; the defender already has the pcap + local replica | all: phase-2 roles |
| 10 | **SLA monitoring + auto-recovery** | Dead service detected 3 ticks late = 3 ticks of zeros | beginner emergency card; expert §ops |
| 11 | **Patch test pipeline** (local checker / functional test before deploy) | Deploy-and-pray patches break checkers (see #2) | intermediate §patch harness |
| 12 | **Shared vuln tracker** (id, service, class, proof, patched?, farmed?) | 3 people × 8 hours without shared state = duplicated work and forgotten patches | all |
| 13 | **Point-rate prioritization** (recurring attack points across all teams vs one-time wins) | A vuln farmed every tick across N−1 teams for the rest of the game dwarfs everything else | intermediate §prioritization; expert §target model |
| 14 | **Comms cadence + fatigue rotation** | Long A/Ds (24–48 h) are won by the team that is still thinking at hour 30 | intermediate §rhythm; expert §ops |

## Universal truths (apply at every level)

1. **Score = SLA + defense + attack, every tick, until the end.** Recurring
   income beats one-time gains; a reliable exploit plus 100 % SLA beats five
   half-working exploits.
2. **Never break the checker.** The checker is the SLA contract; patches are
   edits *inside* that contract, not rewrites of it.
3. **Everything from phase 1 (exploits, patches, farm) must run unattended in
   phase 2.** Phase 2 is for operating, not building.
4. **Debug only against your local replica.** Enemy boxes are for finished
   exploits, exactly once per tick.
5. **One change at a time, every change logged, every change reversible.**
