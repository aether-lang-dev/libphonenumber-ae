//// Validate, parse and format international phone numbers (ABI v7).
////
//// This is a thin Gleam surface over the monorepo's **canonical BEAM NIF**,
//// which lives in `erlang/` and is compiled exactly once. There is no C source
//// in this directory and no second `.so` — every function here is an
//// `@external(erlang, "phonenumber_ae_nif", ...)` binding onto the very same
//// compiled module the Erlang and Elixir bindings load. One engine, one NIF,
//// three languages.
////
//// The engine itself (`core/native/libphonenumber_ae.so`) is pure Aether,
//// compiled from Google libphonenumber's own metadata. No phone-number logic
//// lives in this file: everything marshals to an `aether_pn_embed_*` call
//// across the C ABI in `core/embed.ae` (docs/abi.md — 66 symbols, full
//// PhoneNumberUtil parity plus ShortNumberInfo, TimeZones, Carrier and Geocoder).
////
//// ```gleam
//// phonenumber_ae.country_code("US")
//// // -> "1"
//// let num = phonenumber_ae.parse("+1 201 555 0123 ext 42", "US")
//// phonenumber_ae.national_number(num)
//// // -> "2015550123"
//// phonenumber_ae.format("US", "2015550123", National)
//// // -> "(201) 555-0123"
//// ```
////
//// ## Finding the NIF
////
//// `gleam` honours `$ERL_LIBS`, so pointing it at the directory containing the
//// app built by `erlang/.build.ae` is all that is needed — see
//// `gleam/.tests.ae`. (Mix, by contrast, does not; that is why the Elixir
//// binding has to `Code.append_path` instead.)
////
//// ## Erlang target only
////
//// This module is **Erlang-target only**. It cannot compile to JavaScript,
//// because the whole binding is a NIF. That is not a limitation worth working
//// around: the monorepo already has a JavaScript binding that talks to the
//// same engine.
////
//// ## No handles
////
//// The ABI has no opaque handles. A parsed number and an as-you-type state are
//// themselves caller-owned STRINGS; the `ParsedNumber` and `AsYouType` opaque
//// types below wrap those strings, and every call is one FFI crossing.

import gleam/int
import gleam/list
import gleam/string

/// A format style. These map onto the ABI's integer selectors, which are
/// append-only and must never be renumbered. Note the v2 numbering: `E164` is
/// now 0 (it was 2 in v1).
pub type FormatStyle {
  E164
  International
  National
  Rfc3966
}

/// A PhoneNumberType. `Unknown` is the -1 sentinel.
pub type NumberType {
  Unknown
  FixedLine
  Mobile
  TollFree
  PremiumRate
  SharedCost
  Voip
  PersonalNumber
  Pager
  Uan
  Voicemail
  FixedLineOrMobile
}

/// A ValidationResult, returned by `is_possible_number_with_reason`.
pub type ValidationResult {
  IsPossible
  IsPossibleLocalOnly
  InvalidCountryCode
  TooShort
  InvalidLength
  TooLong
}

/// A MatchType, returned by `is_number_match`.
pub type MatchType {
  NotANumber
  NoMatch
  ShortNsn
  Nsn
  Exact
}

/// A CountryCodeSource, read from a `ParsedNumber` via `source`.
pub type CountryCodeSource {
  FromNumberWithPlus
  FromNumberWithIdd
  FromNumberWithoutPlus
  FromDefaultCountry
  UnspecifiedSource
}

/// Matcher leniency. `StrictGrouping` (2) and `ExactGrouping` (3) consult
/// AlternateFormats in the engine; all levels hit the same `matcher_count`
/// symbol.
pub type Leniency {
  Possible
  Valid
  StrictGrouping
  ExactGrouping
}

/// A ShortNumberCost, returned by `short_expected_cost`. The constructors are
/// prefixed `Cost` because `TollFree` is already a `NumberType` constructor in
/// this module, and Gleam constructor names must be unique per module.
pub type ShortNumberCost {
  CostTollFree
  CostStandardRate
  CostPremiumRate
  CostUnknown
}

/// A parsed phone number. Wraps the caller-owned parsed-number string the ABI
/// returns; read its fields with the `pn_*`-style accessors below (there is no
/// opaque handle — the value IS the string).
pub opaque type ParsedNumber {
  ParsedNumber(pn: String)
}

/// An AsYouTypeFormatter. Wraps the caller-owned state string the ABI returns;
/// `ayt_input` returns a fresh value each keystroke.
pub opaque type AsYouType {
  AsYouType(state: String)
}

/// A phone number found in free text: the `start` and `end` offsets and the
/// `raw` matched text.
pub type Match {
  Match(start: Int, end: Int, raw: String)
}

/// The ABI selector for a format style (core/embed.ae, v2 — append only).
fn style_code(style: FormatStyle) -> Int {
  case style {
    E164 -> 0
    International -> 1
    National -> 2
    Rfc3966 -> 3
  }
}

/// The ABI number-type code as a `NumberType`. Append only, never renumber
/// (core/embed.ae); an unseen code degrades to `Unknown` rather than crashing.
fn type_of_code(code: Int) -> NumberType {
  case code {
    0 -> FixedLine
    1 -> Mobile
    2 -> TollFree
    3 -> PremiumRate
    4 -> SharedCost
    5 -> Voip
    6 -> PersonalNumber
    7 -> Pager
    8 -> Uan
    9 -> Voicemail
    10 -> FixedLineOrMobile
    _ -> Unknown
  }
}

fn code_of_type(t: NumberType) -> Int {
  case t {
    Unknown -> -1
    FixedLine -> 0
    Mobile -> 1
    TollFree -> 2
    PremiumRate -> 3
    SharedCost -> 4
    Voip -> 5
    PersonalNumber -> 6
    Pager -> 7
    Uan -> 8
    Voicemail -> 9
    FixedLineOrMobile -> 10
  }
}

fn validation_of_code(code: Int) -> ValidationResult {
  case code {
    0 -> IsPossible
    4 -> IsPossibleLocalOnly
    1 -> InvalidCountryCode
    2 -> TooShort
    5 -> InvalidLength
    3 -> TooLong
    _ -> InvalidLength
  }
}

fn match_of_code(code: Int) -> MatchType {
  case code {
    0 -> NotANumber
    1 -> NoMatch
    2 -> ShortNsn
    3 -> Nsn
    4 -> Exact
    _ -> NoMatch
  }
}

fn source_of_code(code: Int) -> CountryCodeSource {
  case code {
    1 -> FromNumberWithPlus
    5 -> FromNumberWithIdd
    10 -> FromNumberWithoutPlus
    20 -> FromDefaultCountry
    _ -> UnspecifiedSource
  }
}

fn leniency_code(l: Leniency) -> Int {
  case l {
    Possible -> 0
    Valid -> 1
    StrictGrouping -> 2
    ExactGrouping -> 3
  }
}

/// The ABI ShortNumberCost code as a `ShortNumberCost`. Append only, never
/// renumber; an unseen code degrades to `UnknownCost` rather than crashing.
fn cost_of_code(code: Int) -> ShortNumberCost {
  case code {
    0 -> CostTollFree
    1 -> CostStandardRate
    2 -> CostPremiumRate
    3 -> CostUnknown
    _ -> CostUnknown
  }
}

/// The indices `[0, 1, .., n-1]`, ascending. `list.range` is not in every
/// stdlib version, so we build the small index list ourselves.
fn indices(n: Int) -> List(Int) {
  indices_loop(n - 1, [])
}

fn indices_loop(i: Int, acc: List(Int)) -> List(Int) {
  case i < 0 {
    True -> acc
    False -> indices_loop(i - 1, [i, ..acc])
  }
}

// ---- raw FFI onto the shared NIF ----
//
// The NIF returns 0/1 for predicates and integers for the enums; the public
// wrappers below turn those into Bool / typed values so a Gleam caller never
// sees a bare code. These `_ffi` bindings are private for that reason.

// metadata
@external(erlang, "phonenumber_ae_nif", "country_code")
fn country_code_ffi(region: String) -> String

@external(erlang, "phonenumber_ae_nif", "example_number")
fn example_number_ffi(region: String) -> String

@external(erlang, "phonenumber_ae_nif", "example_number_for_type")
fn example_number_for_type_ffi(region: String, type_code: Int) -> String

@external(erlang, "phonenumber_ae_nif", "invalid_example_number")
fn invalid_example_number_ffi(region: String) -> String

@external(erlang, "phonenumber_ae_nif", "possible_lengths")
fn possible_lengths_ffi(region: String) -> String

@external(erlang, "phonenumber_ae_nif", "region_code_for_country_code")
fn region_code_for_country_code_ffi(cc: String) -> String

@external(erlang, "phonenumber_ae_nif", "is_nanpa_country")
fn is_nanpa_country_ffi(region: String) -> Int

@external(erlang, "phonenumber_ae_nif", "ndd_prefix_for_region")
fn ndd_prefix_for_region_ffi(region: String, strip: Int) -> String

@external(erlang, "phonenumber_ae_nif", "region_count")
fn region_count_ffi() -> Int

@external(erlang, "phonenumber_ae_nif", "region_at")
fn region_at_ffi(index: Int) -> String

@external(erlang, "phonenumber_ae_nif", "regions")
fn regions_ffi() -> List(String)

@external(erlang, "phonenumber_ae_nif", "cc_region_count")
fn cc_region_count_ffi(cc: String) -> Int

@external(erlang, "phonenumber_ae_nif", "cc_region_at")
fn cc_region_at_ffi(cc: String, index: Int) -> String

// parse + accessors
@external(erlang, "phonenumber_ae_nif", "parse")
fn parse_ffi(input: String, region: String) -> String

@external(erlang, "phonenumber_ae_nif", "national_number")
fn national_number_ffi(region: String, input: String) -> String

@external(erlang, "phonenumber_ae_nif", "pn_region")
fn pn_region_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "pn_country_code")
fn pn_country_code_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "pn_national_number")
fn pn_national_number_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "pn_extension")
fn pn_extension_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "pn_italian_leading_zero")
fn pn_italian_leading_zero_ffi(pn: String) -> Int

@external(erlang, "phonenumber_ae_nif", "pn_source")
fn pn_source_ffi(pn: String) -> Int

@external(erlang, "phonenumber_ae_nif", "pn_error")
fn pn_error_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "region_code_for_number")
fn region_code_for_number_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "national_significant_number")
fn national_significant_number_ffi(pn: String) -> String

@external(erlang, "phonenumber_ae_nif", "length_of_ndc")
fn length_of_ndc_ffi(pn: String) -> Int

@external(erlang, "phonenumber_ae_nif", "length_of_area_code")
fn length_of_area_code_ffi(pn: String) -> Int

@external(erlang, "phonenumber_ae_nif", "is_geographical")
fn is_geographical_ffi(pn: String) -> Int

// validation
@external(erlang, "phonenumber_ae_nif", "is_possible_number")
fn is_possible_number_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "is_possible_number_with_reason")
fn is_possible_number_with_reason_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "is_valid_number")
fn is_valid_number_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "is_valid_number_for_region")
fn is_valid_number_for_region_ffi(input: String, region: String) -> Int

@external(erlang, "phonenumber_ae_nif", "number_type")
fn number_type_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "can_be_internationally_dialled")
fn can_be_internationally_dialled_ffi(region: String, input: String) -> Int

// formatting
@external(erlang, "phonenumber_ae_nif", "format")
fn format_ffi(region: String, input: String, style: Int) -> String

@external(erlang, "phonenumber_ae_nif", "format_out_of_country")
fn format_out_of_country_ffi(
  region: String,
  input: String,
  calling_from: String,
) -> String

@external(erlang, "phonenumber_ae_nif", "format_in_original")
fn format_in_original_ffi(pn: String, calling_from: String) -> String

// relations / helpers
@external(erlang, "phonenumber_ae_nif", "is_number_match")
fn is_number_match_ffi(a: String, b: String) -> Int

@external(erlang, "phonenumber_ae_nif", "truncate_too_long")
fn truncate_too_long_ffi(region: String, input: String) -> String

@external(erlang, "phonenumber_ae_nif", "normalize_digits_only")
fn normalize_digits_only_ffi(s: String) -> String

@external(erlang, "phonenumber_ae_nif", "convert_alpha_characters")
fn convert_alpha_characters_ffi(s: String) -> String

@external(erlang, "phonenumber_ae_nif", "is_alpha_number")
fn is_alpha_number_ffi(s: String) -> Int

// AsYouType
@external(erlang, "phonenumber_ae_nif", "ayt_new")
fn ayt_new_ffi(region: String) -> String

@external(erlang, "phonenumber_ae_nif", "ayt_input")
fn ayt_input_ffi(state: String, ch: String) -> String

@external(erlang, "phonenumber_ae_nif", "ayt_result")
fn ayt_result_ffi(state: String) -> String

@external(erlang, "phonenumber_ae_nif", "ayt_clear")
fn ayt_clear_ffi(state: String) -> String

// matcher
@external(erlang, "phonenumber_ae_nif", "matcher_count")
fn matcher_count_ffi(text: String, region: String, leniency: Int) -> Int

@external(erlang, "phonenumber_ae_nif", "matcher_start")
fn matcher_start_ffi(
  text: String,
  region: String,
  leniency: Int,
  idx: Int,
) -> Int

@external(erlang, "phonenumber_ae_nif", "matcher_end")
fn matcher_end_ffi(text: String, region: String, leniency: Int, idx: Int) -> Int

@external(erlang, "phonenumber_ae_nif", "matcher_raw")
fn matcher_raw_ffi(
  text: String,
  region: String,
  leniency: Int,
  idx: Int,
) -> String

@external(erlang, "phonenumber_ae_nif", "abi_version")
fn abi_version_ffi() -> Int

// ShortNumberInfo
@external(erlang, "phonenumber_ae_nif", "short_is_possible")
fn short_is_possible_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_is_valid")
fn short_is_valid_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_is_emergency")
fn short_is_emergency_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_connects_to_emergency")
fn short_connects_to_emergency_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_is_carrier_specific")
fn short_is_carrier_specific_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_is_sms_service")
fn short_is_sms_service_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_expected_cost")
fn short_expected_cost_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "short_example_number")
fn short_example_number_ffi(region: String) -> String

// PhoneNumberToTimeZonesMapper
@external(erlang, "phonenumber_ae_nif", "tz_count")
fn tz_count_ffi(region: String, input: String) -> Int

@external(erlang, "phonenumber_ae_nif", "tz_at")
fn tz_at_ffi(region: String, input: String, idx: Int) -> String

@external(erlang, "phonenumber_ae_nif", "tz_unknown")
fn tz_unknown_ffi() -> String

// PhoneNumberToCarrierMapper (v7: a trailing lang arg)
@external(erlang, "phonenumber_ae_nif", "carrier_name")
fn carrier_name_ffi(region: String, input: String, lang: String) -> String

@external(erlang, "phonenumber_ae_nif", "carrier_name_for_valid")
fn carrier_name_for_valid_ffi(
  region: String,
  input: String,
  lang: String,
) -> String

// PhoneNumberOfflineGeocoder (v7: a trailing lang arg)
@external(erlang, "phonenumber_ae_nif", "geo_description")
fn geo_description_ffi(region: String, input: String, lang: String) -> String

@external(erlang, "phonenumber_ae_nif", "geo_description_for_valid")
fn geo_description_for_valid_ffi(
  region: String,
  input: String,
  lang: String,
) -> String

// ---- metadata ----

/// The country calling code for a region ("1", "44", …), or "" if unknown.
pub fn country_code(region: String) -> String {
  country_code_ffi(region)
}

/// An example national number for the region, or "".
pub fn example_number(region: String) -> String {
  example_number_ffi(region)
}

/// An example national number of a given type, or "".
pub fn example_number_for_type(region: String, ntype: NumberType) -> String {
  example_number_for_type_ffi(region, code_of_type(ntype))
}

/// An example number that is invalid for the region, or "".
pub fn invalid_example_number(region: String) -> String {
  invalid_example_number_ffi(region)
}

/// The possible-lengths spec for the region (e.g. "9,10"), or "".
pub fn possible_lengths(region: String) -> String {
  possible_lengths_ffi(region)
}

/// The (main) region for a country calling code, e.g. "44" -> "GB".
pub fn region_code_for_country_code(cc: String) -> String {
  region_code_for_country_code_ffi(cc)
}

/// True if the region is part of the North American Numbering Plan.
pub fn is_nanpa_country(region: String) -> Bool {
  is_nanpa_country_ffi(region) != 0
}

/// The national-direct-dialling prefix for the region. When `strip_non_digits`
/// is true, formatting characters are removed.
pub fn ndd_prefix_for_region(region: String, strip_non_digits: Bool) -> String {
  ndd_prefix_for_region_ffi(region, case strip_non_digits {
    True -> 1
    False -> 0
  })
}

// ---- region enumeration ----

/// How many regions the metadata carries.
pub fn region_count() -> Int {
  region_count_ffi()
}

/// The region id at `index` (0-based).
pub fn region_at(index: Int) -> String {
  region_at_ffi(index)
}

/// Every region id the metadata carries, as a list of ISO-3166 codes.
pub fn regions() -> List(String) {
  regions_ffi()
}

/// `regions`, sorted.
pub fn sorted_regions() -> List(String) {
  list.sort(regions(), string.compare)
}

/// How many regions share a country calling code.
pub fn cc_region_count(cc: String) -> Int {
  cc_region_count_ffi(cc)
}

/// The region id at `index` among those sharing a country calling code.
pub fn cc_region_at(cc: String, index: Int) -> String {
  cc_region_at_ffi(cc, index)
}

/// Every region sharing a country calling code, e.g. "1" -> ["US", ...].
pub fn regions_for_country_code(cc: String) -> List(String) {
  let n = cc_region_count_ffi(cc)
  list.map(indices(n), fn(i) { cc_region_at_ffi(cc, i) })
}

// ---- parse + accessors ----

/// Parse raw input into a `ParsedNumber`. Read its fields with the accessors
/// below; `pn_error` is non-empty when the parse failed.
pub fn parse(input: String, region: String) -> ParsedNumber {
  ParsedNumber(parse_ffi(input, region))
}

/// The national number extracted from raw input (cc + punctuation stripped).
pub fn national_number(region: String, input: String) -> String {
  national_number_ffi(region, input)
}

/// The parse error, or "" if the parse succeeded.
pub fn pn_error(pn: ParsedNumber) -> String {
  pn_error_ffi(pn.pn)
}

/// The region the number was parsed for.
pub fn pn_region(pn: ParsedNumber) -> String {
  pn_region_ffi(pn.pn)
}

/// The country calling code of a parsed number.
pub fn pn_country_code(pn: ParsedNumber) -> String {
  pn_country_code_ffi(pn.pn)
}

/// The national number of a parsed number.
pub fn pn_national_number(pn: ParsedNumber) -> String {
  pn_national_number_ffi(pn.pn)
}

/// The extension of a parsed number, or "".
pub fn pn_extension(pn: ParsedNumber) -> String {
  pn_extension_ffi(pn.pn)
}

/// True if the parsed number carried a significant leading zero.
pub fn pn_italian_leading_zero(pn: ParsedNumber) -> Bool {
  pn_italian_leading_zero_ffi(pn.pn) != 0
}

/// The `CountryCodeSource` for how the country code was found.
pub fn pn_source(pn: ParsedNumber) -> CountryCodeSource {
  source_of_code(pn_source_ffi(pn.pn))
}

/// The region code a parsed number belongs to.
pub fn region_code_for_number(pn: ParsedNumber) -> String {
  region_code_for_number_ffi(pn.pn)
}

/// The national significant number of a parsed number.
pub fn national_significant_number(pn: ParsedNumber) -> String {
  national_significant_number_ffi(pn.pn)
}

/// The length of the national destination code.
pub fn length_of_ndc(pn: ParsedNumber) -> Int {
  length_of_ndc_ffi(pn.pn)
}

/// The length of the area code.
pub fn length_of_area_code(pn: ParsedNumber) -> Int {
  length_of_area_code_ffi(pn.pn)
}

/// True if the parsed number is geographical (tied to a place).
pub fn is_geographical(pn: ParsedNumber) -> Bool {
  is_geographical_ffi(pn.pn) != 0
}

// ---- validity and typing ----

/// True if the national number is a length the region allows.
pub fn is_possible_number(region: String, input: String) -> Bool {
  is_possible_number_ffi(region, input) != 0
}

/// The `ValidationResult` for the number (`TooShort`, …).
pub fn is_possible_number_with_reason(
  region: String,
  input: String,
) -> ValidationResult {
  validation_of_code(is_possible_number_with_reason_ffi(region, input))
}

/// True if the number matches the region's national-number patterns.
pub fn is_valid_number(region: String, input: String) -> Bool {
  is_valid_number_ffi(region, input) != 0
}

/// True if the number is valid for the specific region (not just its cc).
pub fn is_valid_number_for_region(input: String, region: String) -> Bool {
  is_valid_number_for_region_ffi(input, region) != 0
}

/// The `NumberType` for the number (`FixedLine`, `Mobile`, …).
pub fn number_type(region: String, input: String) -> NumberType {
  type_of_code(number_type_ffi(region, input))
}

/// The raw ABI type code (-1 unknown, 0 fixed_line, …).
pub fn number_type_code(region: String, input: String) -> Int {
  number_type_ffi(region, input)
}

/// True if the number can be dialled from outside its country.
pub fn can_be_internationally_dialled(region: String, input: String) -> Bool {
  can_be_internationally_dialled_ffi(region, input) != 0
}

// ---- formatting ----

/// Format the number in the given style.
pub fn format(region: String, input: String, style: FormatStyle) -> String {
  format_ffi(region, input, style_code(style))
}

/// `format` with the `National` style.
pub fn format_national(region: String, input: String) -> String {
  format(region, input, National)
}

/// `format` with the `International` style.
pub fn format_international(region: String, input: String) -> String {
  format(region, input, International)
}

/// `format` with the `E164` style.
pub fn format_e164(region: String, input: String) -> String {
  format(region, input, E164)
}

/// `format` with the `Rfc3966` style.
pub fn format_rfc3966(region: String, input: String) -> String {
  format(region, input, Rfc3966)
}

/// Format as it would be dialled from `calling_from` (the region dialling out).
pub fn format_out_of_country(
  region: String,
  input: String,
  calling_from: String,
) -> String {
  format_out_of_country_ffi(region, input, calling_from)
}

/// Format a parsed number the way it was originally dialled.
pub fn format_in_original(pn: ParsedNumber, calling_from: String) -> String {
  format_in_original_ffi(pn.pn, calling_from)
}

// ---- relations / helpers ----

/// Compare two numbers; returns a `MatchType` (`Exact`, `NoMatch`, …).
pub fn is_number_match(a: String, b: String) -> MatchType {
  match_of_code(is_number_match_ffi(a, b))
}

/// Drop digits past the region's maximum possible length.
pub fn truncate_too_long(region: String, input: String) -> String {
  truncate_too_long_ffi(region, input)
}

/// Keep only the digits of a string (Unicode digits normalised to 0-9).
pub fn normalize_digits_only(s: String) -> String {
  normalize_digits_only_ffi(s)
}

/// Convert vanity letters to their dial-pad digits (keeping punctuation).
pub fn convert_alpha_characters(s: String) -> String {
  convert_alpha_characters_ffi(s)
}

/// True if the string contains any vanity letters.
pub fn is_alpha_number(s: String) -> Bool {
  is_alpha_number_ffi(s) != 0
}

// ---- AsYouTypeFormatter ----

/// A fresh formatter for a region. Feed it with `ayt_input`.
pub fn ayt_new(region: String) -> AsYouType {
  AsYouType(ayt_new_ffi(region))
}

/// Feed one character; returns a NEW formatter (the old one is now stale).
pub fn ayt_input(formatter: AsYouType, ch: String) -> AsYouType {
  AsYouType(ayt_input_ffi(formatter.state, ch))
}

/// The formatted-so-far string for a formatter.
pub fn ayt_result(formatter: AsYouType) -> String {
  ayt_result_ffi(formatter.state)
}

/// Reset the formatter, returning a cleared one for the same region.
pub fn ayt_clear(formatter: AsYouType) -> AsYouType {
  AsYouType(ayt_clear_ffi(formatter.state))
}

// ---- PhoneNumberMatcher / findNumbers ----

/// Find phone numbers in free text. Returns a list of `Match` (start/end/raw).
pub fn find_numbers(
  text: String,
  region: String,
  leniency: Leniency,
) -> List(Match) {
  let l = leniency_code(leniency)
  let n = matcher_count_ffi(text, region, l)
  list.map(indices(n), fn(i) {
    Match(
      start: matcher_start_ffi(text, region, l, i),
      end: matcher_end_ffi(text, region, l, i),
      raw: matcher_raw_ffi(text, region, l, i),
    )
  })
}

/// How many numbers `find_numbers` would return.
pub fn matcher_count(text: String, region: String, leniency: Leniency) -> Int {
  matcher_count_ffi(text, region, leniency_code(leniency))
}

// ---- ShortNumberInfo (short / emergency numbers) ----
//
// Short numbers are dialled as-is (no country code, no national prefix): the
// input is the raw short number plus a region.

/// True if the short number is a possible length for the region.
pub fn short_is_possible(region: String, input: String) -> Bool {
  short_is_possible_ffi(region, input) != 0
}

/// True if the short number is valid (carrier-independent) for the region.
pub fn short_is_valid(region: String, input: String) -> Bool {
  short_is_valid_ffi(region, input) != 0
}

/// True if the short number is an emergency number for the region.
pub fn is_emergency_number(region: String, input: String) -> Bool {
  short_is_emergency_ffi(region, input) != 0
}

/// True if dialling the number would connect to an emergency service.
pub fn connects_to_emergency_number(region: String, input: String) -> Bool {
  short_connects_to_emergency_ffi(region, input) != 0
}

/// True if the short number is carrier-specific in the region.
pub fn short_is_carrier_specific(region: String, input: String) -> Bool {
  short_is_carrier_specific_ffi(region, input) != 0
}

/// True if the short number is for an SMS service in the region.
pub fn short_is_sms_service(region: String, input: String) -> Bool {
  short_is_sms_service_ffi(region, input) != 0
}

/// The `ShortNumberCost` for the short number (`TollFree`, …).
pub fn short_expected_cost(region: String, input: String) -> ShortNumberCost {
  cost_of_code(short_expected_cost_ffi(region, input))
}

/// The raw ABI ShortNumberCost code (0 toll-free, …).
pub fn short_expected_cost_code(region: String, input: String) -> Int {
  short_expected_cost_ffi(region, input)
}

/// An example short number for the region, or "".
pub fn short_example_number(region: String) -> String {
  short_example_number_ffi(region)
}

// ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----

/// The IANA time-zone ids for a number, as a list. When the engine knows no
/// zone (count 0) the result is a single-element list of the unknown zone,
/// mirroring the other bindings — never an empty list.
pub fn time_zones_for_number(region: String, input: String) -> List(String) {
  case tz_count_ffi(region, input) {
    0 -> [unknown_time_zone()]
    n -> list.map(indices(n), fn(i) { tz_at_ffi(region, input, i) })
  }
}

/// How many time zones the number maps to (0 = only the unknown zone).
pub fn time_zone_count(region: String, input: String) -> Int {
  tz_count_ffi(region, input)
}

/// The engine's sentinel unknown zone, "Etc/Unknown".
pub fn unknown_time_zone() -> String {
  tz_unknown_ffi()
}

// ---- PhoneNumberToCarrierMapper (localized carrier names) ----
//
// Gleam has no default arguments; the `_number` forms default the language to
// "en" (English, always available) and the `_in_language` forms take an ISO
// code. A language not compiled into the engine falls back to English.

/// The carrier name for a number in English, or "" if none is known.
pub fn carrier_name_for_number(region: String, input: String) -> String {
  carrier_name_ffi(region, input, "en")
}

/// The carrier name for a number, localized by `lang`, or "" if none is known.
pub fn carrier_name_for_number_in_language(
  region: String,
  input: String,
  lang: String,
) -> String {
  carrier_name_ffi(region, input, lang)
}

/// The carrier name (English), but only when the number is valid; else "".
pub fn carrier_name_for_valid_number(region: String, input: String) -> String {
  carrier_name_for_valid_ffi(region, input, "en")
}

/// The carrier name localized by `lang`, only when the number is valid; else "".
pub fn carrier_name_for_valid_number_in_language(
  region: String,
  input: String,
  lang: String,
) -> String {
  carrier_name_for_valid_ffi(region, input, lang)
}

// ---- PhoneNumberOfflineGeocoder (localized geographic descriptions) ----

/// A geographic description for a number in English, or "" if none is known.
pub fn geo_description_for_number(region: String, input: String) -> String {
  geo_description_ffi(region, input, "en")
}

/// A geographic description localized by `lang`, or "" if none is known.
pub fn geo_description_for_number_in_language(
  region: String,
  input: String,
  lang: String,
) -> String {
  geo_description_ffi(region, input, lang)
}

/// A geographic description (English), but only when the number is valid; else "".
pub fn geo_description_for_valid_number(region: String, input: String) -> String {
  geo_description_for_valid_ffi(region, input, "en")
}

/// A geographic description localized by `lang`, only when valid; else "".
pub fn geo_description_for_valid_number_in_language(
  region: String,
  input: String,
  lang: String,
) -> String {
  geo_description_for_valid_ffi(region, input, lang)
}

// ---- introspection ----

/// The engine's ABI revision (7).
pub fn abi_version() -> Int {
  abi_version_ffi()
}

/// The engine's ABI revision as a string, for display.
pub fn abi_version_string() -> String {
  int.to_string(abi_version_ffi())
}
