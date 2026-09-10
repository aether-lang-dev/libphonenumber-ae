{-# LANGUAGE OverloadedStrings #-}

-- |
-- The 40-check binding conformance suite (@docs\/conformance.md@, v3).
--
-- Proves the Haskell binding marshals every value shape across the FFI. It is
-- __not__ a phone-number test suite — the behavioural cases live in the
-- engine's own tests and run once, in Aether.
--
-- == Why a plain runner and not hspec\/tasty
--
-- hspec and tasty arrive from Hackage, so running them needs a @cabal update@
-- and a network round trip before a single assertion executes. The rest of
-- this monorepo's bindings test with whatever is already on the box, so this
-- one does too. The dependency set is @base@ + @bytestring@, both of which
-- ship with GHC, which means @runghc@ can drive the whole suite offline:
--
-- @
--     runghc -isrc -itest test\/Conformance.hs
-- @
--
-- The process exit code is the result: 0 all-pass, 1 any failure.
module Main (main) where

import Control.Exception (SomeException, try)
import Control.Monad (forM_, unless)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as C
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import System.Exit (exitFailure, exitSuccess)
import System.IO (hSetEncoding, stdout, utf8)

import PhoneNumber

-- ---------------------------------------------------------------------------
-- A minimal assertion runner
-- ---------------------------------------------------------------------------

type Failures = IORef [String]

-- | An assertion failure, raised inside a check body and caught by 'check'.
assertFail :: String -> IO a
assertFail = ioError . userError

-- | Run one check, accumulating a failure rather than aborting the suite.
check :: Failures -> String -> IO () -> IO ()
check fs name body = do
  r <- try body :: IO (Either SomeException ())
  case r of
    Right () -> putStrLn ("  PASS " ++ name)
    Left e -> do
      modifyIORef' fs (++ [name ++ ": " ++ show e])
      putStrLn ("  FAIL " ++ name)
      putStrLn ("       " ++ show e)

eqStr :: String -> B.ByteString -> B.ByteString -> IO ()
eqStr what got want =
  unless (got == want) $
    assertFail (what ++ ":\n         got  \"" ++ render got ++ "\"\n         want \"" ++ render want ++ "\"")

-- | Render a ByteString for a failure message, hex-dumping non-ASCII so a
-- UTF-8 payload does not come out as mojibake through the UTF-8 handle.
render :: B.ByteString -> String
render bs
  | B.all (< 0x80) bs = C.unpack bs
  | otherwise = unwords (map hex2 (B.unpack bs))
  where
    digits = "0123456789abcdef"
    hex2 w =
      let n = fromIntegral w :: Int
       in [digits !! (n `div` 16), digits !! (n `mod` 16)]

eqInt :: String -> Int -> Int -> IO ()
eqInt what got want =
  unless (got == want) $ assertFail (what ++ ": got " ++ show got ++ ", want " ++ show want)

eqShow :: (Eq a, Show a) => String -> a -> a -> IO ()
eqShow what got want =
  unless (got == want) $ assertFail (what ++ ": got " ++ show got ++ ", want " ++ show want)

isTrue :: String -> Bool -> IO ()
isTrue what got = unless got $ assertFail (what ++ ": expected True")

isFalse :: String -> Bool -> IO ()
isFalse what got = unless (not got) $ assertFail (what ++ ": expected False")

-- ---------------------------------------------------------------------------
-- main
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  hSetEncoding stdout utf8
  putStrLn "=== phonenumber_ae Haskell binding conformance (v3) ==="
  v <- abiVersion
  putStrLn ("engine: ABI v" ++ show v)

  fs <- newIORef []
  runChecks fs
  failures <- readIORef fs

  putStrLn ("=== " ++ show (length failures) ++ " failed ===")
  if null failures
    then exitSuccess
    else do
      putStrLn "failures:"
      forM_ failures (\f -> putStrLn ("  - " ++ f))
      exitFailure

runChecks :: Failures -> IO ()
runChecks fs = do
  -- ---- the forty (docs/conformance.md v3) ----

  check fs "01 country_code US == 1" $ do
    out <- countryCode "US"
    eqStr "country_code" out "1"

  check fs "02 country_code GB == 44" $ do
    out <- countryCode "GB"
    eqStr "country_code" out "44"

  check fs "03 country_code ZZ == empty" $ do
    -- The classic NULL-vs-"" bug: a binding that maps a null char* to an error.
    out <- countryCode "ZZ"
    eqStr "country_code" out ""

  check fs "04 example_number US == 2015550123" $ do
    out <- exampleNumber "US"
    eqStr "example_number" out "2015550123"

  check fs "05 possible_lengths US == 10" $ do
    out <- possibleLengths "US"
    eqStr "possible_lengths" out "10"

  check fs "06 region_code_for_country_code 44 == GB" $ do
    out <- regionCodeForCountryCode "44"
    eqStr "region_for_cc" out "GB"

  check fs "07 is_nanpa_country US" $ do
    ok <- isNanpaCountry "US"
    isTrue "is_nanpa" ok

  check fs "08 region enumeration" $ do
    regs <- regions
    isTrue "region count >= 200" (length regs >= 200)
    case regs of
      (first : _) -> eqInt "first region id is 2 letters" (B.length first) 2
      [] -> assertFail "no regions"

  check fs "09 cc_region_at 1/0 == US" $ do
    regs <- regionsForCountryCode "1"
    case regs of
      (first : _) -> eqStr "first region for +1" first "US"
      [] -> assertFail "no regions for country code 1"

  check fs "10 parse national_number == 2015550123" $ do
    num <- parse "+1 201 555 0123 ext 42" "US"
    err <- errorOf num
    eqStr "parse error" err ""
    nn <- nationalNumberOf num
    eqStr "pn_national_number" nn "2015550123"

  check fs "11 parse extension == 42" $ do
    num <- parse "+1 201 555 0123 ext 42" "US"
    ext <- extensionOf num
    eqStr "pn_extension" ext "42"

  check fs "12 parse country_code == 1" $ do
    num <- parse "+1 201 555 0123 ext 42" "US"
    cc <- countryCodeOf num
    eqStr "pn_country_code" cc "1"

  check fs "13 parse source == FROM_NUMBER_WITH_PLUS" $ do
    num <- parse "+1 201 555 0123 ext 42" "US"
    src <- sourceOf num
    eqShow "pn_source" src FromNumberWithPlus

  check fs "14 parse region_code == US" $ do
    num <- parse "+1 201 555 0123 ext 42" "US"
    rc <- regionCodeOf num
    eqStr "region_code_for_number" rc "US"

  check fs "15 parse trunk 0 stripped (GB)" $ do
    num <- parse "01212345678" "GB"
    nn <- nationalNumberOf num
    eqStr "pn_national_number" nn "1212345678"

  check fs "16 is_possible US 2015550123" $ do
    ok <- isPossibleNumber "US" "2015550123"
    isTrue "is_possible" ok

  check fs "17 reason TOO_SHORT" $ do
    r <- isPossibleNumberWithReason "US" "201555"
    eqShow "reason" r TooShort

  check fs "18 is_valid US 2015550123" $ do
    ok <- isValidNumber "US" "2015550123"
    isTrue "is_valid" ok

  check fs "19 is_valid wrong shape" $ do
    ok <- isValidNumber "US" "1015550123"
    isFalse "is_valid" ok

  check fs "20 is_valid with +cc" $ do
    ok <- isValidNumber "US" "+12015550123"
    isTrue "is_valid" ok

  check fs "21 number_type FIXED_LINE_OR_MOBILE / FIXED_LINE" $ do
    -- US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns
    t <- numberType "US" "2015550123"
    isTrue "number_type US is FixedLineOrMobile" (t == FixedLineOrMobile)
    n <- numberTypeInt "US" "2015550123"
    eqInt "number_type US int" n 10
    tGb <- numberType "GB" "2070313000"
    isTrue "number_type GB is FixedLine" (tGb == FixedLine)
    nGb <- numberTypeInt "GB" "2070313000"
    eqInt "number_type GB int" nGb 0

  check fs "22 format NATIONAL" $ do
    out <- format "US" "2015550123" National
    eqStr "format" out "(201) 555-0123"

  check fs "23 format E164" $ do
    out <- format "US" "2015550123" E164
    eqStr "format" out "+12015550123"

  check fs "24 format INTERNATIONAL" $ do
    out <- format "US" "2015550123" International
    eqStr "format" out "+1 201-555-0123"

  check fs "25 format RFC3966" $ do
    out <- format "US" "2015550123" Rfc3966
    eqStr "format" out "tel:+1-201-555-0123"

  check fs "26 is_number_match EXACT" $ do
    m <- isNumberMatch "+12015550123" "+1 201 555 0123"
    eqShow "match" m ExactMatch

  check fs "27 is_number_match NO_MATCH" $ do
    m <- isNumberMatch "+12015550123" "+12025550123"
    eqShow "match" m NoMatch

  check fs "28 normalize_digits_only" $ do
    out <- normalizeDigitsOnly "+1 (201) 555.0123"
    eqStr "normalize" out "12015550123"

  check fs "29 convert_alpha_characters" $ do
    out <- convertAlphaCharacters "1-800-FLOWERS"
    eqStr "convert_alpha" out "1-800-3569377"

  check fs "30 truncate_too_long" $ do
    out <- truncateTooLong "US" "20155501239999"
    eqStr "truncate" out "2015550123"

  check fs "31 AsYouType 2015550123" $ do
    ayt <- newAsYouTypeFormatter "US"
    out <- feedAll ayt "2015550123"
    eqStr "as_you_type" out "(201) 555-0123"

  check fs "32 matcher_count == 2" $ do
    ms <- findNumbers "call 201-555-0123 or +1 202 555 0199" "US" Valid
    eqInt "match count" (length ms) 2

  check fs "33 matcher_raw" $ do
    ms <- findNumbers "call 201-555-0123 now" "US" Valid
    case ms of
      (m0 : _) -> eqStr "match raw" (matchRaw m0) "201-555-0123"
      [] -> assertFail "no matches"

  check fs "34 abi_version == 3" $ do
    v <- abiVersion
    eqInt "abi_version" v 3

  check fs "35 short is_emergency US 911" $ do
    ok <- isEmergencyNumber "US" "911"
    isTrue "is_emergency_number" ok

  check fs "36 short not-emergency US 999" $ do
    ok <- isEmergencyNumber "US" "999"
    isFalse "is_emergency_number" ok

  check fs "37 short is_emergency GB 999" $ do
    ok <- isEmergencyNumber "GB" "999"
    isTrue "is_emergency_number" ok

  check fs "38 short is_valid US 911" $ do
    ok <- shortIsValid "US" "911"
    isTrue "short_is_valid" ok

  check fs "39 short expected_cost US 911 toll-free" $ do
    c <- shortExpectedCost "US" "911"
    eqShow "short_expected_cost" c TollFreeCost

  check fs "40 short example_number US == 112" $ do
    out <- shortExampleNumber "US"
    eqStr "short_example_number" out "112"

  -- ---- a few surface extras ----

  check fs "format style aliases agree" $ do
    n <- formatNational "US" "2015550123"
    eqStr "national" n "(201) 555-0123"
    i <- formatInternational "US" "2015550123"
    eqStr "international" i "+1 201-555-0123"
    e <- formatE164 "US" "2015550123"
    eqStr "e164" e "+12015550123"
    r <- formatRfc3966 "US" "2015550123"
    eqStr "rfc3966" r "tel:+1-201-555-0123"

  check fs "region_at out of range is empty" $ do
    oob <- regionAt 1000000
    eqStr "out of range" oob ""

  check fs "many round trips do not leak or crash" $ do
    forM_ [1 :: Int .. 3000] $ \_ -> do
      cc <- countryCode "US"
      eqStr "still working" cc "1"

-- | Feed every character of a string through an 'AsYouTypeFormatter', returning
-- the formatted-so-far string after the last digit.
feedAll :: AsYouTypeFormatter -> B.ByteString -> IO B.ByteString
feedAll ayt s = go (C.unpack s) B.empty
  where
    go [] acc = pure acc
    go (c : cs) _ = do
      out <- inputDigit ayt (C.singleton c)
      go cs out
