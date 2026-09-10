#!/usr/bin/env bash
# sync-google-resources.sh — pull Google's phone-number metadata into resources/.
#
# This repo is the Aether port, not a fork of Google's tree: the ONLY thing we
# take from upstream libphonenumber is the metadata the engine compiles against.
# This script copies exactly those paths from the Google mirror branch into
# resources/ — a plain content checkout, never a git merge, so there is no
# rename heuristic and no conflict resolution. It then records which upstream
# commit the data came from and regenerates the engine so you can prove it green.
#
# The mirror is a branch that tracks Google verbatim (this repo's origin/master
# is such a mirror). Override with MIRROR=<ref>, e.g. MIRROR=upstream/master
# after `git remote add upstream https://github.com/google/libphonenumber.git`.
#
# Usage:
#   ./sync-google-resources.sh              # sync from origin/master
#   MIRROR=upstream/master ./sync-google-resources.sh
#   NO_BUILD=1 ./sync-google-resources.sh   # copy only, skip the rebuild/presubmit
set -euo pipefail

MIRROR="${MIRROR:-origin/master}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# The exact resource paths the Aether build consumes (see resources/PROVENANCE.md).
PATHS=(
  resources/PhoneNumberMetadata.xml
  resources/ShortNumberMetadata.xml
  resources/PhoneNumberAlternateFormats.xml
  resources/timezones/map_data.txt
  resources/carrier
  resources/geocoding
)

say() { printf 'sync-resources: %s\n' "$*"; }
die() { printf 'sync-resources: %s\n' "$*" >&2; exit 1; }

# Refresh the mirror if it's a remote-tracking ref (origin/... or upstream/...).
remote="${MIRROR%%/*}"
if git remote | grep -qx "$remote"; then
  say "fetching $remote"
  git fetch --quiet "$remote"
fi
git rev-parse --verify --quiet "$MIRROR^{commit}" >/dev/null \
  || die "mirror ref '$MIRROR' not found (set MIRROR=<ref>, or add the remote)"

commit="$(git rev-parse --short "$MIRROR")"
subject="$(git log -1 --format='%s' "$MIRROR")"
say "mirror $MIRROR @ $commit — $subject"

# Copy each path's content from the mirror into the working tree + index.
# `git checkout <ref> -- <path>` overwrites with the mirror's version; it is a
# content copy, not a merge.
say "checking out ${#PATHS[@]} resource paths"
git checkout "$MIRROR" -- "${PATHS[@]}"

# Stamp provenance so the source commit is recorded in the same change.
if [ -f resources/PROVENANCE.md ]; then
  today="$(date +%Y-%m-%d)"
  tmp="$(mktemp)"
  awk -v c="$commit" -v s="$subject" -v d="$today" '
    /^- Upstream commit:/ { print "- Upstream commit: `" c "` — \"" s "\""; next }
    /^- Synced:/          { print "- Synced: " d; next }
    { print }
  ' resources/PROVENANCE.md > "$tmp" && mv "$tmp" resources/PROVENANCE.md
  git add resources/PROVENANCE.md
fi

if git diff --cached --quiet -- "${PATHS[@]}" resources/PROVENANCE.md; then
  say "resources already match $MIRROR @ $commit — nothing to sync"
  exit 0
fi

say "staged. Review with: git diff --cached -- resources/"
say "commit suggestion:"
printf '  git commit -m "sync Google metadata @ %s (%s)"\n' "$commit" "$subject"

if [ "${NO_BUILD:-0}" = "1" ]; then
  say "NO_BUILD set — skipping rebuild"
  exit 0
fi

# Regenerate the engine tables from the fresh resources and prove green.
command -v aeb >/dev/null 2>&1 || { say "aeb not on PATH — skipping rebuild"; exit 0; }
say "regenerating engine (aeb core/.build.ae)"
rm -rf target
aeb core/.build.ae
say "running presubmit"
aeb .presubmit.ae
say "done — resources synced to $commit and presubmit green. Commit when ready."
