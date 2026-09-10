# libphonenumber-ae — Kotlin

Validate and format international phone numbers.

This layer is **idiomatic sugar only**. It carries no phone-number logic *and no
FFI*: it compiles against the Java binding (`java/`, FFM / Panama) and reaches
the pure-Aether engine in `core/phonenumber.ae` through it, by ordinary JVM
interop.

That is deliberate. There is exactly **one** FFI per runtime in this monorepo,
and on the JVM it is `java/src/main/java/org/libphonenumber/ae`. A
Kotlin-specific FFI would be a second copy of the ABI's marshalling and
ownership rules to keep in step with `core/embed.ae` — and the first thing to
drift. Kotlin, Groovy and Clojure are all thin layers over the same Java
classes.

## Requirements

* **JDK 22 or newer** — the FFM API the Java binding uses is final in 22, so
  `--enable-preview` is *not* needed, but `--enable-native-access=ALL-UNNAMED`
  is.
* **Kotlin 2.x** (older compilers cannot read the Java binding's JDK 22+ class
  files) — see [Toolchain](#toolchain).

## Use

```kotlin
import org.libphonenumber.ae.kotlin.*
import org.libphonenumber.ae.Format

countryCode("US")                          // "1"
isValidNumber("US", "+1 201 555 0123")     // true
nationalNumber("US", "+1 201 555 0123")    // "2015550123"

format("US", "2015550123")                 // "(201) 555-0123"  (NATIONAL default)
format("US", "2015550123", Format.E164)    // "+12015550123"
formatInternational("US", "2015550123")    // "+1 (201) 555-0123"

numberType("US", "2015550123")             // NumberType.FIXED_LINE
regions                                     // ["AC", "AD", ...]  (a property)
abiVersion()                                // 5

// short / emergency numbers (ShortNumberInfo)
isEmergencyNumber("US", "911")             // true
isValidShortNumber("US", "911")            // true
shortExpectedCost("US", "911")             // ShortNumberCost.TOLL_FREE
shortExampleNumber("US")                   // "112"

// time zones (PhoneNumberToTimeZonesMapper)
timeZonesForNumber("US", "2015550123")     // ["America/New_York"]
timeZonesForNumber("GB", "2070313000")     // ["Europe/London"]
unknownTimeZone()                          // "Etc/Unknown"

// carrier names (PhoneNumberToCarrierMapper)
carrierNameForNumber("GB", "7106000000")   // "O2"
carrierNameForValidNumber("GB", "7106000000") // "O2" (only if valid)
```

Everything above is a top-level function (or the `regions` property) over the
Java `PhoneNumbers` class, which remains available and unchanged. `format`
defaults its style to `NATIONAL`.

## Tests

```
aeb kotlin/.tests.ae
```

The suite is a plain main method, not JUnit — same reason as the Java binding's:
it must run with nothing but a JDK and a Kotlin compiler, so it works offline
and cannot fail resolving a test-framework artifact. It mirrors the 18 checks in
`docs/conformance.md` and adds a couple specific to the Kotlin surface (the
default-style `format`, the format helpers).

## Toolchain

`kotlin/.tests.ae` **skips** (green) rather than failing if `KOTLIN_HOME` is not
set to a usable Kotlin. "Usable" is a stronger condition than "on PATH":

The Java binding is compiled by a JDK 22+ `javac`, because the FFM API does not
exist before 22. Its class files are therefore major version 66+. A Kotlin
compiler older than roughly 2.x rejects those with
`Unsupported class file major version`. Debian's `kotlinc` is 1.3 and fails
exactly that way — it also only runs under JDK 17 or older itself.

Point `KOTLIN_HOME` at a real kotlinc 2.x layout — `<home>/bin/kotlinc` plus
`<home>/lib/kotlin-stdlib.jar` — and re-run. Without it the node reports a skip,
not a pass.

## Engine resolution

Inherited from the Java binding: an explicit path,
`$LIBPHONENUMBER_AE_LIB`, the `libphonenumber_ae.lib` system property, `native/`
beside the jar, then the OS loader's own search path. `aeb` sets
`LIBPHONENUMBER_AE_LIB` for you.
