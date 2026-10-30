#!/usr/bin/env bash
# Symlink every skills/<name> into ~/.agents/skills/ (idempotent).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${HOME}/.agents/skills"
mkdir -p "$dest"

for d in "$root"/skills/*/; do
    name="$(basename "$d")"
    target="$dest/$name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        echo "SKIP $name: $target exists and is not a symlink" >&2
        continue
    fi
    ln -s "$d" "$target"
    echo "linked $name -> $d"
done
