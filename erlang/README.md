# phonenumber_ae (Erlang)

Validate and format international phone numbers.

This is a **thin NIF binding** over the monorepo's one shared native engine —
`core/native/libphonenumber_ae.so`, compiled from Google libphonenumber's own
metadata as pure Aether. It contains **no phone-number logic**: every function
marshals to an `aether_pn_embed_*` call across the flat C ABI described in
`core/embed.ae`.

It is also the **canonical BEAM binding**. `elixir/` and `gleam/` do not ship
their own C — they build-depend on this node and load *this* compiled NIF over
the BEAM. One `.so`, three languages.

## Building

```sh
aeb erlang/.build.ae
```

That produces an ordinary OTP application:

```
erlang/_build/phonenumber_ae_nif/
    ebin/phonenumber_ae.beam
    ebin/phonenumber_ae_nif.beam
    ebin/phonenumber_ae_nif.app
    priv/phonenumber_ae_nif.so      the NIF
    priv/libphonenumber_ae.so       the engine, staged
```

Put its **parent** on `ERL_LIBS` and OTP finds the app:

```sh
ERL_LIBS=erlang/_build erl
```

### Two ways to build it

**In your own Erlang toolchain** — `rebar.config` is here for exactly that:

```sh
rebar3 compile     # the NIF + the .beam files
rebar3 eunit       # the conformance suite
```

The engine itself is not a rebar dependency; build it once first (`aeb
core/.build.ae`, see ../core).

**In this monorepo** — `aeb erlang/.build.ae`, which drives aeb's `erlang.nif`
builder. That is what our CI runs, because this repo builds 20+ language
bindings from one dependency graph. Both produce the same OTP application.

### Finding the engine

The NIF `dlopen`s the engine at load time (it does **not** link it, so the BEAM
loads this module cleanly even when the engine is absent). Resolution order:

1. `$LIBPHONENUMBER_AE_LIB`
2. `priv/` next to the app (the staged copy)
3. the OS loader's own search path

## Usage

```erlang
<<"1">>              = phonenumber_ae:country_code(<<"US">>),
<<"2015550123">>     = phonenumber_ae:example_number(<<"US">>),
true                 = phonenumber_ae:is_valid_number(<<"US">>, <<"+1 201 555 0123">>),
false                = phonenumber_ae:is_possible_number(<<"US">>, <<"201555">>),
fixed_line           = phonenumber_ae:number_type(<<"US">>, <<"2015550123">>),
<<"(201) 555-0123">> = phonenumber_ae:format(<<"US">>, <<"2015550123">>, national),
<<"+12015550123">>   = phonenumber_ae:format_e164(<<"US">>, <<"2015550123">>),
Regions              = phonenumber_ae:regions(),   %% [<<"AC">>, <<"AD">>, ...]
7                    = phonenumber_ae:abi_version().
```

All string inputs accept `iodata` (a binary, a string, or an iolist); all
string results come back as binaries.

### Parsing

`parse/2` returns a **caller-owned parsed-number value** (itself just a binary
— the ABI has no opaque handles); read its fields with the `pn_*` accessors:

```erlang
PN = phonenumber_ae:parse(<<"+1 201 555 0123 ext 42">>, <<"US">>),
<<>>             = phonenumber_ae:pn_error(PN),        %% empty => parse ok
<<"2015550123">> = phonenumber_ae:pn_national_number(PN),
<<"42">>         = phonenumber_ae:pn_extension(PN),
<<"1">>          = phonenumber_ae:pn_country_code(PN),
from_number_with_plus = phonenumber_ae:pn_source(PN),
<<"US">>         = phonenumber_ae:region_code_for_number(PN).
```

### As-you-type

The formatter state is also just a caller-owned binary; `ayt_input/2` returns a
fresh state each keystroke:

```erlang
S0 = phonenumber_ae:ayt_new(<<"US">>),
S  = lists:foldl(fun(C, S) -> phonenumber_ae:ayt_input(S, <<C>>) end,
                 S0, "2015550123"),
<<"(201) 555-0123">> = phonenumber_ae:ayt_result(S).
```

### Finding numbers in text

```erlang
phonenumber_ae:find_numbers(<<"call 201-555-0123 or +1 202 555 0199">>, <<"US">>).
%% => [{5, 17, <<"201-555-0123">>}, {21, 36, <<"+1 202 555 0199">>}]
%% each match is {Start, End, Raw}; pass a leniency atom (possible | valid |
%% strict_grouping | exact_grouping) as the 3rd arg, default valid.
```

### Short numbers (emergency, SMS shortcodes)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```erlang
true       = phonenumber_ae:is_emergency_number(<<"US">>, <<"911">>),
false      = phonenumber_ae:is_emergency_number(<<"US">>, <<"999">>),   %% that's GB
true       = phonenumber_ae:short_is_valid(<<"US">>, <<"911">>),
toll_free  = phonenumber_ae:short_expected_cost(<<"US">>, <<"911">>),
<<"112">>  = phonenumber_ae:short_example_number(<<"US">>).
```

### Time zones, carrier and geocoder

The engine also maps a number to its IANA time zones, its carrier, and a
geographic description. All take a region plus the raw input, exactly like the
calls above; carrier and geocoder also take an optional trailing language (an
ISO code, default `<<"en">>`):

```erlang
[<<"America/New_York">>] =
    phonenumber_ae:time_zones_for_number(<<"US">>, <<"2015550123">>),
[<<"Europe/London">>] =
    phonenumber_ae:time_zones_for_number(<<"GB">>, <<"2070313000">>),
<<"Etc/Unknown">> = phonenumber_ae:unknown_time_zone(),
<<"O2">>          = phonenumber_ae:carrier_name_for_number(<<"GB">>, <<"7106000000">>),
<<"Mountain View, CA">> =
    phonenumber_ae:geo_description_for_number(<<"US">>, <<"6502530000">>),
%% carrier/geo take an optional trailing language (ISO code), default <<"en">>:
<<"O2">>          = phonenumber_ae:carrier_name_for_number(<<"GB">>, <<"7106000000">>, <<"en">>).
```

`time_zones_for_number/2` always returns a non-empty list — a number the engine
knows no zone for comes back as `[<<"Etc/Unknown">>]`, not `[]`.

### The surface (v7 — full PhoneNumberUtil parity + ShortNumberInfo + TimeZones + Carrier + Geocoder)

- **Metadata**: `country_code/1`, `example_number/1`,
  `example_number_for_type/2`, `invalid_example_number/1`, `possible_lengths/1`,
  `region_code_for_country_code/1`, `is_nanpa_country/1`,
  `ndd_prefix_for_region/1,2`.
- **Regions**: `region_count/0`, `region_at/1`, `regions/0`,
  `cc_region_count/1`, `cc_region_at/2`, `regions_for_country_code/1`.
- **Parse + accessors**: `parse/2`, `national_number/2`, `pn_region/1`,
  `pn_country_code/1`, `pn_national_number/1`, `pn_extension/1`,
  `pn_italian_leading_zero/1`, `pn_source/1`, `pn_error/1`,
  `region_code_for_number/1`, `national_significant_number/1`,
  `length_of_ndc/1`, `length_of_area_code/1`, `is_geographical/1`.
- **Validity**: `is_possible_number/2`, `is_possible_number_with_reason/2`
  (a ValidationResult atom), `is_valid_number/2`, `is_valid_number_for_region/2`,
  `number_type/2` (atom; `number_type_code/2` for the raw int),
  `can_be_internationally_dialled/2`.
- **Formatting**: `format/3` with a style atom
  (`e164` | `international` | `national` | `rfc3966`), plus `format_national/2`,
  `format_international/2`, `format_e164/2`, `format_rfc3966/2`,
  `format_out_of_country/3`, `format_in_original/2`.
- **Helpers**: `is_number_match/2` (a MatchType atom), `truncate_too_long/2`,
  `normalize_digits_only/1`, `convert_alpha_characters/1`, `is_alpha_number/1`.
- **As-you-type**: `ayt_new/1`, `ayt_input/2`, `ayt_result/1`, `ayt_clear/1`.
- **Find numbers**: `find_numbers/2,3` (list of `{Start, End, Raw}`), and the
  lower-level `matcher_count/3`, `matcher_start/4`, `matcher_end/4`,
  `matcher_raw/4`.
- **Short numbers**: `short_is_possible/2`, `short_is_valid/2`,
  `is_emergency_number/2`, `connects_to_emergency_number/2`,
  `short_is_carrier_specific/2`, `short_is_sms_service/2`,
  `short_expected_cost/2` (a ShortNumberCost atom — `toll_free` |
  `standard_rate` | `premium_rate` | `unknown`; `short_expected_cost_code/2` for
  the raw int), `short_example_number/1`.
- **Time zones**: `time_zones_for_number/2` (a non-empty list of IANA zone
  ids), `time_zone_count/2`, `unknown_time_zone/0` (`<<"Etc/Unknown">>`).
- **Carrier**: `carrier_name_for_number/2,3`,
  `carrier_name_for_valid_number/2,3` (name, or `<<>>`; an optional trailing
  language ISO code, default `<<"en">>`).
- **Geocoder**: `geo_description_for_number/2,3`,
  `geo_description_for_valid_number/2,3` (geographic description, or `<<>>`; an
  optional trailing language ISO code, default `<<"en">>`).
- `abi_version/0` (returns `7`).

> **v7 note.** The carrier and geocoder calls gained an optional trailing
> language argument (an ISO code, default `<<"en">>`; a language not compiled
> into the engine falls back to English). The geocoder calls arrived in v6; the
> time-zone and carrier calls in v5; ShortNumberInfo in v3.
> The format-style selectors from v2 are unchanged: `e164` is `0` (it was `2` in
> v1). Callers that use the style atoms never see the number; callers that
> hard-coded the old integer must switch to the atoms.

### No handle, no callbacks

The engine is a pure `(region[, input]) -> answer` transform. There is no
opaque handle to open or close, and no callback surface — a NIF cannot safely
call back into the BEAM, and this ABI never asks it to. The NIF is pure
binary↔C-string marshalling with the copy-then-free discipline on returned
strings (every `char*` the ABI returns is caller-owned).

## Conformance

`erlang/.tests.ae` runs the 47-check binding conformance suite
(`docs/conformance.md`, v7) as EUnit, against the very same compiled module
Elixir and Gleam load. It samples each *kind* of value crossing the FFI — it
proves the marshalling, not the library. The suite SKIPs (green) when `erl`,
`erl_nif.h`, or `eunit` is absent.
