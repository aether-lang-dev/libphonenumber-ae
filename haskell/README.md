# phonenumber-ae — Haskell

A thin Haskell binding over the shared, pure-Aether libphonenumber engine. All
the phone logic lives in the one engine (`core/phonenumber.ae`); this binding is
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
the engine `.so` is built by `core/.build.ae` and linked from `native/` (this
binding LINKS the engine rather than `dlopen`ing it):

```sh
aeb core/.build.ae && aeb haskell/.dist.ae   # -> target/dist/phonenumber-ae-0.2.0.0.tar.gz
cabal install --lib target/dist/phonenumber-ae-0.2.0.0.tar.gz
```

The `.cabal` bakes `native` and `../core/native` in as `extra-lib-dirs` and
`rpath`, so once the engine `.so` is on one of those paths the linked package
finds it with no further configuration.

You don't need aeb for the engine: download the prebuilt one for your platform
from a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases)
and place it on a lib path, e.g.

```sh
curl -fsSLO https://raw.githubusercontent.com/aether-lang-dev/libphonenumber-ae/main/get-engine.sh
sh get-engine.sh latest native   # downloads the engine into ./native/
```

## Develop / test

From the repo, `aeb` builds the engine, stages it, and runs the suite against
the source tree:

```sh
aeb haskell/.tests.ae      # the 47-check conformance suite
```
