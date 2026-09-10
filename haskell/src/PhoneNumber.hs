{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : PhoneNumber
-- Description : Validate, parse and format international phone numbers (ABI v5).
--
-- A thin binding over the monorepo's ONE shared native engine —
-- @core\/native\/libphonenumber_ae.so@, compiled from pure Aether over Google
-- libphonenumber's own metadata. It contains __no phone-number logic__: every
-- function here marshals to an @aether_pn_embed_*@ call across the flat C ABI
-- described in @core\/embed.ae@. One engine, one set of behaviours, N language
-- surfaces.
--
-- == ABI v5
--
-- The ABI is full @PhoneNumberUtil@ parity plus the @ShortNumberInfo@
-- side-library (short \/ emergency numbers), the @PhoneNumberToTimeZonesMapper@
-- (IANA time zones) and the @PhoneNumberToCarrierMapper@ (English carrier
-- names). A parsed number is a
-- caller-owned string you carry in a 'ParsedNumber' and read fields from on
-- demand; the 'AsYouTypeFormatter' threads its state through the same
-- caller-owned-string mechanism, wrapped here behind an 'IORef'; and
-- 'findNumbers' walks free text for numbers, returning 'Match'es with byte
-- offsets and the raw substring.
--
-- @
-- import qualified Data.ByteString.Char8 as C
-- import PhoneNumber
--
-- main :: IO ()
-- main = do
--     num <- parse \"+1 650 253 0000\" \"US\"
--     nn  <- nationalNumberOf num                 -- \"6502530000\"
--     ok  <- isValidNumber \"US\" \"+1 650 253 0000\" -- True
--     f   <- format \"US\" \"6502530000\" International -- \"+1 650-253-0000\"
--     C.putStrLn nn
-- @
--
-- == Strings
--
-- Everything is 'B.ByteString', holding UTF-8 bytes. The engine speaks UTF-8;
-- passing bytes straight through is lossless and keeps the dependency set to
-- @base@ + @bytestring@. If you work in 'Data.Text.Text', encode with
-- @Data.Text.Encoding.encodeUtf8@ at the boundary.
module PhoneNumber
  ( -- * Metadata
    countryCode
  , exampleNumber
  , exampleNumberForType
  , invalidExampleNumber
  , possibleLengths
  , regionCodeForCountryCode
  , isNanpaCountry
  , nddPrefixForRegion

    -- * Regions
  , regionCount
  , regionAt
  , regions
  , sortedRegions
  , regionsForCountryCode

    -- * Parse + parsed number
  , ParsedNumber
  , parse
  , nationalNumber
  , regionOf
  , countryCodeOf
  , nationalNumberOf
  , extensionOf
  , italianLeadingZeroOf
  , sourceOf
  , errorOf
  , regionCodeOf
  , nationalSignificantNumberOf
  , lengthOfNdc
  , lengthOfAreaCode
  , isGeographical

    -- * Validation
  , isPossibleNumber
  , isPossibleNumberWithReason
  , isValidNumber
  , isValidNumberForRegion
  , numberType
  , canBeInternationallyDialled

    -- * Format
  , Format (..)
  , format
  , formatNational
  , formatInternational
  , formatE164
  , formatRfc3966
  , formatOutOfCountry
  , formatInOriginal

    -- * Relations / helpers
  , isNumberMatch
  , truncateTooLong
  , normalizeDigitsOnly
  , convertAlphaCharacters
  , isAlphaNumber

    -- * AsYouTypeFormatter
  , AsYouTypeFormatter
  , newAsYouTypeFormatter
  , inputDigit
  , currentResult
  , clearFormatter

    -- * PhoneNumberMatcher / findNumbers
  , Leniency (..)
  , Match (..)
  , findNumbers

    -- * ShortNumberInfo (short / emergency numbers)
  , shortIsPossible
  , shortIsValid
  , isEmergencyNumber
  , connectsToEmergencyNumber
  , shortIsCarrierSpecific
  , shortIsSmsService
  , shortExpectedCost
  , shortExpectedCostInt
  , shortExampleNumber

    -- * PhoneNumberToTimeZonesMapper (timezone lookup)
  , timeZonesForNumber
  , timeZoneCount
  , unknownTimeZone

    -- * PhoneNumberToCarrierMapper (English carrier names)
  , carrierNameForNumber
  , carrierNameForValidNumber

    -- * Enumerations
  , NumberType (..)
  , numberTypeInt
  , ValidationResult (..)
  , validationResultFromCInt
  , MatchType (..)
  , matchTypeFromCInt
  , CountryCodeSource (..)
  , countryCodeSourceFromCInt
  , ShortNumberCost (..)
  , shortNumberCostFromCInt

    -- * Introspection
  , abiVersion
  ) where

import qualified Data.ByteString as B
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.List (sort)
import Foreign.C.String (CString)
import Foreign.C.Types (CInt)

import qualified PhoneNumber.Native as N

-- ---------------------------------------------------------------------------
-- Format style (ABI constant — append only, never renumber)
-- ---------------------------------------------------------------------------

-- | A phone-number format style. The 'Enum' derivation is __not__ the wire
-- value — 'formatCInt' is authoritative. As of ABI v2: @E164 = 0@,
-- @International = 1@, @National = 2@, @Rfc3966 = 3@ (E164 moved to @0@).
data Format
  = E164
  | International
  | National
  | Rfc3966
  deriving (Eq, Ord, Show, Enum, Bounded)

formatCInt :: Format -> CInt
formatCInt E164 = 0
formatCInt International = 1
formatCInt National = 2
formatCInt Rfc3966 = 3

-- ---------------------------------------------------------------------------
-- Number type
-- ---------------------------------------------------------------------------

-- | The kind of number 'numberType' reports. @UnknownType@ is the ABI's @-1@,
-- and 'OtherType' stands in for any code a newer engine might introduce that
-- this build has no name for (the ABI is append-only).
data NumberType
  = UnknownType
  | FixedLine
  | Mobile
  | TollFree
  | PremiumRate
  | SharedCost
  | Voip
  | PersonalNumber
  | Pager
  | Uan
  | Voicemail
  | FixedLineOrMobile
  | OtherType CInt
  deriving (Eq, Show)

numberTypeFromCInt :: CInt -> NumberType
numberTypeFromCInt (-1) = UnknownType
numberTypeFromCInt 0 = FixedLine
numberTypeFromCInt 1 = Mobile
numberTypeFromCInt 2 = TollFree
numberTypeFromCInt 3 = PremiumRate
numberTypeFromCInt 4 = SharedCost
numberTypeFromCInt 5 = Voip
numberTypeFromCInt 6 = PersonalNumber
numberTypeFromCInt 7 = Pager
numberTypeFromCInt 8 = Uan
numberTypeFromCInt 9 = Voicemail
numberTypeFromCInt 10 = FixedLineOrMobile
numberTypeFromCInt n = OtherType n

-- ---------------------------------------------------------------------------
-- ValidationResult (is_possible_number_with_reason)
-- ---------------------------------------------------------------------------

-- | The reason 'isPossibleNumberWithReason' reports. Wire values are
-- non-contiguous (@IsPossibleLocalOnly = 4@, @InvalidLength = 5@) — see
-- @docs\/abi.md@ — so 'OtherValidation' guards a future addition.
data ValidationResult
  = IsPossible
  | IsPossibleLocalOnly
  | InvalidCountryCode
  | TooShort
  | InvalidLength
  | TooLong
  | OtherValidation CInt
  deriving (Eq, Show)

validationResultFromCInt :: CInt -> ValidationResult
validationResultFromCInt 0 = IsPossible
validationResultFromCInt 4 = IsPossibleLocalOnly
validationResultFromCInt 1 = InvalidCountryCode
validationResultFromCInt 2 = TooShort
validationResultFromCInt 5 = InvalidLength
validationResultFromCInt 3 = TooLong
validationResultFromCInt n = OtherValidation n

-- ---------------------------------------------------------------------------
-- MatchType (is_number_match)
-- ---------------------------------------------------------------------------

-- | The strength of an 'isNumberMatch' result.
data MatchType
  = NotANumber
  | NoMatch
  | ShortNsnMatch
  | NsnMatch
  | ExactMatch
  | OtherMatch CInt
  deriving (Eq, Show)

matchTypeFromCInt :: CInt -> MatchType
matchTypeFromCInt 0 = NotANumber
matchTypeFromCInt 1 = NoMatch
matchTypeFromCInt 2 = ShortNsnMatch
matchTypeFromCInt 3 = NsnMatch
matchTypeFromCInt 4 = ExactMatch
matchTypeFromCInt n = OtherMatch n

-- ---------------------------------------------------------------------------
-- CountryCodeSource (pn_source)
-- ---------------------------------------------------------------------------

-- | Where the country code on a parsed number came from ('sourceOf'). Wire
-- values are non-contiguous (@1@\/@5@\/@10@\/@20@) — see @docs\/abi.md@.
data CountryCodeSource
  = FromNumberWithPlus
  | FromNumberWithIdd
  | FromNumberWithoutPlus
  | FromDefaultCountry
  | OtherSource CInt
  deriving (Eq, Show)

countryCodeSourceFromCInt :: CInt -> CountryCodeSource
countryCodeSourceFromCInt 1 = FromNumberWithPlus
countryCodeSourceFromCInt 5 = FromNumberWithIdd
countryCodeSourceFromCInt 10 = FromNumberWithoutPlus
countryCodeSourceFromCInt 20 = FromDefaultCountry
countryCodeSourceFromCInt n = OtherSource n

-- ---------------------------------------------------------------------------
-- Matcher leniency
-- ---------------------------------------------------------------------------

-- | How strict 'findNumbers' is. The 'Enum' values ARE the ABI's leniency
-- selector: @Possible = 0@, @Valid = 1@.
data Leniency
  = Possible
  | Valid
  deriving (Eq, Ord, Show, Enum, Bounded)

leniencyCInt :: Leniency -> CInt
leniencyCInt Possible = 0
leniencyCInt Valid = 1

-- ---------------------------------------------------------------------------
-- ShortNumberCost (short_expected_cost)
-- ---------------------------------------------------------------------------

-- | The expected cost of dialling a short number, as reported by
-- 'shortExpectedCost'. Wire values: @TollFreeCost = 0@, @StandardRateCost = 1@,
-- @PremiumRateCost = 2@, @UnknownCost = 3@. 'OtherCost' guards a future
-- addition (the ABI is append-only).
data ShortNumberCost
  = TollFreeCost
  | StandardRateCost
  | PremiumRateCost
  | UnknownCost
  | OtherCost CInt
  deriving (Eq, Show)

shortNumberCostFromCInt :: CInt -> ShortNumberCost
shortNumberCostFromCInt 0 = TollFreeCost
shortNumberCostFromCInt 1 = StandardRateCost
shortNumberCostFromCInt 2 = PremiumRateCost
shortNumberCostFromCInt 3 = UnknownCost
shortNumberCostFromCInt n = OtherCost n

-- ---------------------------------------------------------------------------
-- Small marshalling helpers (private) — keep the surface below terse.
-- ---------------------------------------------------------------------------

-- | Marshal a one-string-arg call that returns a string.
str1 :: (CString -> IO CString) -> B.ByteString -> IO B.ByteString
str1 fn a = N.withUtf8 a $ \x -> N.takeString =<< fn x

-- | Marshal a two-string-arg call that returns a string.
str2 :: (CString -> CString -> IO CString) -> B.ByteString -> B.ByteString -> IO B.ByteString
str2 fn a b =
  N.withUtf8 a $ \x -> N.withUtf8 b $ \y -> N.takeString =<< fn x y

-- | Marshal a one-string-arg call that returns a 'CInt'.
int1 :: (CString -> IO CInt) -> B.ByteString -> IO CInt
int1 fn a = N.withUtf8 a fn

-- | Marshal a two-string-arg call that returns a 'CInt'.
int2 :: (CString -> CString -> IO CInt) -> B.ByteString -> B.ByteString -> IO CInt
int2 fn a b = N.withUtf8 a $ \x -> N.withUtf8 b (fn x)

-- ---------------------------------------------------------------------------
-- Metadata
-- ---------------------------------------------------------------------------

-- | The country calling code for a region (@\"1\"@, @\"44\"@, …), or @\"\"@
-- if unknown.
countryCode :: B.ByteString -> IO B.ByteString
countryCode = str1 N.aether_pn_embed_country_code

-- | An example national number for the region, or @\"\"@.
exampleNumber :: B.ByteString -> IO B.ByteString
exampleNumber = str1 N.aether_pn_embed_example_number

-- | An example number of the given 'NumberType' for the region, or @\"\"@.
exampleNumberForType :: B.ByteString -> NumberType -> IO B.ByteString
exampleNumberForType region ntype =
  N.withUtf8 region $ \r ->
    N.takeString =<< N.aether_pn_embed_example_number_for_type r (numberTypeToCInt ntype)

-- | An example number that is the right length but is __not__ a valid number
-- for the region, or @\"\"@.
invalidExampleNumber :: B.ByteString -> IO B.ByteString
invalidExampleNumber = str1 N.aether_pn_embed_invalid_example_number

-- | The possible-lengths spec for the region (e.g. @\"9,10\"@), or @\"\"@.
possibleLengths :: B.ByteString -> IO B.ByteString
possibleLengths = str1 N.aether_pn_embed_possible_lengths

-- | The main region for a country calling code (@\"44\" -> \"GB\"@), or @\"\"@.
regionCodeForCountryCode :: B.ByteString -> IO B.ByteString
regionCodeForCountryCode = str1 N.aether_pn_embed_region_code_for_country_code

-- | True if the region participates in the North American Numbering Plan.
isNanpaCountry :: B.ByteString -> IO Bool
isNanpaCountry region = (/= 0) <$> int1 N.aether_pn_embed_is_nanpa_country region

-- | The national-direct-dialling prefix for a region (e.g. @\"0\"@), optionally
-- with formatting symbols stripped, or @\"\"@.
nddPrefixForRegion :: B.ByteString -> Bool -> IO B.ByteString
nddPrefixForRegion region stripNonDigits =
  N.withUtf8 region $ \r ->
    N.takeString =<< N.aether_pn_embed_ndd_prefix_for_region r (if stripNonDigits then 1 else 0)

-- ---------------------------------------------------------------------------
-- Regions
-- ---------------------------------------------------------------------------

-- | How many region ids the metadata carries.
regionCount :: IO Int
regionCount = fromIntegral <$> N.aether_pn_embed_region_count

-- | The region id at an index (0-based, the engine's own order), or @\"\"@
-- when out of range.
regionAt :: Int -> IO B.ByteString
regionAt i = N.takeString =<< N.aether_pn_embed_region_at (fromIntegral i)

-- | Every region id the metadata carries, in the engine's own order.
regions :: IO [B.ByteString]
regions = do
  n <- regionCount
  mapM regionAt [0 .. n - 1]

-- | 'regions', sorted. Use this when you want determinism.
sortedRegions :: IO [B.ByteString]
sortedRegions = sort <$> regions

-- | Every region id that shares a country calling code, in the engine's order
-- (the main region first).
regionsForCountryCode :: B.ByteString -> IO [B.ByteString]
regionsForCountryCode cc =
  N.withUtf8 cc $ \c -> do
    n <- N.aether_pn_embed_cc_region_count c
    mapM (\i -> N.takeString =<< N.aether_pn_embed_cc_region_at c (fromIntegral i))
         [0 .. fromIntegral n - 1 :: Int]

-- ---------------------------------------------------------------------------
-- Parse + parsed number
-- ---------------------------------------------------------------------------

-- | A parsed phone number. Wraps the caller-owned parsed-number string the ABI
-- returns from 'parse'; its fields are read on demand through the @pn_*@
-- accessors. Because the underlying string is a plain 'B.ByteString' copied out
-- of the engine, a 'ParsedNumber' is immutable and can be read as many times as
-- you like.
newtype ParsedNumber = ParsedNumber B.ByteString

-- | Parse a raw human-typed number in the context of a default region. The
-- result is always a 'ParsedNumber'; inspect 'errorOf' to tell a failed parse
-- (non-empty error) from a good one.
parse :: B.ByteString -> B.ByteString -> IO ParsedNumber
parse input region = ParsedNumber <$> str2 N.aether_pn_embed_parse input region

-- | The national significant number extracted from raw input for a region
-- (country code + punctuation stripped) — the one-shot form that does not need
-- a 'ParsedNumber'.
nationalNumber :: B.ByteString -> B.ByteString -> IO B.ByteString
nationalNumber region input = str2 N.aether_pn_embed_national_number region input

pnStr :: (CString -> IO CString) -> ParsedNumber -> IO B.ByteString
pnStr fn (ParsedNumber pn) = str1 fn pn

pnInt :: (CString -> IO CInt) -> ParsedNumber -> IO CInt
pnInt fn (ParsedNumber pn) = int1 fn pn

-- | The region code stored on the parsed number, or @\"\"@.
regionOf :: ParsedNumber -> IO B.ByteString
regionOf = pnStr N.aether_pn_embed_pn_region

-- | The country calling code of the parsed number (@\"1\"@, @\"44\"@, …).
countryCodeOf :: ParsedNumber -> IO B.ByteString
countryCodeOf = pnStr N.aether_pn_embed_pn_country_code

-- | The national number of the parsed number.
nationalNumberOf :: ParsedNumber -> IO B.ByteString
nationalNumberOf = pnStr N.aether_pn_embed_pn_national_number

-- | The extension of the parsed number, or @\"\"@.
extensionOf :: ParsedNumber -> IO B.ByteString
extensionOf = pnStr N.aether_pn_embed_pn_extension

-- | Whether the number carries an Italian-style leading zero.
italianLeadingZeroOf :: ParsedNumber -> IO Bool
italianLeadingZeroOf pn = (/= 0) <$> pnInt N.aether_pn_embed_pn_italian_leading_zero pn

-- | Where the country code came from (a 'CountryCodeSource').
sourceOf :: ParsedNumber -> IO CountryCodeSource
sourceOf pn = countryCodeSourceFromCInt <$> pnInt N.aether_pn_embed_pn_source pn

-- | The parse error, or @\"\"@ if the parse succeeded.
errorOf :: ParsedNumber -> IO B.ByteString
errorOf = pnStr N.aether_pn_embed_pn_error

-- | The region the parsed number belongs to (@\"US\"@, @\"GB\"@, …), or @\"\"@.
regionCodeOf :: ParsedNumber -> IO B.ByteString
regionCodeOf = pnStr N.aether_pn_embed_region_code_for_number

-- | The national significant number of the parsed number.
nationalSignificantNumberOf :: ParsedNumber -> IO B.ByteString
nationalSignificantNumberOf = pnStr N.aether_pn_embed_national_significant_number

-- | The length of the national destination code, or @0@.
lengthOfNdc :: ParsedNumber -> IO Int
lengthOfNdc pn = fromIntegral <$> pnInt N.aether_pn_embed_length_of_ndc pn

-- | The length of the area code, or @0@.
lengthOfAreaCode :: ParsedNumber -> IO Int
lengthOfAreaCode pn = fromIntegral <$> pnInt N.aether_pn_embed_length_of_area_code pn

-- | Whether the parsed number is geographical.
isGeographical :: ParsedNumber -> IO Bool
isGeographical pn = (/= 0) <$> pnInt N.aether_pn_embed_is_geographical pn

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

-- | True if the national number is a length the region allows.
isPossibleNumber :: B.ByteString -> B.ByteString -> IO Bool
isPossibleNumber region input = (/= 0) <$> int2 N.aether_pn_embed_is_possible_number region input

-- | The reason the number is or is not possible (a 'ValidationResult').
isPossibleNumberWithReason :: B.ByteString -> B.ByteString -> IO ValidationResult
isPossibleNumberWithReason region input =
  validationResultFromCInt <$> int2 N.aether_pn_embed_is_possible_number_with_reason region input

-- | True if the number matches the region's national-number patterns.
isValidNumber :: B.ByteString -> B.ByteString -> IO Bool
isValidNumber region input = (/= 0) <$> int2 N.aether_pn_embed_is_valid_number region input

-- | True if the number is valid __for the given region__. Note the argument
-- order mirrors the ABI: @(number, region)@.
isValidNumberForRegion :: B.ByteString -> B.ByteString -> IO Bool
isValidNumberForRegion input region =
  (/= 0) <$> int2 N.aether_pn_embed_is_valid_number_for_region input region

-- | The kind of number (a 'NumberType'; 'UnknownType' for unknown).
numberType :: B.ByteString -> B.ByteString -> IO NumberType
numberType region input = numberTypeFromCInt <$> int2 N.aether_pn_embed_number_type region input

-- | The raw ABI number-type int (@-1@ for unknown), for a caller who wants the
-- wire value rather than the 'NumberType'.
numberTypeInt :: B.ByteString -> B.ByteString -> IO Int
numberTypeInt region input = fromIntegral <$> int2 N.aether_pn_embed_number_type region input

-- | True if the number can be dialled from outside its country.
canBeInternationallyDialled :: B.ByteString -> B.ByteString -> IO Bool
canBeInternationallyDialled region input =
  (/= 0) <$> int2 N.aether_pn_embed_can_be_internationally_dialled region input

-- ---------------------------------------------------------------------------
-- Format
-- ---------------------------------------------------------------------------

-- | Format the number in the given style.
format :: B.ByteString -> B.ByteString -> Format -> IO B.ByteString
format region input style =
  N.withUtf8 region $ \r ->
    N.withUtf8 input $ \i ->
      N.takeString =<< N.aether_pn_embed_format r i (formatCInt style)

formatNational :: B.ByteString -> B.ByteString -> IO B.ByteString
formatNational region input = format region input National

formatInternational :: B.ByteString -> B.ByteString -> IO B.ByteString
formatInternational region input = format region input International

formatE164 :: B.ByteString -> B.ByteString -> IO B.ByteString
formatE164 region input = format region input E164

formatRfc3966 :: B.ByteString -> B.ByteString -> IO B.ByteString
formatRfc3966 region input = format region input Rfc3966

-- | Format a number for dialling from another country
-- (@region@, @input@, @callingFrom@).
formatOutOfCountry :: B.ByteString -> B.ByteString -> B.ByteString -> IO B.ByteString
formatOutOfCountry region input callingFrom =
  N.withUtf8 region $ \r ->
    N.withUtf8 input $ \i ->
      N.withUtf8 callingFrom $ \c ->
        N.takeString =<< N.aether_pn_embed_format_out_of_country r i c

-- | Format a parsed number in its original dialling form, as if dialled from
-- @callingFrom@.
formatInOriginal :: ParsedNumber -> B.ByteString -> IO B.ByteString
formatInOriginal (ParsedNumber pn) callingFrom =
  N.withUtf8 pn $ \p ->
    N.withUtf8 callingFrom $ \c ->
      N.takeString =<< N.aether_pn_embed_format_in_original p c

-- ---------------------------------------------------------------------------
-- Relations / helpers
-- ---------------------------------------------------------------------------

-- | How strongly two numbers match (a 'MatchType').
isNumberMatch :: B.ByteString -> B.ByteString -> IO MatchType
isNumberMatch a b = matchTypeFromCInt <$> int2 N.aether_pn_embed_is_number_match a b

-- | Truncate a too-long number to the region's longest valid length, or @\"\"@
-- if it cannot be made valid.
truncateTooLong :: B.ByteString -> B.ByteString -> IO B.ByteString
truncateTooLong region input = str2 N.aether_pn_embed_truncate_too_long region input

-- | Strip everything but digits (and a leading @+@ is dropped — see the ABI).
normalizeDigitsOnly :: B.ByteString -> IO B.ByteString
normalizeDigitsOnly = str1 N.aether_pn_embed_normalize_digits_only

-- | Convert vanity letters to their dial-pad digits, leaving punctuation.
convertAlphaCharacters :: B.ByteString -> IO B.ByteString
convertAlphaCharacters = str1 N.aether_pn_embed_convert_alpha_characters

-- | True if the input contains vanity letters.
isAlphaNumber :: B.ByteString -> IO Bool
isAlphaNumber s = (/= 0) <$> int1 N.aether_pn_embed_is_alpha_number s

-- ---------------------------------------------------------------------------
-- AsYouTypeFormatter
-- ---------------------------------------------------------------------------

-- | Formats a number as it is typed, digit by digit. The ABI threads the
-- formatter state as a caller-owned string; this wrapper keeps that string in
-- an 'IORef', replacing it (and letting 'N.takeString' free the old one) on
-- every 'inputDigit' and 'clearFormatter'.
newtype AsYouTypeFormatter = AsYouTypeFormatter (IORef B.ByteString)

-- | A fresh formatter for the given default region.
newAsYouTypeFormatter :: B.ByteString -> IO AsYouTypeFormatter
newAsYouTypeFormatter region = do
  st <- str1 N.aether_pn_embed_ayt_new region
  AsYouTypeFormatter <$> newIORef st

-- | Feed one character; returns the formatted-so-far string.
inputDigit :: AsYouTypeFormatter -> B.ByteString -> IO B.ByteString
inputDigit (AsYouTypeFormatter ref) ch = do
  st <- readIORef ref
  st' <- str2 N.aether_pn_embed_ayt_input st ch
  writeIORef ref st'
  N.withUtf8 st' $ \s -> N.takeString =<< N.aether_pn_embed_ayt_result s

-- | The formatted-so-far string, without feeding anything.
currentResult :: AsYouTypeFormatter -> IO B.ByteString
currentResult (AsYouTypeFormatter ref) = do
  st <- readIORef ref
  N.withUtf8 st $ \s -> N.takeString =<< N.aether_pn_embed_ayt_result s

-- | Reset the formatter to empty.
clearFormatter :: AsYouTypeFormatter -> IO ()
clearFormatter (AsYouTypeFormatter ref) = do
  st <- readIORef ref
  st' <- str1 N.aether_pn_embed_ayt_clear st
  writeIORef ref st'

-- ---------------------------------------------------------------------------
-- PhoneNumberMatcher / findNumbers
-- ---------------------------------------------------------------------------

-- | One number found in free text: its byte offsets @[start, end)@ and the raw
-- matched substring.
data Match = Match
  { matchStart :: Int
  , matchEnd :: Int
  , matchRaw :: B.ByteString
  }
  deriving (Eq, Show)

-- | Find phone numbers in free text. Returns a 'Match' per number found, in
-- order. Free every returned string — 'N.takeString' does.
findNumbers :: B.ByteString -> B.ByteString -> Leniency -> IO [Match]
findNumbers text region leniency =
  N.withUtf8 text $ \t ->
    N.withUtf8 region $ \r -> do
      let ln = leniencyCInt leniency
      n <- N.aether_pn_embed_matcher_count t r ln
      mapM (one t r ln) [0 .. fromIntegral n - 1 :: Int]
  where
    one t r ln i = do
      let ci = fromIntegral i :: CInt
      s <- N.aether_pn_embed_matcher_start t r ln ci
      e <- N.aether_pn_embed_matcher_end t r ln ci
      raw <- N.takeString =<< N.aether_pn_embed_matcher_raw t r ln ci
      pure (Match (fromIntegral s) (fromIntegral e) raw)

-- ---------------------------------------------------------------------------
-- ShortNumberInfo (short / emergency numbers)
-- ---------------------------------------------------------------------------
--
-- Short numbers are dialled as-is — no country code, no national prefix — so
-- the input is the raw short number plus a region. Pure marshalling, like the
-- rest.

-- | True if @input@ is a possible short number for the region (right length).
shortIsPossible :: B.ByteString -> B.ByteString -> IO Bool
shortIsPossible region input = (/= 0) <$> int2 N.aether_pn_embed_short_is_possible region input

-- | True if @input@ matches a short-number pattern for the region.
shortIsValid :: B.ByteString -> B.ByteString -> IO Bool
shortIsValid region input = (/= 0) <$> int2 N.aether_pn_embed_short_is_valid region input

-- | True if @input@ is an emergency number for the region (e.g. US @\"911\"@).
isEmergencyNumber :: B.ByteString -> B.ByteString -> IO Bool
isEmergencyNumber region input = (/= 0) <$> int2 N.aether_pn_embed_short_is_emergency region input

-- | True if dialling @input@ connects to an emergency number for the region.
connectsToEmergencyNumber :: B.ByteString -> B.ByteString -> IO Bool
connectsToEmergencyNumber region input =
  (/= 0) <$> int2 N.aether_pn_embed_short_connects_to_emergency region input

-- | True if the short number is specific to a single carrier.
shortIsCarrierSpecific :: B.ByteString -> B.ByteString -> IO Bool
shortIsCarrierSpecific region input =
  (/= 0) <$> int2 N.aether_pn_embed_short_is_carrier_specific region input

-- | True if the short number is usable as an SMS service.
shortIsSmsService :: B.ByteString -> B.ByteString -> IO Bool
shortIsSmsService region input =
  (/= 0) <$> int2 N.aether_pn_embed_short_is_sms_service region input

-- | The expected cost of dialling the short number (a 'ShortNumberCost').
shortExpectedCost :: B.ByteString -> B.ByteString -> IO ShortNumberCost
shortExpectedCost region input =
  shortNumberCostFromCInt <$> int2 N.aether_pn_embed_short_expected_cost region input

-- | The raw ABI cost int (@0@ toll-free, @1@ standard, @2@ premium, @3@
-- unknown), for a caller who wants the wire value rather than the
-- 'ShortNumberCost'.
shortExpectedCostInt :: B.ByteString -> B.ByteString -> IO Int
shortExpectedCostInt region input =
  fromIntegral <$> int2 N.aether_pn_embed_short_expected_cost region input

-- | An example short number for the region, or @\"\"@.
shortExampleNumber :: B.ByteString -> IO B.ByteString
shortExampleNumber = str1 N.aether_pn_embed_short_example_number

-- ---------------------------------------------------------------------------
-- PhoneNumberToTimeZonesMapper (timezone lookup)
-- ---------------------------------------------------------------------------
--
-- Longest-prefix match over the number's E.164 digits. Pass a raw
-- @(region, input)@ like everywhere else; the engine parses to E.164 itself.
-- The unknown-zone sentinel is @\"Etc/Unknown\"@.

-- | The IANA timezone ids for a number, as a list. A number with no known
-- zones maps to a single-element list holding the unknown zone
-- (@[\"Etc/Unknown\"]@), never the empty list — matching the other bindings.
timeZonesForNumber :: B.ByteString -> B.ByteString -> IO [B.ByteString]
timeZonesForNumber region input =
  N.withUtf8 region $ \r ->
    N.withUtf8 input $ \i -> do
      n <- N.aether_pn_embed_tz_count r i
      if n == 0
        then (: []) <$> unknownTimeZone
        else mapM (\idx -> N.takeString =<< N.aether_pn_embed_tz_at r i (fromIntegral idx))
                  [0 .. fromIntegral n - 1 :: Int]

-- | How many timezones the number maps to (@0@ means only the unknown zone).
timeZoneCount :: B.ByteString -> B.ByteString -> IO Int
timeZoneCount region input = fromIntegral <$> int2 N.aether_pn_embed_tz_count region input

-- | The unknown-timezone sentinel, @\"Etc/Unknown\"@.
unknownTimeZone :: IO B.ByteString
unknownTimeZone = N.takeString =<< N.aether_pn_embed_tz_unknown

-- ---------------------------------------------------------------------------
-- PhoneNumberToCarrierMapper (English carrier names)
-- ---------------------------------------------------------------------------
--
-- Longest-prefix match over the E.164 digits; English names only. @\"\"@ when
-- no carrier is known for the number.

-- | The carrier name for a number (English), or @\"\"@ if none is known.
carrierNameForNumber :: B.ByteString -> B.ByteString -> IO B.ByteString
carrierNameForNumber region input = str2 N.aether_pn_embed_carrier_name region input

-- | The carrier name only when the number is valid, else @\"\"@.
carrierNameForValidNumber :: B.ByteString -> B.ByteString -> IO B.ByteString
carrierNameForValidNumber region input = str2 N.aether_pn_embed_carrier_name_for_valid region input

-- ---------------------------------------------------------------------------
-- Introspection
-- ---------------------------------------------------------------------------

-- | The engine's ABI revision (@5@ for this binding — adds ShortNumberInfo,
-- the TimeZones mapper and the Carrier mapper).
abiVersion :: IO Int
abiVersion = fromIntegral <$> N.aether_pn_embed_abi_version

-- ---------------------------------------------------------------------------
-- Private: NumberType -> wire int (for example_number_for_type)
-- ---------------------------------------------------------------------------

numberTypeToCInt :: NumberType -> CInt
numberTypeToCInt UnknownType = -1
numberTypeToCInt FixedLine = 0
numberTypeToCInt Mobile = 1
numberTypeToCInt TollFree = 2
numberTypeToCInt PremiumRate = 3
numberTypeToCInt SharedCost = 4
numberTypeToCInt Voip = 5
numberTypeToCInt PersonalNumber = 6
numberTypeToCInt Pager = 7
numberTypeToCInt Uan = 8
numberTypeToCInt Voicemail = 9
numberTypeToCInt FixedLineOrMobile = 10
numberTypeToCInt (OtherType n) = n
