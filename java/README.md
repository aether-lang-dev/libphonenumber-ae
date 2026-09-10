# libphonenumber-ae — Java

Validate and format international phone numbers.

This is the **one JVM binding** to the shared Aether phonenumber engine. It uses
the Java 22+ Foreign Function & Memory API (FFM / Panama) to load
`core/phonenumber.ae`'s compiled `.so` and call its flat C ABI. The Kotlin,
Groovy and Clojure layers in this monorepo are **thin wrappers over these
classes** — there is exactly one FFI per runtime, and on the JVM it lives here.

The binding carries **no phone-number logic**: the metadata table, validation,
number-type classification and formatting are all in the pure-Aether engine,
shared by every language binding. Cross-language behaviour is therefore
identical by construction, not by test.

## Requirements

* **JDK 22 or newer** — the FFM API is final in 22, so `--enable-preview` is
  *not* needed, but `--enable-native-access=ALL-UNNAMED` is.

## Use

```java
import org.libphonenumber.ae.PhoneNumbers;
import org.libphonenumber.ae.Format;
import org.libphonenumber.ae.NumberType;
import org.libphonenumber.ae.ShortNumberInfo;
import org.libphonenumber.ae.ShortNumberCost;
import org.libphonenumber.ae.TimeZones;
import org.libphonenumber.ae.Carrier;
import org.libphonenumber.ae.Geocoder;

PhoneNumbers.countryCode("US");                        // "1"
PhoneNumbers.isValidNumber("US", "+1 201 555 0123");   // true
PhoneNumbers.nationalNumber("US", "+1 201 555 0123");  // "2015550123"

PhoneNumbers.format("US", "2015550123", Format.NATIONAL);      // "(201) 555-0123"
PhoneNumbers.formatE164("US", "2015550123");                   // "+12015550123"
PhoneNumbers.formatInternational("US", "2015550123");          // "+1 (201) 555-0123"

PhoneNumbers.numberType("US", "2015550123");           // NumberType.FIXED_LINE
PhoneNumbers.regions();                                // ["AC", "AD", "AE", ...]
PhoneNumbers.abiVersion();                             // 7

// short / emergency numbers (ShortNumberInfo)
ShortNumberInfo.isEmergencyNumber("US", "911");        // true
ShortNumberInfo.isValidShortNumber("US", "911");       // true
ShortNumberInfo.expectedCost("US", "911");             // ShortNumberCost.TOLL_FREE
ShortNumberInfo.exampleNumber("US");                   // "112"

// time zones (PhoneNumberToTimeZonesMapper)
TimeZones.timeZonesForNumber("US", "2015550123");      // ["America/New_York"]
TimeZones.timeZonesForNumber("GB", "2070313000");      // ["Europe/London"]
TimeZones.unknownTimeZone();                           // "Etc/Unknown"

// carrier names (PhoneNumberToCarrierMapper) — lang defaults to "en"
Carrier.carrierNameForNumber("GB", "7106000000");            // "O2"
Carrier.carrierNameForNumber("GB", "7106000000", "de");      // localized to German
Carrier.carrierNameForValidNumber("GB", "7106000000");       // "O2" (only if valid)

// geographic descriptions (PhoneNumberOfflineGeocoder) — lang defaults to "en"
Geocoder.geoDescriptionForNumber("US", "6502530000");        // "Mountain View, CA"
Geocoder.geoDescriptionForNumber("US", "6502530000", "de");  // localized to German
Geocoder.geoDescriptionForValidNumber("US", "6502530000");   // "Mountain View, CA" (only if valid)
```

All entry points are static and stateless — the ABI has no handle. The engine
is loaded lazily and cached on first use.

## API surface

* `PhoneNumbers` — static methods: `countryCode`, `exampleNumber`,
  `possibleLengths`, `nationalNumber`, `isPossibleNumber`, `isValidNumber`,
  `numberType` (and `numberTypeCode`), `format`, `formatNational`,
  `formatInternational`, `formatE164`, `regions`, `abiVersion`.
* `Format` — `NATIONAL`, `INTERNATIONAL`, `E164`.
* `NumberType` — `UNKNOWN`, `FIXED_LINE`, `MOBILE`, `TOLL_FREE`,
  `PREMIUM_RATE`, `SHARED_COST`, `VOIP`, `PERSONAL_NUMBER`, `PAGER`, `UAN`,
  `VOICEMAIL`, plus `NumberType.of(int)`. `of` falls back to `UNKNOWN` for a
  code this build does not know, so a newer engine adding an (append-only) type
  cannot make the binding throw.
* `ShortNumberInfo` — static methods for short / emergency numbers:
  `isPossibleShortNumber`, `isValidShortNumber`, `isEmergencyNumber`,
  `connectsToEmergencyNumber`, `isCarrierSpecific`, `isSmsService`,
  `expectedCost` (and `expectedCostCode`), `exampleNumber`. Also delegated from
  `PhoneNumbers`.
* `ShortNumberCost` — `TOLL_FREE`, `STANDARD_RATE`, `PREMIUM_RATE`, `UNKNOWN`,
  plus `ShortNumberCost.of(int)` (falls back to `UNKNOWN`).
* `TimeZones` — static methods for the timezone mapper:
  `timeZonesForNumber` (a `List<String>` of IANA zone ids; a number with no
  known zone maps to `["Etc/Unknown"]`), `timeZoneCount`, `unknownTimeZone`.
  Also delegated from `PhoneNumbers`.
* `Carrier` — static methods for the carrier mapper (localized names, `lang`
  defaults to `"en"`): `carrierNameForNumber`, `carrierNameForValidNumber`
  (`""` = no known carrier). Also delegated from `PhoneNumbers`.
* `Geocoder` — static methods for the offline geocoder (localized descriptions,
  `lang` defaults to `"en"`): `geoDescriptionForNumber`,
  `geoDescriptionForValidNumber` (`""` = no known description). Also delegated
  from `PhoneNumbers`.
* `Native` — the FFM symbol table. The only class that knows the C ABI.

## Tests

```
aeb java/.tests.ae
```

or directly:

```
javac -d out $(find src/main/java src/test/java -name '*.java')
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
  java --enable-native-access=ALL-UNNAMED -cp out org.libphonenumber.ae.ConformanceTest
```

The suite is a plain `main` method, not JUnit: it must run with nothing but a
JDK, so it works offline and cannot fail resolving a test-framework artifact. It
asserts the 18 checks in `docs/conformance.md` plus a couple specific to the
Java surface (the `formatNational`/`International`/`E164` helpers, and that
`NumberType.of` degrades gracefully).

This binding is built by aeb/javac (`java/.build.ae`), not Maven. The
`java/pom.xml` in this repo belongs to the upstream Google libphonenumber Java
project and is left untouched; the Aether binding's sources live under
`java/src/main/java/org/libphonenumber/ae/`, a path Google's build does not use.

## Engine resolution

`Native.load` tries, in order:

1. an explicit path — `Native.load("/path/to/libphonenumber_ae.so")`
2. `$LIBPHONENUMBER_AE_LIB`, then the `libphonenumber_ae.lib` system property
3. `native/` beside the jar
4. the OS loader's own search path

Panama's `SymbolLookup.libraryLookup` goes through the OS loader directly and
**ignores `-Djava.library.path`**, which is why the path is passed as an env var
or `-D` property rather than the usual library-path flag.
