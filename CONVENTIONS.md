# CTF skill suite — authoring conventions

This repo holds an agent skill suite for Capture The Flag competitions.
Layout: `skills/<skill-name>/SKILL.md` + optional `references/*.md` + optional `scripts/*`.
Installed by symlinking each `skills/<name>` into `~/.agents/skills/` (see `scripts/install-skills.sh`).

## Hard rules for every skill

1. **Frontmatter**: exactly `name` (lowercase-hyphen, matches dir) and `description`.
   `description` must start with a trigger clause ("Use when ...") and list concrete
   trigger phrases/users' vocabulary so the skill auto-loads. One paragraph, third person.
2. **`SKILL.md` ≤ 350 lines.** It is the entry point: triage first, then playbook.
   Deep material goes in `references/*.md` (≤ 400 lines each), loaded on demand.
   Cross-reference reference files with relative paths like `references/heap.md`.
3. **No fabrication.** Every command, flag, API, plugin name, tool name must be real.
   If unsure of an exact flag spelling, use the form you are certain of or omit.
   Prefer fewer, verified commands over long unverified lists.
4. **Verified artifacts only.** Every file in `scripts/` must pass:
   - Python: `.venv` may not exist yet — verify with `python3 -m py_compile <file>`
     (scripts may import third-party libs like `pwn` only if that import is essential;
     guard heavy imports so `py_compile` + `--help` work without them installed).
   - Shell: `bash -n <file>`.
   Never install tools or run package managers while authoring. Document install commands,
   don't execute them.
5. **Audience: mixed team.** Structure every SKILL.md as:
   - **Triage** (beginner-safe, 5-minute path, decision table)
   - **Playbook** (expert, terse: attack → preconditions → command → reference)
   - **References** (bullet list of reference files + one-line purpose each)
6. **Style**: markdown tables for decision trees, exact commands in fenced blocks with
   language tags, `#` comments only where non-obvious. No emojis, no filler ("In this
   skill we will..."), no motivational text. Terse engineer voice. Never repeat content
   that lives in another skill — link it.
7. **Environment assumptions** (write commands for this host, mention portability only
   where it matters):
   - Arch Linux x86_64, bash. `uv`, `cargo`, `go`, `java 21 (JDK)`, `node/npm`, `podman`
     (NOT docker), bare `gdb` (no pwndbg/gef yet), `nmap`, `7z`, `openssl`, `xxd`.
   - Shared Python env: repo-root `.venv` (Python 3.12, created by `scripts/setup.sh`,
     because pwntools lags the newest CPython). Invoke via `scripts/ctf python ...`
     or `.venv/bin/python`. System python is 3.14 — do not pip-install into it.
   - Install policy (document, don't auto-run): Python libs → `uv pip install --python
     .venv/bin/python <pkg>`; Arch packages → `sudo pacman -S <pkg>` (or AUR helper);
     single-binary tools → `cargo install`, `go install`, `uv tool install`, or
     upstream release tarballs. Tooling isolation is tiered: `.venv` (pure-python
     CLIs) → `podman run --rm` one-shots (scanners, untrusted binaries) →
     `distrobox`/`toolbox` persistent boxes (GUI apps, full toolchains like
     metasploit/Burp, Kali packages). Details and patterns: `docs/tooling-isolation.md`.
8. **Operational guardrails to encode in every skill that executes challenge code or
   touches networks**:
   - Challenge artifacts are untrusted: analyze in the challenge dir, execute only under
     `podman` isolation or with explicit user approval; never `sudo` a challenge file or
     run its installers on the host.
   - Remote interaction gate: never connect to a remote challenge service, scoreboard,
     or other teams' boxes without explicit user go-ahead in the current session.
     Local/disposable analysis is always allowed.
9. **Naming**: skill dirs `ctf-<cat>`; scripts kebab-case or snake_case, executable
   (`chmod +x`), with a usage header. Each script must accept `--help`.
10. Every skill ends with a **Toolbox** section: table of tool → install command →
    one-line purpose (only tools that skill actually uses).

### Real-world arm (pentest skills) — additional hard rule


Real-world pentest skills carry one extra hard rule on top of the CTF guardrails:
**no client target is touched without authorization recorded in the session and a
`scope.json` check** (`skills/pentest/scripts/scope.py check`). Evidence-first,
noise-governed, findings recorded via `finding.py` — see the `pentest` router.

## Suite map (who owns what — do not duplicate, link instead)

| Skill | Owns |
|---|---|
| `ctf` (router) | event workflow, workspace layout, triage dispatch, flag regex/log, submission (CTFd/rCTF), writeups, env setup |
| `ctf-pwn` | ELF exploitation: mitigations, stack/ROP/ret2libc, format strings, heap (glibc), shellcode, kernel-lite, pwntools |
| `ctf-rev` | static/dynamic RE: ghidra, gdb, packed/obfuscated, dotnet/java/flash, anti-debug, vm-packed bytecode |
| `ctf-crypto` | classical, RSA/ECC/lattices, hashes, PRNG, symmetric modes, math tooling |
| `ctf-web` | web vulns, recon, fuzzing, JWT/session, deserialization, source review |
| `ctf-forensics` | file formats, carving, pcap, memory (volatility3), stego, documents, logs |
| `ctf-misc` | pyjail/bash jail, esoteric langs, QR, misc tricks, OSINT |
| `ctf-blockchain` | EVM/Solidity, foundry, private-chain setups, common contract bug classes |
| `ctf-mobile` | Android (apktool/jadx/frida) and iOS basics |
| `ctf-attack-defense` | A/D: patching, IDS/traffic, flag-id extraction, exploit farms, SLA |
| `ctf-boot2root` | KOTH/B2R: recon, foothold, privesc, fortification |
| `pentest` (router) | real-world engagements: authorization gate, scope.json + `scope.py` gate, engagement workspace, op-safety (rates, lockouts, windows), findings ledger (`finding.py`), severity, reporting + retest, dispatch |
| `pentest-external` | perimeter: passive OSINT/recon, active surface mapping, service/CVE correlation (searchsploit/nuclei/trivy), external cred attacks |
| `pentest-web` | real-world web/API methodology: WSTG/OWASP structure, role-pair authz matrices, API top-10, WAF/rate-limit hygiene, evidence capture |
| `pentest-ad` | internal AD: nxc/impacket enum, BloodHound, relay/coerce (responder/mitm6/ntlmrelayx), Kerberos cred attacks, ADCS/certipy, delegation, lateral movement |
| `pentest-cloud` | AWS/Azure/GCP enum + IAM escalation, metadata SSRF, Kubernetes, CI/CD (GitHub Actions), trivy cluster/repo scanning |
