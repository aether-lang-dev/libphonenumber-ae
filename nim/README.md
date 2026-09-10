# phonenumber_ae (Nim)

Validate, parse and format international phone numbers.

This package is a **thin `importc` binding** over the monorepo's one shared
native engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether
over Google libphonenumber's own metadata. It contains **no phone-number
logic**: every proc marshals to an `aether_pn_embed_*` call across the flat C
ABI (v3, full `PhoneNumberUtil` parity plus the ShortNumberInfo surface)
described in `core/embed.ae`. One engine, one set of behaviours, N language
surfaces.

The v3 ABI has **no opaque handle**: a parsed number and an AsYouType state are
themselves caller-owned *strings* — you get one back, pass it to accessor calls,
and free it like any other returned string.

## Building

Unlike the dlopen-based bindings (Python/ctypes, Ruby/Fiddle, Rust/libloading),
this binding **links** the engine, so the shared library must exist at *build*
time as well as run time. Build it first:

```sh
aeb core/.build.ae
# → target/build/core/lib/libphonenumber_ae.so
```

The `{.passL.}` in `src/phonenumber_ae.nim` searches both `nim/native` and
`../core/native`, and bakes the same two directories in as `rpath`, so an
in-tree build needs no further setup and no `LD_LIBRARY_PATH`:

```
-Lnim/native -Lcore/native -lphonenumber_ae
-Wl,-rpath,nim/native -Wl,-rpath,core/native
```

The paths are derived from `currentSourcePath()`, so they are correct no matter
which directory you invoke the compiler from. For a distributable build, copy
the engine into `nim/native/` (which `.tests.ae` does automatically) so the
rpath resolves without the monorepo layout around it.

## Usage

```nim
import phonenumber_ae

echo countryCode("US")                       # "1"
echo isValidNumber("US", "+1 201 555 0123")  # true
echo format("US", "2015550123", fmtNational) # "(201) 555-0123"
echo format("US", "2015550123", fmtE164)     # "+12015550123"
echo numberType("US", "2015550123")          # ntFixedLine
echo regions().len                           # >= 200
```

### Parsing

`parse` returns a `ParsedNumber` whose fields are read on demand:

```nim
let num = parse("+1 201 555 0123 ext 42", "US")
echo num.error                    # ""  (non-empty if the parse failed)
echo num.nationalNumber           # "2015550123"
echo num.extension                # "42"
echo num.countryCode              # "1"
echo num.source                   # srcFromNumberWithPlus
echo num.regionCode               # "US"
echo num.nationalSignificantNumber
echo num.isGeographical
```

### AsYouTypeFormatter

```nim
var ayt = initAsYouTypeFormatter("US")
var last = ""
for c in "6502530000":
  last = ayt.inputDigit(c)        # last == "(650) 253-0000"
ayt.clear()                       # reset
```

### Finding numbers in free text

```nim
for m in findNumbers("call 201-555-0123 today", "US", lenValid):
  echo m.raw, " @ ", m.start, "..", m.`end`   # "201-555-0123" @ 5..17
```

### Short numbers (ShortNumberInfo)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```nim
echo isEmergencyNumber("US", "911")          # true
echo isEmergencyNumber("GB", "999")          # true
echo shortIsValid("US", "911")               # true
echo shortExpectedCost("US", "911")          # costTollFree
echo shortExampleNumber("US")                # "112"
```

### The surface

```nim
# metadata
countryCode(region): string
exampleNumber(region): string
exampleNumberForType(region, ntype): string
invalidExampleNumber(region): string
possibleLengths(region): string
regionCodeForCountryCode(cc): string
isNanpaCountry(region): bool
nddPrefixForRegion(region, stripNonDigits = false): string
regions(): seq[string]                     # engine order
sortedRegions(): seq[string]               # deterministic
regionCount(): int
regionAt(index): string                    # "" when out of range
regionsForCountryCode(cc): seq[string]

# parse
parse(number, region): ParsedNumber
ParsedNumber: .region .countryCode .nationalNumber .extension
  .italianLeadingZero .source .error .regionCode
  .nationalSignificantNumber .lengthOfNdc .lengthOfAreaCode .isGeographical
nationalNumber(region, input): string

# validation
isPossibleNumber(region, input): bool
isPossibleNumberWithReason(region, input): ValidationResult
isValidNumber(region, input): bool
isValidNumberForRegion(input, region): bool
numberType(region, input): NumberType      # ntUnknown | ntFixedLine | …
canBeInternationallyDialled(region, input): bool

# formatting
format(region, input, style = fmtNational): string
formatE164 / formatInternational / formatNational / formatRfc3966 (region, input)
formatOutOfCountry(region, input, callingFrom): string
formatInOriginal(parsed, callingFrom): string

# helpers
isNumberMatch(a, b): MatchType
truncateTooLong(region, input): string
normalizeDigitsOnly(s): string
convertAlphaCharacters(s): string
isAlphaNumber(s): bool
abiVersion(): int                          # 3

# short numbers (ShortNumberInfo)
shortIsPossible(region, input): bool
shortIsValid(region, input): bool
isEmergencyNumber(region, input): bool
connectsToEmergencyNumber(region, input): bool
shortIsCarrierSpecific(region, input): bool
shortIsSmsService(region, input): bool
shortExpectedCost(region, input): ShortNumberCost   # costTollFree | …
shortExampleNumber(region): string

# AsYouTypeFormatter, findNumbers (above)
```

### Constants

`Format` is `fmtE164 | fmtInternational | fmtNational | fmtRfc3966` (ABI
**0/1/2/3**). **Note the v2 change: `E164` is now `0`, not `2`.** A `format`
overload also takes the raw `cint` via the `E164` / `INTERNATIONAL` / `NATIONAL`
/ `RFC3966` aliases. Every constant group is exposed both as an enum and as bare
`cint` aliases for a caller comparing against the wire format:

- `Format` / `E164`, `INTERNATIONAL`, `NATIONAL`, `RFC3966`
- `NumberType` / `TYPE_*` (`ntUnknown` at `-1`)
- `ValidationResult` / `VR_*`
- `MatchType` / `MATCH_*`
- `CountryCodeSource` / `SRC_*`
- `Leniency` / `LENIENCY_POSSIBLE`, `LENIENCY_VALID`
- `ShortNumberCost` / `COST_TOLL_FREE`, `COST_STANDARD_RATE`, `COST_PREMIUM_RATE`, `COST_UNKNOWN`

## Memory

Every `cstring` the engine returns is caller-owned. Exactly one proc —
`takeString` — is allowed to touch a returned pointer, and it always copies into
a Nim `string` and frees the original through `aether_pn_embed_free_string`.
There is no other call to `free_string` in the binding and no returned pointer
escapes `takeString`. This holds for the parsed-number string and the AsYouType
state too: they are ordinary caller-owned strings, adopted into `ParsedNumber` /
`AsYouTypeFormatter` and re-owned on each state transition.

This matters more in Nim than it looks: assigning a `cstring` to a `string`
*copies*, it does not adopt, so a forgotten free is a silent leak rather than a
crash.

### The `int`-not-`cint` trap

Nim's `int` is pointer-sized — on LP64 it is C `long`, not C `int`. The ABI is
`int` throughout, so every ABI proc in `src/phonenumber_ae.nim` uses `cint`
explicitly. Do not "simplify" one of them to `int`.

## Conformance

The 40-check conformance suite (`docs/conformance.md`, v3) lives in
`tests/tconformance.nim`, alongside a few surface extras (the format-style
aliases, the raw-int overload, out-of-range `regionAt`, AsYouType clear, and a
several-thousand round-trip loop over `takeString`).

```sh
aeb nim/.tests.ae     # builds the engine, stages it into nim/native, runs the suite
```

With the engine already built, the suite runs standalone — no nimble required:

```sh
nim c -r tests/tconformance.nim
nim c -r --mm:refc tests/tconformance.nim    # also green under refc
```

`nimble test` works too where nimble is installed; `phonenumber_ae.nimble` is
the package manifest either way.
