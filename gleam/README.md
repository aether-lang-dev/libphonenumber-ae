# phonenumber_ae — Gleam

A thin Gleam binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding compiles
no C — every function is an `@external(erlang, "phonenumber_ae_nif", ...)` onto the
**canonical BEAM NIF** the Erlang binding builds (and Elixir shares). Erlang target
only. See the [repo README](../README.md) for the whole picture.

## Use it

```gleam
import phonenumber_ae.{National, FixedLine}

phonenumber_ae.is_valid_number("US", "+1 201 555 0123")   // -> True
phonenumber_ae.is_possible_number("GB", "1212345678")     // -> True
phonenumber_ae.format("US", "2015550123", National)       // -> "(201) 555-0123"
phonenumber_ae.format_e164("US", "2015550123")            // -> "+12015550123"
phonenumber_ae.number_type("US", "2015550123")            // -> FixedLine
phonenumber_ae.country_code("JP")                         // -> "81"

// side-libraries
phonenumber_ae.carrier_name_for_number("GB", "7106000000")    // -> "O2"
phonenumber_ae.geo_description_for_number("US", "6502530000")  // -> "Mountain View, CA"
```

`abi_version()` returns `7`.

## Install it in your project

Build the package tarball (from the repo root), then unpack it and depend on it as
a `path` dependency in your `gleam.toml`:

```sh
aeb core/.build.ae && aeb gleam/.dist.ae   # -> target/dist/phonenumber-ae-gleam.tar.gz
tar -xzf target/dist/phonenumber-ae-gleam.tar.gz   # -> phonenumber_ae/ (add path = "..." dep)
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb gleam/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHubReleases.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb gleam/.dist.ae
```

Same package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The core `.so` is vendored under the package's `priv/` (current-OS-only). The NIF
`dlopen`s it in this order: `$LIBPHONENUMBER_AE_LIB`, then `priv/` beside the app,
then the OS loader's search path — and `gleam` honours `$ERL_LIBS` for resolving the
shared `phonenumber_ae_nif` module at runtime.

## Develop / test

```sh
aeb gleam/.tests.ae      # the 47-check conformance suite
```
