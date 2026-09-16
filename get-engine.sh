#!/usr/bin/env sh
# get-engine.sh — download the prebuilt libphonenumber_ae engine for THIS machine
# from a GitHub Release, verify its checksum, and print its path.
#
# This is the "no clone, no aeb, no Aether" path: a binding needs the engine
# shared library at run time (or link time); instead of building it from source,
# fetch the platform artifact that release/publish.sh attached to a release.
#
# Usage:
#   ./get-engine.sh                       # latest release, into ./ (prints the path)
#   ./get-engine.sh v1.2.3                # a specific tag
#   ./get-engine.sh v1.2.3 /opt/lib       # into a directory of your choice
#   LIBPHONENUMBER_AE_TAG=v1.2.3 DEST=~/lib ./get-engine.sh
#
# Point a binding at the printed path via LIBPHONENUMBER_AE_LIB, or drop it where
# the binding's loader looks (usually a native/ dir beside the package, or the OS
# loader path).
set -eu

REPO="aether-lang-dev/libphonenumber-ae"
TAG="${1:-${LIBPHONENUMBER_AE_TAG:-latest}}"
DEST="${2:-${DEST:-.}}"

die() { printf 'get-engine: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have curl || die "curl is required."

# Normalized (os, arch) — the same vocabulary aeb's get.sh and release/build.sh
# use: os in {linux,macos,windows,freebsd}, arch in {x86_64,arm64}.
# (This uname block is hand-rolled because the toolchain has no user-facing
# platform command yet — filed as ../aeb/asks/user-facing-platform-word-cli-...md.
# When `ae platform` lands, replace this with: platform="$(ae platform)".)
case "$(uname -s 2>/dev/null)" in
  Linux)                _os=linux ;;
  Darwin)               _os=macos ;;
  FreeBSD)              _os=freebsd ;;
  MINGW*|MSYS*|CYGWIN*) _os=windows ;;
  *) die "unrecognized OS $(uname -s) — download an engine asset manually from https://github.com/$REPO/releases" ;;
esac
case "$(uname -m 2>/dev/null)" in
  x86_64|amd64)   _arch=x86_64 ;;
  arm64|aarch64)  _arch=arm64 ;;
  *) die "unrecognized CPU $(uname -m) — download an engine asset manually from https://github.com/$REPO/releases" ;;
esac
case "$_os" in macos) _ext=dylib ;; windows) _ext=dll ;; *) _ext=so ;; esac

# The asset name embeds the TAG (release/build.sh stamps it): for `latest` we
# can't know the tag up front, so resolve it via the GitHub API.
if [ "$TAG" = "latest" ]; then
  have jq && TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | jq -r .tag_name)" \
          || TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$TAG" ] && [ "$TAG" != "null" ] || die "could not resolve the latest release tag (is there a published release?)"
fi

ASSET="libphonenumber_ae-${TAG}-${_os}-${_arch}.${_ext}"
BASE="https://github.com/$REPO/releases/download/$TAG"
mkdir -p "$DEST"
OUT="$DEST/$ASSET"

printf 'get-engine: fetching %s (%s-%s, tag %s)\n' "$ASSET" "$_os" "$_arch" "$TAG" >&2
curl -fsSL "$BASE/$ASSET"        -o "$OUT"      || die "download failed: $BASE/$ASSET (no asset for this platform/tag?)"
curl -fsSL "$BASE/$ASSET.sha256" -o "$OUT.sha256" 2>/dev/null || printf 'get-engine: no .sha256 sidecar to verify against\n' >&2

# Verify the checksum if a checksum tool + the sidecar are present.
if [ -f "$OUT.sha256" ]; then
  if have sha256sum;   then _sum=$(cd "$DEST" && sha256sum "$ASSET" | awk '{print $1}')
  elif have shasum;    then _sum=$(cd "$DEST" && shasum -a 256 "$ASSET" | awk '{print $1}')
  else _sum=""; printf 'get-engine: no sha256sum/shasum — skipping verification\n' >&2
  fi
  if [ -n "$_sum" ]; then
    _want=$(awk '{print $1}' "$OUT.sha256")
    [ "$_sum" = "$_want" ] || die "CHECKSUM MISMATCH for $ASSET (got $_sum, want $_want) — do NOT use this file"
    printf 'get-engine: checksum OK\n' >&2
  fi
fi

# The path is the one useful thing on stdout, so it can be captured:
#   LIBPHONENUMBER_AE_LIB="$(./get-engine.sh)"
printf '%s\n' "$OUT"
