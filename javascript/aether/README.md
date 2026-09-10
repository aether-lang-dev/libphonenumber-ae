# phonenumber_ae — JavaScript / Node binding

Validate, parse and format international phone numbers.

> This is the **Aether-engine binding**, distinct from the legacy Google
> Closure JavaScript port in `javascript/i18n/`. It marshals to the shared
> native engine rather than reimplementing phone logic in JavaScript.

This package is **marshalling only**. The engine itself — Google
libphonenumber's metadata, parse, `isPossible`/`isValid`, number typing,
formatting, the as-you-type formatter and the free-text matcher — is the
pure-Aether engine in `core/phonenumber.ae`, shared by every language binding in
this monorepo and reached through the full **v6** `aether_pn_embed_*` C ABI
(`core/embed.ae`, 66 symbols, `docs/abi.md`). Cross-language behaviour is
therefore identical by construction, not by test.

## Install

```
npm install koffi
```

The binding loads `libphonenumber_ae.so` at runtime via
[koffi](https://koffi.dev). Resolution order:

1. an explicit path — `require('phonenumber_ae/lib/native').load('/path/to/lib.so')`
2. `$LIBPHONENUMBER_AE_LIB`
3. `native/` bundled next to this package
4. the OS loader's own search path

## Use

```js
const pn = require('phonenumber_ae');

// Parse into a ParsedNumber and read its fields on demand.
const num = pn.parse('+1 201 555 0123 ext 42', 'US');
num.nationalNumber;   // '2015550123'
num.extension;        // '42'
num.countryCode;      // '1'
num.regionCode;       // 'US'
num.source;           // pn.SRC_FROM_NUMBER_WITH_PLUS

// Stateless validation / formatting.
pn.isValidNumber('US', '+1 201 555 0123');        // true
pn.isPossibleNumberWithReason('US', '201555');    // pn.VR_TOO_SHORT
pn.format('US', '2015550123', pn.NATIONAL);        // '(201) 555-0123'
pn.format('US', '2015550123', pn.E164);            // '+12015550123'
pn.format('US', '2015550123', pn.INTERNATIONAL);   // '+1 201-555-0123'
pn.numberType('US', '2015550123');                 // pn.TYPE_FIXED_LINE (0)
pn.countryCode('JP');                              // '81'
pn.regions();                                      // ['AC', 'AD', 'AE', …]

// Format a number as it is typed.
const ayt = new pn.AsYouTypeFormatter('US');
let out;
for (const c of '6502530000') out = ayt.inputDigit(c);   // '(650) 253-0000'

// Find numbers in free text.
const matches = pn.findNumbers('call 201-555-0123 or +1 202 555 0199', 'US');
matches.length;        // 2
matches[0].raw;        // '201-555-0123'
matches[0].start;      // 5
matches[0].end;        // 17

// Short / emergency numbers (v3 — ShortNumberInfo).
pn.ShortNumberInfo.isEmergencyNumber('US', '911');   // true
pn.ShortNumberInfo.isEmergencyNumber('GB', '999');   // true
pn.ShortNumberInfo.isValid('US', '911');             // true
pn.ShortNumberInfo.expectedCost('US', '911') === pn.COST_TOLL_FREE;  // true
pn.ShortNumberInfo.exampleNumber('US');              // '112'

// Time zones + carrier (v5 — TimeZones, Carrier).
pn.TimeZones.timeZonesForNumber('US', '2015550123'); // ['America/New_York']
pn.TimeZones.timeZonesForNumber('GB', '2070313000'); // ['Europe/London']
pn.TimeZones.unknownTimeZone();                      // 'Etc/Unknown'
pn.Carrier.carrierNameForNumber('GB', '7106000000'); // 'O2'

// Geographic descriptions (v6 — Geocoder).
pn.Geocoder.geoDescriptionForNumber('US', '6502530000'); // 'Mountain View, CA'
```

### Surface

* **Metadata** — `countryCode`, `exampleNumber`, `exampleNumberForType`,
  `invalidExampleNumber`, `possibleLengths`, `regionCodeForCountryCode`,
  `isNanpaCountry`, `nddPrefixForRegion`, `regions`, `ccRegionCount`,
  `regionsForCountryCode`.
* **Parse** — `parse(input, region)` → a `ParsedNumber` with accessors
  `region`, `countryCode`, `nationalNumber`, `extension`, `italianLeadingZero`,
  `source`, `error`, `regionCode`, `nationalSignificantNumber`, `lengthOfNdc`,
  `lengthOfAreaCode`, `isGeographical`; plus `nationalNumber(region, input)`.
* **Validation** — `isPossibleNumber`, `isPossibleNumberWithReason`,
  `isValidNumber`, `isValidNumberForRegion`, `numberType`,
  `canBeInternationallyDialled`.
* **Formatting** — `format(region, input, style)`, `formatNational`,
  `formatInternational`, `formatE164`, `formatRfc3966`, `formatOutOfCountry`,
  `formatInOriginal(parsed, callingFrom)`.
* **Helpers** — `isNumberMatch`, `truncateTooLong`, `normalizeDigitsOnly`,
  `convertAlphaCharacters`, `isAlphaNumber`, `abiVersion`.
* **`AsYouTypeFormatter`** — `new AsYouTypeFormatter(region)`, `inputDigit(ch)`,
  `result()`, `clear()`.
* **`findNumbers(text, region, leniency)`** — an array of `Match { start, end,
  raw }`.
* **`ShortNumberInfo`** — short / emergency numbers: `isPossible`, `isValid`,
  `isEmergencyNumber`, `connectsToEmergencyNumber`, `isCarrierSpecific`,
  `isSmsService`, `expectedCost` (a `COST_*` int), `exampleNumber(region)`.
* **`TimeZones`** (v5) — IANA time-zone lookup:
  `timeZonesForNumber(region, input)` (an array; `['Etc/Unknown']` when none),
  `timeZoneCount(region, input)`, `unknownTimeZone()`.
* **`Carrier`** (v5) — English carrier names: `carrierNameForNumber(region,
  input)`, `carrierNameForValidNumber(region, input)` (`''` when none).
* **`Geocoder`** (v6) — English geographic descriptions:
  `geoDescriptionForNumber(region, input)`,
  `geoDescriptionForValidNumber(region, input)` (`''` when none).

### Constants

Format styles (v2 renumbered these — **`E164` is now `0`, not `2`**):
`E164` (0), `INTERNATIONAL` (1), `NATIONAL` (2), `RFC3966` (3).

Number types: `TYPE_UNKNOWN` (-1), `TYPE_FIXED_LINE` (0), `TYPE_MOBILE` (1),
`TYPE_TOLL_FREE` (2), `TYPE_PREMIUM_RATE` (3), `TYPE_SHARED_COST` (4),
`TYPE_VOIP` (5), `TYPE_PERSONAL_NUMBER` (6), `TYPE_PAGER` (7), `TYPE_UAN` (8),
`TYPE_VOICEMAIL` (9).

ValidationResult (`isPossibleNumberWithReason`): `VR_IS_POSSIBLE` (0),
`VR_IS_POSSIBLE_LOCAL_ONLY` (4), `VR_INVALID_COUNTRY_CODE` (1), `VR_TOO_SHORT`
(2), `VR_INVALID_LENGTH` (5), `VR_TOO_LONG` (3).

MatchType (`isNumberMatch`): `MATCH_NOT_A_NUMBER` (0), `MATCH_NO_MATCH` (1),
`MATCH_SHORT_NSN` (2), `MATCH_NSN` (3), `MATCH_EXACT` (4).

CountryCodeSource (`ParsedNumber.source`): `SRC_FROM_NUMBER_WITH_PLUS` (1),
`SRC_FROM_NUMBER_WITH_IDD` (5), `SRC_FROM_NUMBER_WITHOUT_PLUS` (10),
`SRC_FROM_DEFAULT_COUNTRY` (20).

Matcher leniency: `LENIENCY_POSSIBLE` (0), `LENIENCY_VALID` (1).

ShortNumberCost (`ShortNumberInfo.expectedCost`): `COST_TOLL_FREE` (0),
`COST_STANDARD_RATE` (1), `COST_PREMIUM_RATE` (2), `COST_UNKNOWN` (3).

## Tests

```
node --test test/conformance.test.js
```

or, with the engine built for you:

```
aeb javascript/aether/.tests.ae
```

The suite is the 45-check v6 conformance contract in `docs/conformance.md`. It
uses `node:test` and `node:assert`, so koffi is the only dependency that has to
be installed.

## Notes for maintainers

* **Koffi 3 represents pointers as BigInt**, not opaque objects, and a null
  pointer is `null`/`0n`. Decode an owned `char *` with
  `koffi.decode.string(ptr)`.
* Every string-returning ABI call is declared `void *`, never `const char *`,
  so the pointer survives long enough to be freed with
  `aether_pn_embed_free_string`. Declaring it `const char *` would let koffi
  decode-and-forget it, leaking every result. `takeString` copies then frees in
  a `finally`.
* There are **no opaque handles** in this ABI. A `ParsedNumber` and an
  `AsYouTypeFormatter` both wrap a caller-owned ABI *string* — the parsed-number
  blob and the formatter state respectively — that is passed back to the
  accessor calls. `AsYouTypeFormatter.inputDigit` threads a new state and frees
  the old one via `takeString`, so the surface never leaks.
* There are no callbacks in this ABI, so there is no keepalive list and nothing
  to unregister.
