# phonenumber_ae — Elixir

A thin Elixir binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding compiles
no C — every function `defdelegate`s to `:phonenumber_ae_nif`, the **canonical BEAM
NIF** the Erlang binding builds (and Gleam shares). One core, one NIF, three
languages. See the [repo README](../README.md) for the whole picture.

## Use it

```elixir
PhonenumberAe.is_valid_number?("US", "+1 201 555 0123")   # => true
PhonenumberAe.is_possible_number?("GB", "1212345678")     # => true
PhonenumberAe.format("US", "2015550123", :national)       # => "(201) 555-0123"
PhonenumberAe.format_e164("US", "2015550123")             # => "+12015550123"
PhonenumberAe.number_type("US", "2015550123")             # => :fixed_line
PhonenumberAe.country_code("JP")                          # => "81"

# side-libraries
PhonenumberAe.carrier_name_for_number("GB", "7106000000")    # => "O2"
PhonenumberAe.geo_description_for_number("US", "6502530000")  # => "Mountain View, CA"
```

`abi_version/0` returns `7`.

## Install it in your project

Build the Hex package (from the repo root), then add it as a `:path` (or published)
dependency:

```sh
aeb core/.build.ae && aeb elixir/.dist.ae   # -> target/dist/phonenumber_ae-0.1.0.tar
mix hex.publish   # or unpack the tar and depend on it: {:phonenumber_ae, path: "..."}
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the hex package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb elixir/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb elixir/.dist.ae
```

Same hex package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The Hex package ships **no native code** — the shared NIF is built once by the
Erlang node and loaded at runtime. The NIF `dlopen`s the core in this order:
`$LIBPHONENUMBER_AE_LIB`, then `priv/` beside the app, then the OS loader's search
path.

## Develop / test

```sh
aeb elixir/.tests.ae      # the 47-check conformance suite
```
