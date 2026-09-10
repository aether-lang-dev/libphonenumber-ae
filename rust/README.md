# phonenumber_ae — Rust binding

Validate, parse and format international phone numbers.

This crate is **marshalling only**. The library itself — the metadata table,
`isPossible`/`isValid`, number-type classification, the formatter, the
AsYouType formatter, the matcher — is the pure-Aether engine in
`core/phonenumber.ae`, compiled from Google libphonenumber's own metadata,
shared by every language binding in this monorepo and reached through the v3
`aether_pn_embed_*` C ABI (`core/embed.ae`, full `PhoneNumberUtil` parity plus
`ShortNumberInfo`). Cross-language behaviour is therefore identical by
construction, not by test.

`src/native.rs` is the **canonical 1:1 symbol table** for that ABI: all 50
exported symbols, in the order `core/embed.ae` declares them, with the exact C
signature. Other bindings are expected to be diffable against it.

## Install

```toml
[dependencies]
phonenumber_ae = "0.1"
```

The engine is loaded at runtime with [libloading](https://docs.rs/libloading).
Resolution order:

1. an explicit path — `PhoneNumbers::with_library(Some(path))`
2. `$LIBPHONENUMBER_AE_LIB`
3. `native/` next to the crate
4. the OS loader's own search path

## Use

The ABI is stateless — no handle, only caller-owned strings — so the
crate-level free functions load one process-wide engine on first use and are
the simplest way in:

```rust
use phonenumber_ae as pn;

// parse → a ParsedNumber whose fields are read on demand
let num = pn::parse("+1 650 253 0000", "US");
assert_eq!(num.national_number(), "6502530000");
assert_eq!(num.country_code(), "1");
assert_eq!(num.region_code(), "US");

// validate + format
assert!(pn::is_valid_number("US", "+1 650 253 0000"));
assert_eq!(pn::format("US", "6502530000", pn::NATIONAL), "(650) 253-0000");
assert_eq!(pn::format("US", "6502530000", pn::INTERNATIONAL), "+1 650-253-0000");
assert_eq!(pn::number_type_enum("US", "6502530000"), pn::NumberType::FixedLine);
```

### As-you-type formatting

```rust
use phonenumber_ae as pn;

let mut ayt = pn::as_you_type_formatter("US");
let mut shown = String::new();
for c in "2015550123".chars() {
    shown = ayt.input_digit(c);
}
assert_eq!(shown, "(201) 555-0123");
```

### Finding numbers in free text

```rust
use phonenumber_ae as pn;

let matches = pn::find_numbers("call 201-555-0123 or +1 202 555 0199", "US", pn::LENIENCY_VALID);
assert_eq!(matches.len(), 2);
assert_eq!(matches[0].raw, "201-555-0123");
// each Match also carries `start` and `end` offsets in the source text
```

### Short and emergency numbers

Short numbers are dialled as-is — no country code, no national prefix.

```rust
use phonenumber_ae as pn;

assert!(pn::is_emergency_number("US", "911"));
assert!(pn::is_emergency_number("GB", "999"));
assert!(pn::short_is_valid("US", "911"));
assert_eq!(pn::short_expected_cost("US", "911"), pn::COST_TOLL_FREE);
assert_eq!(pn::short_example_number("US"), "112");
```

To load a specific `.so`, use the [`PhoneNumbers`] type — the same surface over
an engine you loaded yourself:

```rust
use phonenumber_ae::PhoneNumbers;

let pn = PhoneNumbers::new()?;                 // default resolution order
assert_eq!(pn.country_code("GB"), "44");
let num = pn.parse("01212345678", "GB");       // trunk 0 stripped
assert_eq!(num.national_number(), "1212345678");
# Ok::<(), phonenumber_ae::Error>(())
```

## Surface

| Group | Calls |
|---|---|
| Metadata | `country_code`, `example_number`, `example_number_for_type`, `invalid_example_number`, `possible_lengths`, `region_code_for_country_code`, `is_nanpa_country`, `ndd_prefix_for_region`, `region_count`, `region_at`, `regions`, `regions_for_country_code` |
| Parse | `parse` → `ParsedNumber` (`region`, `country_code`, `national_number`, `extension`, `italian_leading_zero`, `source`/`source_enum`, `error`, `region_code`, `national_significant_number`, `length_of_ndc`, `length_of_area_code`, `is_geographical`, `format_in_original`), `national_number` |
| Validation | `is_possible_number`, `is_possible_number_with_reason`(`_enum`), `is_valid_number`, `is_valid_number_for_region`, `number_type`(`_enum`), `can_be_internationally_dialled` |
| Formatting | `format`, `format_national`/`_international`/`_e164`/`_rfc3966`, `format_out_of_country` |
| Helpers | `is_number_match`(`_enum`), `truncate_too_long`, `normalize_digits_only`, `convert_alpha_characters`, `is_alpha_number` |
| Stateful | `AsYouTypeFormatter` (`as_you_type_formatter`), `find_numbers` → `Vec<Match>` |
| Short numbers | `short_is_possible`, `short_is_valid`, `is_emergency_number`, `connects_to_emergency_number`, `short_is_carrier_specific`, `short_is_sms_service`, `short_expected_cost`(`_enum`), `short_example_number` |
| Metadata | `abi_version` (→ `3`) |

Every metadata/free-function surface is available both crate-level (over one
process-wide engine) and as a method on `PhoneNumbers`.

### Constants and enums

Format styles are `E164` (0), `INTERNATIONAL` (1), `NATIONAL` (2), `RFC3966`
(3) — mirrored by the `Format` enum. Note **E164 is `0`** in the v2 ABI.

Other constant groups, each with a raw `i32` const and a typed enum:

* `TYPE_*` / `NumberType` — `-1` unknown, `0..=9` fixed-line … voicemail.
* `VR_*` / `ValidationResult` — the `is_possible_number_with_reason` outcome.
* `MATCH_*` / `MatchType` — the `is_number_match` outcome.
* `SRC_*` / `CountryCodeSource` — the parsed number's `source`.
* `LENIENCY_*` / `Leniency` — the `find_numbers` strictness.
* `COST_*` / `Cost` — the `short_expected_cost` outcome (`0` toll-free, `1`
  standard rate, `2` premium rate, `3` unknown).

`region` is an ISO-3166 alpha-2 code (case-insensitive). `input` is a raw phone
number as a human might type it — digits with optional spaces, dashes,
parentheses, dots, an optional leading `+countrycode`, and an optional
extension.

## Tests

```
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so cargo test --offline
```

or, with the engine built for you:

```
aeb rust/.tests.ae
```

The suite is the 40-check v3 conformance contract in `docs/conformance.md`,
plus a few extras covering the typed idiomatic surface.

## Notes for maintainers

* **Every `*mut c_char` the ABI returns is caller-owned.** `Api::take_string`
  copies the bytes into a Rust `String` and frees the pointer through
  `aether_pn_embed_free_string`; anything else leaks. This includes the two
  "stateful" surfaces: a `ParsedNumber` and an `AsYouTypeFormatter`'s state are
  themselves caller-owned strings, threaded through accessor calls.
* There is **no opaque handle and there are no callbacks** — the engine is a
  pure transform over a baked-in metadata table. `native.rs` is a plain symbol
  table; nothing to create or free but the strings you get back.
* Interior NULs in an input string are caught by `native::to_c` rather than
  silently truncating the string as it crosses the FFI.
* The `Cargo.lock` is vendored so `cargo test --offline` is reproducible; the
  only dependency is `libloading`.
