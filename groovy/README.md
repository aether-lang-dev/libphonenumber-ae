# phonenumber_ae — Groovy

A thin Groovy binding over the shared, pure-Aether libphonenumber engine. All the
phone logic lives in the one engine (`core/phonenumber.ae`); this layer carries no
FFI of its own — it is idiomatic sugar over the Java binding (FFM / Panama), which
holds the single JVM FFI. See the [repo README](../README.md) for the whole picture.

## Use it

```groovy
import static org.libphonenumber.ae.groovy.PhoneNumbers.*
import org.libphonenumber.ae.Format

isValidNumber('US', '+1 201 555 0123')     // true
format('US', '2015550123')                 // "(201) 555-0123"  (NATIONAL default)
format('US', '2015550123', Format.E164)    // "+12015550123"
numberType('US', '2015550123')             // NumberType.FIXED_LINE
countryCode('JP')                          // "81"

// side-libraries
carrierNameForNumber('GB', '7106000000')       // "O2"
geoDescriptionForNumber('US', '6502530000')    // "Mountain View, CA"
```

`PhoneNumbers` is a Groovy facade over the Java `PhoneNumbers` class, which stays
available and unchanged; `format` defaults its style to `NATIONAL`.

## Install it in your project

Build the binding jar (from the repo root), then add it plus the Java fat jar to
your classpath — this is a source jar (`.groovy` compiled at the consumer, the
idiomatic Groovy shape) that layers over the Java jar and a Groovy runtime:

```sh
aeb core/.build.ae && aeb groovy/.dist.ae   # -> target/dist/groovy-phonenumber-ae.jar
groovy -cp groovy-phonenumber-ae.jar:phonenumber-ae.jar MyApp.groovy
```

Only the Java fat jar (`phonenumber-ae.jar`, from `aeb java/.jar.ae`) carries the
engine `.so` — it is bundled at `/native/` and self-extracts on first use, so put
both jars on the classpath and no external `.so` or `LIBPHONENUMBER_AE_LIB` is
needed. Runs on any Groovy 4.x on a JDK 22+ VM.

## Develop / test

```sh
aeb groovy/.tests.ae      # the 47-check conformance suite
```

