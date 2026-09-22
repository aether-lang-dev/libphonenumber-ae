# phonenumber_ae — Nim

A thin Nim binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
`importc` marshalling over `libphonenumber_ae.so` (ABI v7, 66 exports). See the
[repo README](../README.md) for the whole picture.

## Use it

```nim
import phonenumber_ae

isValidNumber("US", "+1 201 555 0123")           # true
isPossibleNumber("GB", "1212345678")             # true
format("US", "2015550123", fmtNational)          # "(201) 555-0123"
format("US", "2015550123", fmtE164)              # "+12015550123"
numberType("US", "2015550123")                   # ntFixedLine
countryCode("JP")                                # "81"

# side-libraries
carrierNameForNumber("GB", "7106000000")         # "O2"
geoDescriptionForNumber("US", "6502530000")      # "Mountain View, CA"
```

## Install it in your project

Build the tarball (from the repo root), then unpack it — the core `.so` is
vendored at `native/` inside, so nothing else is needed at build or run time:

```sh
aeb core/.build.ae && aeb nim/.dist.ae   # -> target/dist/phonenumber-ae-nim.tar.gz
tar xzf target/dist/phonenumber-ae-nim.tar.gz   # -> phonenumber_ae.nimble, src/, native/
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb nim/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb nim/.dist.ae
```

Same package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

`nimble install` it from the unpacked dir (or add `requires "phonenumber_ae"` and
point at it as a local dependency). Unlike the dlopen bindings, this one *links*
the core: the `{.passL.}` in `src/phonenumber_ae.nim` searches `nim/native` and
bakes it in as `rpath`, so the vendored `native/libphonenumber_ae.so` resolves with
no `LD_LIBRARY_PATH`. The tarball is current-OS-only (it vendors this platform's
`.so`).

## Develop / test

From the repo, `aeb` builds the core, stages it, and runs the suite:

```sh
aeb nim/.tests.ae      # the 47-check conformance suite
```
