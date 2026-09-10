{-# LANGUAGE ForeignFunctionInterface #-}

-- |
-- Module      : PhoneNumber.Native
-- Description : The 1:1 symbol table for the phonenumber C ABI (v2).
--
-- This module is the ONLY place in the Haskell binding that knows about the C
-- ABI. Every symbol the engine exports appears here once, with the exact C
-- signature, in the order @core\/embed.ae@ declares it. No phone-number logic
-- lives here or anywhere else in this package — the engine is
-- @core\/phonenumber.ae@, compiled to @libphonenumber_ae.so@.
--
-- == ABI v2
--
-- The ABI is now __full @PhoneNumberUtil@ parity__ — 50 symbols, ABI version
-- @2@. Signatures remain scalar-only (@const char*@ and @int@), so nothing here
-- re-enters the Haskell RTS and every import is still @unsafe@. Two symbols are
-- __stateful in disguise__: 'aether_pn_embed_parse' returns a caller-owned
-- parsed-number __string__, and the @ayt_*@ formatter threads its state as a
-- caller-owned __string__. There is still no opaque handle and no callback — a
-- parsed number and an AsYouType state are ordinary returned strings you free
-- like any other.
--
-- == Naming
--
-- @core\/embed.ae@ names its exports @pn_embed_\<name\>@; building with
-- @--emit=lib@ mangles them to __@aether_pn_embed_\<name\>@__. That mangled
-- name is what we link against.
--
-- == The one ownership rule
--
-- __Every @CString@ this ABI returns is caller-owned__ and must be handed back
-- to 'aether_pn_embed_free_string'. Leaking it is the single most common bug in
-- a binding, so this package routes every returned string through exactly one
-- helper, 'takeString'.
module PhoneNumber.Native
  ( -- * Lifecycle / introspection
    aether_pn_embed_abi_version
  , aether_pn_embed_free_string

    -- * Metadata
  , aether_pn_embed_country_code
  , aether_pn_embed_example_number
  , aether_pn_embed_example_number_for_type
  , aether_pn_embed_invalid_example_number
  , aether_pn_embed_possible_lengths
  , aether_pn_embed_region_code_for_country_code
  , aether_pn_embed_is_nanpa_country
  , aether_pn_embed_ndd_prefix_for_region
  , aether_pn_embed_region_count
  , aether_pn_embed_region_at
  , aether_pn_embed_cc_region_count
  , aether_pn_embed_cc_region_at

    -- * Parse + parsed-number accessors
  , aether_pn_embed_parse
  , aether_pn_embed_national_number
  , aether_pn_embed_pn_region
  , aether_pn_embed_pn_country_code
  , aether_pn_embed_pn_national_number
  , aether_pn_embed_pn_extension
  , aether_pn_embed_pn_italian_leading_zero
  , aether_pn_embed_pn_source
  , aether_pn_embed_pn_error
  , aether_pn_embed_region_code_for_number
  , aether_pn_embed_national_significant_number
  , aether_pn_embed_length_of_ndc
  , aether_pn_embed_length_of_area_code
  , aether_pn_embed_is_geographical

    -- * Validation
  , aether_pn_embed_is_possible_number
  , aether_pn_embed_is_possible_number_with_reason
  , aether_pn_embed_is_valid_number
  , aether_pn_embed_is_valid_number_for_region
  , aether_pn_embed_number_type
  , aether_pn_embed_can_be_internationally_dialled

    -- * Formatting
  , aether_pn_embed_format
  , aether_pn_embed_format_out_of_country
  , aether_pn_embed_format_in_original

    -- * Relations / helpers
  , aether_pn_embed_is_number_match
  , aether_pn_embed_truncate_too_long
  , aether_pn_embed_normalize_digits_only
  , aether_pn_embed_convert_alpha_characters
  , aether_pn_embed_is_alpha_number

    -- * AsYouTypeFormatter (state threaded as a caller-owned string)
  , aether_pn_embed_ayt_new
  , aether_pn_embed_ayt_input
  , aether_pn_embed_ayt_result
  , aether_pn_embed_ayt_clear

    -- * PhoneNumberMatcher / findNumbers
  , aether_pn_embed_matcher_count
  , aether_pn_embed_matcher_start
  , aether_pn_embed_matcher_end
  , aether_pn_embed_matcher_raw

    -- * String marshalling helpers
  , takeString
  , withUtf8
  ) where

import qualified Data.ByteString as B
import Foreign.C.String (CString)
import Foreign.C.Types (CInt (..))
import Foreign.Ptr (nullPtr)

-- ---------------------------------------------------------------------------
-- The symbol table. Order mirrors core/embed.ae so the two can be diffed by
-- eye. Every integer is 'CInt' (the ABI is C @int@, not @long@); every
-- returned string is a caller-owned 'CString'.
-- ---------------------------------------------------------------------------

-- Lifecycle / introspection ------------------------------------------------

foreign import ccall unsafe "aether_pn_embed_abi_version"
  aether_pn_embed_abi_version :: IO CInt

foreign import ccall unsafe "aether_pn_embed_free_string"
  aether_pn_embed_free_string :: CString -> IO ()

-- Metadata -----------------------------------------------------------------

foreign import ccall unsafe "aether_pn_embed_country_code"
  aether_pn_embed_country_code :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_example_number"
  aether_pn_embed_example_number :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_example_number_for_type"
  aether_pn_embed_example_number_for_type :: CString -> CInt -> IO CString

foreign import ccall unsafe "aether_pn_embed_invalid_example_number"
  aether_pn_embed_invalid_example_number :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_possible_lengths"
  aether_pn_embed_possible_lengths :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_region_code_for_country_code"
  aether_pn_embed_region_code_for_country_code :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_is_nanpa_country"
  aether_pn_embed_is_nanpa_country :: CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_ndd_prefix_for_region"
  aether_pn_embed_ndd_prefix_for_region :: CString -> CInt -> IO CString

foreign import ccall unsafe "aether_pn_embed_region_count"
  aether_pn_embed_region_count :: IO CInt

foreign import ccall unsafe "aether_pn_embed_region_at"
  aether_pn_embed_region_at :: CInt -> IO CString

foreign import ccall unsafe "aether_pn_embed_cc_region_count"
  aether_pn_embed_cc_region_count :: CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_cc_region_at"
  aether_pn_embed_cc_region_at :: CString -> CInt -> IO CString

-- Parse + parsed-number accessors ------------------------------------------

foreign import ccall unsafe "aether_pn_embed_parse"
  aether_pn_embed_parse :: CString -> CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_national_number"
  aether_pn_embed_national_number :: CString -> CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_pn_region"
  aether_pn_embed_pn_region :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_pn_country_code"
  aether_pn_embed_pn_country_code :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_pn_national_number"
  aether_pn_embed_pn_national_number :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_pn_extension"
  aether_pn_embed_pn_extension :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_pn_italian_leading_zero"
  aether_pn_embed_pn_italian_leading_zero :: CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_pn_source"
  aether_pn_embed_pn_source :: CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_pn_error"
  aether_pn_embed_pn_error :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_region_code_for_number"
  aether_pn_embed_region_code_for_number :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_national_significant_number"
  aether_pn_embed_national_significant_number :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_length_of_ndc"
  aether_pn_embed_length_of_ndc :: CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_length_of_area_code"
  aether_pn_embed_length_of_area_code :: CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_is_geographical"
  aether_pn_embed_is_geographical :: CString -> IO CInt

-- Validation ---------------------------------------------------------------

foreign import ccall unsafe "aether_pn_embed_is_possible_number"
  aether_pn_embed_is_possible_number :: CString -> CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_is_possible_number_with_reason"
  aether_pn_embed_is_possible_number_with_reason :: CString -> CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_is_valid_number"
  aether_pn_embed_is_valid_number :: CString -> CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_is_valid_number_for_region"
  aether_pn_embed_is_valid_number_for_region :: CString -> CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_number_type"
  aether_pn_embed_number_type :: CString -> CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_can_be_internationally_dialled"
  aether_pn_embed_can_be_internationally_dialled :: CString -> CString -> IO CInt

-- Formatting ---------------------------------------------------------------

foreign import ccall unsafe "aether_pn_embed_format"
  aether_pn_embed_format :: CString -> CString -> CInt -> IO CString

foreign import ccall unsafe "aether_pn_embed_format_out_of_country"
  aether_pn_embed_format_out_of_country :: CString -> CString -> CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_format_in_original"
  aether_pn_embed_format_in_original :: CString -> CString -> IO CString

-- Relations / helpers ------------------------------------------------------

foreign import ccall unsafe "aether_pn_embed_is_number_match"
  aether_pn_embed_is_number_match :: CString -> CString -> IO CInt

foreign import ccall unsafe "aether_pn_embed_truncate_too_long"
  aether_pn_embed_truncate_too_long :: CString -> CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_normalize_digits_only"
  aether_pn_embed_normalize_digits_only :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_convert_alpha_characters"
  aether_pn_embed_convert_alpha_characters :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_is_alpha_number"
  aether_pn_embed_is_alpha_number :: CString -> IO CInt

-- AsYouTypeFormatter -------------------------------------------------------

foreign import ccall unsafe "aether_pn_embed_ayt_new"
  aether_pn_embed_ayt_new :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_ayt_input"
  aether_pn_embed_ayt_input :: CString -> CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_ayt_result"
  aether_pn_embed_ayt_result :: CString -> IO CString

foreign import ccall unsafe "aether_pn_embed_ayt_clear"
  aether_pn_embed_ayt_clear :: CString -> IO CString

-- PhoneNumberMatcher / findNumbers -----------------------------------------

foreign import ccall unsafe "aether_pn_embed_matcher_count"
  aether_pn_embed_matcher_count :: CString -> CString -> CInt -> IO CInt

foreign import ccall unsafe "aether_pn_embed_matcher_start"
  aether_pn_embed_matcher_start :: CString -> CString -> CInt -> CInt -> IO CInt

foreign import ccall unsafe "aether_pn_embed_matcher_end"
  aether_pn_embed_matcher_end :: CString -> CString -> CInt -> CInt -> IO CInt

foreign import ccall unsafe "aether_pn_embed_matcher_raw"
  aether_pn_embed_matcher_raw :: CString -> CString -> CInt -> CInt -> IO CString

-- ---------------------------------------------------------------------------
-- String marshalling
-- ---------------------------------------------------------------------------

-- | Copy an ABI-returned string out and free it through the ABI.
--
-- __This is the only place a returned @CString@ is consumed.__ The one rule of
-- this ABI is that every @char*@ out of the engine is caller-owned; funnelling
-- them all through one function is what makes that auditable. A null pointer
-- (which the ABI does not currently produce) yields @\"\"@ rather than a
-- segfault.
--
-- The result is a 'B.ByteString' of the raw UTF-8 bytes. This binding does not
-- decode to 'String'\/'Data.Text.Text': the engine speaks UTF-8 bytes, so
-- handing bytes back is both lossless and dependency-free.
takeString :: CString -> IO B.ByteString
takeString p
  | p == nullPtr = pure B.empty
  | otherwise = do
      -- packCString COPIES up to the NUL, so the ByteString stays valid after
      -- the free below. (unsafePackCString would alias the buffer we are about
      -- to hand back to the engine — a use-after-free.)
      bs <- B.packCString p
      aether_pn_embed_free_string p
      pure bs

-- | Run an action with a NUL-terminated copy of a 'B.ByteString'.
--
-- 'B.useAsCString' copies and appends the NUL, which is what a @const char*@
-- parameter requires (a slice of a larger ByteString is not NUL-terminated of
-- its own accord). An interior NUL truncates on the C side — the same
-- behaviour every other binding in this monorepo settles on for a value that
-- has already been accepted as a byte string.
withUtf8 :: B.ByteString -> (CString -> IO a) -> IO a
withUtf8 = B.useAsCString
