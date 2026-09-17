# phonenumber_ae — Kotlin

A thin Kotlin binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this layer carries no
FFI of its own — it is idiomatic sugar over the Java binding (FFM / Panama), which
holds the single JVM FFI. See the [repo README](../README.md) for the whole picture.

## Use it

```kotlin
import org.libphonenumber.ae.kotlin.*
import org.libphonenumber.ae.Format

isValidNumber("US", "+1 201 555 0123")     // true
format("US", "2015550123")                 // "(201) 555-0123"  (NATIONAL default)
format("US", "2015550123", Format.E164)    // "+12015550123"
numberType("US", "2015550123")             // NumberType.FIXED_LINE
countryCode("JP")                          // "81"

// side-libraries
carrierNameForNumber("GB", "7106000000")       // "O2"
geoDescriptionForNumber("US", "6502530000")    // "Mountain View, CA"
```

Everything is a top-level function (with `regions` as a property) over the Java
`PhoneNumbers` class; `format` defaults its style to `NATIONAL`.

## Install it in your project

Build the binding jar (from the repo root), then add it to your classpath — this
thin jar layers over the Java fat jar and the Kotlin stdlib:

```sh
aeb core/.build.ae && aeb kotlin/.dist.ae   # -> target/dist/kotlin-phonenumber-ae.jar
kotlinc -cp kotlin-phonenumber-ae.jar:phonenumber-ae.jar MyApp.kt
```

Only the Java fat jar (`phonenumber-ae.jar`, from `aeb java/.jar.ae`) carries the
core `.so` — it is bundled at `/native/` and self-extracts on first use, so put
both jars on the classpath and no external `.so` or `LIBPHONENUMBER_AE_LIB` is
needed. Building the jar needs a real kotlinc 2.x via `KOTLIN_HOME` (Debian's 1.3
cannot read the Java binding's FFM-era bytecode).

## Develop / test

```sh
KOTLIN_HOME=/path/to/kotlinc aeb kotlin/.tests.ae   # the 47-check conformance suite
```

