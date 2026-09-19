#!/usr/bin/env bash
# Cut a GitHub release of the cross-built core — no repo settings, no Actions,
# no secrets. Uses your existing `gh` auth to attach the artifacts to a tag.
#
# We publish the CORE LIBS ONLY (libphonenumber_ae.<so|dylib|dll> per platform,
# each with a .sha256, plus SHA256SUMS.txt). These are the reusable, language-
# agnostic pieces a binding links or dlopens. The per-language packages
# (wheel/gem/jar/crate/…) are NOT published here — they are toolchain-bound and
# belong to their own registries (PyPI/RubyGems/npm/Maven/crates.io), which would
# need per-registry secrets.
#
# Usage:
#   release/publish.sh v1.2.3               # build the matrix + create the release
#   release/publish.sh v1.2.3 --draft       # create as a draft to review first
#   release/publish.sh v1.2.3 --prerelease  # mark as a pre-release
#   release/publish.sh v1.2.3 --no-build    # attach whatever is already in release/dist
set -uo pipefail
shopt -s nullglob

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DIST="$ROOT/release/dist"

say() { printf 'publish: %s\n' "$*"; }
die() { printf 'publish: %s\n' "$*" >&2; exit 1; }

TAG=""; NO_BUILD=0; TARGET=""; GH_FLAGS=()
for a in "$@"; do
  case "$a" in
    --no-build)   NO_BUILD=1 ;;
    --draft)      GH_FLAGS+=(--draft) ;;
    --prerelease) GH_FLAGS+=(--prerelease) ;;
    --target=*)   TARGET="${a#--target=}" ;;
    -*)           die "unknown flag: $a" ;;
    *)            TAG="$a" ;;
  esac
done
[ -n "$TAG" ] || die "usage: release/publish.sh <tag> [--target=<branch|sha>] [--draft] [--prerelease] [--no-build]"

# Anchor the tag to the commit the binaries were built from. gh creates the tag
# at --target on the remote; default it to the CURRENT branch so a release cut
# from a divergent branch (e.g. reboot) tags THAT branch's HEAD, not the repo's
# default branch — the "tag and binaries are the same code" invariant, enforced
# remotely too. (publish.sh already refuses a dirty tracked tree below.)
[ -n "$TARGET" ] || TARGET="$(git rev-parse --abbrev-ref HEAD)"
GH_FLAGS+=(--target "$TARGET")

command -v gh >/dev/null 2>&1 || die "gh (GitHub CLI) not on PATH — install it and \`gh auth login\`"
gh auth status >/dev/null 2>&1 || die "not authenticated — run \`gh auth login\`"

if [ "$NO_BUILD" = "0" ]; then
  say "building the core matrix for $TAG"
  RELEASE_TAG="$TAG" "$HERE/build.sh" || die "build failed — fix it, or --no-build to publish existing dist"
fi

bins=( "$DIST"/*.so "$DIST"/*.dylib "$DIST"/*.dll "$DIST"/*.dll.lib )
sums=( "$DIST"/*.sha256 )                 # includes aether.toml.sha256
manifest=( "$DIST"/SHA256SUMS.txt )
# The Aether-source-consumer manifest: a single aether.toml declaring the release
# a binary package for `ae add` (see release/build.sh). Fetched by `ae add` from
# the release root, so it must be attached as a release asset in its own right.
toml=( "$DIST"/aether.toml )
[ "${#bins[@]}" -gt 0 ] || die "no core artifacts in release/dist — run release/build.sh (or drop --no-build)"
[ -f "$DIST/aether.toml" ] || die "no aether.toml in release/dist — run release/build.sh (or drop --no-build)"
assets=( "${bins[@]}" "${toml[@]}" "${sums[@]}" "${manifest[@]}" )

# Count real platform libs (exclude the Windows .dll.lib import stub).
nbin=0; for f in "${bins[@]}"; do case "$f" in *.dll.lib) ;; *) nbin=$((nbin+1)) ;; esac; done

COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
notes="Cross-built \`libphonenumber_ae\` core — ${nbin} platform artifact(s), each with a \`.sha256\` (and a combined \`SHA256SUMS.txt\`).

The core is the shared, language-agnostic library every binding uses. Download the
\`.so\`/\`.dylib\`/\`.dll\` for your platform and point a binding at it
(\`LIBPHONENUMBER_AE_LIB\`, the OS loader path, or bundle it beside your app). The
per-language packages (wheel/gem/jar/crate/…) are built from this repo's
\`<lang>/.dist.ae\` and are not attached here.

### Two ways to consume the core — both use the prebuilt binaries above

- **FFI / other languages** — the language bindings \`dlopen\` the core over its C
  ABI. A consumer fetches the platform artifact (see \`get-core.sh\`) and points a
  binding at it (\`LIBPHONENUMBER_AE_LIB\`, the OS loader path, or bundled beside the app).
- **Aether (\`ae add\`)** — an Aether program consumes the SAME prebuilt core as an
  \`ae add\` binary package: this release attaches an \`aether.toml\` declaring
  \`[package] binary = \"libphonenumber_ae\"\`, so \`ae add
  github.com/aether-lang-dev/libphonenumber-ae@$TAG\` fetches the host's core, and
  the consumer \`import\`s it and calls its catalog (\`pn_embed_is_valid_number\`, …)
  — no source checkout, no metadata tables, no \`--lib\`. (Requires an \`ae\` with the
  binary-package \`ae add\` path — aether #2105.)

Built from ${COMMIT:0:9}."

say "creating release $TAG with ${#assets[@]} asset(s)$([ "${#GH_FLAGS[@]}" -gt 0 ] && echo " (${GH_FLAGS[*]})")"
gh release create "$TAG" "${GH_FLAGS[@]}" \
  --repo aether-lang-dev/libphonenumber-ae \
  --title "$TAG" --notes "$notes" \
  "${assets[@]}" \
  || die "gh release create failed"

printf 'publish: done — %s\n' "$(gh release view "$TAG" --repo aether-lang-dev/libphonenumber-ae --json url -q .url 2>/dev/null || echo "$TAG created")"
