# phonenumber_ae (Elixir)

Validate and format international phone numbers.

A thin Elixir surface over the monorepo's **canonical BEAM NIF** (in `erlang/`),
compiled from Google libphonenumber's own metadata as pure Aether. It contains
**no phone-number logic**: every function marshals to an `aether_pn_embed_*`
call across the C ABI in `core/embed.ae`.

## There is no C in this directory

This project compiles nothing native — no `make`, no `elixir_make`, no `c_src`.
Every function `defdelegate`s to `:phonenumber_ae_nif`, the very same compiled
module the Erlang and Gleam bindings load. One engine, one NIF, three
languages. Shipping a second copy of the C here would break the monorepo's
one-engine rule.

## Building and testing

```sh
aeb elixir/.tests.ae
```

That deps the `erlang/.build.ae` node (which builds the NIF once), then runs the
ExUnit suite against it.

### The Mix wrinkle

`erl`, `escript` and `gleam` all honour `$ERL_LIBS`, so they find the OTP app
built by `erlang/.build.ae` for free. **Mix does not** — it builds its code path
from `deps/` and `_build/`, and an OTP app Mix did not build is invisible to it.

So `elixir/.tests.ae` exports `$LIBPHONENUMBER_AE_BEAM_APP` (the built app
directory) and `test/test_helper.exs` calls `Code.append_path/1` on its `ebin/`.
That is the one wrinkle of consuming an OTP app Mix did not build.

To run the suite by hand after a plain `aeb erlang/.build.ae`:

```sh
cd elixir
LIBPHONENUMBER_AE_LIB=/path/to/libphonenumber_ae.so mix test
```

(the helper falls back to the in-tree `../erlang/_build/phonenumber_ae_nif` when
`$LIBPHONENUMBER_AE_BEAM_APP` is unset).

### Finding the engine

The NIF `dlopen`s the engine at load time. Resolution order: `$LIBPHONENUMBER_AE_LIB`,
then `priv/` beside the app, then the OS loader's own search path.

## Usage

```elixir
PhonenumberAe.country_code("US")                       # => "1"
PhonenumberAe.example_number("US")                     # => "2015550123"
PhonenumberAe.is_valid_number?("US", "+1 201 555 0123") # => true
PhonenumberAe.is_possible_number?("US", "201555")      # => false
PhonenumberAe.number_type("US", "2015550123")          # => :fixed_line
PhonenumberAe.format("US", "2015550123", :national)    # => "(201) 555-0123"
PhonenumberAe.format_e164("US", "2015550123")          # => "+12015550123"
PhonenumberAe.regions()                                # => ["AC", "AD", ...]
PhonenumberAe.abi_version()                            # => 3
```

### Parsing

`parse/2` returns a `PhonenumberAe.ParsedNumber` struct wrapping the
caller-owned parsed-number string; read its fields through the struct module:

```elixir
alias PhonenumberAe.ParsedNumber
num = PhonenumberAe.parse("+1 201 555 0123 ext 42", "US")
ParsedNumber.error(num)             # => ""   (empty means parse ok)
ParsedNumber.national_number(num)   # => "2015550123"
ParsedNumber.extension(num)         # => "42"
ParsedNumber.country_code(num)      # => "1"
ParsedNumber.source(num)            # => :from_number_with_plus
ParsedNumber.region_code(num)       # => "US"
```

### As-you-type

`AsYouTypeFormatter` stays immutable: `input_digit/2` returns
`{new_formatter, formatted_so_far}`.

```elixir
alias PhonenumberAe.AsYouTypeFormatter
f = AsYouTypeFormatter.new("US")
{_f, out} =
  "2015550123"
  |> String.graphemes()
  |> Enum.reduce({f, ""}, fn c, {f, _} -> AsYouTypeFormatter.input_digit(f, c) end)
out   # => "(201) 555-0123"
```

### Finding numbers in text

```elixir
PhonenumberAe.find_numbers("call 201-555-0123 or +1 202 555 0199", "US")
# => [%PhonenumberAe.Match{start: 5, end: 17, raw: "201-555-0123"}, ...]
# pass a leniency atom (:possible | :valid) as the 3rd arg, default :valid.
```

### Short numbers (emergency, SMS shortcodes)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```elixir
PhonenumberAe.is_emergency_number?("US", "911")   # => true
PhonenumberAe.is_emergency_number?("US", "999")   # => false  (that's GB)
PhonenumberAe.short_is_valid?("US", "911")        # => true
PhonenumberAe.short_expected_cost("US", "911")    # => :toll_free
PhonenumberAe.short_example_number("US")          # => "112"
```

### The surface (v3 — full PhoneNumberUtil parity + ShortNumberInfo)

- **Metadata**: `country_code/1`, `example_number/1`,
  `example_number_for_type/2`, `invalid_example_number/1`, `possible_lengths/1`,
  `region_code_for_country_code/1`, `is_nanpa_country?/1`,
  `ndd_prefix_for_region/2`.
- **Regions**: `region_count/0`, `region_at/1`, `regions/0`,
  `cc_region_count/1`, `cc_region_at/2`, `regions_for_country_code/1`.
- **Parse**: `parse/2` (→ `PhonenumberAe.ParsedNumber`), `national_number/2`.
- **Validity**: `is_possible_number?/2`, `is_possible_number_with_reason/2`
  (a ValidationResult atom), `is_valid_number?/2`, `is_valid_number_for_region?/2`,
  `number_type/2` (atom; `number_type_code/2` for the raw int),
  `can_be_internationally_dialled?/2`.
- **Formatting**: `format/3` with a style atom
  (`:e164` | `:international` | `:national` | `:rfc3966`), plus
  `format_national/2`, `format_international/2`, `format_e164/2`,
  `format_rfc3966/2`, `format_out_of_country/3`, `format_in_original/2`.
- **Helpers**: `is_number_match/2` (a MatchType atom), `truncate_too_long/2`,
  `normalize_digits_only/1`, `convert_alpha_characters/1`, `is_alpha_number?/1`.
- **As-you-type**: `PhonenumberAe.AsYouTypeFormatter`.
- **Find numbers**: `find_numbers/3` (list of `PhonenumberAe.Match`).
- **Short numbers**: `short_is_possible?/2`, `short_is_valid?/2`,
  `is_emergency_number?/2`, `connects_to_emergency_number?/2`,
  `short_is_carrier_specific?/2`, `short_is_sms_service?/2`,
  `short_expected_cost/2` (a ShortNumberCost atom — `:toll_free` |
  `:standard_rate` | `:premium_rate` | `:unknown`; `short_expected_cost_code/2`
  for the raw int), `short_example_number/1`.
- `abi_version/0` (returns `3`).

> **v3 note.** ShortNumberInfo (the `short_*` / `*_emergency_number?` calls
> above) is new in v3. The v2 format-style selectors are unchanged: `:e164` is
> `0` (it was `2` in v1). Callers that use the style atoms never see the number.

### No handles

The ABI has no opaque handles: a parsed number and an as-you-type state are
themselves caller-owned strings, wrapped by the structs above. Every function
is a direct FFI crossing.

## Conformance

`elixir/.tests.ae` runs the 40-check binding conformance suite
(`docs/conformance.md`, v3) as ExUnit. It samples each *kind* of value crossing
the FFI — it proves the marshalling, not the library. The node SKIPs (green)
when Elixir/Mix or the shared NIF is absent.
