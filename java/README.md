# phonenumber_ae — Java

A thin Java binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
Java 22+ FFM (Panama) marshalling over `libphonenumber_ae.so`. It is the one FFI
for the whole JVM family — Kotlin, Clojure and Groovy layer over these classes.
See the [repo README](../README.md) for the whole picture.

## Use it

```java
import org.libphonenumber.ae.PhoneNumbers;
import org.libphonenumber.ae.Format;
import org.libphonenumber.ae.NumberType;
import org.libphonenumber.ae.Carrier;
import org.libphonenumber.ae.Geocoder;

PhoneNumbers.isValidNumber("US", "+1 201 555 0123");         // true
PhoneNumbers.format("US", "2015550123", Format.NATIONAL);    // "(201) 555-0123"
PhoneNumbers.formatE164("US", "2015550123");                 // "+12015550123"
PhoneNumbers.numberType("US", "2015550123");                 // NumberType.FIXED_LINE
PhoneNumbers.countryCode("JP");                              // "81"

// side-libraries
Carrier.carrierNameForNumber("GB", "7106000000");            // "O2"
Geocoder.geoDescriptionForNumber("US", "6502530000");        // "Mountain View, CA"
```

All entry points are static and stateless; the core is loaded lazily and cached.

## Install it in your project

Build the fat jar (from the repo root), then add it to your classpath — the
core `.so` is bundled at `/native/` inside the jar, so nothing else is needed:

```sh
aeb core/.build.ae && aeb java/.jar.ae   # -> target/dist/phonenumber-ae.jar
java -cp phonenumber-ae.jar:. MyApp
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the jar's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb java/.jar.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb java/.jar.ae
```

Same jar either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The jar is self-contained and current-OS-only (it bundles this platform's `.so`).
On first use `Native.openLibrary()` extracts `/native/libphonenumber_ae.so` from
the classpath to a temp file and dlopens it — an installed jar needs no
`LIBPHONENUMBER_AE_LIB` and no external `.so`. Run with
`--enable-native-access=ALL-UNNAMED` to silence the FFM warning.

## Develop / test

```sh
aeb java/.tests.ae      # the 47-check conformance suite
```
