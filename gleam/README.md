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
phonenumber_ae.abi_version()                             // -> 2
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

### The surface (v2 — full PhoneNumberUtil parity)

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
- `abi_version/0` (returns `2`), `abi_version_string/0`.

> **v2 note.** The format-style selectors changed: `E164` is now `0` (was `2`
> in v1). Callers that use the `FormatStyle` constructors never see the number.

### No handles

The ABI has no opaque handles: a parsed number and an as-you-type state are
themselves caller-owned strings, wrapped by the opaque `ParsedNumber` and
`AsYouType` types. Every function is a direct FFI crossing.

## Conformance

`gleam/.tests.ae` runs the 34-check binding conformance suite
(`docs/conformance.md`, v2) with gleeunit. It samples each *kind* of value
crossing the FFI — it proves the marshalling, not the library.
