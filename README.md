# offsec-skills

Agent skill suite for offensive security: Capture The Flag competitions **and**
authorized real-world pentest engagements. Two routers, one toolbox:

- **`ctf`** — CTF arm: event workflow, per-category playbooks, flags, writeups.
- **`pentest`** — real-world arm: authorization + scope gates, engagement
  workspace, op-safety (rates/lockouts), evidence-bound findings ledger,
  reporting + retest, dispatch to external/web/AD/cloud skills.

Both arms are mixed-level (beginner-safe triage, expert playbooks) and share the
bug-class mechanics in the `ctf-*` references.

## Skills

| Skill | Scope |
|---|---|
| `ctf` | router: workflow, triage, dispatch, flags, submission, writeups, env |
| `ctf-pwn` | binary/ELF exploitation, heap, ROP, format strings |
| `ctf-rev` | static & dynamic reverse engineering |
| `ctf-crypto` | RSA/ECC/lattices/classical/hashes/PRNG |
| `ctf-web` | web exploitation & source review |
| `ctf-forensics` | file carving, pcap, memory forensics, stego |
| `ctf-misc` | pyjail/bash jails, esoteric, OSINT |
| `ctf-blockchain` | EVM/Solidity exploitation with Foundry |
| `ctf-mobile` | Android/iOS RE and instrumentation |
| `ctf-attack-defense` | A/D: patching, traffic, flag-ids, farms |
| `ctf-boot2root` | KOTH/HTB-style: recon, foothold, privesc |

## Real-world arm (authorized engagements only)

| Skill | Scope |
|---|---|
| `pentest` | router: RoE, scope gate (`scope.py`), findings ledger (`finding.py`), severity, report, retest |
| `pentest-external` | perimeter: OSINT, attack-surface mapping, service/CVE correlation, nuclei/trivy, cred attacks |
| `pentest-web` | web app + API pentest: WSTG/OWASP methodology, role-pair authz matrices, WAF/rate-limit hygiene |
| `pentest-ad` | internal AD: nxc/impacket enum, relay/coerce, Kerberos cred attacks, ADCS, lateral movement |
| `pentest-cloud` | AWS/Azure/GCP, Kubernetes, CI/CD; creds, metadata SSRF, IAM escalation |

Engagements live in `work/<client>-<yyyymm>-<type>/` with `scope.json`,
`findings/`, `evidence/`, `coverage.md`. The scope gate is checked before any
client contact; findings without captured evidence don't exist.

## Setup

```bash
scripts/setup.sh          # create .venv (Python 3.12) + core libs
scripts/install-skills.sh # symlink skills into ~/.agents/skills/
```

Optional offsec box — Kali toolchain/GUI apps in a container, not on the host:
`distrobox create --name offsec --image docker.io/kalilinux/kali-rolling`.
Full tiering policy (`.venv` → podman one-shots → distrobox): `docs/tooling-isolation.md`.

Daily use: `scripts/ctf <cmd>` runs anything with the venv on PATH.
Challenge work happens in `work/<event>/<chal>/`; engagements in `work/<eng>/`.

See `CONVENTIONS.md` before editing or adding skills.
