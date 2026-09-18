#!/usr/bin/env bash
# Cross-build the core (libphonenumber_ae) for the release matrix from ONE host.
#
# The core is pure Aether; `ae build --target=<triple>` cross-compiles via zig
# cc — no per-OS runner. Output name:
#   libphonenumber_ae-<tag>-<os>-<arch>.<ext>   (.so linux / .dylib macos / .dll windows)
# Alongside each: <artifact>.sha256, plus a combined release/dist/SHA256SUMS.txt.
#
# We ship the CORE LIBS ONLY — the reusable, language-agnostic artifact every
# binding links or dlopens. The per-language packages (wheel/gem/jar/crate/…) are
# built by each `<lang>/.dist.ae` and are deliberately NOT part of this release:
# they are toolchain-bound and belong to their own registries, not gh-releases.
#
# Usage:
#   release/build.sh                          # core matrix (linux+macos x86_64/arm64)
#   RELEASE_EXTRA_TARGETS=1 release/build.sh  # + windows (slow) + freebsd (auto-finds
#                                               a per-arch base under ../aether-crossbuild/
#                                               bases/; fetch with that repo's
#                                               scripts/fetch-freebsd-base.sh <cpu>)
#   RELEASE_TAG=v1.2.3 release/build.sh       # stamp the tag into artifact names
#                                               (default: `git describe`, else "dev")
#   TARGETS="aarch64-macos" release/build.sh  # override the matrix entirely
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck disable=SC1091
. "$HERE/targets.env"
cd "$ROOT"

export PATH="${PREFIX:-$HOME/.local}/bin:$HOME/.aether/bin:$PATH"

say()  { printf 'release: %s\n' "$*"; }
die()  { printf 'release: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have ae  || die "ae not on PATH (run ./bootstrap.sh, or ci/versions.env's pins)"
have zig || die "zig not on PATH — required for cross-compilation (ae build --target)"
have sha256sum || die "sha256sum required to checksum artifacts"

# The release tag. Single source of truth is the repo-root VERSION file — the
# SAME file core/.getFromGitHub.ae reads to name the asset it fetches, so a
# published asset and a fetched asset can never drift. RELEASE_TAG overrides it
# (to cut a one-off / test build); git-describe is only the last-ditch fallback
# if VERSION is somehow absent.
_version_file="$ROOT/VERSION"
TAG="${RELEASE_TAG:-$( [ -f "$_version_file" ] && tr -d '[:space:]' < "$_version_file" || git describe --tags --always 2>/dev/null || echo dev )}"

# Resolve the matrix.
if [ -n "${TARGETS:-}" ]; then
  MATRIX="$TARGETS"
else
  MATRIX="$RELEASE_TARGETS"
  [ "${RELEASE_EXTRA_TARGETS:-0}" = "1" ] && MATRIX="$MATRIX $RELEASE_EXTRA_TARGETS_LIST"
fi

DIST="$ROOT/release/dist"
rm -rf "$DIST"; mkdir -p "$DIST"

# triple -> {os, arch, extension} for the artifact name.
os_of()  { case "$1" in *-linux|*-linux-musl) echo linux;; *-macos) echo macos;; *-windows) echo windows;; *-freebsd) echo freebsd;; *) echo unknown;; esac; }
arch_of(){ case "$1" in aarch64-*) echo arm64;; x86_64-*) echo x86_64;; *) echo "$1";; esac; }
ext_of() { case "$1" in *-macos) echo dylib;; *-windows) echo dll;; *) echo so;; esac; }

# The metadata tables + the assembled ABI are BUILD ARTIFACTS, generated from the
# pristine in-tree resources/ (exactly as core/.build.ae does before its compile).
# Generate them ONCE, host-side — they are platform-independent source that every
# target then cross-compiles.
say "generating metadata + assembling embed (host-side, once)"
core/gen/generate_metadata.sh en >/dev/null || die "generate_metadata.sh failed"
core/gen/assemble_embed.sh core/embed.ae all >/dev/null || die "assemble_embed.sh failed"

say "core: libphonenumber_ae  tag: $TAG"
say "matrix: $MATRIX"
echo

built=0; failed=0
# freebsd_sysroot_for <cpu> — resolve the FreeBSD base sysroot for ONE cpu.
# The two FreeBSD arches need DIFFERENT base sysroots (each carries its own
# arch's libc/crt), so a single AETHER_SYSROOT can't serve both in one run.
# Precedence, most specific first:
#   1. AETHER_SYSROOT_FREEBSD_<CPU>   — explicit per-arch override (X86_64 / ARM64)
#   2. auto-discovery under aether-crossbuild/bases/<cpu>-freebsd*/  (newest first)
#   3. AETHER_SYSROOT                 — single-sysroot fallback (only correct when
#                                       the matrix has one freebsd arch)
# Prints the path, or "" if none found.
freebsd_sysroot_for() {
  cpu="$1"                       # x86_64 | aarch64
  ucpu=$(printf '%s' "$cpu" | tr '[:lower:]' '[:upper:]')
  eval "ov=\${AETHER_SYSROOT_FREEBSD_${ucpu}:-}"
  [ -n "$ov" ] && { printf '%s' "$ov"; return; }
  # bases/<cpu>-freebsd, bases/<cpu>-freebsd15, … — pick the newest that has libc.
  cb="${AETHER_CROSSBUILD:-$ROOT/../aether-crossbuild}"
  if [ -d "$cb/bases" ]; then
    for d in $(ls -d "$cb"/bases/"$cpu"-freebsd* 2>/dev/null | sort -rV); do
      [ -f "$d/usr/lib/libc.a" ] && { printf '%s' "$d"; return; }
    done
  fi
  printf '%s' "${AETHER_SYSROOT:-}"
}

for t in $MATRIX; do
  os=$(os_of "$t"); arch=$(arch_of "$t"); ext=$(ext_of "$t")
  name="libphonenumber_ae-${TAG}-${os}-${arch}.${ext}"
  out="$DIST/$name"
  log="$DIST/.$t.log"

  # FreeBSD needs a per-arch base sysroot; resolve it and skip loudly if absent.
  sysroot=""
  if [ "$os" = "freebsd" ]; then
    # arch_of maps triples to release-asset arch words (x86_64 / arm64); the
    # FreeBSD base dirs use the triple cpu (x86_64 / aarch64), so map back.
    case "$arch" in arm64) cpu=aarch64 ;; *) cpu="$arch" ;; esac
    sysroot=$(freebsd_sysroot_for "$cpu")
    if [ -z "$sysroot" ]; then
      say "SKIP $t — no FreeBSD base sysroot for $cpu (set AETHER_SYSROOT_FREEBSD_$(printf '%s' "$cpu" | tr '[:lower:]' '[:upper:]'), or fetch one: aether-crossbuild/scripts/fetch-freebsd-base.sh $cpu)"
      continue
    fi
  fi

  printf 'release:   %-18s -> %s ... ' "$t" "$name"
  # --size strips the artifact. No --with / --lib: the core has no caps and
  # imports nothing by bare name (mirrors core/.build.ae's aether.shared_lib()).
  # Run from ROOT: core/embed.ae imports `core.phonenumber` etc., which resolve
  # from the project root, not from inside core/. --extra takes an ABSOLUTE path
  # (ae's cross path does not resolve a relative --extra C file from CWD).
  # AETHER_SYSROOT is set per-target (the freebsd base for this arch, or empty
  # for the sysroot-free targets — ae ignores an empty one).
  if ( cd "$ROOT" && AETHER_SYSROOT="$sysroot" \
       ae build --emit=lib --size --target="$t" \
            core/embed.ae --extra "$ROOT/core/_embed_support.c" -o "$out" ) >"$log" 2>&1; then
    ( cd "$DIST" && sha256sum "$name" > "$name.sha256" )
    # Windows emits an import library (<dll>.lib) beside the DLL — needed only by
    # a consumer that LINKS the DLL at build time (our FFI bindings dlopen at
    # runtime and don't use it, but ship it so Windows is first-class). Checksum it.
    if [ "$os" = "windows" ] && [ -f "$out.lib" ]; then
      ( cd "$DIST" && sha256sum "$name.lib" > "$name.lib.sha256" )
    fi
    printf 'ok  (%s)\n' "$(file -b "$out" 2>/dev/null | cut -c1-42)"
    built=$((built+1))
    rm -f "$log"
  else
    printf 'FAILED\n'
    sed 's/^/release:     /' "$log" | grep -iE 'error|fatal' | head -3
    failed=$((failed+1))
  fi
done

# A combined checksum manifest over every artifact (not the .sha256 sidecars).
# Named SHA256SUMS.txt so a browser renders it inline (no forced download).
( cd "$DIST" && sha256sum ./*.so ./*.dylib ./*.dll ./*.dll.lib 2>/dev/null > SHA256SUMS.txt || true )

echo
say "built $built core artifact(s) into release/dist/ ($failed failed)"
[ "$failed" -eq 0 ] || exit 1
