#!/usr/bin/env bash
# One-time toolbox setup: shared Python 3.12 venv + core CTF libraries.
# Python is pinned to 3.12 because pwntools lags the newest CPython;
# uv downloads a managed 3.12 automatically if missing.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -x .venv/bin/python ]; then
    uv venv --python 3.12 .venv
fi

uv pip install --python .venv/bin/python \
    pwntools \
    pycryptodome \
    gmpy2 \
    sympy \
    paramiko \
    requests \
    beautifulsoup4 \
    yara-python \
    lief \
    pillow

echo "OK: .venv ready. Use: scripts/ctf python <script>   (or .venv/bin/python)"
