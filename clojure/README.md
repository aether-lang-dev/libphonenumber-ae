# phonenumber_ae — Clojure

A thin Clojure binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this layer carries no
FFI of its own — it is idiomatic sugar over the Java binding (FFM / Panama), which
holds the single JVM FFI. See the [repo README](../README.md) for the whole picture.

## Use it

```clojure
(require '[org.libphonenumber.ae.core :as pn])

(pn/valid-number? "US" "+1 201 555 0123")    ;; => true
(pn/format-number "US" "2015550123")         ;; => "(201) 555-0123"  (:national default)
(pn/format-number "US" "2015550123" :e164)   ;; => "+12015550123"
(pn/number-type "US" "2015550123")           ;; => :fixed-line
(pn/country-code "JP")                        ;; => "81"

;; side-libraries
(pn/carrier-name-for-number "GB" "7106000000")     ;; => "O2"
(pn/geo-description-for-number "US" "6502530000")   ;; => "Mountain View, CA"
```

`number-type` returns a keyword and `format-number` takes one, so callers never
touch the Java enums; both degrade to a fallback rather than throwing.

## Install it in your project

Build the binding jar (from the repo root), then add it plus the Java fat jar to
your classpath — this is a source jar (`.clj` loaded at the consumer, the
idiomatic Clojure library shape) that layers over the Java jar and a Clojure runtime:

```sh
aeb core/.build.ae && aeb clojure/.dist.ae   # -> target/dist/clojure-phonenumber-ae.jar
clj -Scp clojure-phonenumber-ae.jar:phonenumber-ae.jar:$(clojure -Spath) -M -e "(require 'org.libphonenumber.ae.core)"
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the jar's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb clojure/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb clojure/.dist.ae
```

Same jar either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

Only the Java fat jar (`phonenumber-ae.jar`, from `aeb java/.jar.ae`) carries the
core `.so` — it is bundled at `/native/` and self-extracts on first use, so put
both jars on the classpath and no external `.so` or `LIBPHONENUMBER_AE_LIB` is
needed. Runs on any Clojure 1.11+ on a JDK 22+ VM.

## Develop / test

```sh
aeb clojure/.tests.ae      # the 47-check conformance suite
```

