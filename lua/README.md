# phonenumber_ae (Lua)

Validate, parse and format international phone numbers (ABI v5 — full
PhoneNumberUtil parity plus the ShortNumberInfo, TimeZones and Carrier
side-libraries).

This binding is a **thin Lua 5.4 C extension** over the monorepo's one shared
native engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether
over Google libphonenumber's own metadata. It contains **no phone-number
logic**: every call marshals to an `aether_pn_embed_*` symbol. One engine, one
set of behaviours, N language surfaces. The ABI has no handle, no callbacks and
no state.

Two files make up the binding:

| File | Role |
|---|---|
| `src/phonenumber_ae.c` | the C extension — the **only** place that knows the ABI |
| `src/phonenumber_ae.lua` | the idiomatic Lua surface over it |

## Why a C extension and not FFI

Standard Lua 5.4 has no FFI. LuaJIT's `ffi` library is not Lua 5.4 and would
pin the binding to a fork stuck at 5.1 semantics. So this binding does what Lua
bindings normally do: a small C extension.

It still **`dlopen`s** the engine rather than linking it, so the same
`LIBPHONENUMBER_AE_LIB` resolution every other runtime-loading binding uses
applies here, and one engine `.so` serves them all.

## Building

```sh
aeb core/.build.ae
cd lua && cc -O2 -fPIC -shared $(pkg-config --cflags lua5.4) \
    src/phonenumber_ae.c -o phonenumber_ae_native.so -ldl
```

That produces `phonenumber_ae_native.so`. It links **`-ldl` but not liblua**:
the host interpreter already provides the Lua symbols, and linking a second copy
is the classic "two Lua VMs in one process" crash.

Or with LuaRocks:

```sh
luarocks make phonenumber_ae-0.2.0-1.rockspec
```

### The bundled `lua54` host

Debian 12 (and some others) ship `liblua5.4-dev` — headers and shared
library — but package **`lua5.3`** as the interpreter. A 5.3 interpreter cannot
load a 5.4 extension (`undefined symbol: lua_newuserdatauv`), so on such a box
there is nothing to test against. Rather than skip, `.tests.ae` compiles
`host/lua54.c` — about forty lines that call `luaL_newstate` / `luaL_openlibs`
/ `luaL_dofile` — into `./lua54` and runs the suite through it. This is **test
scaffolding only**: the extension itself loads into any real Lua 5.4 host. When
a `lua5.4` binary *is* on `PATH`, `.tests.ae` uses it directly.

### Library resolution

In order:

1. an explicit path — `pn.load("/path/to/libphonenumber_ae.so")`
2. `$LIBPHONENUMBER_AE_LIB` (what the in-tree `.tests.ae` leaf sets)
3. `native/libphonenumber_ae.so`, then `../core/native/libphonenumber_ae.so`
4. the OS loader's own search path

`pn.engine_path()` reports which one actually loaded.

## Usage

```lua
local pn = require("phonenumber_ae")

print(pn.country_code("US"))                        -- "1"
print(pn.is_valid_number("US", "+1 201 555 0123"))  -- true
print(pn.format("US", "2015550123", pn.NATIONAL))   -- "(201) 555-0123"
print(pn.number_type("US", "2015550123"))           -- 0 (pn.TYPE_FIXED_LINE)
```

### Parsing

`parse(input, region)` returns a `ParsedNumber` whose fields are read on demand
(each is a method — it marshals to a `pn_*` accessor over the caller-owned
parsed-number string):

```lua
local num = pn.parse("+1 201 555 0123 ext 42", "US")
num:national_number()   -- "2015550123"
num:extension()         -- "42"
num:country_code()      -- "1"
num:source()            -- pn.SRC_FROM_NUMBER_WITH_PLUS
num:region_code()       -- "US"
num:error()             -- "" (non-empty if the parse failed)
-- also: region, italian_leading_zero, national_significant_number,
--       length_of_ndc, length_of_area_code, is_geographical
```

### AsYouTypeFormatter

```lua
local ayt = pn.AsYouTypeFormatter.new("US")
local last
for c in ("2015550123"):gmatch(".") do last = ayt:input_digit(c) end
-- last == "(201) 555-0123";  ayt:result() re-reads it, ayt:clear() resets
```

### find_numbers

```lua
for _, m in ipairs(pn.find_numbers("call 201-555-0123 today", "US")) do
  print(m.raw, m.start, m["end"])   -- "201-555-0123", byte offsets (ABI, 0-based)
end
```

### Short numbers (ShortNumberInfo)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```lua
pn.is_emergency_number("US", "911")       -- true
pn.is_emergency_number("GB", "999")       -- true
pn.short_is_valid("US", "911")            -- true
pn.short_expected_cost("US", "911")       -- pn.COST_TOLL_FREE (0)
pn.short_example_number("US")             -- "112"
```

### Time zones and carrier

Both take a raw `(region, input)` and let the engine parse to E.164 itself.
`time_zones_for_number` returns a list of IANA ids — a number with no known
zones comes back as `{"Etc/Unknown"}`, never empty. Carrier names are English
only, and `""` when no carrier is known.

```lua
pn.time_zones_for_number("US", "2015550123")  -- {"America/New_York"}
pn.time_zones_for_number("GB", "2070313000")  -- {"Europe/London"}
pn.time_zone_count("US", "2015550123")        -- 1
pn.unknown_time_zone()                         -- "Etc/Unknown"

pn.carrier_name_for_number("GB", "7106000000")        -- "O2"
pn.carrier_name_for_valid_number("GB", "7106000000")  -- "O2" (only if valid)
```

The wider surface:

```lua
-- metadata
pn.country_code(region) / example_number(region) / possible_lengths(region)
pn.example_number_for_type(region, type) / invalid_example_number(region)
pn.region_code_for_country_code(cc)       -- "44" -> "GB"
pn.is_nanpa_country(region)               -- boolean
pn.ndd_prefix_for_region(region, strip)   -- national-direct-dial prefix
pn.regions() / sorted_regions() / region_count() / region_at(index)  -- 1-based
pn.regions_for_country_code(cc)           -- {"US","CA",…}
-- validation
pn.is_possible_number(region, input)                 -- boolean
pn.is_possible_number_with_reason(region, input)     -- VR_* integer
pn.is_valid_number(region, input) / is_valid_number_for_region(input, region)
pn.number_type(region, input)                        -- TYPE_* integer
pn.can_be_internationally_dialled(region, input)     -- boolean
-- formatting
pn.format(region, input, style)                      -- style defaults to NATIONAL
pn.format_national / _international / _e164 / _rfc3966 (region, input)
pn.format_out_of_country(region, input, calling_from)
pn.format_in_original(parsed, calling_from)
-- helpers
pn.is_number_match(a, b)                              -- MATCH_* integer
pn.truncate_too_long(region, input)
pn.normalize_digits_only(s) / convert_alpha_characters(s) / is_alpha_number(s)
-- short numbers (ShortNumberInfo)
pn.short_is_possible(region, input) / short_is_valid(region, input)
pn.is_emergency_number(region, input) / connects_to_emergency_number(region, input)
pn.short_is_carrier_specific(region, input) / short_is_sms_service(region, input)
pn.short_expected_cost(region, input)                -- COST_* integer
pn.short_example_number(region)
-- time zones (PhoneNumberToTimeZonesMapper)
pn.time_zones_for_number(region, input)              -- list; {"Etc/Unknown"} if none
pn.time_zone_count(region, input)                    -- 0 == only the unknown zone
pn.unknown_time_zone()                               -- "Etc/Unknown"
-- carrier (PhoneNumberToCarrierMapper, English names)
pn.carrier_name_for_number(region, input)            -- "" if none known
pn.carrier_name_for_valid_number(region, input)      -- "" unless the number is valid
-- lifecycle
pn.abi_version() / engine_path() / load(path)
```

Constant groups (all mirror `docs/abi.md`): **Format** `pn.E164`,
`pn.INTERNATIONAL`, `pn.NATIONAL`, `pn.RFC3966`; **NumberType** `pn.TYPE_*`
(`TYPE_UNKNOWN` = -1 through `TYPE_VOICEMAIL` = 9); **ValidationResult**
`pn.VR_*`; **MatchType** `pn.MATCH_*`; **CountryCodeSource** `pn.SRC_*`;
**Leniency** `pn.LENIENCY_POSSIBLE` / `pn.LENIENCY_VALID`; **ShortNumberCost**
`pn.COST_TOLL_FREE` / `pn.COST_STANDARD_RATE` / `pn.COST_PREMIUM_RATE` /
`pn.COST_UNKNOWN`.

> **v2 constant change:** the format style `E164` is now **0** (it was `2` in
> v1). `INTERNATIONAL` = 1, `NATIONAL` = 2, `RFC3966` = 3. Always use the named
> constants rather than bare integers.

Region indices are **1-based** throughout — the C extension converts to the
ABI's 0-based indexing so the Lua surface never sees it.

## Memory

Every `char*` the engine returns is caller-owned. `push_owned()` is the single
place a returned string becomes a Lua string, and it always calls
`aether_pn_embed_free_string`. Strings handed *to* the engine are Lua's own
buffers, valid for the duration of the call.

## Tests

The 44-check conformance suite (`docs/conformance.md`, v5) lives in
`test/conformance.lua`, alongside a few surface extras. Lua 5.4 ships no
de-facto-standard test framework, so it is a **plain assertion runner** — no
dependency to install, and the exit code is the result.

```sh
aeb lua/.tests.ae     # builds the engine + extension, then runs the suite
# or, with the engine already built:
cc -O2 -fPIC -shared $(pkg-config --cflags lua5.4) \
    src/phonenumber_ae.c -o phonenumber_ae_native.so -ldl
LUA_CPATH="./?.so;;" LUA_PATH="./src/?.lua;;" \
    LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
    lua5.4 test/conformance.lua
```

`.tests.ae` skips (exit 0, with a clear `lua: SKIPPED` line) when there is no C
compiler or no Lua 5.4 headers — rather than failing the build DAG for a missing
toolchain.
