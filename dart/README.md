# phonenumber_ae (Dart)

Validate, parse and format international phone numbers.

This package is a **thin `dart:ffi` binding** over the monorepo's one shared
native engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether
over Google libphonenumber's own metadata. It contains **no phone-number
logic**: every member marshals to an `aether_pn_embed_*` call. One engine, one
set of behaviours, N language surfaces.

It speaks the full **v2** `aether_pn_embed_*` C ABI (50 symbols, full
PhoneNumberUtil parity — `docs/abi.md`). Every signature is still scalar-only
(`const char*` and `int`), and there are still no opaque handles: a parsed
number and an as-you-type state are themselves caller-owned *strings*.

## Building

The engine is `dlopen`ed at runtime, so nothing needs to link against it — just
build it first:

```sh
aeb core/.build.ae
cd dart && dart pub get
```

Library resolution, in order:

1. an explicit path — `Api.open('/path/to/lib.so')`
2. `$LIBPHONENUMBER_AE_LIB` (what the in-tree `.tests.ae` leaf sets)
3. `native/` next to the package, then `../core/native/` and `core/native/`
   (the in-tree monorepo layout)
4. the OS loader's own search path

`pn.nativeLibraryPath` reports which one actually loaded.

## Usage

```dart
import 'package:phonenumber_ae/phonenumber_ae.dart' as pn;

// Parse into a ParsedNumber and read its fields on demand.
final num = pn.parse('+1 201 555 0123 ext 42', 'US');
num.nationalNumber;   // '2015550123'
num.extension;        // '42'
num.countryCode;      // '1'
num.regionCode;       // 'US'
num.source;           // CountryCodeSource.fromNumberWithPlus

// Stateless validation / formatting.
pn.isValidNumber('US', '+1 201 555 0123');                  // true
pn.isPossibleNumberWithReason('US', '201555');              // ValidationResult.tooShort
pn.format('US', '2015550123', pn.PhoneFormat.national);      // '(201) 555-0123'
pn.format('US', '2015550123', pn.PhoneFormat.e164);          // '+12015550123'
pn.format('US', '2015550123', pn.PhoneFormat.international);  // '+1 201-555-0123'
pn.numberType('US', '2015550123');                          // PhoneNumberType.fixedLine
pn.countryCode('JP');                                       // '81'
pn.regions();                                               // ['AC', 'AD', 'AE', …]

// Format a number as it is typed.
final ayt = pn.AsYouTypeFormatter('US');
var out = '';
for (final c in '6502530000'.split('')) out = ayt.inputDigit(c);   // '(650) 253-0000'

// Find numbers in free text.
final matches = pn.findNumbers('call 201-555-0123 or +1 202 555 0199', 'US');
matches.length;        // 2
matches.first.raw;     // '201-555-0123'
matches.first.start;   // 5
matches.first.end;     // 17
```

### Surface

* **Metadata** — `countryCode`, `exampleNumber`, `exampleNumberForType`,
  `invalidExampleNumber`, `possibleLengths`, `regionCodeForCountryCode`,
  `isNanpaCountry`, `nddPrefixForRegion`, `regions`, `ccRegionCount`,
  `regionsForCountryCode`.
* **Parse** — `parse(input, region)` → a `ParsedNumber` with getters `region`,
  `countryCode`, `nationalNumber`, `extension`, `italianLeadingZero`, `source`,
  `error`, `regionCode`, `nationalSignificantNumber`, `lengthOfNdc`,
  `lengthOfAreaCode`, `isGeographical`, plus `formatInOriginal(callingFrom)`;
  and `nationalNumber(region, input)`.
* **Validation** — `isPossibleNumber`, `isPossibleNumberWithReason`,
  `isValidNumber`, `isValidNumberForRegion`, `numberType`,
  `canBeInternationallyDialled`.
* **Formatting** — `format(region, input, [style])`, `formatNational`,
  `formatInternational`, `formatE164`, `formatRfc3966`, `formatOutOfCountry`.
* **Helpers** — `isNumberMatch`, `truncateTooLong`, `normalizeDigitsOnly`,
  `convertAlphaCharacters`, `isAlphaNumber`, `abiVersion`, `nativeLibraryPath`.
* **`AsYouTypeFormatter`** — `AsYouTypeFormatter(region)`, `inputDigit(ch)`,
  `result()`, `clear()`.
* **`findNumbers(text, region, {leniency})`** — a `List<PhoneNumberMatch>` with
  `start`, `end`, `raw`.

### Enums

`PhoneFormat` (v2 renumbered these — **`e164` is now `0`, not `2`**): `e164`
(0), `international` (1), `national` (2), `rfc3966` (3).

`PhoneNumberType`: `unknown` (-1), `fixedLine` (0), `mobile` (1), `tollFree`
(2), `premiumRate` (3), `sharedCost` (4), `voip` (5), `personalNumber` (6),
`pager` (7), `uan` (8), `voicemail` (9). `PhoneNumberType.fromCode(int)` maps an
ABI integer back to the enum.

`ValidationResult` (`isPossibleNumberWithReason`): `isPossible` (0),
`isPossibleLocalOnly` (4), `invalidCountryCode` (1), `tooShort` (2),
`invalidLength` (5), `tooLong` (3).

`MatchType` (`isNumberMatch`): `notANumber` (0), `noMatch` (1), `shortNsn` (2),
`nsn` (3), `exact` (4).

`CountryCodeSource` (`ParsedNumber.source`): `fromNumberWithPlus` (1),
`fromNumberWithIdd` (5), `fromNumberWithoutPlus` (10), `fromDefaultCountry`
(20).

`Leniency` (`findNumbers`): `possible` (0), `valid` (1).

## Memory

Every `char*` the engine returns is caller-owned. `Api.takeString` copies it
into a Dart string and frees it through `aether_pn_embed_free_string` in a
`finally`; every string result in this package goes through that one function.
Strings handed *to* the engine are allocated with `calloc` and freed in a
`finally` around the call. A `ParsedNumber` and an `AsYouTypeFormatter` each
hold a caller-owned ABI *string* (the parsed-number blob, the formatter state);
`inputDigit` threads a fresh state and frees the old one via `takeString`.
Because this ABI has no callbacks, there are no trampolines, no keepalive list,
and nothing borrowed to track.

## Tests

The 34-check v2 conformance suite (`docs/conformance.md`) lives in
`test/conformance_test.dart`.

```sh
aeb dart/.tests.ae     # builds the engine, then runs dart test
# or, with the engine already built:
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so dart test
```

`.tests.ae` skips (exit 0, with a clear `dart: SKIPPED` line) when no Dart SDK
is on `PATH`, or when `dart pub get` cannot resolve dependencies — rather than
failing the build DAG for a missing toolchain.
