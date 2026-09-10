# phonenumber (Go)

Validate and format international phone numbers.

This package is a **thin cgo binding** over the monorepo's one shared native
engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether over
Google libphonenumber's own metadata. It contains **no phone-number logic**:
every function marshals to an `aether_pn_embed_*` call across the flat C ABI in
[`docs/abi.md`](../docs/abi.md) (**v7**, full `PhoneNumberUtil` parity plus
`ShortNumberInfo`, `TimeZones`, `Carrier` and `Geocoder`). One engine, one set of
behaviours, N language surfaces.

The ABI is **handle-free**. There is no opaque handle: a parsed number and an
as-you-type state each cross the seam as a caller-owned **string** that you pass
back to accessor calls. This package wraps those as a `ParsedNumber` value and
an `AsYouTypeFormatter`, so most of the surface is still plain package-level
functions with nothing to close.

## Building

Unlike the dlopen-based bindings (Python/ctypes, Ruby/Fiddle), cgo **links**
the engine, so the shared library must exist at *build* time as well as run
time. Build it first, from the repo root:

```sh
export PATH="$HOME/.local/bin:$PATH"
aeb core/.build.ae            # -> target/build/core/lib/libphonenumber_ae.so
cp target/build/core/lib/libphonenumber_ae.so go/native/libphonenumber_ae.so
```

The `#cgo LDFLAGS` in `phonenumber.go` search both `go/native` and
`../core/native`, and bake the same two directories in as `rpath`, so an
in-tree `go build ./...` needs no further setup:

```
-L${SRCDIR}/native -L${SRCDIR}/../core/native -lphonenumber_ae
-Wl,-rpath,${SRCDIR}/native -Wl,-rpath,${SRCDIR}/../core/native
```

For a distributable build, copy the engine into `go/native/` (which
`.tests.ae` does automatically) so the rpath resolves without the monorepo
layout around it.

## Usage

```go
import pn "github.com/paul-hammant/libphonenumber-ae/go"

pn.IsValidNumber("US", "+1 201 555 0123")    // true
pn.IsPossibleNumber("GB", "1212345678")      // true
pn.Format("US", "2015550123", pn.NATIONAL)   // "(201) 555-0123"
pn.Format("US", "2015550123", pn.E164)       // "+12015550123"
pn.NumberType("US", "2015550123")            // pn.TypeFixedLine
pn.CountryCode("JP")                         // "81"
```

### Parsing

`Parse` returns a `ParsedNumber` whose fields are read via accessor methods.
Check `Error()` for whether parsing succeeded.

```go
num := pn.Parse("+1 201 555 0123 ext 42", "US")
num.Error()          // "" on success
num.NationalNumber() // "2015550123"
num.CountryCode()    // "1"
num.Extension()      // "42"
num.RegionCode()     // "US"
num.Source()         // pn.SourceFromNumberWithPlus
```

### As-you-type formatting

`AsYouTypeFormatter` formats a number one character at a time.

```go
ayt := pn.NewAsYouTypeFormatter("US")
var out string
for _, c := range "2015550123" {
    out = ayt.InputDigit(c)
}
out // "(201) 555-0123"
```

### Finding numbers in text

`FindNumbers` scans free text and returns each `Match` (byte `Start`/`End`
offsets and the `Raw` substring).

```go
matches := pn.FindNumbers("call 201-555-0123 or +1 202 555 0199", "US", pn.LeniencyValid)
len(matches)        // 2
matches[0].Raw      // "201-555-0123"
```

`region` is an ISO-3166 alpha-2 code (`"US"`, `"GB"`, `"JP"`; case-insensitive).
`input` is a number as a human might type it — digits with optional spaces,
dashes, parentheses, dots, and an optional leading `+countrycode`.

### Short and emergency numbers

Short numbers are dialled as-is — no country code, no national prefix.

```go
pn.IsEmergencyNumber("US", "911")   // true
pn.IsEmergencyNumber("GB", "999")   // true
pn.ShortIsValid("US", "911")        // true
pn.ShortExpectedCost("US", "911")   // pn.CostTollFree
pn.ShortExampleNumber("US")         // "112"
```

### Time zones

The engine parses the raw `(region, input)` to E.164 itself, then does a
longest-prefix match over its digits.

```go
pn.TimeZonesForNumber("US", "2015550123")  // ["America/New_York"]
pn.TimeZonesForNumber("GB", "2070313000")  // ["Europe/London"]
pn.TimeZoneCount("US", "2015550123")       // 1 (0 = only the unknown zone)
pn.UnknownTimeZone()                       // "Etc/Unknown"
```

A number with no known zone maps to a single-element `["Etc/Unknown"]`.

### Carrier names

```go
pn.CarrierNameForNumber("GB", "7106000000")        // "O2"
pn.CarrierNameForValidNumber("GB", "7106000000")   // "O2" (or "" if invalid)
pn.CarrierNameForNumber("GB", "7106000000", "de")  // localized (optional lang, defaults to "en")
```

The optional trailing `lang` (an ISO code, defaults to `"en"`) localizes the
name; `"en"` is always available and is the fallback for any language the engine
was not built with. `""` means no carrier is known for the number.

### Geocoding

```go
pn.GeoDescriptionForNumber("US", "6502530000")        // "Mountain View, CA"
pn.GeoDescriptionForValidNumber("US", "6502530000")   // "Mountain View, CA" (or "" if invalid)
pn.GeoDescriptionForNumber("US", "6502530000", "de")  // localized (optional lang, defaults to "en")
```

The optional trailing `lang` (an ISO code, defaults to `"en"`) localizes the
description; `"en"` is always available and is the fallback for any language the
engine was not built with. `""` means no description is known for the number.

### Functions

```go
// metadata
pn.CountryCode(region)                  // "1", "44", …; "" if the region is unknown
pn.ExampleNumber(region)                // an example national number, or ""
pn.ExampleNumberForType(region, t)      // an example of a given Type
pn.InvalidExampleNumber(region)         // an example invalid number
pn.PossibleLengths(region)              // the length spec, e.g. "9,10", or ""
pn.RegionCodeForCountryCode(cc)         // "44" -> "GB"
pn.IsNanpaCountry(region)          bool // part of the +1 numbering plan
pn.NddPrefixForRegion(region, strip)    // national trunk prefix
pn.RegionCount()                   int  // how many regions the metadata carries
pn.RegionAt(index)                 string
pn.Regions()                       []string
pn.RegionsForCountryCode(cc)       []string // every region sharing a calling code

// parse + parsed-number accessors
pn.Parse(input, region)            pn.ParsedNumber
pn.NationalNumber(region, input)   // cc + punctuation stripped

// validation
pn.IsPossibleNumber(region, input)           bool
pn.IsPossibleNumberWithReason(region, input) pn.ValidationResult
pn.IsValidNumber(region, input)              bool
pn.IsValidNumberForRegion(input, region)     bool
pn.NumberType(region, input)                 pn.Type
pn.CanBeInternationallyDialled(region, input) bool

// formatting
pn.Format(region, input, style)   // E164 | INTERNATIONAL | NATIONAL | RFC3966
pn.FormatNational(region, input)
pn.FormatInternational(region, input)
pn.FormatE164(region, input)
pn.FormatRFC3966(region, input)
pn.FormatOutOfCountry(region, input, callingFrom)
pn.FormatInOriginal(parsed, callingFrom)

// relations / helpers
pn.IsNumberMatch(a, b)             pn.MatchType
pn.TruncateTooLong(region, input)  // drop excess trailing digits
pn.NormalizeDigitsOnly(s)          // strip everything but digits
pn.ConvertAlphaCharacters(s)       // "1-800-FLOWERS" -> "1-800-3569377"
pn.IsAlphaNumber(s)                bool

// as-you-type + finder
pn.NewAsYouTypeFormatter(region)   *pn.AsYouTypeFormatter
pn.FindNumbers(text, region, leniency) []pn.Match

// short / emergency numbers
pn.ShortIsPossible(region, input)            bool
pn.ShortIsValid(region, input)               bool
pn.IsEmergencyNumber(region, input)          bool
pn.ConnectsToEmergencyNumber(region, input)  bool
pn.ShortIsCarrierSpecific(region, input)     bool
pn.ShortIsSMSService(region, input)          bool
pn.ShortExpectedCost(region, input)          pn.Cost
pn.ShortExampleNumber(region)                // an example short number, or ""

// time zones
pn.TimeZonesForNumber(region, input)         []string // IANA zone ids
pn.TimeZoneCount(region, input)              int      // 0 = only the unknown zone
pn.UnknownTimeZone()                         // "Etc/Unknown"

// carrier names (optional trailing lang, defaults to "en")
pn.CarrierNameForNumber(region, input, lang...)       // a name, or ""
pn.CarrierNameForValidNumber(region, input, lang...)  // a name only if valid, else ""

// geographic descriptions (optional trailing lang, defaults to "en")
pn.GeoDescriptionForNumber(region, input, lang...)       // a description, or ""
pn.GeoDescriptionForValidNumber(region, input, lang...)  // a description only if valid, else ""

pn.ABIVersion()     int            // the engine's ABI revision (7)
```

### Constants

Format styles (`Style`): `E164` (0), `INTERNATIONAL` (1), `NATIONAL` (2),
`RFC3966` (3). **Note:** in v2 `E164` is `0` (it was `2` in v1).

Number types (`Type`, mirroring libphonenumber's `PhoneNumberType`):
`TypeUnknown` (-1), `TypeFixedLine`, `TypeMobile`, `TypeTollFree`,
`TypePremiumRate`, `TypeSharedCost`, `TypeVoIP`, `TypePersonalNumber`,
`TypePager`, `TypeUAN`, `TypeVoicemail`.

Validation results (`ValidationResult`, from `IsPossibleNumberWithReason`):
`ResultIsPossible` (0), `ResultIsPossibleLocalOnly` (4),
`ResultInvalidCountryCode` (1), `ResultTooShort` (2), `ResultInvalidLength` (5),
`ResultTooLong` (3).

Match types (`MatchType`, from `IsNumberMatch`): `MatchNotANumber` (0),
`MatchNoMatch` (1), `MatchShortNSN` (2), `MatchNSN` (3), `MatchExact` (4).

Country-code sources (`Source`, from `ParsedNumber.Source`):
`SourceFromNumberWithPlus` (1), `SourceFromNumberWithIDD` (5),
`SourceFromNumberWithoutPlus` (10), `SourceFromDefaultCountry` (20).

Matcher leniency (`Leniency`, for `FindNumbers`): `LeniencyPossible` (0),
`LeniencyValid` (1).

Short-number cost (`Cost`, from `ShortExpectedCost`): `CostTollFree` (0),
`CostStandardRate` (1), `CostPremiumRate` (2), `CostUnknown` (3).

## isPossible vs isValid

Two levels of "is this a phone number", matching libphonenumber's own:

- **`IsPossibleNumber`** — the national number has a length the country allows.
  A cheap check that catches most typos.
- **`IsValidNumber`** — it additionally matches the country's national-number
  regex for some number type. The real answer.

## Memory

Every `char*` the engine returns is caller-owned. `takeString` copies it into a
Go string and frees it through `aether_pn_embed_free_string` in a `defer`;
every string result in the package goes through that one function. Each C-string
argument is `C.CString`'d (malloc) and `C.free`'d after the call. There is no
handle and there are no callbacks, so there is nothing else to release — the
engine is a pure, stateless transform.

## Tests

The 45-check conformance suite ([`docs/conformance.md`](../docs/conformance.md))
lives in `phonenumber_test.go`. It is not a phone-number test suite — the
behavioural cases are proven once, in the engine — it samples each *kind* of
value crossing the FFI, so it proves the marshalling.

```sh
aeb go/.tests.ae     # builds the engine, stages it into go/native, runs go test
# or, with the engine already staged into go/native:
LD_LIBRARY_PATH=$PWD/native go test ./...
LD_LIBRARY_PATH=$PWD/native go test -race ./...
```

`.tests.ae` runs `go test` with `CGO_ENABLED=1`, `GOFLAGS=-mod=mod`, and
`LIBPHONENUMBER_AE_LIB` pointed at the dep'd engine artifact.
