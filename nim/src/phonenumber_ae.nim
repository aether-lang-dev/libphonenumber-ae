## phonenumber_ae — the Nim binding over the monorepo's one shared native engine.
##
## Validate, parse and format international phone numbers.
##
## There is **no phone-number logic in this file**, and there must never be any.
## The metadata table, isPossible/isValid, number-type, the parser, the
## AsYouTypeFormatter and the matcher all live in `core/phonenumber.ae`; the flat
## C ABI over it is `core/embed.ae`, whose exports `--emit=lib` mangles to
## `aether_pn_embed_<name>`. Everything below is marshalling: Nim values in, C
## scalars and `cstring`s out, and back.
##
## ABI v7 (full `PhoneNumberUtil` parity, plus the ShortNumberInfo, TimeZones,
## Carrier and Geocoder surfaces; the Carrier and Geocoder calls take a per-call
## `lang` ISO code). The
## ABI has **no opaque handle**: a
## parsed number and an AsYouType state are themselves caller-owned *strings* —
## you get one back, pass it to accessor calls, and free it like any other
## returned string. Every call is independent.
##
## Why `importc` + a real link, rather than `dynlib`/dlopen
## ========================================================
##
## Several bindings in this repo (Python/ctypes, Ruby/Fiddle, Rust/libloading)
## resolve the engine at run time so they can report a friendly error when it is
## missing. Nim is a compiled, statically-linked-by-default language, and the
## house style for that family (Go/cgo, Zig) is to LINK. So we do: `{.passL.}`
## below points the linker at `nim/native` and `../core/native`, and bakes both
## in as `rpath` so an in-tree binary finds the `.so` with no `LD_LIBRARY_PATH`.
## `nim/.tests.ae` stages the engine artifact into `nim/native/` before
## compiling, exactly as `go/.tests.ae` does for cgo, so the link and the rpath
## resolve wherever `aeb` put it.
##
## The consequence to be aware of: the engine must exist at BUILD time, not just
## at run time. A missing `.so` is a link error, not a nice exception.
##
## The one ownership rule
## ======================
##
## **Every `cstring` this ABI returns is caller-owned.** It was malloc'd on the
## C side and must be handed back to `aether_pn_embed_free_string`. Nim will not
## do this for you: assigning a `cstring` to a `string` *copies*, it does not
## adopt, so a forgotten free is a silent leak. This is the single most common
## bug in a binding of this ABI, so exactly one proc — `takeString` — is allowed
## to touch a returned pointer, and it always frees. Grep this file: there is no
## other call to `free_string`, and no returned pointer escapes `takeString`.
##
## The `int`-not-`cint` trap
## =========================
##
## Nim's `int` is pointer-sized (64-bit here) — it is C `long`, not C `int`. The
## ABI is `int` throughout, so every ABI proc below uses `cint` explicitly. Do
## not "simplify" one of them to `int`.

import std/[algorithm, os]

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------
#
# Search nim/native first (where .tests.ae stages the artifact), then the
# in-tree core/native, and bake both in as rpath so the produced binary is
# runnable straight out of the build directory. `currentSourcePath` keeps this
# correct no matter what directory the compiler was invoked from.

const
  srcDir = currentSourcePath().parentDir()
  nativeDir = srcDir & "/../native"
  coreNativeDir = srcDir & "/../../core/native"

{.passL: "-L" & nativeDir & " -L" & coreNativeDir & " -lphonenumber_ae" &
         " -Wl,-rpath," & nativeDir & " -Wl,-rpath," & coreNativeDir.}

# ---------------------------------------------------------------------------
# ABI constants — append only, never renumber (they are the wire format).
# ---------------------------------------------------------------------------

type
  Format* = enum ## A phone-number format style. The values ARE the ABI's `fmt`
    ## selector; an enum keeps callers from passing a bare `2` and meaning the
    ## wrong style. NOTE (v2): E164 is now `0`, not `2`.
    fmtE164 = 0
    fmtInternational = 1
    fmtNational = 2
    fmtRfc3966 = 3

  NumberType* = enum ## The kind of number `numberType` reports.
    ## `ntUnknown` is `-1`; the rest match the ABI exactly.
    ntUnknown = -1
    ntFixedLine = 0
    ntMobile = 1
    ntTollFree = 2
    ntPremiumRate = 3
    ntSharedCost = 4
    ntVoip = 5
    ntPersonalNumber = 6
    ntPager = 7
    ntUan = 8
    ntVoicemail = 9
    ntFixedLineOrMobile = 10

  ValidationResult* = enum ## `isPossibleNumberWithReason`'s answer.
    vrIsPossible = 0
    vrInvalidCountryCode = 1
    vrTooShort = 2
    vrTooLong = 3
    vrIsPossibleLocalOnly = 4
    vrInvalidLength = 5

  MatchType* = enum ## `isNumberMatch`'s answer.
    matchNotANumber = 0
    matchNoMatch = 1
    matchShortNsn = 2
    matchNsn = 3
    matchExact = 4

  CountryCodeSource* = enum ## Where a parsed number's country code came from.
    srcFromNumberWithPlus = 1
    srcFromNumberWithIdd = 5
    srcFromNumberWithoutPlus = 10
    srcFromDefaultCountry = 20

  Leniency* = enum ## How strict `findNumbers` is.
    lenPossible = 0
    lenValid = 1

  ShortNumberCost* = enum ## What `expectedCost` reports for a short number.
    costTollFree = 0
    costStandardRate = 1
    costPremiumRate = 2
    costUnknown = 3

# Bare integer aliases, for a caller who prefers the wire format to the enum.
const
  E164* = 0.cint
  INTERNATIONAL* = 1.cint
  NATIONAL* = 2.cint
  RFC3966* = 3.cint

  TYPE_UNKNOWN* = -1.cint
  TYPE_FIXED_LINE* = 0.cint
  TYPE_MOBILE* = 1.cint
  TYPE_TOLL_FREE* = 2.cint
  TYPE_PREMIUM_RATE* = 3.cint
  TYPE_SHARED_COST* = 4.cint
  TYPE_VOIP* = 5.cint
  TYPE_PERSONAL_NUMBER* = 6.cint
  TYPE_PAGER* = 7.cint
  TYPE_UAN* = 8.cint
  TYPE_VOICEMAIL* = 9.cint
  TYPE_FIXED_LINE_OR_MOBILE* = 10.cint

  VR_IS_POSSIBLE* = 0.cint
  VR_INVALID_COUNTRY_CODE* = 1.cint
  VR_TOO_SHORT* = 2.cint
  VR_TOO_LONG* = 3.cint
  VR_IS_POSSIBLE_LOCAL_ONLY* = 4.cint
  VR_INVALID_LENGTH* = 5.cint

  MATCH_NOT_A_NUMBER* = 0.cint
  MATCH_NO_MATCH* = 1.cint
  MATCH_SHORT_NSN* = 2.cint
  MATCH_NSN* = 3.cint
  MATCH_EXACT* = 4.cint

  SRC_FROM_NUMBER_WITH_PLUS* = 1.cint
  SRC_FROM_NUMBER_WITH_IDD* = 5.cint
  SRC_FROM_NUMBER_WITHOUT_PLUS* = 10.cint
  SRC_FROM_DEFAULT_COUNTRY* = 20.cint

  LENIENCY_POSSIBLE* = 0.cint
  LENIENCY_VALID* = 1.cint

  COST_TOLL_FREE* = 0.cint
  COST_STANDARD_RATE* = 1.cint
  COST_PREMIUM_RATE* = 2.cint
  COST_UNKNOWN* = 3.cint

# ---------------------------------------------------------------------------
# The 1:1 symbol table.
# ---------------------------------------------------------------------------
#
# Declared in the order core/embed.ae / docs/abi.md declare them, so the two can
# be diffed by eye. Every integer is `cint`; every returned string is `cstring`
# and is caller-owned (see the ownership rule at the top). All 66 symbols.

# ---- lifecycle / metadata ----
proc pnAbiVersion(): cint {.importc: "aether_pn_embed_abi_version", cdecl.}
proc pnFreeString(s: cstring) {.importc: "aether_pn_embed_free_string", cdecl.}
proc pnCountryCode(region: cstring): cstring
  {.importc: "aether_pn_embed_country_code", cdecl.}
proc pnExampleNumber(region: cstring): cstring
  {.importc: "aether_pn_embed_example_number", cdecl.}
proc pnExampleNumberForType(region: cstring, ntype: cint): cstring
  {.importc: "aether_pn_embed_example_number_for_type", cdecl.}
proc pnInvalidExampleNumber(region: cstring): cstring
  {.importc: "aether_pn_embed_invalid_example_number", cdecl.}
proc pnPossibleLengths(region: cstring): cstring
  {.importc: "aether_pn_embed_possible_lengths", cdecl.}
proc pnRegionCodeForCountryCode(cc: cstring): cstring
  {.importc: "aether_pn_embed_region_code_for_country_code", cdecl.}
proc pnIsNanpaCountry(region: cstring): cint
  {.importc: "aether_pn_embed_is_nanpa_country", cdecl.}
proc pnNddPrefixForRegion(region: cstring, stripNonDigits: cint): cstring
  {.importc: "aether_pn_embed_ndd_prefix_for_region", cdecl.}
proc pnRegionCount(): cint {.importc: "aether_pn_embed_region_count", cdecl.}
proc pnRegionAt(index: cint): cstring
  {.importc: "aether_pn_embed_region_at", cdecl.}
proc pnCcRegionCount(cc: cstring): cint
  {.importc: "aether_pn_embed_cc_region_count", cdecl.}
proc pnCcRegionAt(cc: cstring, index: cint): cstring
  {.importc: "aether_pn_embed_cc_region_at", cdecl.}

# ---- parse + parsed-number accessors ----
proc pnParse(input, region: cstring): cstring
  {.importc: "aether_pn_embed_parse", cdecl.}
proc pnNationalNumber(region, input: cstring): cstring
  {.importc: "aether_pn_embed_national_number", cdecl.}
proc pnPnRegion(pn: cstring): cstring
  {.importc: "aether_pn_embed_pn_region", cdecl.}
proc pnPnCountryCode(pn: cstring): cstring
  {.importc: "aether_pn_embed_pn_country_code", cdecl.}
proc pnPnNationalNumber(pn: cstring): cstring
  {.importc: "aether_pn_embed_pn_national_number", cdecl.}
proc pnPnExtension(pn: cstring): cstring
  {.importc: "aether_pn_embed_pn_extension", cdecl.}
proc pnPnItalianLeadingZero(pn: cstring): cint
  {.importc: "aether_pn_embed_pn_italian_leading_zero", cdecl.}
proc pnPnSource(pn: cstring): cint
  {.importc: "aether_pn_embed_pn_source", cdecl.}
proc pnPnError(pn: cstring): cstring
  {.importc: "aether_pn_embed_pn_error", cdecl.}
proc pnRegionCodeForNumber(pn: cstring): cstring
  {.importc: "aether_pn_embed_region_code_for_number", cdecl.}
proc pnNationalSignificantNumber(pn: cstring): cstring
  {.importc: "aether_pn_embed_national_significant_number", cdecl.}
proc pnLengthOfNdc(pn: cstring): cint
  {.importc: "aether_pn_embed_length_of_ndc", cdecl.}
proc pnLengthOfAreaCode(pn: cstring): cint
  {.importc: "aether_pn_embed_length_of_area_code", cdecl.}
proc pnIsGeographical(pn: cstring): cint
  {.importc: "aether_pn_embed_is_geographical", cdecl.}

# ---- validation ----
proc pnIsPossibleNumber(region, input: cstring): cint
  {.importc: "aether_pn_embed_is_possible_number", cdecl.}
proc pnIsPossibleNumberWithReason(region, input: cstring): cint
  {.importc: "aether_pn_embed_is_possible_number_with_reason", cdecl.}
proc pnIsValidNumber(region, input: cstring): cint
  {.importc: "aether_pn_embed_is_valid_number", cdecl.}
proc pnIsValidNumberForRegion(input, region: cstring): cint
  {.importc: "aether_pn_embed_is_valid_number_for_region", cdecl.}
proc pnNumberType(region, input: cstring): cint
  {.importc: "aether_pn_embed_number_type", cdecl.}
proc pnCanBeInternationallyDialled(region, input: cstring): cint
  {.importc: "aether_pn_embed_can_be_internationally_dialled", cdecl.}

# ---- formatting ----
proc pnFormat(region, input: cstring, fmt: cint): cstring
  {.importc: "aether_pn_embed_format", cdecl.}
proc pnFormatOutOfCountry(region, input, callingFrom: cstring): cstring
  {.importc: "aether_pn_embed_format_out_of_country", cdecl.}
proc pnFormatInOriginal(pn, callingFrom: cstring): cstring
  {.importc: "aether_pn_embed_format_in_original", cdecl.}

# ---- relations / helpers ----
proc pnIsNumberMatch(a, b: cstring): cint
  {.importc: "aether_pn_embed_is_number_match", cdecl.}
proc pnTruncateTooLong(region, input: cstring): cstring
  {.importc: "aether_pn_embed_truncate_too_long", cdecl.}
proc pnNormalizeDigitsOnly(s: cstring): cstring
  {.importc: "aether_pn_embed_normalize_digits_only", cdecl.}
proc pnConvertAlphaCharacters(s: cstring): cstring
  {.importc: "aether_pn_embed_convert_alpha_characters", cdecl.}
proc pnIsAlphaNumber(s: cstring): cint
  {.importc: "aether_pn_embed_is_alpha_number", cdecl.}

# ---- AsYouTypeFormatter (state threaded as a caller-owned string) ----
proc pnAytNew(region: cstring): cstring
  {.importc: "aether_pn_embed_ayt_new", cdecl.}
proc pnAytInput(state, ch: cstring): cstring
  {.importc: "aether_pn_embed_ayt_input", cdecl.}
proc pnAytResult(state: cstring): cstring
  {.importc: "aether_pn_embed_ayt_result", cdecl.}
proc pnAytClear(state: cstring): cstring
  {.importc: "aether_pn_embed_ayt_clear", cdecl.}

# ---- PhoneNumberMatcher / findNumbers ----
proc pnMatcherCount(text, region: cstring, leniency: cint): cint
  {.importc: "aether_pn_embed_matcher_count", cdecl.}
proc pnMatcherStart(text, region: cstring, leniency, idx: cint): cint
  {.importc: "aether_pn_embed_matcher_start", cdecl.}
proc pnMatcherEnd(text, region: cstring, leniency, idx: cint): cint
  {.importc: "aether_pn_embed_matcher_end", cdecl.}
proc pnMatcherRaw(text, region: cstring, leniency, idx: cint): cstring
  {.importc: "aether_pn_embed_matcher_raw", cdecl.}

# ---- ShortNumberInfo (short / emergency numbers) ----
proc pnShortIsPossible(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_is_possible", cdecl.}
proc pnShortIsValid(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_is_valid", cdecl.}
proc pnShortIsEmergency(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_is_emergency", cdecl.}
proc pnShortConnectsToEmergency(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_connects_to_emergency", cdecl.}
proc pnShortIsCarrierSpecific(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_is_carrier_specific", cdecl.}
proc pnShortIsSmsService(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_is_sms_service", cdecl.}
proc pnShortExpectedCost(region, input: cstring): cint
  {.importc: "aether_pn_embed_short_expected_cost", cdecl.}
proc pnShortExampleNumber(region: cstring): cstring
  {.importc: "aether_pn_embed_short_example_number", cdecl.}

# ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----
proc pnTzCount(region, input: cstring): cint
  {.importc: "aether_pn_embed_tz_count", cdecl.}
proc pnTzAt(region, input: cstring, idx: cint): cstring
  {.importc: "aether_pn_embed_tz_at", cdecl.}
proc pnTzAll(region, input: cstring): cstring
  {.importc: "aether_pn_embed_tz_all", cdecl.}
proc pnTzUnknown(): cstring
  {.importc: "aether_pn_embed_tz_unknown", cdecl.}

# ---- PhoneNumberToCarrierMapper (localized carrier names) ----
proc pnCarrierName(region, input, lang: cstring): cstring
  {.importc: "aether_pn_embed_carrier_name", cdecl.}
proc pnCarrierNameForValid(region, input, lang: cstring): cstring
  {.importc: "aether_pn_embed_carrier_name_for_valid", cdecl.}

# ---- PhoneNumberOfflineGeocoder (localized geographic descriptions) ----
proc pnGeoDescription(region, input, lang: cstring): cstring
  {.importc: "aether_pn_embed_geo_description", cdecl.}
proc pnGeoDescriptionForValid(region, input, lang: cstring): cstring
  {.importc: "aether_pn_embed_geo_description_for_valid", cdecl.}

# ---------------------------------------------------------------------------
# String marshalling — the one place a returned pointer is allowed to live.
# ---------------------------------------------------------------------------

proc takeString(p: cstring): string =
  ## Copy an ABI-returned string into a Nim `string` and free the original
  ## through the ABI. **Every** `cstring` this library returns goes through
  ## here, and the pointer is dead the moment this returns.
  if p.isNil:
    return ""
  result = $p          # $ on a cstring copies the bytes into a Nim string
  pnFreeString(p)

# ---------------------------------------------------------------------------
# Metadata
# ---------------------------------------------------------------------------

proc countryCode*(region: string): string =
  ## The country calling code for a region ("1", "44", …), or "" if unknown.
  takeString(pnCountryCode(region.cstring))

proc exampleNumber*(region: string): string =
  ## An example national number for the region, or "".
  takeString(pnExampleNumber(region.cstring))

proc exampleNumberForType*(region: string, ntype: NumberType): string =
  ## An example national number of a given type for the region, or "".
  takeString(pnExampleNumberForType(region.cstring, cint(ord(ntype))))

proc exampleNumberForType*(region: string, ntype: cint): string =
  ## Overload taking the raw ABI number-type int.
  takeString(pnExampleNumberForType(region.cstring, ntype))

proc invalidExampleNumber*(region: string): string =
  ## An example number that is invalid for the region, or "".
  takeString(pnInvalidExampleNumber(region.cstring))

proc possibleLengths*(region: string): string =
  ## The possible-lengths spec for the region (e.g. "9,10"), or "".
  takeString(pnPossibleLengths(region.cstring))

proc regionCodeForCountryCode*(cc: string): string =
  ## The primary region id for a country calling code ("44" -> "GB"), or "".
  takeString(pnRegionCodeForCountryCode(cc.cstring))

proc isNanpaCountry*(region: string): bool =
  ## True if the region is part of the North American Numbering Plan.
  pnIsNanpaCountry(region.cstring) != 0

proc nddPrefixForRegion*(region: string, stripNonDigits = false): string =
  ## The national-direct-dialling prefix for the region, or "".
  takeString(pnNddPrefixForRegion(region.cstring, (if stripNonDigits: 1.cint else: 0.cint)))

proc regionCount*(): int =
  ## How many region ids the metadata carries.
  int(pnRegionCount())

proc regionAt*(index: int): string =
  ## The region id at `index` in the engine's own order; "" when out of range.
  takeString(pnRegionAt(cint(index)))

proc regions*(): seq[string] =
  ## Every region id the metadata carries, as a list of ISO-3166 codes.
  let n = regionCount()
  result = newSeqOfCap[string](n)
  for i in 0 ..< n:
    result.add regionAt(i)

proc sortedRegions*(): seq[string] =
  ## The deterministic version of `regions`.
  result = regions()
  result.sort()

proc ccRegionCount*(cc: string): int =
  ## How many regions share a country calling code.
  int(pnCcRegionCount(cc.cstring))

proc regionsForCountryCode*(cc: string): seq[string] =
  ## Every region id that shares a country calling code, primary region first.
  let n = ccRegionCount(cc)
  result = newSeqOfCap[string](n)
  for i in 0 ..< n:
    result.add takeString(pnCcRegionAt(cc.cstring, cint(i)))

# ---------------------------------------------------------------------------
# Parsed number
# ---------------------------------------------------------------------------

type
  ParsedNumber* = object ## A parsed phone number. Wraps the caller-owned
    ## parsed-number string the ABI returns; its fields are read on demand.
    pn: string

proc parse*(number, region: string): ParsedNumber =
  ## Parse a raw human-typed number in the context of a default region. The
  ## result's `error` is non-empty if parsing failed.
  ParsedNumber(pn: takeString(pnParse(number.cstring, region.cstring)))

proc region*(p: ParsedNumber): string =
  takeString(pnPnRegion(p.pn.cstring))

proc countryCode*(p: ParsedNumber): string =
  takeString(pnPnCountryCode(p.pn.cstring))

proc nationalNumber*(p: ParsedNumber): string =
  takeString(pnPnNationalNumber(p.pn.cstring))

proc extension*(p: ParsedNumber): string =
  takeString(pnPnExtension(p.pn.cstring))

proc italianLeadingZero*(p: ParsedNumber): bool =
  pnPnItalianLeadingZero(p.pn.cstring) != 0

proc source*(p: ParsedNumber): CountryCodeSource =
  # CountryCodeSource is an enum with holes (1,5,10,20); a plain conversion
  # trips HoleEnumConv. cast avoids the check — the engine only ever returns
  # one of these four values.
  cast[CountryCodeSource](pnPnSource(p.pn.cstring))

proc sourceInt*(p: ParsedNumber): int =
  int(pnPnSource(p.pn.cstring))

proc error*(p: ParsedNumber): string =
  ## Non-empty if the parse failed.
  takeString(pnPnError(p.pn.cstring))

proc regionCode*(p: ParsedNumber): string =
  takeString(pnRegionCodeForNumber(p.pn.cstring))

proc nationalSignificantNumber*(p: ParsedNumber): string =
  takeString(pnNationalSignificantNumber(p.pn.cstring))

proc lengthOfNdc*(p: ParsedNumber): int =
  int(pnLengthOfNdc(p.pn.cstring))

proc lengthOfAreaCode*(p: ParsedNumber): int =
  int(pnLengthOfAreaCode(p.pn.cstring))

proc isGeographical*(p: ParsedNumber): bool =
  pnIsGeographical(p.pn.cstring) != 0

proc nationalNumber*(region, input: string): string =
  ## The national number extracted from raw input (cc + punctuation stripped).
  takeString(pnNationalNumber(region.cstring, input.cstring))

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

proc isPossibleNumber*(region, input: string): bool =
  ## True if the national number is a length the region allows.
  pnIsPossibleNumber(region.cstring, input.cstring) != 0

proc isPossibleNumberWithReason*(region, input: string): ValidationResult =
  ## Why a number is / isn't possible (a `ValidationResult`).
  ValidationResult(pnIsPossibleNumberWithReason(region.cstring, input.cstring))

proc isPossibleNumberWithReasonInt*(region, input: string): int =
  int(pnIsPossibleNumberWithReason(region.cstring, input.cstring))

proc isValidNumber*(region, input: string): bool =
  ## True if the number matches the region's national-number patterns.
  pnIsValidNumber(region.cstring, input.cstring) != 0

proc isValidNumberForRegion*(input, region: string): bool =
  ## True if the number is valid *for* the given region specifically.
  pnIsValidNumberForRegion(input.cstring, region.cstring) != 0

proc numberType*(region, input: string): NumberType =
  ## The kind of number (a `NumberType`; `ntUnknown` for unknown).
  NumberType(pnNumberType(region.cstring, input.cstring))

proc numberTypeInt*(region, input: string): int =
  ## The raw ABI number-type int (-1 for unknown), for a caller who wants the
  ## wire value rather than the enum.
  int(pnNumberType(region.cstring, input.cstring))

proc canBeInternationallyDialled*(region, input: string): bool =
  ## True if the number can be dialled from outside its region.
  pnCanBeInternationallyDialled(region.cstring, input.cstring) != 0

# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

proc format*(region, input: string, style: Format = fmtNational): string =
  ## Format the number in the given style (E164 / INTERNATIONAL / NATIONAL /
  ## RFC3966).
  takeString(pnFormat(region.cstring, input.cstring, cint(ord(style))))

proc format*(region, input: string, style: cint): string =
  ## Format overload taking the raw ABI style int (0 E164, 1 INTERNATIONAL,
  ## 2 NATIONAL, 3 RFC3966).
  takeString(pnFormat(region.cstring, input.cstring, style))

proc formatNational*(region, input: string): string =
  format(region, input, fmtNational)

proc formatInternational*(region, input: string): string =
  format(region, input, fmtInternational)

proc formatE164*(region, input: string): string =
  format(region, input, fmtE164)

proc formatRfc3966*(region, input: string): string =
  format(region, input, fmtRfc3966)

proc formatOutOfCountry*(region, input, callingFrom: string): string =
  ## Format `input` (typed in `region`) as it should be dialled from
  ## `callingFrom`.
  takeString(pnFormatOutOfCountry(region.cstring, input.cstring, callingFrom.cstring))

proc formatInOriginal*(p: ParsedNumber, callingFrom: string): string =
  ## Format a parsed number in the format it was originally entered.
  takeString(pnFormatInOriginal(p.pn.cstring, callingFrom.cstring))

# ---------------------------------------------------------------------------
# Relations / helpers
# ---------------------------------------------------------------------------

proc isNumberMatch*(a, b: string): MatchType =
  ## How closely two numbers match (a `MatchType`).
  MatchType(pnIsNumberMatch(a.cstring, b.cstring))

proc isNumberMatchInt*(a, b: string): int =
  int(pnIsNumberMatch(a.cstring, b.cstring))

proc truncateTooLong*(region, input: string): string =
  ## Drop trailing digits until the number is a valid length (or "").
  takeString(pnTruncateTooLong(region.cstring, input.cstring))

proc normalizeDigitsOnly*(s: string): string =
  ## Keep only the (Unicode) digits, mapping them to ASCII.
  takeString(pnNormalizeDigitsOnly(s.cstring))

proc convertAlphaCharacters*(s: string): string =
  ## Map vanity letters to their dial-pad digits.
  takeString(pnConvertAlphaCharacters(s.cstring))

proc isAlphaNumber*(s: string): bool =
  ## True if the number contains vanity (alpha) characters.
  pnIsAlphaNumber(s.cstring) != 0

proc abiVersion*(): int =
  ## The ABI revision the linked engine reports (v7 — the Carrier and Geocoder
  ## surfaces gained a per-call `lang` argument).
  int(pnAbiVersion())

# ---------------------------------------------------------------------------
# AsYouTypeFormatter
# ---------------------------------------------------------------------------

type
  AsYouTypeFormatter* = object ## Formats a number as it is typed, digit by
    ## digit. The engine state is threaded as a caller-owned string; each
    ## `inputDigit` frees the previous state and adopts the new one.
    state: string

proc initAsYouTypeFormatter*(region: string): AsYouTypeFormatter =
  ## Start a formatter for the given default region.
  AsYouTypeFormatter(state: takeString(pnAytNew(region.cstring)))

proc result*(f: AsYouTypeFormatter): string =
  ## The formatted-so-far string.
  takeString(pnAytResult(f.state.cstring))

proc inputDigit*(f: var AsYouTypeFormatter, ch: char): string =
  ## Feed one character; advance the state and return the formatted-so-far
  ## string.
  f.state = takeString(pnAytInput(f.state.cstring, ($ch).cstring))
  f.result

proc inputDigit*(f: var AsYouTypeFormatter, ch: string): string =
  ## Feed one character (as a 1-char string).
  f.state = takeString(pnAytInput(f.state.cstring, ch.cstring))
  f.result

proc clear*(f: var AsYouTypeFormatter) =
  ## Reset to an empty number.
  f.state = takeString(pnAytClear(f.state.cstring))

# ---------------------------------------------------------------------------
# PhoneNumberMatcher / findNumbers
# ---------------------------------------------------------------------------

type
  Match* = object ## A phone number found in free text.
    start*: int   ## UTF-8 byte offset where the match starts.
    `end`*: int   ## UTF-8 byte offset one past the match.
    raw*: string  ## The exact substring that matched.

proc findNumbers*(text, region: string, leniency: Leniency = lenValid): seq[Match] =
  ## Find phone numbers in free text. Returns a sequence of `Match`.
  let len = cint(ord(leniency))
  let n = pnMatcherCount(text.cstring, region.cstring, len)
  result = newSeqOfCap[Match](int(n))
  for i in 0 ..< n:
    result.add Match(
      start: int(pnMatcherStart(text.cstring, region.cstring, len, i)),
      `end`: int(pnMatcherEnd(text.cstring, region.cstring, len, i)),
      raw: takeString(pnMatcherRaw(text.cstring, region.cstring, len, i)))

# ---------------------------------------------------------------------------
# ShortNumberInfo (short / emergency numbers)
# ---------------------------------------------------------------------------
#
# Short numbers are dialled as-is — no country code, no national prefix — so the
# input is the raw short number plus a region. Pure marshalling, like the rest.

proc shortIsPossible*(region, input: string): bool =
  ## True if `input` is a possible short number for the region (right length).
  pnShortIsPossible(region.cstring, input.cstring) != 0

proc shortIsValid*(region, input: string): bool =
  ## True if `input` matches a short-number pattern for the region.
  pnShortIsValid(region.cstring, input.cstring) != 0

proc isEmergencyNumber*(region, input: string): bool =
  ## True if `input` is an emergency number for the region (e.g. US "911").
  pnShortIsEmergency(region.cstring, input.cstring) != 0

proc connectsToEmergencyNumber*(region, input: string): bool =
  ## True if dialling `input` connects to an emergency number for the region.
  pnShortConnectsToEmergency(region.cstring, input.cstring) != 0

proc shortIsCarrierSpecific*(region, input: string): bool =
  ## True if the short number is specific to a single carrier.
  pnShortIsCarrierSpecific(region.cstring, input.cstring) != 0

proc shortIsSmsService*(region, input: string): bool =
  ## True if the short number is usable as an SMS service.
  pnShortIsSmsService(region.cstring, input.cstring) != 0

proc shortExpectedCost*(region, input: string): ShortNumberCost =
  ## The expected cost of dialling the short number (a `ShortNumberCost`).
  ShortNumberCost(pnShortExpectedCost(region.cstring, input.cstring))

proc shortExpectedCostInt*(region, input: string): int =
  ## The raw ABI cost int (0 toll-free, 1 standard, 2 premium, 3 unknown).
  int(pnShortExpectedCost(region.cstring, input.cstring))

proc shortExampleNumber*(region: string): string =
  ## An example short number for the region, or "".
  takeString(pnShortExampleNumber(region.cstring))

# ---------------------------------------------------------------------------
# PhoneNumberToTimeZonesMapper (timezone lookup)
# ---------------------------------------------------------------------------
#
# Longest-prefix match over the number's E.164 digits. Pass a raw (region,
# input) like everywhere else; the engine parses to E.164 itself. The
# unknown-zone sentinel is "Etc/Unknown".

proc unknownTimeZone*(): string =
  ## The unknown-timezone sentinel, "Etc/Unknown".
  takeString(pnTzUnknown())

proc timeZoneCount*(region, input: string): int =
  ## How many timezones the number maps to (0 means only the unknown zone).
  int(pnTzCount(region.cstring, input.cstring))

proc timeZonesForNumber*(region, input: string): seq[string] =
  ## The IANA timezone ids for a number, as a sequence. A number with no known
  ## zones maps to a single-element sequence holding the unknown zone, matching
  ## the other bindings.
  let n = pnTzCount(region.cstring, input.cstring)
  if n == 0:
    return @[unknownTimeZone()]
  result = newSeqOfCap[string](int(n))
  for i in 0 ..< n:
    result.add takeString(pnTzAt(region.cstring, input.cstring, i))

# ---------------------------------------------------------------------------
# PhoneNumberToCarrierMapper (localized carrier names)
# ---------------------------------------------------------------------------
#
# Longest-prefix match over the E.164 digits. `lang` is an ISO code ("en", "de",
# …); "en" is always available and is the fallback for any language not compiled
# into the engine. "" when no carrier is known for the number.

proc carrierNameForNumber*(region, input: string, lang = "en"): string =
  ## The carrier name for a number, localized by `lang` (default "en"), or "" if
  ## none is known.
  takeString(pnCarrierName(region.cstring, input.cstring, lang.cstring))

proc carrierNameForValidNumber*(region, input: string, lang = "en"): string =
  ## The carrier name only when the number is valid, else "".
  takeString(pnCarrierNameForValid(region.cstring, input.cstring, lang.cstring))

# ---------------------------------------------------------------------------
# PhoneNumberOfflineGeocoder (localized geographic descriptions)
# ---------------------------------------------------------------------------
#
# Longest-prefix match over the E.164 digits. Pass a raw (region, input) like
# everywhere else; the engine parses to E.164 itself. `lang` is an ISO code
# ("en", "de", …); "en" is always available and is the fallback. "" when no
# description is known for the number.

proc geoDescriptionForNumber*(region, input: string, lang = "en"): string =
  ## A geographic description for a number, localized by `lang` (default "en"),
  ## or "" if none is known.
  takeString(pnGeoDescription(region.cstring, input.cstring, lang.cstring))

proc geoDescriptionForValidNumber*(region, input: string, lang = "en"): string =
  ## A geographic description only when the number is valid, else "".
  takeString(pnGeoDescriptionForValid(region.cstring, input.cstring, lang.cstring))
