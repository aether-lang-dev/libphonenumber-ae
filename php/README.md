# phonenumber_ae (PHP)

Validate, parse and format international phone numbers.

This package is a **thin ext-ffi binding** over the monorepo's one shared
native engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether
over Google libphonenumber's own metadata. It contains **no phone-number
logic**: every method marshals to an `aether_pn_embed_*` call. One engine, one
set of behaviours, N language surfaces.

It speaks the full **v7** `aether_pn_embed_*` C ABI (66 symbols, full
PhoneNumberUtil parity plus ShortNumberInfo, TimeZones, Carrier and Geocoder —
`docs/abi.md`). Every signature is still scalar-only (`const char*` and `int`),
and there are still no opaque handles: a parsed number and an as-you-type state
are themselves caller-owned *strings*.

| File | Role |
|---|---|
| `src/Native.php` | the `FFI::cdef` symbol table — the **only** place that knows the ABI |
| `src/PhoneNumber.php` | the idiomatic PHP API over it (metadata, validation, formatting, helpers, `findNumbers`) |
| `src/ParsedNumber.php` | the value `PhoneNumber::parse()` returns, with field accessors |
| `src/AsYouTypeFormatter.php` | formats a number as it is typed |
| `src/PhoneNumberMatch.php` | one match `findNumbers()` returns (`start`, `end`, `raw`) |
| `src/ShortNumberInfo.php` | short / emergency-number queries (the v3 ABI addition) |
| `src/TimeZones.php` | IANA time-zone lookup (the v5 ABI addition) |
| `src/Carrier.php` | carrier-name lookup (v5 ABI addition; v7 optional `$lang`) |
| `src/Geocoder.php` | geographic-description lookup (v6 ABI addition; v7 optional `$lang`) |
| `tests/conformance.php` | the 45-check v7 conformance suite, as an assertion runner |

Requires **PHP 8.1+** and **ext-ffi**. No Composer dependencies at all — which
is also what lets it run on a box with no network.

## Requirements

`ext-ffi` ships with PHP but is not always enabled:

```sh
# Debian/Ubuntu
sudo apt install php-ffi
```

```ini
; php.ini
extension=ffi
ffi.enable=true      ; "preload" (a common distro default) blocks FFI::cdef from CLI
```

Or per-run, which is what the `.tests.ae` leaf does:

```sh
php -d ffi.enable=1 tests/conformance.php
```

## Building

The engine is `dlopen`ed at run time, so nothing links against it — just build
it first:

```sh
aeb core/.build.ae
```

Library resolution, in order:

1. an explicit path — `PhoneNumberAe\Native::load('/path/to/lib.so')`
2. `$LIBPHONENUMBER_AE_LIB` (what the in-tree `.tests.ae` leaf sets)
3. `native/` next to the package, then `../core/native/` (the monorepo layout),
   then the same two relative to the cwd
4. the OS loader's own search path

`PhoneNumber::nativeLibraryPath()` reports which candidate actually loaded.

## Usage

```php
use PhoneNumberAe\AsYouTypeFormatter;
use PhoneNumberAe\Carrier;
use PhoneNumberAe\Geocoder;
use PhoneNumberAe\PhoneNumber;
use PhoneNumberAe\ShortNumberInfo;
use PhoneNumberAe\TimeZones;

// Parse into a ParsedNumber and read its fields on demand.
$num = PhoneNumber::parse('+1 201 555 0123 ext 42', 'US');
$num->nationalNumber();   // '2015550123'
$num->extension();        // '42'
$num->countryCode();      // '1'
$num->regionCode();       // 'US'
$num->source();           // PhoneNumber::SRC_FROM_NUMBER_WITH_PLUS

// Stateless validation / formatting.
PhoneNumber::isValidNumber('US', '+1 201 555 0123');            // true
PhoneNumber::isPossibleNumberWithReason('US', '201555');       // PhoneNumber::VR_TOO_SHORT
PhoneNumber::format('US', '2015550123', PhoneNumber::NATIONAL); // '(201) 555-0123'
PhoneNumber::format('US', '2015550123', PhoneNumber::E164);     // '+12015550123'
PhoneNumber::format('US', '2015550123', PhoneNumber::INTERNATIONAL); // '+1 201-555-0123'
PhoneNumber::numberType('US', '2015550123');                   // 0 (TYPE_FIXED_LINE)
PhoneNumber::countryCode('JP');                                // '81'
PhoneNumber::regions();                                        // ['AC', 'AD', 'AE', …]

// Format a number as it is typed.
$ayt = new AsYouTypeFormatter('US');
$out = '';
foreach (str_split('6502530000') as $c) $out = $ayt->inputDigit($c);   // '(650) 253-0000'

// Find numbers in free text.
$matches = PhoneNumber::findNumbers('call 201-555-0123 or +1 202 555 0199', 'US');
count($matches);        // 2
$matches[0]->raw;       // '201-555-0123'
$matches[0]->start;     // 5
$matches[0]->end;       // 17

// Short / emergency numbers (v3 — ShortNumberInfo).
ShortNumberInfo::isEmergencyNumber('US', '911');   // true
ShortNumberInfo::isEmergencyNumber('GB', '999');   // true
ShortNumberInfo::isValid('US', '911');             // true
ShortNumberInfo::expectedCost('US', '911');        // ShortNumberInfo::COST_TOLL_FREE
ShortNumberInfo::exampleNumber('US');              // '112'

// Time zones + carrier (v5 — TimeZones, Carrier).
TimeZones::timeZonesForNumber('US', '2015550123'); // ['America/New_York']
TimeZones::timeZonesForNumber('GB', '2070313000'); // ['Europe/London']
TimeZones::unknownTimeZone();                      // 'Etc/Unknown'
Carrier::carrierNameForNumber('GB', '7106000000');       // 'O2'
Carrier::carrierNameForNumber('GB', '7106000000', 'en'); // 'O2' ($lang is optional, defaults to 'en')

// Geographic descriptions (v6 — Geocoder; v7 adds an optional $lang).
Geocoder::geoDescriptionForNumber('US', '6502530000');       // 'Mountain View, CA'
Geocoder::geoDescriptionForNumber('US', '6502530000', 'en'); // 'Mountain View, CA'
```

### Surface

* **Metadata** — `countryCode`, `exampleNumber`, `exampleNumberForType`,
  `invalidExampleNumber`, `possibleLengths`, `regionCodeForCountryCode`,
  `isNanpaCountry`, `nddPrefixForRegion`, `regions`, `ccRegionCount`,
  `regionsForCountryCode`.
* **Parse** — `parse(input, region)` → a `ParsedNumber` with accessors
  `region()`, `countryCode()`, `nationalNumber()`, `extension()`,
  `italianLeadingZero()`, `source()`, `error()`, `regionCode()`,
  `nationalSignificantNumber()`, `lengthOfNdc()`, `lengthOfAreaCode()`,
  `isGeographical()`, plus `formatInOriginal(callingFrom)`; and
  `nationalNumber(region, input)`.
* **Validation** — `isPossibleNumber`, `isPossibleNumberWithReason`,
  `isValidNumber`, `isValidNumberForRegion`, `numberType`,
  `canBeInternationallyDialled`.
* **Formatting** — `format(region, input, style)`, `formatNational`,
  `formatInternational`, `formatE164`, `formatRfc3966`, `formatOutOfCountry`.
* **Helpers** — `isNumberMatch`, `truncateTooLong`, `normalizeDigitsOnly`,
  `convertAlphaCharacters`, `isAlphaNumber`, `abiVersion`, `nativeLibraryPath`.
* **`AsYouTypeFormatter`** — `new AsYouTypeFormatter(region)`, `inputDigit(ch)`,
  `result()`, `clear()`.
* **`findNumbers(text, region, leniency)`** — a `list<PhoneNumberMatch>` with
  `start`, `end`, `raw`.
* **`ShortNumberInfo`** — short / emergency numbers: `isPossible`, `isValid`,
  `isEmergencyNumber`, `connectsToEmergencyNumber`, `isCarrierSpecific`,
  `isSmsService`, `expectedCost` (a `COST_*` int), `exampleNumber($region)`.
* **`TimeZones`** (v5) — IANA time-zone lookup:
  `timeZonesForNumber($region, $input)` (a `list<string>`; `['Etc/Unknown']`
  when none), `timeZoneCount($region, $input)`, `unknownTimeZone()`.
* **`Carrier`** (v5; v7 adds `$lang`) — carrier names:
  `carrierNameForNumber($region, $input, $lang = 'en')`,
  `carrierNameForValidNumber($region, $input, $lang = 'en')` (`''` when none). The
  optional `$lang` is an ISO code that localizes the result and defaults to `'en'`.
* **`Geocoder`** (v6; v7 adds `$lang`) — geographic descriptions:
  `geoDescriptionForNumber($region, $input, $lang = 'en')`,
  `geoDescriptionForValidNumber($region, $input, $lang = 'en')` (`''` when none). The
  optional `$lang` is an ISO code that localizes the result and defaults to `'en'`.

### Constants

Format styles (v2 renumbered these — **`E164` is now `0`, not `2`**): `E164`
(0), `INTERNATIONAL` (1), `NATIONAL` (2), `RFC3966` (3).

Number types: `TYPE_UNKNOWN` (-1), `TYPE_FIXED_LINE` (0), `TYPE_MOBILE` (1),
`TYPE_TOLL_FREE` (2), `TYPE_PREMIUM_RATE` (3), `TYPE_SHARED_COST` (4),
`TYPE_VOIP` (5), `TYPE_PERSONAL_NUMBER` (6), `TYPE_PAGER` (7), `TYPE_UAN` (8),
`TYPE_VOICEMAIL` (9).

ValidationResult (`isPossibleNumberWithReason`): `VR_IS_POSSIBLE` (0),
`VR_IS_POSSIBLE_LOCAL_ONLY` (4), `VR_INVALID_COUNTRY_CODE` (1), `VR_TOO_SHORT`
(2), `VR_INVALID_LENGTH` (5), `VR_TOO_LONG` (3).

MatchType (`isNumberMatch`): `MATCH_NOT_A_NUMBER` (0), `MATCH_NO_MATCH` (1),
`MATCH_SHORT_NSN` (2), `MATCH_NSN` (3), `MATCH_EXACT` (4).

CountryCodeSource (`ParsedNumber::source()`): `SRC_FROM_NUMBER_WITH_PLUS` (1),
`SRC_FROM_NUMBER_WITH_IDD` (5), `SRC_FROM_NUMBER_WITHOUT_PLUS` (10),
`SRC_FROM_DEFAULT_COUNTRY` (20).

Matcher leniency: `LENIENCY_POSSIBLE` (0), `LENIENCY_VALID` (1).

ShortNumberCost (`ShortNumberInfo::expectedCost()`): `COST_TOLL_FREE` (0),
`COST_STANDARD_RATE` (1), `COST_PREMIUM_RATE` (2), `COST_UNKNOWN` (3).

## Memory

Every `char*` the engine returns is caller-owned. `Native::takeString` copies
it with `FFI::string` and frees it through `aether_pn_embed_free_string` in a
`finally`; every string result in this package goes through that one function. A
`ParsedNumber` and an `AsYouTypeFormatter` each hold a caller-owned ABI *string*
(the parsed-number blob, the formatter state); `inputDigit` threads a fresh
state and frees the old one via `takeString`. Because this ABI has no callbacks,
there is no keepalive list and no borrowed pointers to track.

## Tests

The 45-check v7 conformance suite (`docs/conformance.md`) lives in
`tests/conformance.php`, alongside a couple of extras and a 5,000-iteration
loop over the caller-owned-string contract.

### Why an assertion runner and not PHPUnit

PHPUnit arrives via Composer, so `vendor/bin/phpunit` needs a `composer
install` — a network round trip, or a pre-warmed cache — before a single
assertion executes. The rest of this monorepo's bindings test with whatever is
already on the box, so this one does too: **no dependencies, no install**, and
the process exit code is the result. The suite falls back to a four-line PSR-4
autoloader when `vendor/autoload.php` is absent, so it runs from a bare
checkout.

```sh
aeb php/.tests.ae     # builds the engine, then runs the suite
# or, with the engine already built:
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
    php -d ffi.enable=1 tests/conformance.php
```

`.tests.ae` skips (exit 0, with a clear `php: SKIPPED` line) when no `php` is on
`PATH`, or when ext-ffi is not loaded — rather than failing the build DAG for a
missing toolchain.

> **Status on this checkout:** PHP is **not installed** on the development box
> these bindings were written on, so the PHP binding was upgraded to the v3 ABI
> (adding the `ShortNumberInfo` surface) to mirror the proven JavaScript and
> Dart bindings exactly but has not been executed here. `aeb php/.tests.ae`
> reports `php: SKIPPED` and exits 0. The engine ABI it targets is proven by
> `core_tests/abi_smoke.c` and by the Dart, Python and JavaScript bindings that
> do run against the same `.so`.
