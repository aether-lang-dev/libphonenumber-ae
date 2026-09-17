# phonenumber_ae — Rust

A thin Rust binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this crate is just
[libloading](https://docs.rs/libloading) FFI marshalling over
`libphonenumber_ae.so`. See the [repo README](../README.md) for the whole picture.

## Use it

```rust
use phonenumber_ae as pn;

pn::is_valid_number("US", "+1 201 555 0123");                       // true
pn::is_possible_number("GB", "1212345678");                        // true
pn::format("US", "2015550123", pn::NATIONAL);                      // "(201) 555-0123"
pn::format("US", "2015550123", pn::E164);                         // "+12015550123"
pn::number_type_enum("US", "2015550123");                          // pn::NumberType::FixedLine
pn::country_code("JP");                                            // "81"

// side-libraries
pn::carrier_name_for_number("GB", "7106000000", None);             // "O2"
pn::geo_description_for_number("US", "6502530000", None);          // "Mountain View, CA"
```

## Install it in your project

Build the source `.crate` (from the repo root), then add it as a dependency. No
`.so` is bundled — the crate is built by the consumer and loads the core via
FFI at run time:

```sh
aeb core/.build.ae && aeb rust/.dist.ae   # -> target/dist/phonenumber_ae-*.crate
cargo add phonenumber_ae   # or point a path/registry dependency at the .crate
```

At run time the core is resolved in this order: an explicit
`PhoneNumbers::with_library(Some(path))`, `$LIBPHONENUMBER_AE_LIB`, a `native/`
dir next to the crate, then the OS loader's search path — so set
`LIBPHONENUMBER_AE_LIB` or drop the `.so` beside the binary.

You don't need aeb for the core: download the prebuilt one for your platform
from a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases)
and point at it:

```sh
export LIBPHONENUMBER_AE_LIB="$(curl -fsSL https://raw.githubusercontent.com/aether-lang-dev/libphonenumber-ae/main/get-core.sh | sh)"
```

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb rust/.tests.ae      # the 47-check conformance suite
```
