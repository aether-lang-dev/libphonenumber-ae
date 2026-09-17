# release — cross-built core artifacts for GitHub Releases

The core (`libphonenumber_ae`) is pure Aether, so it **cross-compiles for the
whole platform matrix from one Linux host** — no per-OS runner. This directory
builds those artifacts, checksums them, and attaches them to a GitHub Release.

**Scope: the core libs only.** These are the reusable, language-agnostic pieces
a binding links or `dlopen`s. The per-language packages (wheel/gem/jar/crate/…)
are built by each `<lang>/.dist.ae` and are **not** part of this release — they
are toolchain-bound and belong to their own registries (PyPI, RubyGems, npm,
Maven Central, crates.io), which would need per-registry secrets. gh-releases
carries the linkable core; the language registries carry the language packages.

## Build

```sh
release/build.sh                          # core matrix: linux + macos, x86_64 + arm64
RELEASE_TAG=v1.2.3 release/build.sh        # stamp a tag into the artifact names
RELEASE_EXTRA_TARGETS=1 release/build.sh   # + windows (slow) + freebsd (needs AETHER_SYSROOT)
TARGETS="aarch64-macos" release/build.sh   # just one target
```

Needs `ae` + `zig` on PATH (`./bootstrap.sh` installs the pinned pair) and
`sha256sum`. Outputs into `release/dist/` (gitignored):

- `libphonenumber_ae-<tag>-<os>-<arch>.{so,dylib,dll}` — the artifact
- `<artifact>.sha256` — its checksum (sidecar)
- `SHA256SUMS.txt` — every artifact in one manifest

Each is stripped (`--size`). `so`=linux ELF, `dylib`=macOS Mach-O, `dll`=Windows
PE (with a `.dll.lib` import stub beside it for consumers that *link* the DLL;
our bindings `dlopen` at runtime and don't need it, but it ships so Windows is
first-class).

## Publish

```sh
release/publish.sh v1.2.3               # build the matrix + create the release, assets attached
release/publish.sh v1.2.3 --draft       # create as a draft to review first
release/publish.sh v1.2.3 --no-build    # attach whatever is already in release/dist
```

`publish.sh` builds (unless `--no-build`), then `gh release create <tag>` with
every artifact, its `.sha256`, and `SHA256SUMS.txt`. It uses your existing `gh`
auth — **nothing in GitHub Settings, no Actions, no secrets.**

## Why build-here

The build is deterministic and platform-agnostic (zig cross-compiles the exact
bytes every time), so building on Linux and running on the target test *identical
bytes* — no "works on my machine" gap. A Linux host can't *run* an arm64-macOS
binary, so on-target verification is done out of band and (optionally) recorded
as an attestation keyed by the artifact's SHA256.

## Consuming a released core

A binding needs the core `.so`/`.dylib`/`.dll` at runtime (or link time).
Instead of cloning this repo and running `aeb core/.build.ae`, a consumer can
download the platform artifact from a release and point the binding at it —
`LIBPHONENUMBER_AE_LIB=/path/to/libphonenumber_ae-<tag>-<os>-<arch>.so`, the OS
loader path, or bundled beside the app. Verify it against its `.sha256` first.
