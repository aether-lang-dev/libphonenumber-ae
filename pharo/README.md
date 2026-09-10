# phonenumber_ae — Pharo (UnifiedFFI)

Validate and format international phone numbers.

A thin Pharo binding over the monorepo's one shared native engine —
`core/native/libphonenumber_ae.so`, compiled from Google libphonenumber's own
metadata as pure Aether. It contains **no phone-number logic**: every method
marshals to an `aether_pn_embed_*` call across the flat C ABI in
`core/embed.ae`.

Unlike the Kotlin/Scala/Clojure/Groovy layers (which sit on the Java binding),
this is a **real FFI**: Pharo is not a JVM, so it binds the C ABI directly with
UnifiedFFI. There is no Java classpath here — only the engine `.so`.

## Requirements

- A Pharo VM + image (UnifiedFFI and SUnit are both in the base image; the
  binding has **no** external Pharo dependencies).
- The engine `.so`, built once with `aeb core/.build.ae`.

## Loading it

From a checkout, via Metacello reading the Tonel sources straight from the
working tree:

```smalltalk
Metacello new
    baseline: 'PhonenumberAe';
    repository: 'tonel://<path-to-repo>/pharo/src';
    load.
```

Point the binding at the engine before the first FFI call — either set
`$LIBPHONENUMBER_AE_LIB`, or:

```smalltalk
PhonenumberAeLibrary explicitPath: '/path/to/libphonenumber_ae.so'.
```

## Use

Every call is class-side — the engine is stateless, so there is no handle to
create or close:

```smalltalk
PhonenumberAe countryCode: 'US'.                              "-> '1'"
PhonenumberAe exampleNumber: 'US'.                            "-> '2015550123'"
PhonenumberAe isValidNumber: '+1 201 555 0123' region: 'US'. "-> true"
PhonenumberAe isPossibleNumber: '201555' region: 'US'.       "-> false"
PhonenumberAe numberType: '2015550123' region: 'US'.         "-> #fixedLine"
PhonenumberAe format: '2015550123' region: 'US' style: #national.
"-> '(201) 555-0123'"
PhonenumberAe formatE164: '2015550123' region: 'US'.         "-> '+12015550123'"
PhonenumberAe regions.                                        "-> an OrderedCollection: 'AC' 'AD' ..."
PhonenumberAe abiVersion.                                     "-> 3"
```

### Parsing

`parse:region:` returns a `PhonenumberAeParsedNumber` wrapping the caller-owned
parsed-number string; read its fields with the instance accessors:

```smalltalk
| num |
num := PhonenumberAe parse: '+1 201 555 0123 ext 42' region: 'US'.
num error.            "-> ''   (empty means parse ok)"
num nationalNumber.   "-> '2015550123'"
num extension.        "-> '42'"
num countryCode.      "-> '1'"
num source.           "-> #fromNumberWithPlus"
num regionCode.       "-> 'US'"
```

### As-you-type

```smalltalk
| f |
f := PhonenumberAe asYouTypeFormatterFor: 'US'.
'2015550123' do: [ :c | f inputDigit: c asString ].
f result.   "-> '(201) 555-0123'"
```

### Finding numbers in text

```smalltalk
PhonenumberAe findNumbers: 'call 201-555-0123 or +1 202 555 0199' region: 'US'.
"-> an OrderedCollection of PhonenumberAeMatch; each has start / end / raw."
```

### Short numbers (emergency, SMS shortcodes)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```smalltalk
PhonenumberAe isEmergencyNumber: '911' region: 'US'.   "-> true"
PhonenumberAe isEmergencyNumber: '999' region: 'US'.   "-> false  (that's GB)"
PhonenumberAe shortIsValid: '911' region: 'US'.        "-> true"
PhonenumberAe shortExpectedCost: '911' region: 'US'.   "-> #tollFree"
PhonenumberAe shortExampleNumber: 'US'.                "-> '112'"
```

### The surface (v3 — full PhoneNumberUtil parity + ShortNumberInfo)

- **Metadata**: `countryCode:`, `exampleNumber:`, `exampleNumberForType:region:`,
  `invalidExampleNumber:`, `possibleLengths:`, `regionCodeForCountryCode:`,
  `isNanpaCountry:`, `nddPrefixForRegion:` / `nddPrefixForRegion:stripNonDigits:`.
- **Regions**: `regionCount`, `regionAt:`, `regions`, `ccRegionCount:`,
  `ccRegionAt:index:`, `regionsForCountryCode:`.
- **Parse**: `parse:region:` (→ `PhonenumberAeParsedNumber`),
  `nationalNumber:region:`.
- **Validity**: `isPossibleNumber:region:`, `isPossibleNumberWithReason:region:`
  (a ValidationResult symbol), `isValidNumber:region:`,
  `isValidNumberForRegion:region:`, `numberType:region:` (a Symbol;
  `numberTypeCode:region:` for the raw int), `canBeInternationallyDialled:region:`.
- **Formatting**: `format:region:style:` with a style symbol
  (`#e164` | `#international` | `#national` | `#rfc3966`), plus
  `formatNational:region:`, `formatInternational:region:`, `formatE164:region:`,
  `formatRfc3966:region:`, `formatOutOfCountry:region:callingFrom:`,
  `formatInOriginal:callingFrom:`.
- **Helpers**: `isNumberMatch:with:` (a MatchType symbol),
  `truncateTooLong:region:`, `normalizeDigitsOnly:`, `convertAlphaCharacters:`,
  `isAlphaNumber:`.
- **As-you-type**: `asYouTypeFormatterFor:` (→ `PhonenumberAeAsYouTypeFormatter`).
- **Find numbers**: `findNumbers:region:` / `findNumbers:region:leniency:`
  (→ `PhonenumberAeMatch` with `start` / `end` / `raw`).
- **Short numbers**: `shortIsPossible:region:`, `shortIsValid:region:`,
  `isEmergencyNumber:region:`, `connectsToEmergencyNumber:region:`,
  `shortIsCarrierSpecific:region:`, `shortIsSmsService:region:`,
  `shortExpectedCost:region:` (a ShortNumberCost symbol — `#tollFree` |
  `#standardRate` | `#premiumRate` | `#unknown`; `shortExpectedCostCode:region:`
  for the raw int), `shortExampleNumber:`.
- `abiVersion` (returns `3`).

> **v3 note.** ShortNumberInfo (the `short*` / `*EmergencyNumber:region:` calls
> above) is new in v3. The v2 format-style selectors are unchanged: `#e164` is
> `0` (it was `2` in v1). Callers that use the style symbols never see the
> number.

## The one ABI trap worth knowing

**Every `char*` the ABI returns is caller-owned.** `PhonenumberAe
class >> takeString:` copies the bytes out and frees the buffer through
`aether_pn_embed_free_string` — wrapped in an `ensure:` so even a malformed byte
sequence cannot leak the buffer on its way out. Reading a returned pointer
without that free is the single most common bug in a binding of this ABI, so the
FFI `primNULL...` calls return `void *` and route through `takeString:`, never
`char *` (which would let UnifiedFFI decode-and-drop the pointer for you and
leak the engine's allocation).

There is no callback surface and no opaque handle — the html-sanitizer binding
this was mirrored from had both, but the phone ABI is a pure
`(region[, input]) -> answer` transform, so neither exists here.

## Engine resolution

Matching every other binding in the monorepo (see `PhonenumberAeLibrary`):

1. an explicit path — `PhonenumberAeLibrary explicitPath: '...'`
2. `$LIBPHONENUMBER_AE_LIB`
3. `native/` beside the image
4. the OS loader's own search path

## Tests

`pharo/run-tests.sh` loads the Tonel package into a **throwaway copy** of a
Pharo image (loading code mutates an image permanently, so the developer's own
image is never touched) and runs the 40-check binding conformance suite
(`docs/conformance.md`, v3) headless. `pharo/.tests.ae` drives it, threading the
engine `.so` through `$LIBPHONENUMBER_AE_LIB`.

Exit codes: `0` pass, `1` fail, `77` = no Pharo VM (a clean **SKIP** — nothing
is ever downloaded; a runner that installs a VM behind your back is a worse
failure mode than a clear skip).

```sh
aeb pharo/.tests.ae
```
