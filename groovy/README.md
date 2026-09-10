# libphonenumber-ae — Groovy

Validate and format international phone numbers.

This layer is **idiomatic sugar only**. It carries no phone-number logic *and no
FFI*: it compiles against the Java binding (`java/`, FFM / Panama) and reaches
the pure-Aether engine in `core/phonenumber.ae` through it, by ordinary JVM
interop.

That is deliberate. There is exactly **one** FFI per runtime in this monorepo,
and on the JVM it is `java/src/main/java/org/libphonenumber/ae`. A
Groovy-specific FFI would be a second copy of the ABI's marshalling and
ownership rules to keep in step with `core/embed.ae` — and the first thing to
drift. Kotlin, Groovy and Clojure are all thin layers over the same Java
classes.

## Requirements

* **JDK 22 or newer** — the FFM API the Java binding uses is final in 22, so
  `--enable-preview` is *not* needed, but `--enable-native-access=ALL-UNNAMED`
  is.
* **Groovy 4.x** on a JDK 22+ VM — see [Toolchain](#toolchain).

## Use

```groovy
import static org.libphonenumber.ae.groovy.PhoneNumbers.*
import org.libphonenumber.ae.Format

countryCode('US')                          // "1"
isValidNumber('US', '+1 201 555 0123')     // true
nationalNumber('US', '+1 201 555 0123')    // "2015550123"

format('US', '2015550123')                 // "(201) 555-0123"  (NATIONAL default)
format('US', '2015550123', Format.E164)    // "+12015550123"
formatInternational('US', '2015550123')    // "+1 (201) 555-0123"

numberType('US', '2015550123')             // NumberType.FIXED_LINE
regions()                                   // ["AC", "AD", ...]
abiVersion()                                // 5

// short / emergency numbers (ShortNumberInfo)
isEmergencyNumber('US', '911')             // true
isValidShortNumber('US', '911')            // true
shortExpectedCost('US', '911')             // ShortNumberCost.TOLL_FREE
shortExampleNumber('US')                   // "112"

// time zones (PhoneNumberToTimeZonesMapper)
timeZonesForNumber('US', '2015550123')     // ["America/New_York"]
timeZonesForNumber('GB', '2070313000')     // ["Europe/London"]
unknownTimeZone()                          // "Etc/Unknown"

// carrier names (PhoneNumberToCarrierMapper)
carrierNameForNumber('GB', '7106000000')   // "O2"
carrierNameForValidNumber('GB', '7106000000') // "O2" (only if valid)
```

`PhoneNumbers` is a Groovy facade over the Java `PhoneNumbers` class, which
remains available and unchanged. `format` defaults its style to `NATIONAL`.

## Tests

```
aeb groovy/.tests.ae
```

or directly:

```
PN_JAVA_CLASSES=../target/.aeb/java-classes \
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
  ./run-tests.sh
```

The suite is a plain main method, not Spock/JUnit — same reason as the Java
binding's: it must run with nothing but a JDK and the Groovy jar, so it works
offline and cannot fail resolving a test-framework artifact. It mirrors the 18
checks in `docs/conformance.md` plus a couple specific to the Groovy surface.

## Toolchain

`groovy/.tests.ae` **skips** (exit 77, reported green) rather than failing if no
usable Groovy is present. "Usable" is a stronger condition than "on PATH":

groovyc *loads* the classes it compiles against into its own JVM, so it must be
BOTH new enough (Groovy 4+) AND running on a JDK 22+ VM — the Java binding's
classes are major version 66+ because the FFM API does not exist before 22.
Debian's `groovy` is 2.4 on JDK 17 and dies with `UnsupportedClassVersionError`.

`run-tests.sh` therefore does not trust `command -v groovy`. It probes
candidates (`$GROOVY_JAR`, `$GROOVY_HOME`, the `groovy` on PATH, jars in `~/.m2`
or a Gradle distribution) and **verifies each by compiling and running a
one-liner against the real Java classes** before committing to it. If none
works, it exits 77 and the node reports a skip — never a pass.

## Engine resolution

Inherited from the Java binding: an explicit path, `$LIBPHONENUMBER_AE_LIB`, the
`libphonenumber_ae.lib` system property, `native/` beside the jar, then the OS
loader's own search path. `aeb` sets `LIBPHONENUMBER_AE_LIB` for you.
