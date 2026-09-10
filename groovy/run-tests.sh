#!/usr/bin/env sh
# Compile and run the Groovy conformance suite.
#
# Inputs (set by groovy/.tests.ae; all have sensible defaults for a manual run):
#   PN_JAVA_CLASSES      the Java binding's compiled classes (java/.build.ae artifact)
#   PN_OUT               where to put the compiled Groovy classes
#   LIBPHONENUMBER_AE_LIB  the engine .so                    (core/.build.ae artifact)
#
# Exit codes: 0 pass, 1 fail, 77 = no usable Groovy toolchain (SKIP).
#
# ---------------------------------------------------------------------------
# Why this is not just `groovyc`
#
# The Java binding is compiled by a JDK 22+ javac, because the FFM API it binds
# through does not exist before 22 — so its class files are major version 66+.
# groovyc LOADS the classes it compiles against into its own JVM, so it fails on
# those unless it is BOTH new enough (Groovy 4+) and running on a JDK 22+ VM:
#
#     UnsupportedClassVersionError: ... class file version 68.0
#
# Debian's `groovy` package is 2.4 on JDK 17 and fails exactly that way. So
# "groovy is on PATH" is NOT the same question as "Groovy can build this". We
# probe candidates and VERIFY the choice by compiling AND running a one-liner
# against the real Java classes before committing to it.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")

PN_JAVA_CLASSES=${PN_JAVA_CLASSES:-"$root/target/.aeb/java-classes"}
PN_OUT=${PN_OUT:-"$root/target/.aeb/groovy-classes"}
LIBPHONENUMBER_AE_LIB=${LIBPHONENUMBER_AE_LIB:-"$root/target/build/core/lib/libphonenumber_ae.so"}
export LIBPHONENUMBER_AE_LIB

if [ ! -d "$PN_JAVA_CLASSES" ] && [ ! -f "$PN_JAVA_CLASSES" ]; then
    echo "groovy: the Java binding classes are missing ($PN_JAVA_CLASSES)." >&2
    echo "groovy: run \`aeb java/.build.ae\` first, or use \`aeb groovy/.tests.ae\`." >&2
    exit 1
fi

# ---- a JVM new enough to RUN (and compile against) the FFM binding ----
find_run_java() {
    for cand in \
        "${JAVA_HOME:-}/bin/java" \
        /usr/lib/jvm/java-24-*/bin/java \
        /usr/lib/jvm/java-23-*/bin/java \
        /usr/lib/jvm/java-22-*/bin/java \
        "$(command -v java 2>/dev/null || true)"
    do
        [ -x "$cand" ] || continue
        v=$("$cand" -XshowSettings:properties -version 2>&1 \
            | sed -n 's/.*java\.specification\.version = \([0-9][0-9]*\).*/\1/p' | head -1)
        [ -n "$v" ] || continue
        [ "$v" -ge 22 ] 2>/dev/null || continue
        echo "$cand"
        return 0
    done
    return 1
}

RUN_JAVA=$(find_run_java || true)
if [ -z "$RUN_JAVA" ]; then
    echo "groovy: skipped: no JDK 22+ to run the FFM binding on"
    exit 77
fi

# ---- find a Groovy jar that can read JDK 22+ bytecode ----
probe_dir=$(mktemp -d)
trap 'rm -rf "$probe_dir"' EXIT
# The probe both COMPILES against the real Java classes (which a Groovy too old
# to read JDK 22+ bytecode cannot do) and RUNS, touching the FFM-bearing class.
cat > "$probe_dir/Probe.groovy" <<'EOF'
import org.libphonenumber.ae.PhoneNumbers
class Probe {
    static void main(String[] args) {
        assert PhoneNumbers.countryCode('US') == '1'
        println('probe-ok')
    }
}
EOF

GROOVY_CP=""

try_groovy_cp() {
    cp=$1
    [ -n "$cp" ] || return 1
    rm -rf "$probe_dir/out"
    mkdir -p "$probe_dir/out"
    "$RUN_JAVA" -cp "$cp" org.codehaus.groovy.tools.FileSystemCompiler \
        -cp "$PN_JAVA_CLASSES" -d "$probe_dir/out" "$probe_dir/Probe.groovy" \
        >"$probe_dir/log" 2>&1 || return 1
    grep -q 'UnsupportedClassVersionError\|class file version' "$probe_dir/log" && return 1
    "$RUN_JAVA" --enable-native-access=ALL-UNNAMED \
        -cp "$cp:$PN_JAVA_CLASSES:$probe_dir/out" Probe \
        >"$probe_dir/runlog" 2>&1 || return 1
    grep -q 'probe-ok' "$probe_dir/runlog" || return 1
    GROOVY_CP=$cp
    return 0
}

# Only groovy-<digits>.jar is the core jar (rejects groovy-xml etc.); sort on
# the extracted version, not the full path, so the newest Groovy wins wherever
# it lives.
list_core_groovy_jars() {
    for d in "$@"; do
        [ -d "$d" ] || continue
        for j in "$d"/groovy-[0-9]*.jar; do
            [ -f "$j" ] || continue
            case $(basename "$j") in
                groovy-[0-9]*) ;;
                *) continue ;;
            esac
            echo "$j"
        done
    done | grep -v sources | while read -r j; do
        v=$(basename "$j" .jar | sed 's/^groovy-//')
        printf '%s\t%s\n' "$v" "$j"
    done | sort -Vr | cut -f2
}

cp_from_libdir() {
    j=$(list_core_groovy_jars "$1" | head -1)
    [ -n "$j" ] || return 1
    echo "$j"
}

# 1. explicit override
if [ -n "${GROOVY_JAR:-}" ] && [ -f "$GROOVY_JAR" ]; then
    try_groovy_cp "$GROOVY_JAR" || true
fi

# 2. $GROOVY_HOME, or the groovy on PATH
if [ -z "$GROOVY_CP" ] && [ -n "${GROOVY_HOME:-}" ]; then
    c=$(cp_from_libdir "$GROOVY_HOME/lib" || true)
    [ -n "$c" ] && { try_groovy_cp "$c" || true; }
fi
if [ -z "$GROOVY_CP" ] && command -v groovy >/dev/null 2>&1; then
    gh=$(dirname "$(dirname "$(readlink -f "$(command -v groovy)")")")
    c=$(cp_from_libdir "$gh/lib" || true)
    [ -n "$c" ] && { try_groovy_cp "$c" || true; }
fi

# 3. a groovy jar from the local Maven repo or a Gradle distribution, newest first.
if [ -z "$GROOVY_CP" ]; then
    for jar in $(list_core_groovy_jars \
            "$HOME"/.m2/repository/org/apache/groovy/groovy/* \
            "$HOME"/.m2/repository/org/codehaus/groovy/groovy/* \
            "$HOME"/.gradle/wrapper/dists/*/*/*/lib)
    do
        try_groovy_cp "$jar" && break
    done
fi

if [ -z "$GROOVY_CP" ]; then
    if command -v groovy >/dev/null 2>&1; then
        echo "groovy: skipped: groovy not installed at a version that can read JDK 22+ bytecode"
        echo "groovy:   (the groovy on PATH is too old — groovyc loads the Java binding's"
        echo "groovy:    classes, which are JDK 22+ because the FFM API requires it)"
    else
        echo "groovy: skipped: groovy not installed"
    fi
    echo "groovy:   install Groovy 4.x on a JDK 22+ VM, or set GROOVY_JAR to a"
    echo "groovy:   groovy-4.x jar, then re-run."
    exit 77
fi

# ---- compile ----
rm -rf "$PN_OUT"
mkdir -p "$PN_OUT"

sources=$(find "$here/src" -name '*.groovy' | sort)

# shellcheck disable=SC2086
"$RUN_JAVA" -cp "$GROOVY_CP" org.codehaus.groovy.tools.FileSystemCompiler \
    -cp "$PN_JAVA_CLASSES" -d "$PN_OUT" $sources

# ---- run ----
# FFM is final in JDK 22, so --enable-preview is NOT needed; the native access
# flag is, and without it the JVM only warns today but will refuse later.
exec "$RUN_JAVA" --enable-native-access=ALL-UNNAMED \
    -cp "$GROOVY_CP:$PN_JAVA_CLASSES:$PN_OUT" org.libphonenumber.ae.groovy.ConformanceTest
