# ctf-skills

Agent skill suite for Capture The Flag competitions. Router + per-category skills,
mixed-team level (beginner-safe triage, expert playbooks).

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

## Setup

```bash
scripts/setup.sh          # create .venv (Python 3.12) + core libs
scripts/install-skills.sh # symlink skills into ~/.agents/skills/
```

Daily use: `scripts/ctf <cmd>` runs anything with the venv on PATH.
Challenge work happens in `work/<event>/<chal>/`.

See `CONVENTIONS.md` before editing or adding skills.
