# libphonenumber-ae — Clojure

Validate and format international phone numbers.

This layer is **idiomatic sugar only**. It carries no phone-number logic *and no
FFI*: it calls the Java binding (`java/`, FFM / Panama) and reaches the
pure-Aether engine in `core/phonenumber.ae` through it, by ordinary JVM interop.

That is deliberate. There is exactly **one** FFI per runtime in this monorepo,
and on the JVM it is `java/src/main/java/org/libphonenumber/ae`. A
Clojure-specific FFI would be a second copy of the ABI's marshalling and
ownership rules to keep in step with `core/embed.ae` — and the first thing to
drift. Kotlin, Groovy and Clojure are all thin layers over the same Java
classes.

## Requirements

* **JDK 22 or newer** — the FFM API the Java binding uses is final in 22, so
  `--enable-preview` is *not* needed, but `--enable-native-access=ALL-UNNAMED`
  is.
* **A Clojure runtime** (1.11+) on a JDK 22+ VM — see [Toolchain](#toolchain).

## Use

```clojure
(require '[org.libphonenumber.ae.core :as pn])

(pn/country-code "US")                       ;; => "1"
(pn/valid-number? "US" "+1 201 555 0123")    ;; => true
(pn/national-number "US" "+1 201 555 0123")  ;; => "2015550123"

(pn/format-number "US" "2015550123")               ;; => "(201) 555-0123"  (:national default)
(pn/format-number "US" "2015550123" :e164)         ;; => "+12015550123"
(pn/format-international "US" "2015550123")         ;; => "+1 (201) 555-0123"

(pn/number-type "US" "2015550123")           ;; => :fixed-line
(pn/regions)                                  ;; => ["AC" "AD" ...]
(pn/abi-version)                              ;; => 1
```

The `number-type` result is a keyword and `format-number` takes one
(`:national`, `:international`, `:e164`), so callers never import the Java enums.
Both degrade to a fallback (`:unknown` / `:national`) rather than throwing on a
code this build does not know — the ABI's constants are append-only.

## Tests

```
aeb clojure/.tests.ae
```

or directly:

```
PN_JAVA_CLASSES=../target/.aeb/java-classes \
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
  ./run-tests.sh
```

The suite uses `clojure.test`, so the run needs nothing but the Clojure jar: it
works offline and cannot fail resolving a test-framework artifact. It mirrors
the 18 checks in `docs/conformance.md` plus a couple specific to the Clojure
surface.

## Toolchain

`clojure/.tests.ae` **skips** (exit 77, reported green) rather than failing if no
usable Clojure runtime is present. There is no AOT step — `clojure.main` loads
the namespaces from source — so the only requirement is a Clojure runtime jar on
a JDK 22+ VM (22+ because the runtime *loads* the Java binding's FFM-era
bytecode, not merely compiles against it).

`run-tests.sh` looks for `$CLOJURE_JARS`, then clojure jars in `~/.m2` or the
Gradle caches, then the `clojure`/`clj` CLI (verified with `-Sdescribe`, because
Debian ships a different tool of the same name). If none works, it exits 77 and
the node reports a skip — never a pass.

## Engine resolution

Inherited from the Java binding: an explicit path, `$LIBPHONENUMBER_AE_LIB`, the
`libphonenumber_ae.lib` system property, `native/` beside the jar, then the OS
loader's own search path. `aeb` sets `LIBPHONENUMBER_AE_LIB` for you.
