# phonenumber-ae — Haskell

A thin Haskell binding over the shared, pure-Aether libphonenumber core. All
the phone logic lives in the one core (`core/phonenumber.ae`); this binding is
just GHC-FFI marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

```haskell
{-# LANGUAGE OverloadedStrings #-}
import PhoneNumber

main :: IO ()
main = do
    ok  <- isValidNumber "US" "+1 201 555 0123"       -- True
    p   <- isPossibleNumber "GB" "1212345678"         -- True
    nat <- format "US" "2015550123" National          -- "(201) 555-0123"
    e   <- format "US" "2015550123" E164              -- "+12015550123"
    ty  <- numberType "US" "2015550123"               -- FixedLine
    cc  <- countryCode "JP"                            -- "81"

    num <- parse "+1 650 253 0000" "US"
    nn  <- nationalNumberOf num                        -- "6502530000"
    rc  <- regionCodeOf num                            -- "US"

    -- side-libraries
    car <- carrierNameForNumber "GB" "7106000000"      -- "O2"
    geo <- geoDescriptionForNumber "US" "6502530000"   -- "Mountain View, CA"
    return ()
```

Everything is in `IO` and every string is a UTF-8 `ByteString`.

## Install it in your project

Build the Cabal source distribution (from the repo root), then depend on it —
the core `.so` is built by `core/.build.ae` and linked from `native/` (this
binding LINKS the core rather than `dlopen`ing it):

```sh
aeb core/.build.ae && aeb haskell/.dist.ae   # -> target/dist/phonenumber-ae-0.2.0.0.tar.gz
cabal install --lib target/dist/phonenumber-ae-0.2.0.0.tar.gz
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb haskell/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb haskell/.dist.ae
```

Same package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The `.cabal` bakes `native` and `../core/native` in as `extra-lib-dirs` and
`rpath`, so once the core `.so` is on one of those paths the linked package
finds it with no further configuration.

You don't need aeb for the core: download the prebuilt one for your platform
from a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases)
and place it on a lib path (`native/` is baked into `extra-lib-dirs`). Each
release attaches `libphonenumber_ae-<tag>-<os>-<arch>.<ext>` (+ a `.sha256`):

```sh
TAG=<tag>; ASSET="libphonenumber_ae-$TAG-linux-x86_64.so"   # pick your <os>-<arch>/<ext>
BASE="https://github.com/aether-lang-dev/libphonenumber-ae/releases/download/$TAG"
mkdir -p native && curl -fsSL "$BASE/$ASSET" -o "native/libphonenumber_ae.so"
```

## Develop / test

From the repo, `aeb` builds the core, stages it, and runs the suite against
the source tree:

```sh
aeb haskell/.tests.ae      # the 47-check conformance suite
```
