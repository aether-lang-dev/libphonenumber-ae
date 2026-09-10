# phonenumber_ae (Gleam)

Validate and format international phone numbers.

A thin Gleam surface over the monorepo's **canonical BEAM NIF** (in `erlang/`),
compiled from Google libphonenumber's own metadata as pure Aether. It contains
**no phone-number logic**: every function marshals to an `aether_pn_embed_*`
call across the C ABI in `core/embed.ae`.

## There is no C in this directory

This project compiles nothing native — no `c_src`, no build hooks, no second
`.so`. Every function is an `@external(erlang, "phonenumber_ae_nif", ...)`
binding onto the very same compiled module the Erlang and Elixir bindings load.
One engine, one NIF, three languages.

## Erlang target only

This binding is **Erlang-target only** (`target = "erlang"` in `gleam.toml`). It
cannot compile to JavaScript, because the whole binding is a NIF. Stating the
target makes that a clear manifest error rather than a confusing missing-module
error at runtime. (The monorepo already has a JavaScript binding onto the same
engine.)

## Building and testing

```sh
aeb gleam/.tests.ae
```

That deps the `erlang/.build.ae` node (which builds the NIF once), then runs the
gleeunit suite against it.

`gleam` honours `$ERL_LIBS`, so pointing it at the **parent** of the built app
directory is all it takes for the `@external` calls to resolve at runtime:

```sh
cd gleam
LIBPHONENUMBER_AE_LIB=/path/to/libphonenumber_ae.so \
  ERL_LIBS=../erlang/_build gleam test
```

`gleeunit` and `gleam_stdlib` come from hex; the node SKIPs (green) when they
cannot be resolved offline.

### Finding the engine

The NIF `dlopen`s the engine at load time. Resolution order: `$LIBPHONENUMBER_AE_LIB`,
then `priv/` beside the app, then the OS loader's own search path.

## Usage

```gleam
import phonenumber_ae.{National, E164, FixedLine, Valid}

phonenumber_ae.country_code("US")                        // -> "1"
phonenumber_ae.example_number("US")                      // -> "2015550123"
phonenumber_ae.is_valid_number("US", "+1 201 555 0123")  // -> True
phonenumber_ae.is_possible_number("US", "201555")        // -> False
phonenumber_ae.number_type("US", "2015550123")           // -> FixedLine
phonenumber_ae.format("US", "2015550123", National)      // -> "(201) 555-0123"
phonenumber_ae.format_e164("US", "2015550123")           // -> "+12015550123"
phonenumber_ae.regions()                                 // -> ["AC", "AD", ...]
phonenumber_ae.abi_version()                             // -> 7
```

### Parsing

`parse` returns an opaque `ParsedNumber` wrapping the caller-owned
parsed-number string; read its fields with the `pn_*` accessors:

```gleam
let num = phonenumber_ae.parse("+1 201 555 0123 ext 42", "US")
phonenumber_ae.pn_error(num)            // -> ""   (empty means parse ok)
phonenumber_ae.pn_national_number(num)  // -> "2015550123"
phonenumber_ae.pn_extension(num)        // -> "42"
phonenumber_ae.pn_country_code(num)     // -> "1"
phonenumber_ae.pn_source(num)           // -> FromNumberWithPlus
phonenumber_ae.region_code_for_number(num)  // -> "US"
```

### As-you-type

The opaque `AsYouType` value is threaded through `ayt_input`, which returns a
fresh formatter each keystroke:

```gleam
let f =
  "2015550123"
  |> string.to_graphemes
  |> list.fold(phonenumber_ae.ayt_new("US"), phonenumber_ae.ayt_input)
phonenumber_ae.ayt_result(f)   // -> "(201) 555-0123"
```

### Finding numbers in text

```gleam
phonenumber_ae.find_numbers("call 201-555-0123 or +1 202 555 0199", "US", Valid)
// -> [Match(start: 5, end: 17, raw: "201-555-0123"), ...]
```

### Short numbers (emergency, SMS shortcodes)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```gleam
import phonenumber_ae.{CostTollFree}

phonenumber_ae.is_emergency_number("US", "911")   // -> True
phonenumber_ae.is_emergency_number("US", "999")   // -> False  (that's GB)
phonenumber_ae.short_is_valid("US", "911")        // -> True
phonenumber_ae.short_expected_cost("US", "911")   // -> CostTollFree
phonenumber_ae.short_example_number("US")         // -> "112"
```

### Time zones, carrier and geocoder

The engine also maps a number to its IANA time zones, its carrier, and a
geographic description. All take a region plus the raw input, exactly like the
calls above. Gleam has no default arguments, so the carrier/geocoder calls come
in two forms: the plain `_number` form (English), and an `_in_language` form
taking an ISO code (a language not compiled into the engine falls back to
English):

```gleam
phonenumber_ae.time_zones_for_number("US", "2015550123")   // -> ["America/New_York"]
phonenumber_ae.time_zones_for_number("GB", "2070313000")   // -> ["Europe/London"]
phonenumber_ae.unknown_time_zone()                         // -> "Etc/Unknown"
phonenumber_ae.carrier_name_for_number("GB", "7106000000") // -> "O2"
phonenumber_ae.carrier_name_for_number_in_language("GB", "7106000000", "en") // -> "O2"
phonenumber_ae.geo_description_for_number("US", "6502530000") // -> "Mountain View, CA"
```

`time_zones_for_number/2` always returns a non-empty list — a number the engine
knows no zone for comes back as `["Etc/Unknown"]`, not `[]`.

### The surface (v7 — full PhoneNumberUtil parity + ShortNumberInfo + TimeZones + Carrier + Geocoder)

- **Metadata**: `country_code/1`, `example_number/1`,
  `example_number_for_type/2`, `invalid_example_number/1`, `possible_lengths/1`,
  `region_code_for_country_code/1`, `is_nanpa_country/1`,
  `ndd_prefix_for_region/2`.
- **Regions**: `region_count/0`, `region_at/1`, `regions/0`,
  `sorted_regions/0`, `cc_region_count/1`, `cc_region_at/2`,
  `regions_for_country_code/1`.
- **Parse + accessors**: `parse/2` (→ opaque `ParsedNumber`),
  `national_number/2`, `pn_error/1`, `pn_region/1`, `pn_country_code/1`,
  `pn_national_number/1`, `pn_extension/1`, `pn_italian_leading_zero/1`,
  `pn_source/1`, `region_code_for_number/1`, `national_significant_number/1`,
  `length_of_ndc/1`, `length_of_area_code/1`, `is_geographical/1`.
- **Validity**: `is_possible_number/2`, `is_possible_number_with_reason/2`
  (a `ValidationResult`), `is_valid_number/2`, `is_valid_number_for_region/2`,
  `number_type/2` (a `NumberType`; `number_type_code/2` for the raw `Int`),
  `can_be_internationally_dialled/2`.
- **Formatting**: `format/3` with a `FormatStyle`
  (`E164` | `International` | `National` | `Rfc3966`), plus `format_national/2`,
  `format_international/2`, `format_e164/2`, `format_rfc3966/2`,
  `format_out_of_country/3`, `format_in_original/2`.
- **Helpers**: `is_number_match/2` (a `MatchType`), `truncate_too_long/2`,
  `normalize_digits_only/1`, `convert_alpha_characters/1`, `is_alpha_number/1`.
- **As-you-type**: `ayt_new/1`, `ayt_input/2`, `ayt_result/1`, `ayt_clear/1`.
- **Find numbers**: `find_numbers/3` (a list of `Match`), `matcher_count/3`.
- **Short numbers**: `short_is_possible/2`, `short_is_valid/2`,
  `is_emergency_number/2`, `connects_to_emergency_number/2`,
  `short_is_carrier_specific/2`, `short_is_sms_service/2`,
  `short_expected_cost/2` (a `ShortNumberCost` — `CostTollFree` |
  `CostStandardRate` | `CostPremiumRate` | `CostUnknown`;
  `short_expected_cost_code/2` for the raw `Int`), `short_example_number/1`.
- **Time zones**: `time_zones_for_number/2` (a non-empty list of IANA zone
  ids), `time_zone_count/2`, `unknown_time_zone/0` (`"Etc/Unknown"`).
- **Carrier**: `carrier_name_for_number/2`, `carrier_name_for_valid_number/2`
  (English name, or `""`), plus `carrier_name_for_number_in_language/3`,
  `carrier_name_for_valid_number_in_language/3` (an ISO code).
- **Geocoder**: `geo_description_for_number/2`,
  `geo_description_for_valid_number/2` (English geographic description, or `""`),
  plus `geo_description_for_number_in_language/3`,
  `geo_description_for_valid_number_in_language/3` (an ISO code).
- `abi_version/0` (returns `7`), `abi_version_string/0`.

> **v7 note.** The carrier and geocoder calls gained a language argument (an ISO
> code; a language not compiled into the engine falls back to English). Gleam
> has no default arguments, so this is a separate `_in_language/3` form beside
> each `_number/2` (English) form. The geocoder calls arrived in v6; the
> time-zone and carrier calls in v5; ShortNumberInfo in v3.
> The v2 format-style selectors are unchanged: `E164` is `0` (it was `2` in v1).
> Callers that use the `FormatStyle` constructors never see the number.

### No handles

The ABI has no opaque handles: a parsed number and an as-you-type state are
themselves caller-owned strings, wrapped by the opaque `ParsedNumber` and
`AsYouType` types. Every function is a direct FFI crossing.

## Conformance

`gleam/.tests.ae` runs the 45-check binding conformance suite
(`docs/conformance.md`, v7) with gleeunit. It samples each *kind* of value
crossing the FFI — it proves the marshalling, not the library.
