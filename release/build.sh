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

# The release tag. Single source of truth is the repo-root VERSION file, so the
# asset names the aeb builder emits carry the same tag every release. RELEASE_TAG
# overrides it (to cut a one-off / test build); git-describe is only the last-ditch
# fallback if VERSION is somehow absent.
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
# Clear aeb's ae-add staging dir too: emit_binary_package ACCUMULATES each triple's
# asset there across a run, so a stale asset from a prior build could otherwise be
# collected. (We copy per-triple by exact name, but keep the source dir clean.)
rm -rf "$ROOT/target/build/core/ae-add"

# triple -> {os, arch, extension} for the artifact name.
os_of()  { case "$1" in *-linux|*-linux-musl) echo linux;; *-macos) echo macos;; *-windows) echo windows;; *-freebsd) echo freebsd;; *) echo unknown;; esac; }
arch_of(){ case "$1" in aarch64-*) echo arm64;; x86_64-*) echo x86_64;; *) echo "$1";; esac; }
ext_of() { case "$1" in *-macos) echo dylib;; *-windows) echo dll;; *) echo so;; esac; }

# aeb owns metadata generation + the cross-build + the `ae add` asset trio now:
# `LIBPHONENUMBER_AE_TARGET=<triple> aeb core/.build.ae` (with AEB_RELEASE_TAG set)
# generates the tables, cross-builds the .so with --size, and stages
# target/build/core/ae-add/{aether.toml, libphonenumber_ae-<tag>-<triple><ext>,
# <asset>.sha256} via aether.emit_binary_package (aeb >= v0.324). We loop the
# matrix, then collect each triple's asset trio into release/dist/. This replaces
# the old hand-rolled `ae build --target` + sha256sum + aether.toml heredoc — the
# aeb builder is the single source of the asset-name/manifest/checksum contract.
have aeb || die "aeb not on PATH (run ./bootstrap.sh, or ci/versions.env's pins)"
CORE_AEADD="$ROOT/target/build/core/ae-add"

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
  # CRITICAL: clean the shared build lib dir before each triple. All triples write
  # target/build/core/lib/, and emit_binary_package resolves the built lib by trying
  # the plain output name (libphonenumber_ae.so) FIRST, then the cross-mangled
  # <out>.<ext> (…so.dll / …so.dylib). A prior triple's leftover plain .so would be
  # matched instead of THIS target's cross lib — silently staging the wrong-platform
  # bytes into the asset (a windows .dll that is actually a Mach-O). Wiping the dir
  # leaves only the current build's lib, so the resolver can't grab a stale one.
  rm -rf "$ROOT/target/build/core/lib"
  # aeb cross-builds the .so (--size, via aether.shared_lib target()) AND stages
  # the `ae add` asset trio (via aether.emit_binary_package) into core's ae-add/.
  # Run from ROOT: core/embed.ae imports `core.phonenumber` etc., resolved from the
  # project root. AETHER_SYSROOT is set per-target (freebsd base for this arch, or
  # empty — ae ignores an empty one); the freebsd emit inherits it exactly as the
  # cross shared_lib does. AEB_RELEASE_TAG names the assets; the LIBPHONENUMBER_AE_
  # TARGET env selects core/.build.ae's release path.
  if ( cd "$ROOT" && AETHER_SYSROOT="$sysroot" \
       AEB_RELEASE_TAG="$TAG" LIBPHONENUMBER_AE_TARGET="$t" \
       aeb core/.build.ae ) >"$log" 2>&1 \
     && [ -f "$CORE_AEADD/$name" ]; then
    # Collect this triple's trio (lib + .sha256 + the shared aether.toml) from the
    # builder's staging dir into release/dist/.
    cp "$CORE_AEADD/$name" "$DIST/$name"
    cp "$CORE_AEADD/$name.sha256" "$DIST/$name.sha256"
    cp "$CORE_AEADD/aether.toml" "$DIST/aether.toml"          # shared; same each triple
    # Windows also emits an import library (<lib>.so.lib) beside the cross DLL —
    # needed only by a consumer that LINKS the DLL at build time (our FFI bindings
    # dlopen at runtime and don't use it, but ship it so Windows is first-class).
    # It is NOT part of the ae-add trio; grab it from the build lib dir + checksum.
    if [ "$os" = "windows" ]; then
      libsrc=$(ls "$ROOT"/target/build/core/lib/libphonenumber_ae.so.lib "$ROOT"/target/build/core/lib/libphonenumber_ae.dll.lib 2>/dev/null | head -1)
      if [ -n "$libsrc" ] && [ -f "$libsrc" ]; then
        cp "$libsrc" "$DIST/$name.lib"
        ( cd "$DIST" && sha256sum "$name.lib" > "$name.lib.sha256" )
      fi
    fi
    printf 'ok  (%s)\n' "$(file -b "$DIST/$name" 2>/dev/null | cut -c1-42)"
    built=$((built+1))
    rm -f "$log"
  else
    printf 'FAILED\n'
    sed 's/^/release:     /' "$log" | grep -iE 'error|fatal' | head -3
    failed=$((failed+1))
  fi
done

# The aether.toml (ae add binary-package manifest) is now emitted by
# aether.emit_binary_package and copied above — one shared asset for the whole
# release (ae add picks the host's core by the triple it appends). Checksum it.
[ -f "$DIST/aether.toml" ] && ( cd "$DIST" && sha256sum aether.toml > aether.toml.sha256 )

# A combined checksum manifest over every artifact (not the .sha256 sidecars).
# Named SHA256SUMS.txt so a browser renders it inline (no forced download).
( cd "$DIST" && sha256sum ./*.so ./*.dylib ./*.dll ./*.dll.lib aether.toml 2>/dev/null > SHA256SUMS.txt || true )

echo
say "built $built core artifact(s) into release/dist/ ($failed failed)"
[ "$failed" -eq 0 ] || exit 1
