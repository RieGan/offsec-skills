#!/usr/bin/env bash
# Feed freshness preflight — refreshes the CVE/exploit databases of tools that
# are ALREADY INSTALLED. Never installs anything (see CONVENTIONS install policy).
# Run at engagement kickoff; paste the printed versions into the methodology
# section of work/<eng>/notes.md.
set -u
cd "$(dirname "$0")/.."

say() { printf '%s\n' "$*"; }

say "== feed preflight: updates databases only, installs nothing =="

# nuclei — template DB
if command -v nuclei >/dev/null 2>&1; then
  nuclei -update-templates 2>&1 | tail -n 2
  nuclei -version 2>/dev/null | sed -n '1,2p'
else
  say "[skip] nuclei not installed — see pentest-external Toolbox (go install)"
fi

# trivy — vulnerability DB
if command -v trivy >/dev/null 2>&1; then
  trivy image --download-db-only 2>&1 | tr '\r' '\n' | tail -n 2
else
  say "[skip] trivy not a local binary — podman one-shots fetch a fresh DB on every run (ephemeral = always current; docs/tooling-isolation.md)"
fi

# exploitdb / searchsploit
if command -v searchsploit >/dev/null 2>&1; then
  if [ -d /usr/share/exploitdb/.git ]; then
    searchsploit -u 2>&1 | tail -n 2
  else
    say "[hint] exploitdb came from pacman — refresh with: sudo pacman -Syu exploitdb"
  fi
else
  say "[skip] searchsploit not installed — sudo pacman -S exploitdb"
fi

# box-resident stacks (tier 2) — hints only, the box may not exist yet
if command -v distrobox >/dev/null 2>&1 && distrobox list 2>/dev/null | grep -q offsec; then
  say "[hint] metasploit/seclists live in the offsec box — refresh inside it:"
  say "       distrobox-enter offsec -- sudo apt update && sudo apt upgrade metasploit-framework seclists"
fi

say ""
say "Feeds don't verify findings — the fingerprint→correlate→verify loop in"
say "skills/pentest-external/references/vulnscan.md still applies to every hit."
