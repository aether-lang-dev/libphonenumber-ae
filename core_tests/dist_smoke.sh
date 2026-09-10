#!/usr/bin/env bash
# dist_smoke.sh — assert the distribution artifacts in target/dist/ are real.
#
# For each artifact that was produced (toolchain-absent bindings skip and produce
# nothing, which is fine), check it exists and is non-empty; for artifacts that
# bundle the engine natively, check the engine is actually inside.
#
# Exit 0 = every produced artifact is valid (and at least the JVM jar, which
# builds wherever a JDK 22+ is present, was checked). Exit 1 = a produced
# artifact is missing/empty/malformed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/target/dist"
LIB="libphonenumber_ae.so"

say()  { printf 'dist-smoke: %s\n' "$*"; }
fail() { printf 'dist-smoke: FAIL — %s\n' "$*" >&2; exit 1; }

[ -d "$DIST" ] || fail "target/dist/ does not exist (run the dist nodes first)"

checked=0

nonempty() {  # <path> <label>
  [ -f "$1" ] || fail "$2 missing: $1"
  [ -s "$1" ] || fail "$2 is empty: $1"
}

# --- JVM fat jar: must exist, be non-empty, and bundle the engine at native/ ---
JAR="$DIST/phonenumber-ae.jar"
if [ -f "$JAR" ]; then
  nonempty "$JAR" "jvm jar"
  if command -v jar >/dev/null 2>&1; then
    jar tf "$JAR" | grep -qx "native/$LIB" \
      || fail "jvm jar does not bundle native/$LIB (fat jar incomplete)"
    jar tf "$JAR" | grep -q '^org/libphonenumber/ae/.*\.class$' \
      || fail "jvm jar has no org/libphonenumber/ae classes"
    say "jvm jar OK — classes + native/$LIB bundled"
  else
    say "jvm jar present (no 'jar' tool to inspect contents)"
  fi
  checked=$((checked + 1))
fi

# --- The JVM-layer thin jars (kotlin/groovy/clojure) layer over java/'s classes
# and deliberately do NOT bundle the engine; check presence + non-empty only. ---
shopt -s nullglob
for f in "$DIST"/kotlin-phonenumber-ae.jar "$DIST"/groovy-phonenumber-ae.jar \
         "$DIST"/clojure-phonenumber-ae.jar; do
  nonempty "$f" "jvm-layer jar"
  say "$(basename "$f") OK — present, non-empty (thin, reuses the fat jar's engine)"
  checked=$((checked + 1))
done

# --- Other bindings' artifacts: presence + non-empty by extension. ---
for f in "$DIST"/*.whl "$DIST"/*.gem "$DIST"/*.crate "$DIST"/*.tgz \
         "$DIST"/*.nupkg "$DIST"/*.tar.gz "$DIST"/*.tar "$DIST"/*.rock; do
  nonempty "$f" "artifact"
  say "$(basename "$f") OK — present, non-empty"
  checked=$((checked + 1))
done

[ "$checked" -gt 0 ] || fail "no distribution artifacts found in target/dist/"
say "PASS — $checked artifact(s) verified"
