# phonenumber_ae — Lua

A thin Lua 5.4 binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just a
small C extension that `dlopen`s and marshals to `libphonenumber_ae.so` (ABI v7,
66 exports). See the [repo README](../README.md) for the whole picture.

## Use it

```lua
local pn = require("phonenumber_ae")

pn.is_valid_number("US", "+1 201 555 0123")           -- true
pn.is_possible_number("GB", "1212345678")             -- true
pn.format("US", "2015550123", pn.NATIONAL)            -- "(201) 555-0123"
pn.format("US", "2015550123", pn.E164)                -- "+12015550123"
pn.number_type("US", "2015550123")                    -- pn.TYPE_FIXED_LINE (0)
pn.country_code("JP")                                 -- "81"

-- side-libraries
pn.carrier_name_for_number("GB", "7106000000")        -- "O2"
pn.geo_description_for_number("US", "6502530000")     -- "Mountain View, CA"
```

## Install it in your project

Build the rock (from the repo root), then install it — the core `.so` is
vendored at `native/` inside the package, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb lua/.dist.ae   # -> target/dist/phonenumber_ae-0.2.0-1.*.rock
luarocks install target/dist/phonenumber_ae-0.2.0-1.*.rock
```

(Where luarocks is absent, `.dist.ae` emits a `phonenumber-ae-lua.tar.gz` of the
same sources + rockspec instead; unpack it and `luarocks make` the rockspec.) The
package is current-OS-only (it vendors this platform's `.so`). The extension
`dlopen`s the core: point `$LIBPHONENUMBER_AE_LIB` at the vendored
`native/libphonenumber_ae.so` (or pass it to `pn.load(path)`); `pn.engine_path()`
reports which one loaded.

## Develop / test

From the repo, `aeb` builds the core and extension, then runs the suite:

```sh
aeb lua/.tests.ae      # the 47-check conformance suite
```
