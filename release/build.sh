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
#   RELEASE_EXTRA_TARGETS=1 release/build.sh  # + windows (slow) + freebsd (needs sysroot)
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

TAG="${RELEASE_TAG:-$(git describe --tags --always 2>/dev/null || echo dev)}"

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
for t in $MATRIX; do
  os=$(os_of "$t"); arch=$(arch_of "$t"); ext=$(ext_of "$t")
  name="libphonenumber_ae-${TAG}-${os}-${arch}.${ext}"
  out="$DIST/$name"
  log="$DIST/.$t.log"

  # FreeBSD needs a base sysroot; skip loudly rather than fail if it's absent.
  if [ "$os" = "freebsd" ] && [ -z "${AETHER_SYSROOT:-}" ]; then
    say "SKIP $t — set AETHER_SYSROOT to a FreeBSD base sysroot (see aether-crossbuild)"
    continue
  fi

  printf 'release:   %-18s -> %s ... ' "$t" "$name"
  # --size strips the artifact. No --with / --lib: the core has no caps and
  # imports nothing by bare name (mirrors core/.build.ae's aether.shared_lib()).
  # Run from ROOT: core/embed.ae imports `core.phonenumber` etc., which resolve
  # from the project root, not from inside core/. --extra takes an ABSOLUTE path
  # (ae's cross path does not resolve a relative --extra C file from CWD).
  if ( cd "$ROOT" \
       && ae build --emit=lib --size --target="$t" \
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
