# phonenumber-ae (Haskell)

Validate, parse and format international phone numbers.

This package is a **thin GHC-FFI binding** over the monorepo's one shared native
engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether over
Google libphonenumber's own metadata. It contains **no phone-number logic**:
every function marshals to an `aether_pn_embed_*` call across the flat C ABI
described in `core/embed.ae`. One engine, one set of behaviours, N language
surfaces.

As of **ABI v5** the surface is full `PhoneNumberUtil` parity plus the
`ShortNumberInfo` side-library (short / emergency numbers), the
`PhoneNumberToTimeZonesMapper` (IANA time zones) and the
`PhoneNumberToCarrierMapper` (English carrier names) — 64 symbols. A
parsed number is a caller-owned string you carry in a `ParsedNumber`; the
`AsYouTypeFormatter` threads its state through the same caller-owned-string
mechanism; and `findNumbers` walks free text for numbers.

> ### Honest status: this code has never been compiled
>
> It was written on a machine with **no GHC, cabal or stack installed**, and a
> GHC install is a multi-gigabyte download that was out of scope here. So every
> FFI type, import and cross-module name was checked **by hand** against
> `core/embed.ae` and `docs/abi.md` — but **no compiler has confirmed any of
> it**.
>
> `haskell/.tests.ae` therefore SKIPs, loudly and truthfully:
>
> ```
> haskell: SKIPPED — ghc not installed (no GHC toolchain on PATH)
> ```
>
> It does **not** report a pass it did not earn. The first person to run this
> with a real GHC should expect to fix compile errors; the ABI-level design was
> the part verified carefully, and the exported symbol names were checked
> against `docs/abi.md` and the built `.so`.

## Layout

```
haskell/
    phonenumber_ae.cabal         build manifest
    src/PhoneNumber.hs           the public API
    src/PhoneNumber/Native.hs    the 1:1 C ABI symbol table (all 64 symbols)
    test/Conformance.hs          the 44-check suite, a plain assertion runner
    native/                      where .tests.ae stages the engine .so
```

## Building

Unlike the `dlopen`-based bindings (Python/ctypes, Ruby/Fiddle,
Rust/libloading), this one **LINKS** the engine, so the shared library must
exist at *build* time as well as run time. Build it first:

```sh
aeb core/.build.ae
```

The `.cabal` searches both `haskell/native` and `../core/native`, and bakes the
same two directories in as `rpath`:

```
extra-lib-dirs:  native, ../core/native
extra-libraries: phonenumber_ae
ld-options:      -Wl,-rpath,native -Wl,-rpath,../core/native
```

Then either:

```sh
cabal build
cabal test conformance
```

or, with no package manager at all — which is how `.tests.ae` drives it,
because the dependency set is `base` + `bytestring` and both ship inside GHC:

```sh
runghc -isrc -itest -Lnative -lphonenumber_ae test/Conformance.hs
```

## Usage

```haskell
{-# LANGUAGE OverloadedStrings #-}
import qualified Data.ByteString.Char8 as C
import PhoneNumber

main :: IO ()
main = do
    -- parse, then read fields off the ParsedNumber
    num <- parse "+1 650 253 0000" "US"
    nn  <- nationalNumberOf num                 -- "6502530000"
    rc  <- regionCodeOf num                     -- "US"

    ok  <- isValidNumber "US" "+1 650 253 0000" -- True
    f   <- format "US" "6502530000" International -- "+1 650-253-0000"
    C.putStrLn (nn <> " " <> rc <> " " <> f)

    -- format a number as it is typed
    ayt <- newAsYouTypeFormatter "US"
    last' <- foldMap' (inputDigit ayt . C.singleton) "6502530000"
    -- last' is "(650) 253-0000" after the final digit

    -- find numbers in free text
    ms <- findNumbers "call 201-555-0123 today" "US" Valid
    mapM_ (C.putStrLn . matchRaw) ms            -- "201-555-0123"
```

(`foldMap'` above is illustrative; feed the characters through `inputDigit` in
order and keep the last result — see `test/Conformance.hs`'s `feedAll`.)

The surface (everything in `IO`, everything `ByteString`):

```haskell
-- metadata
countryCode              :: ByteString -> IO ByteString
exampleNumber            :: ByteString -> IO ByteString
exampleNumberForType     :: ByteString -> NumberType -> IO ByteString
invalidExampleNumber     :: ByteString -> IO ByteString
possibleLengths          :: ByteString -> IO ByteString
regionCodeForCountryCode :: ByteString -> IO ByteString
isNanpaCountry           :: ByteString -> IO Bool
nddPrefixForRegion       :: ByteString -> Bool -> IO ByteString

-- regions
regionCount           :: IO Int
regionAt              :: Int -> IO ByteString          -- "" out of range
regions               :: IO [ByteString]               -- engine order
sortedRegions         :: IO [ByteString]               -- deterministic
regionsForCountryCode :: ByteString -> IO [ByteString]

-- parse + parsed number
parse                       :: ByteString -> ByteString -> IO ParsedNumber
nationalNumber              :: ByteString -> ByteString -> IO ByteString
nationalNumberOf            :: ParsedNumber -> IO ByteString
countryCodeOf               :: ParsedNumber -> IO ByteString
extensionOf                 :: ParsedNumber -> IO ByteString
regionOf / regionCodeOf     :: ParsedNumber -> IO ByteString
italianLeadingZeroOf        :: ParsedNumber -> IO Bool
sourceOf                    :: ParsedNumber -> IO CountryCodeSource
errorOf                     :: ParsedNumber -> IO ByteString
nationalSignificantNumberOf :: ParsedNumber -> IO ByteString
lengthOfNdc / lengthOfAreaCode :: ParsedNumber -> IO Int
isGeographical              :: ParsedNumber -> IO Bool

-- validation
isPossibleNumber            :: ByteString -> ByteString -> IO Bool
isPossibleNumberWithReason  :: ByteString -> ByteString -> IO ValidationResult
isValidNumber               :: ByteString -> ByteString -> IO Bool
isValidNumberForRegion      :: ByteString -> ByteString -> IO Bool  -- (number, region)
numberType                  :: ByteString -> ByteString -> IO NumberType
numberTypeInt               :: ByteString -> ByteString -> IO Int
canBeInternationallyDialled :: ByteString -> ByteString -> IO Bool

-- format
format             :: ByteString -> ByteString -> Format -> IO ByteString
formatNational / formatInternational / formatE164 / formatRfc3966
                   :: ByteString -> ByteString -> IO ByteString
formatOutOfCountry :: ByteString -> ByteString -> ByteString -> IO ByteString
formatInOriginal   :: ParsedNumber -> ByteString -> IO ByteString

-- relations / helpers
isNumberMatch          :: ByteString -> ByteString -> IO MatchType
truncateTooLong        :: ByteString -> ByteString -> IO ByteString
normalizeDigitsOnly    :: ByteString -> IO ByteString
convertAlphaCharacters :: ByteString -> IO ByteString
isAlphaNumber          :: ByteString -> IO Bool

-- AsYouTypeFormatter
newAsYouTypeFormatter :: ByteString -> IO AsYouTypeFormatter
inputDigit            :: AsYouTypeFormatter -> ByteString -> IO ByteString
currentResult         :: AsYouTypeFormatter -> IO ByteString
clearFormatter        :: AsYouTypeFormatter -> IO ()

-- findNumbers
findNumbers :: ByteString -> ByteString -> Leniency -> IO [Match]
data Match = Match { matchStart :: Int, matchEnd :: Int, matchRaw :: ByteString }

-- ShortNumberInfo (short / emergency numbers)
shortIsPossible           :: ByteString -> ByteString -> IO Bool
shortIsValid              :: ByteString -> ByteString -> IO Bool
isEmergencyNumber         :: ByteString -> ByteString -> IO Bool
connectsToEmergencyNumber :: ByteString -> ByteString -> IO Bool
shortIsCarrierSpecific    :: ByteString -> ByteString -> IO Bool
shortIsSmsService         :: ByteString -> ByteString -> IO Bool
shortExpectedCost         :: ByteString -> ByteString -> IO ShortNumberCost
shortExampleNumber        :: ByteString -> IO ByteString

-- PhoneNumberToTimeZonesMapper (timezone lookup)
timeZonesForNumber :: ByteString -> ByteString -> IO [ByteString]  -- ["Etc/Unknown"] if none
timeZoneCount      :: ByteString -> ByteString -> IO Int           -- 0 == only the unknown zone
unknownTimeZone    :: IO ByteString                                 -- "Etc/Unknown"

-- PhoneNumberToCarrierMapper (English carrier names)
carrierNameForNumber      :: ByteString -> ByteString -> IO ByteString  -- "" if none known
carrierNameForValidNumber :: ByteString -> ByteString -> IO ByteString  -- "" unless the number is valid

abiVersion :: IO Int
```

### Short numbers (ShortNumberInfo)

Short numbers are dialled as-is — no country code, no national prefix — so the
input is the raw short number plus a region:

```haskell
isEmergencyNumber "US" "911"    -- True
isEmergencyNumber "GB" "999"    -- True
shortIsValid "US" "911"         -- True
shortExpectedCost "US" "911"    -- TollFreeCost
shortExampleNumber "US"         -- "112"
```

### Time zones and carrier

Both take a raw `(region, input)` and let the engine parse to E.164 itself.
`timeZonesForNumber` returns a list of IANA ids — a number with no known zones
comes back as `["Etc/Unknown"]`, never the empty list. Carrier names are
English only, and `""` when no carrier is known.

```haskell
timeZonesForNumber "US" "2015550123"      -- ["America/New_York"]
timeZonesForNumber "GB" "2070313000"      -- ["Europe/London"]
timeZoneCount "US" "2015550123"           -- 1
unknownTimeZone                            -- "Etc/Unknown"

carrierNameForNumber "GB" "7106000000"        -- "O2"
carrierNameForValidNumber "GB" "7106000000"   -- "O2" (only if valid)
```

### Constants

`Format` is `E164 | International | National | Rfc3966`. **Note the v2 wire
change: `E164` is now `0` (it was `2` under v1); `International = 1`,
`National = 2`, `Rfc3966 = 3`.** The `Enum` derivation is not the wire value —
the binding maps `Format` to the ABI int internally.

`NumberType` mirrors the ABI's number-type codes, with `UnknownType` at `-1` and
an `OtherType CInt` fallthrough. `ValidationResult`, `MatchType`,
`CountryCodeSource`, `Leniency` and `ShortNumberCost` (`TollFreeCost` / `StandardRateCost`
/ `PremiumRateCost` / `UnknownCost`) are the other constant groups, each with an
`Other…` fallthrough where the wire values are non-contiguous.

### Strings

Everything is `ByteString`, holding UTF-8 bytes. The engine speaks UTF-8, so
passing bytes straight through is lossless and keeps the dependency set to
`base` + `bytestring`. Working in `Text`? Encode at the boundary with
`Data.Text.Encoding.encodeUtf8`.

## The rule that matters

**Every returned `char*` is caller-owned** and must be freed with
`aether_pn_embed_free_string`. Leaking them is the single most common bug in a
binding, so **every** returned string in this package goes through exactly one
function:

```haskell
takeString :: CString -> IO ByteString   -- packCString, then free through the ABI
```

`B.packCString` *copies* up to the NUL, so the `ByteString` stays valid after
the free. (`unsafePackCString` would alias the buffer we are about to hand
back — a use-after-free.)

A `ParsedNumber` and an `AsYouTypeFormatter` are **not** opaque handles: the
parsed number is an ordinary caller-owned string carried in the `ParsedNumber`,
and the formatter threads its state as a caller-owned string held in an
`IORef`, replaced (old one freed through `takeString`) on every `inputDigit`.

Because this ABI has **no callbacks**, none of the Haskell-FFI hazards a
callback-carrying binding faces apply here: there is no `foreign import ccall
"wrapper"`, no `FunPtr` keepalive list, and no `safe` import. Nothing in the ABI
re-enters the Haskell RTS, so every import in `Native.hs` is `unsafe` — cheap,
non-reentrant C calls.

## Conformance

The 44-check suite (`docs/conformance.md`) lives in `test/Conformance.hs`,
alongside a few surface extras (the format-style aliases, out-of-range
`regionAt`, timezone-count agreement, `carrierNameForValidNumber`, and a
3000-iteration loop over the caller-owned string contract). It
is a plain assertion runner with its own exit code — no hspec, no tasty, no
Hackage round trip — for the same reason the other bindings' runners are: the
suite must run with whatever is already on the box.

```sh
aeb haskell/.tests.ae   # builds the engine, stages it, runs the suite (or SKIPs)
```
