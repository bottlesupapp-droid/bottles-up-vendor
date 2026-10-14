#!/usr/bin/env bash
# Put archived files back where they came from.
#
#   _archive/restore.sh <path-prefix> [--dry-run]
#
# <path-prefix> is matched against the ORIGINAL path, for example:
#   _archive/restore.sh lib/features/loyalty     # one feature
#   _archive/restore.sh lib                      # everything that came from lib/
#   _archive/restore.sh ""                       # everything, all tiers
#
# This only moves files back. Tier 2 also removed routes, tabs and tiles that
# pointed at those files. To put that wiring back, run from the app root:
#   git apply -R _archive/restore/tier2_edits.patch
set -euo pipefail
cd "$(dirname "$0")/.."
prefix="${1-__missing__}"
if [ "$prefix" = "__missing__" ]; then sed -n '2,14p' "$0"; exit 1; fi
dry="${2:-}"
moved=0; skipped=0
for manifest in _archive/MANIFEST_*.txt; do
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in "$prefix"*) ;; *) continue ;; esac
    src="_archive/$f"
    [ -e "$src" ] || continue
    if [ -e "$f" ]; then echo "skip (already exists): $f"; skipped=$((skipped+1)); continue; fi
    if [ "$dry" = "--dry-run" ]; then echo "would restore: $f"; moved=$((moved+1)); continue; fi
    mkdir -p "$(dirname "$f")"
    git mv "$src" "$f" 2>/dev/null || mv "$src" "$f"
    moved=$((moved+1))
  done < "$manifest"
done
echo "restored: $moved   skipped: $skipped"
