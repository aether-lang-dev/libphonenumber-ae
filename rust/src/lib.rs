//! Validate, parse and format international phone numbers.
//!
//! ```no_run
//! use phonenumber_ae as pn;
//!
//! let num = pn::parse("+1 650 253 0000", "US");
//! assert_eq!(num.national_number(), "6502530000");
//! assert!(pn::is_valid_number("US", "+1 650 253 0000"));
//! assert_eq!(pn::format("US", "6502530000", pn::INTERNATIONAL), "+1 650-253-0000");
//! ```
//!
//! This crate carries **no phone-number logic**. The engine — the metadata
//! table, `isPossible`/`isValid`, number-type classification, the formatter,
//! the AsYouType formatter, the matcher — is the pure-Aether
//! `core/phonenumber.ae`, shared by every language binding in this monorepo and
//! reached over the v7 `aether_pn_embed_*` C ABI (full `PhoneNumberUtil` parity
//! plus `ShortNumberInfo`, time zones, carrier names and geocoding). Everything here is
//! marshalling; see [`native`] for the 1:1 symbol table.
//!
//! The ABI is stateless — there is no handle, only caller-owned strings — so
//! the free functions [`country_code`], [`parse`], [`format`], etc. load a
//! process-wide engine on first use and are the simplest way in. The
//! [`PhoneNumbers`] type is the same surface over an engine you loaded from an
//! explicit path.

use std::ffi::{c_char, c_int};
use std::path::Path;
use std::sync::OnceLock;

pub mod native;

pub use native::{
    Error, E164, INTERNATIONAL, NATIONAL, RFC3966, TYPE_FIXED_LINE, TYPE_MOBILE, TYPE_PAGER,
    TYPE_PERSONAL_NUMBER, TYPE_PREMIUM_RATE, TYPE_SHARED_COST, TYPE_TOLL_FREE, TYPE_UAN,
    TYPE_FIXED_LINE_OR_MOBILE, TYPE_UNKNOWN, TYPE_VOICEMAIL, TYPE_VOIP,
    // ValidationResult
    VR_INVALID_COUNTRY_CODE, VR_INVALID_LENGTH, VR_IS_POSSIBLE, VR_IS_POSSIBLE_LOCAL_ONLY,
    VR_TOO_LONG, VR_TOO_SHORT,
    // MatchType
    MATCH_EXACT, MATCH_NO_MATCH, MATCH_NOT_A_NUMBER, MATCH_NSN, MATCH_SHORT_NSN,
    // CountryCodeSource
    SRC_FROM_DEFAULT_COUNTRY, SRC_FROM_NUMBER_WITH_IDD, SRC_FROM_NUMBER_WITH_PLUS,
    SRC_FROM_NUMBER_WITHOUT_PLUS,
    // Leniency
    LENIENCY_POSSIBLE, LENIENCY_VALID, LENIENCY_STRICT_GROUPING, LENIENCY_EXACT_GROUPING,
    // ShortNumberCost
    COST_TOLL_FREE, COST_STANDARD_RATE, COST_PREMIUM_RATE, COST_UNKNOWN,
};

use native::Api;

/// The kind of phone number, mirroring libphonenumber's `PhoneNumberType`.
///
/// [`NumberType::from_raw`] maps the ABI's `int` (`-1` and `0..=10`) onto this;
/// [`number_type`] returns the raw `i32` so no information is lost across the
/// FFI, and [`PhoneNumbers::number_type_enum`] is the typed convenience.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NumberType {
    Unknown,
    FixedLine,
    Mobile,
    TollFree,
    PremiumRate,
    SharedCost,
    Voip,
    PersonalNumber,
    Pager,
    Uan,
    Voicemail,
    FixedLineOrMobile,
}

impl NumberType {
    /// Map the ABI's `number_type` result onto the enum. Any value outside the
    /// documented range collapses to [`NumberType::Unknown`].
    pub fn from_raw(raw: i32) -> NumberType {
        match raw {
            TYPE_FIXED_LINE => NumberType::FixedLine,
            TYPE_MOBILE => NumberType::Mobile,
            TYPE_TOLL_FREE => NumberType::TollFree,
            TYPE_PREMIUM_RATE => NumberType::PremiumRate,
            TYPE_SHARED_COST => NumberType::SharedCost,
            TYPE_VOIP => NumberType::Voip,
            TYPE_PERSONAL_NUMBER => NumberType::PersonalNumber,
            TYPE_PAGER => NumberType::Pager,
            TYPE_UAN => NumberType::Uan,
            TYPE_VOICEMAIL => NumberType::Voicemail,
            TYPE_FIXED_LINE_OR_MOBILE => NumberType::FixedLineOrMobile,
            _ => NumberType::Unknown,
        }
    }

    /// The raw ABI value for this type.
    pub fn as_raw(self) -> i32 {
        match self {
            NumberType::Unknown => TYPE_UNKNOWN,
            NumberType::FixedLine => TYPE_FIXED_LINE,
            NumberType::Mobile => TYPE_MOBILE,
            NumberType::TollFree => TYPE_TOLL_FREE,
            NumberType::PremiumRate => TYPE_PREMIUM_RATE,
            NumberType::SharedCost => TYPE_SHARED_COST,
            NumberType::Voip => TYPE_VOIP,
            NumberType::PersonalNumber => TYPE_PERSONAL_NUMBER,
            NumberType::Pager => TYPE_PAGER,
            NumberType::Uan => TYPE_UAN,
            NumberType::Voicemail => TYPE_VOICEMAIL,
            NumberType::FixedLineOrMobile => TYPE_FIXED_LINE_OR_MOBILE,
        }
    }
}

/// The format style passed to [`format`], mirroring libphonenumber's
/// `PhoneNumberFormat`. The raw ABI constants ([`E164`], [`INTERNATIONAL`],
/// [`NATIONAL`], [`RFC3966`]) are also exported for callers who prefer them.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Format {
    E164,
    International,
    National,
    Rfc3966,
}

impl Format {
    pub fn as_raw(self) -> i32 {
        match self {
            Format::E164 => E164,
            Format::International => INTERNATIONAL,
            Format::National => NATIONAL,
            Format::Rfc3966 => RFC3966,
        }
    }
}

/// The outcome of [`is_possible_number_with_reason`], mirroring
/// libphonenumber's `ValidationResult`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ValidationResult {
    IsPossible,
    IsPossibleLocalOnly,
    InvalidCountryCode,
    TooShort,
    InvalidLength,
    TooLong,
}

impl ValidationResult {
    /// Map the ABI's `is_possible_number_with_reason` result onto the enum.
    /// An unrecognized value collapses to [`ValidationResult::IsPossible`].
    pub fn from_raw(raw: i32) -> ValidationResult {
        match raw {
            VR_IS_POSSIBLE_LOCAL_ONLY => ValidationResult::IsPossibleLocalOnly,
            VR_INVALID_COUNTRY_CODE => ValidationResult::InvalidCountryCode,
            VR_TOO_SHORT => ValidationResult::TooShort,
            VR_INVALID_LENGTH => ValidationResult::InvalidLength,
            VR_TOO_LONG => ValidationResult::TooLong,
            _ => ValidationResult::IsPossible,
        }
    }
}

/// The outcome of [`is_number_match`], mirroring libphonenumber's `MatchType`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MatchType {
    NotANumber,
    NoMatch,
    ShortNsn,
    Nsn,
    Exact,
}

impl MatchType {
    /// Map the ABI's `is_number_match` result onto the enum. An unrecognized
    /// value collapses to [`MatchType::NotANumber`].
    pub fn from_raw(raw: i32) -> MatchType {
        match raw {
            MATCH_NO_MATCH => MatchType::NoMatch,
            MATCH_SHORT_NSN => MatchType::ShortNsn,
            MATCH_NSN => MatchType::Nsn,
            MATCH_EXACT => MatchType::Exact,
            _ => MatchType::NotANumber,
        }
    }
}

/// Where the country calling code came from when a number was parsed,
/// mirroring libphonenumber's `CountryCodeSource` ([`ParsedNumber::source`]).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CountryCodeSource {
    FromNumberWithPlus,
    FromNumberWithIdd,
    FromNumberWithoutPlus,
    FromDefaultCountry,
}

impl CountryCodeSource {
    /// Map the ABI's `pn_source` result onto the enum. An unrecognized value
    /// collapses to [`CountryCodeSource::FromDefaultCountry`].
    pub fn from_raw(raw: i32) -> CountryCodeSource {
        match raw {
            SRC_FROM_NUMBER_WITH_PLUS => CountryCodeSource::FromNumberWithPlus,
            SRC_FROM_NUMBER_WITH_IDD => CountryCodeSource::FromNumberWithIdd,
            SRC_FROM_NUMBER_WITHOUT_PLUS => CountryCodeSource::FromNumberWithoutPlus,
            _ => CountryCodeSource::FromDefaultCountry,
        }
    }
}

/// How hard a number in free text has to look like a phone number for
/// [`find_numbers`] to report it, mirroring libphonenumber's `Leniency`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Leniency {
    Possible,
    Valid,
    /// The candidate's digit grouping must match a format the region
    /// recognises (a MAIN or an alternate format).
    StrictGrouping,
    /// Like [`Leniency::StrictGrouping`] but the grouping must match a MAIN
    /// format exactly.
    ExactGrouping,
}

impl Leniency {
    pub fn as_raw(self) -> i32 {
        match self {
            Leniency::Possible => LENIENCY_POSSIBLE,
            Leniency::Valid => LENIENCY_VALID,
            Leniency::StrictGrouping => LENIENCY_STRICT_GROUPING,
            Leniency::ExactGrouping => LENIENCY_EXACT_GROUPING,
        }
    }
}

/// The expected cost of dialling a short number, mirroring libphonenumber's
/// `ShortNumberInfo.ShortNumberCost` ([`PhoneNumbers::short_expected_cost_enum`]).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Cost {
    TollFree,
    StandardRate,
    PremiumRate,
    Unknown,
}

impl Cost {
    /// Map the ABI's `short_expected_cost` result onto the enum. An
    /// unrecognized value collapses to [`Cost::Unknown`].
    pub fn from_raw(raw: i32) -> Cost {
        match raw {
            COST_TOLL_FREE => Cost::TollFree,
            COST_STANDARD_RATE => Cost::StandardRate,
            COST_PREMIUM_RATE => Cost::PremiumRate,
            _ => Cost::Unknown,
        }
    }

    /// The raw ABI value for this cost.
    pub fn as_raw(self) -> i32 {
        match self {
            Cost::TollFree => COST_TOLL_FREE,
            Cost::StandardRate => COST_STANDARD_RATE,
            Cost::PremiumRate => COST_PREMIUM_RATE,
            Cost::Unknown => COST_UNKNOWN,
        }
    }
}

/// A loaded phonenumber engine.
///
/// The engine holds no mutable state, so a `PhoneNumbers` is just the resolved
/// symbol table plus the `dlopen` handle that keeps it mapped. Use
/// [`PhoneNumbers::new`] for the default resolution order, or
/// [`PhoneNumbers::with_library`] to load a specific `.so`. Most callers can
/// skip this type and use the crate-level free functions, which share one
/// process-wide engine.
pub struct PhoneNumbers {
    api: Api,
}

impl PhoneNumbers {
    /// Load the engine (see [`native::Api::load`] for the resolution order).
    pub fn new() -> Result<PhoneNumbers, Error> {
        PhoneNumbers::with_library(None)
    }

    /// As [`PhoneNumbers::new`], but loading the engine from an explicit path.
    pub fn with_library(path: Option<&Path>) -> Result<PhoneNumbers, Error> {
        Ok(PhoneNumbers {
            api: Api::load(path)?,
        })
    }

    /// The ABI revision the loaded engine reports (5 for this crate).
    pub fn abi_version(&self) -> i32 {
        unsafe { (self.api.abi_version)() }
    }

    // ---- region metadata ----

    /// The country calling code for a region (`"1"`, `"44"`, …), or `""` if the
    /// region is unknown.
    pub fn country_code(&self, region: &str) -> String {
        self.str_1(self.api.country_code, region)
    }

    /// An example national number for the region, or `""`.
    pub fn example_number(&self, region: &str) -> String {
        self.str_1(self.api.example_number, region)
    }

    /// An example national number of a given [`NumberType`] for the region
    /// (pass a `TYPE_*` constant or [`NumberType::as_raw`]), or `""`.
    pub fn example_number_for_type(&self, region: &str, ntype: i32) -> String {
        let r = match native::to_c(region) {
            Ok(r) => r,
            Err(_) => return String::new(),
        };
        unsafe {
            self.api
                .take_string((self.api.example_number_for_type)(r.as_ptr(), ntype as c_int))
        }
    }

    /// An example number that is *not* valid for the region, or `""`.
    pub fn invalid_example_number(&self, region: &str) -> String {
        self.str_1(self.api.invalid_example_number, region)
    }

    /// The possible-lengths spec for the region (e.g. `"10"`), or `""`.
    pub fn possible_lengths(&self, region: &str) -> String {
        self.str_1(self.api.possible_lengths, region)
    }

    /// The main region id for a country calling code (`"44"` → `"GB"`), or `""`.
    pub fn region_code_for_country_code(&self, cc: &str) -> String {
        self.str_1(self.api.region_code_for_country_code, cc)
    }

    /// `true` if the region belongs to the North American Numbering Plan.
    pub fn is_nanpa_country(&self, region: &str) -> bool {
        self.int_1(self.api.is_nanpa_country, region) != 0
    }

    /// The national-direct-dialling prefix for the region (e.g. `"0"`), or `""`.
    /// When `strip_non_digits` is set, punctuation such as `~` is removed.
    pub fn ndd_prefix_for_region(&self, region: &str, strip_non_digits: bool) -> String {
        let r = match native::to_c(region) {
            Ok(r) => r,
            Err(_) => return String::new(),
        };
        unsafe {
            self.api.take_string((self.api.ndd_prefix_for_region)(
                r.as_ptr(),
                if strip_non_digits { 1 } else { 0 },
            ))
        }
    }

    /// How many regions the metadata carries.
    pub fn region_count(&self) -> i32 {
        unsafe { (self.api.region_count)() }
    }

    /// The i-th region id, or `""` if out of range.
    pub fn region_at(&self, index: i32) -> String {
        unsafe { self.api.take_string((self.api.region_at)(index as c_int)) }
    }

    /// Every region id the metadata carries, as ISO-3166 alpha-2 codes.
    pub fn regions(&self) -> Vec<String> {
        let n = self.region_count();
        (0..n).map(|i| self.region_at(i)).collect()
    }

    /// Every region that shares a country calling code, main region first
    /// (`"1"` → `["US", "CA", …]`).
    pub fn regions_for_country_code(&self, cc: &str) -> Vec<String> {
        let c = match native::to_c(cc) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let n = unsafe { (self.api.cc_region_count)(c.as_ptr()) };
        (0..n)
            .map(|i| unsafe { self.api.take_string((self.api.cc_region_at)(c.as_ptr(), i)) })
            .collect()
    }

    // ---- parse + accessors ----

    /// Parse raw input as dialled from `region`. The result is a
    /// [`ParsedNumber`] whose fields are read on demand; check
    /// [`ParsedNumber::error`] for a parse failure.
    pub fn parse(&self, input: &str, region: &str) -> ParsedNumber<'_> {
        let pn = self.str_2(self.api.parse, input, region);
        ParsedNumber { api: &self.api, pn }
    }

    /// The national number extracted from raw input (country code and
    /// punctuation stripped).
    pub fn national_number(&self, region: &str, input: &str) -> String {
        self.str_2(self.api.national_number, region, input)
    }

    // ---- validation ----

    /// `true` if the national number is a length the region allows.
    pub fn is_possible_number(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.is_possible_number, region, input) != 0
    }

    /// Why a number is or isn't possible, as a raw [`ValidationResult`] `i32`.
    pub fn is_possible_number_with_reason(&self, region: &str, input: &str) -> i32 {
        self.int_2(self.api.is_possible_number_with_reason, region, input)
    }

    /// Why a number is or isn't possible, as the typed [`ValidationResult`].
    pub fn is_possible_number_with_reason_enum(
        &self,
        region: &str,
        input: &str,
    ) -> ValidationResult {
        ValidationResult::from_raw(self.is_possible_number_with_reason(region, input))
    }

    /// `true` if the number matches the region's national-number patterns.
    pub fn is_valid_number(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.is_valid_number, region, input) != 0
    }

    /// `true` if the number is valid *and* the region is one the number could
    /// belong to. Note the argument order — `(input, region)`.
    pub fn is_valid_number_for_region(&self, input: &str, region: &str) -> bool {
        self.int_2(self.api.is_valid_number_for_region, input, region) != 0
    }

    /// The [`PhoneNumberType`](NumberType) as a raw `i32` (a `TYPE_*` constant;
    /// `-1` for unknown), exactly as the ABI reports it.
    pub fn number_type(&self, region: &str, input: &str) -> i32 {
        self.int_2(self.api.number_type, region, input)
    }

    /// The number type as the typed [`NumberType`] enum.
    pub fn number_type_enum(&self, region: &str, input: &str) -> NumberType {
        NumberType::from_raw(self.number_type(region, input))
    }

    /// `true` if the number can be dialled from outside its own country.
    pub fn can_be_internationally_dialled(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.can_be_internationally_dialled, region, input) != 0
    }

    // ---- formatting ----

    /// Format the number in the given style ([`NATIONAL`], [`INTERNATIONAL`],
    /// [`E164`] or [`RFC3966`]). Any other value is treated as `NATIONAL`.
    pub fn format(&self, region: &str, input: &str, style: i32) -> String {
        let (r, i) = match (native::to_c(region), native::to_c(input)) {
            (Ok(r), Ok(i)) => (r, i),
            _ => return String::new(),
        };
        unsafe {
            self.api
                .take_string((self.api.format)(r.as_ptr(), i.as_ptr(), style as c_int))
        }
    }

    /// Format in [`NATIONAL`] style.
    pub fn format_national(&self, region: &str, input: &str) -> String {
        self.format(region, input, NATIONAL)
    }

    /// Format in [`INTERNATIONAL`] style.
    pub fn format_international(&self, region: &str, input: &str) -> String {
        self.format(region, input, INTERNATIONAL)
    }

    /// Format in [`E164`] style.
    pub fn format_e164(&self, region: &str, input: &str) -> String {
        self.format(region, input, E164)
    }

    /// Format in [`RFC3966`] style.
    pub fn format_rfc3966(&self, region: &str, input: &str) -> String {
        self.format(region, input, RFC3966)
    }

    /// Format the number as it would be dialled from `calling_from`.
    pub fn format_out_of_country(&self, region: &str, input: &str, calling_from: &str) -> String {
        let (r, i, c) = match (
            native::to_c(region),
            native::to_c(input),
            native::to_c(calling_from),
        ) {
            (Ok(r), Ok(i), Ok(c)) => (r, i, c),
            _ => return String::new(),
        };
        unsafe {
            self.api.take_string((self.api.format_out_of_country)(
                r.as_ptr(),
                i.as_ptr(),
                c.as_ptr(),
            ))
        }
    }

    // ---- relations / helpers ----

    /// How well two numbers match, as a raw [`MatchType`] `i32`.
    pub fn is_number_match(&self, a: &str, b: &str) -> i32 {
        self.int_2(self.api.is_number_match, a, b)
    }

    /// How well two numbers match, as the typed [`MatchType`].
    pub fn is_number_match_enum(&self, a: &str, b: &str) -> MatchType {
        MatchType::from_raw(self.is_number_match(a, b))
    }

    /// Drop trailing digits until the number is no longer too long for its
    /// region, returning the truncated national number.
    pub fn truncate_too_long(&self, region: &str, input: &str) -> String {
        self.str_2(self.api.truncate_too_long, region, input)
    }

    /// Keep only the digits of `s` (converting Unicode digits to ASCII).
    pub fn normalize_digits_only(&self, s: &str) -> String {
        self.str_1(self.api.normalize_digits_only, s)
    }

    /// Replace vanity letters with their dialpad digits (`"800-FLOWERS"` →
    /// `"800-3569377"`), leaving punctuation in place.
    pub fn convert_alpha_characters(&self, s: &str) -> String {
        self.str_1(self.api.convert_alpha_characters, s)
    }

    /// `true` if `s` contains vanity letters (and so needs conversion).
    pub fn is_alpha_number(&self, s: &str) -> bool {
        self.int_1(self.api.is_alpha_number, s) != 0
    }

    // ---- stateful surfaces ----

    /// A fresh [`AsYouTypeFormatter`] for `region`.
    pub fn as_you_type_formatter(&self, region: &str) -> AsYouTypeFormatter<'_> {
        AsYouTypeFormatter::new(&self.api, region)
    }

    /// Find phone numbers in free text, at the given [`Leniency`] (pass a
    /// `LENIENCY_*` constant or [`Leniency::as_raw`]).
    pub fn find_numbers(&self, text: &str, region: &str, leniency: i32) -> Vec<Match> {
        let (t, r) = match (native::to_c(text), native::to_c(region)) {
            (Ok(t), Ok(r)) => (t, r),
            _ => return Vec::new(),
        };
        let n = unsafe { (self.api.matcher_count)(t.as_ptr(), r.as_ptr(), leniency as c_int) };
        (0..n)
            .map(|i| {
                let start =
                    unsafe { (self.api.matcher_start)(t.as_ptr(), r.as_ptr(), leniency as c_int, i) };
                let end =
                    unsafe { (self.api.matcher_end)(t.as_ptr(), r.as_ptr(), leniency as c_int, i) };
                let raw = unsafe {
                    self.api.take_string((self.api.matcher_raw)(
                        t.as_ptr(),
                        r.as_ptr(),
                        leniency as c_int,
                        i,
                    ))
                };
                Match { start, end, raw }
            })
            .collect()
    }

    // ---- ShortNumberInfo (short / emergency numbers) ----
    //
    // Short numbers are dialled as-is: no country code, no national prefix.
    // Each takes the raw short number plus a region.

    /// `true` if the short number is a possible length for the region.
    pub fn short_is_possible(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.short_is_possible, region, input) != 0
    }

    /// `true` if the short number matches a short-number pattern for the region.
    pub fn short_is_valid(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.short_is_valid, region, input) != 0
    }

    /// `true` if the number is an emergency number for the region (e.g. `"911"`
    /// in the US, `"999"` in the GB).
    pub fn is_emergency_number(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.short_is_emergency, region, input) != 0
    }

    /// `true` if dialling the number connects to an emergency service in the
    /// region (looser than [`PhoneNumbers::is_emergency_number`]).
    pub fn connects_to_emergency_number(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.short_connects_to_emergency, region, input) != 0
    }

    /// `true` if the short number is carrier-specific.
    pub fn short_is_carrier_specific(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.short_is_carrier_specific, region, input) != 0
    }

    /// `true` if the short number is an SMS short code for the region.
    pub fn short_is_sms_service(&self, region: &str, input: &str) -> bool {
        self.int_2(self.api.short_is_sms_service, region, input) != 0
    }

    /// The expected cost of the short number as a raw [`Cost`] `i32` (a `COST_*`
    /// constant), exactly as the ABI reports it.
    pub fn short_expected_cost(&self, region: &str, input: &str) -> i32 {
        self.int_2(self.api.short_expected_cost, region, input)
    }

    /// The expected cost of the short number as the typed [`Cost`] enum.
    pub fn short_expected_cost_enum(&self, region: &str, input: &str) -> Cost {
        Cost::from_raw(self.short_expected_cost(region, input))
    }

    /// An example short number for the region, or `""`.
    pub fn short_example_number(&self, region: &str) -> String {
        self.str_1(self.api.short_example_number, region)
    }

    // ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----
    //
    // The engine parses the raw `(region, input)` to E.164 itself, then does a
    // longest-prefix match over its digits. The unknown-zone sentinel is
    // `"Etc/Unknown"`.

    /// The IANA time-zone ids a number maps to. A number with no known zone
    /// maps to a single-element `vec!["Etc/Unknown".to_string()]`.
    pub fn time_zones_for_number(&self, region: &str, input: &str) -> Vec<String> {
        let (r, i) = match (native::to_c(region), native::to_c(input)) {
            (Ok(r), Ok(i)) => (r, i),
            _ => return vec![self.unknown_time_zone()],
        };
        let n = unsafe { (self.api.tz_count)(r.as_ptr(), i.as_ptr()) };
        if n == 0 {
            return vec![self.unknown_time_zone()];
        }
        (0..n)
            .map(|idx| unsafe { self.api.take_string((self.api.tz_at)(r.as_ptr(), i.as_ptr(), idx)) })
            .collect()
    }

    /// How many time zones a number maps to (`0` = only the unknown zone).
    pub fn time_zone_count(&self, region: &str, input: &str) -> i32 {
        self.int_2(self.api.tz_count, region, input)
    }

    /// The unknown-zone sentinel, `"Etc/Unknown"`.
    pub fn unknown_time_zone(&self) -> String {
        unsafe { self.api.take_string((self.api.tz_unknown)()) }
    }

    // ---- PhoneNumberToCarrierMapper (localized carrier names) ----

    /// The carrier name for a number, or `""` if no carrier is known.
    ///
    /// `lang` is an optional ISO language code (`"en"`, `"de"`, `"fr"`, …);
    /// pass `None` (or omit via `.into()`) for the default `"en"`, which is
    /// always available and the fallback for any language the engine lacks.
    pub fn carrier_name_for_number<'a>(
        &self,
        region: &str,
        input: &str,
        lang: impl Into<Option<&'a str>>,
    ) -> String {
        self.str_3(self.api.carrier_name, region, input, lang.into().unwrap_or("en"))
    }

    /// The carrier name only when the number is valid, else `""`. `lang` is an
    /// optional ISO code; `None` selects the default `"en"`.
    pub fn carrier_name_for_valid_number<'a>(
        &self,
        region: &str,
        input: &str,
        lang: impl Into<Option<&'a str>>,
    ) -> String {
        self.str_3(
            self.api.carrier_name_for_valid,
            region,
            input,
            lang.into().unwrap_or("en"),
        )
    }

    // ---- PhoneNumberOfflineGeocoder (localized geographic descriptions) ----

    /// The geographic description for a number, or `""` if none is known.
    /// `lang` is an optional ISO code; `None` selects the default `"en"`.
    pub fn geo_description_for_number<'a>(
        &self,
        region: &str,
        input: &str,
        lang: impl Into<Option<&'a str>>,
    ) -> String {
        self.str_3(self.api.geo_description, region, input, lang.into().unwrap_or("en"))
    }

    /// The geographic description only when the number is valid, else `""`.
    /// `lang` is an optional ISO code; `None` selects the default `"en"`.
    pub fn geo_description_for_valid_number<'a>(
        &self,
        region: &str,
        input: &str,
        lang: impl Into<Option<&'a str>>,
    ) -> String {
        self.str_3(
            self.api.geo_description_for_valid,
            region,
            input,
            lang.into().unwrap_or("en"),
        )
    }

    // ---- marshalling helpers ----

    fn str_1(&self, f: unsafe extern "C" fn(*const c_char) -> *mut c_char, a: &str) -> String {
        let a = match native::to_c(a) {
            Ok(a) => a,
            Err(_) => return String::new(),
        };
        unsafe { self.api.take_string(f(a.as_ptr())) }
    }

    fn str_2(
        &self,
        f: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
        a: &str,
        b: &str,
    ) -> String {
        let (a, b) = match (native::to_c(a), native::to_c(b)) {
            (Ok(a), Ok(b)) => (a, b),
            _ => return String::new(),
        };
        unsafe { self.api.take_string(f(a.as_ptr(), b.as_ptr())) }
    }

    fn str_3(
        &self,
        f: unsafe extern "C" fn(*const c_char, *const c_char, *const c_char) -> *mut c_char,
        a: &str,
        b: &str,
        c: &str,
    ) -> String {
        let (a, b, c) = match (native::to_c(a), native::to_c(b), native::to_c(c)) {
            (Ok(a), Ok(b), Ok(c)) => (a, b, c),
            _ => return String::new(),
        };
        unsafe { self.api.take_string(f(a.as_ptr(), b.as_ptr(), c.as_ptr())) }
    }

    fn int_1(&self, f: unsafe extern "C" fn(*const c_char) -> c_int, a: &str) -> i32 {
        let a = match native::to_c(a) {
            Ok(a) => a,
            Err(_) => return 0,
        };
        unsafe { f(a.as_ptr()) }
    }

    fn int_2(
        &self,
        f: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
        a: &str,
        b: &str,
    ) -> i32 {
        let (a, b) = match (native::to_c(a), native::to_c(b)) {
            (Ok(a), Ok(b)) => (a, b),
            _ => return 0,
        };
        unsafe { f(a.as_ptr(), b.as_ptr()) }
    }
}

// The engine has no global mutable state; loading it twice just maps it twice.
// A shared `PhoneNumbers` is safe to call from many threads.
unsafe impl Send for PhoneNumbers {}
unsafe impl Sync for PhoneNumbers {}

/// A parsed phone number.
///
/// Wraps the caller-owned parsed-number string the ABI's `parse` returns and
/// borrows the engine it came from; its fields are read on demand through the
/// `pn_*` accessors. Check [`ParsedNumber::error`] to detect a parse failure.
pub struct ParsedNumber<'a> {
    api: &'a Api,
    pn: String,
}

impl ParsedNumber<'_> {
    /// The parsed-number string as the ABI returned it. Rarely needed
    /// directly; the accessors below read individual fields.
    pub fn as_str(&self) -> &str {
        &self.pn
    }

    fn acc_str(&self, f: unsafe extern "C" fn(*const c_char) -> *mut c_char) -> String {
        let p = match native::to_c(&self.pn) {
            Ok(p) => p,
            Err(_) => return String::new(),
        };
        unsafe { self.api.take_string(f(p.as_ptr())) }
    }

    fn acc_int(&self, f: unsafe extern "C" fn(*const c_char) -> c_int) -> i32 {
        let p = match native::to_c(&self.pn) {
            Ok(p) => p,
            Err(_) => return 0,
        };
        unsafe { f(p.as_ptr()) }
    }

    /// The default region the number was parsed against.
    pub fn region(&self) -> String {
        self.acc_str(self.api.pn_region)
    }

    /// The country calling code, e.g. `"1"`.
    pub fn country_code(&self) -> String {
        self.acc_str(self.api.pn_country_code)
    }

    /// The national number, digits only.
    pub fn national_number(&self) -> String {
        self.acc_str(self.api.pn_national_number)
    }

    /// The extension, or `""`.
    pub fn extension(&self) -> String {
        self.acc_str(self.api.pn_extension)
    }

    /// `true` if the number preserves a leading zero (the Italian-leading-zero
    /// flag).
    pub fn italian_leading_zero(&self) -> bool {
        self.acc_int(self.api.pn_italian_leading_zero) != 0
    }

    /// Where the country code came from, as a raw [`CountryCodeSource`] `i32`.
    pub fn source(&self) -> i32 {
        self.acc_int(self.api.pn_source)
    }

    /// Where the country code came from, as the typed [`CountryCodeSource`].
    pub fn source_enum(&self) -> CountryCodeSource {
        CountryCodeSource::from_raw(self.source())
    }

    /// A non-empty message if the parse failed, `""` otherwise.
    pub fn error(&self) -> String {
        self.acc_str(self.api.pn_error)
    }

    /// The region the number itself resolves to (which may differ from the
    /// region it was parsed against), or `""`.
    pub fn region_code(&self) -> String {
        self.acc_str(self.api.region_code_for_number)
    }

    /// The national significant number.
    pub fn national_significant_number(&self) -> String {
        self.acc_str(self.api.national_significant_number)
    }

    /// The length of the national destination code, or `0`.
    pub fn length_of_ndc(&self) -> i32 {
        self.acc_int(self.api.length_of_ndc)
    }

    /// The length of the area code, or `0`.
    pub fn length_of_area_code(&self) -> i32 {
        self.acc_int(self.api.length_of_area_code)
    }

    /// `true` if the number is geographically bound (a fixed line or similar).
    pub fn is_geographical(&self) -> bool {
        self.acc_int(self.api.is_geographical) != 0
    }

    /// Format this parsed number the way it was originally dialled, as seen
    /// from `calling_from`.
    pub fn format_in_original(&self, calling_from: &str) -> String {
        let (p, c) = match (native::to_c(&self.pn), native::to_c(calling_from)) {
            (Ok(p), Ok(c)) => (p, c),
            _ => return String::new(),
        };
        unsafe {
            self.api
                .take_string((self.api.format_in_original)(p.as_ptr(), c.as_ptr()))
        }
    }
}

/// Formats a number in the style of the region as it is typed, digit by digit.
///
/// The ABI threads the formatter's state as a caller-owned string; this type
/// owns that string and borrows the engine. Feed characters with
/// [`AsYouTypeFormatter::input_digit`] and read the running result it returns
/// (or [`AsYouTypeFormatter::result`]); [`AsYouTypeFormatter::clear`] resets it.
pub struct AsYouTypeFormatter<'a> {
    api: &'a Api,
    state: String,
}

impl<'a> AsYouTypeFormatter<'a> {
    fn new(api: &'a Api, region: &str) -> AsYouTypeFormatter<'a> {
        let r = native::to_c(region).unwrap_or_default();
        let state = unsafe { api.take_string((api.ayt_new)(r.as_ptr())) };
        AsYouTypeFormatter { api, state }
    }

    /// Feed one character and return the formatted-so-far string.
    pub fn input_digit(&mut self, ch: char) -> String {
        let mut buf = [0u8; 4];
        let ch_str = ch.encode_utf8(&mut buf);
        let (s, c) = match (native::to_c(&self.state), native::to_c(ch_str)) {
            (Ok(s), Ok(c)) => (s, c),
            _ => return self.result(),
        };
        self.state = unsafe {
            self.api
                .take_string((self.api.ayt_input)(s.as_ptr(), c.as_ptr()))
        };
        self.result()
    }

    /// The formatted-so-far string, without feeding anything new.
    pub fn result(&self) -> String {
        let s = match native::to_c(&self.state) {
            Ok(s) => s,
            Err(_) => return String::new(),
        };
        unsafe { self.api.take_string((self.api.ayt_result)(s.as_ptr())) }
    }

    /// Reset the formatter to empty.
    pub fn clear(&mut self) {
        let s = match native::to_c(&self.state) {
            Ok(s) => s,
            Err(_) => return,
        };
        self.state = unsafe { self.api.take_string((self.api.ayt_clear)(s.as_ptr())) };
    }
}

/// One phone number found in free text by [`find_numbers`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Match {
    /// The start offset of the match in the source text.
    pub start: i32,
    /// The end offset (exclusive) of the match in the source text.
    pub end: i32,
    /// The matched text, exactly as it appeared.
    pub raw: String,
}

// ---- the process-wide default engine, behind the free functions ----

fn shared() -> &'static PhoneNumbers {
    static ENGINE: OnceLock<PhoneNumbers> = OnceLock::new();
    ENGINE.get_or_init(|| {
        PhoneNumbers::new()
            .expect("could not load the phonenumber engine (set LIBPHONENUMBER_AE_LIB)")
    })
}

/// The ABI revision the loaded engine reports (5 for this crate).
pub fn abi_version() -> i32 {
    shared().abi_version()
}

/// The country calling code for a region (`"1"`, `"44"`, …), or `""` if unknown.
pub fn country_code(region: &str) -> String {
    shared().country_code(region)
}

/// An example national number for the region, or `""`.
pub fn example_number(region: &str) -> String {
    shared().example_number(region)
}

/// An example national number of a given [`NumberType`] for the region, or `""`.
pub fn example_number_for_type(region: &str, ntype: i32) -> String {
    shared().example_number_for_type(region, ntype)
}

/// An example number that is *not* valid for the region, or `""`.
pub fn invalid_example_number(region: &str) -> String {
    shared().invalid_example_number(region)
}

/// The possible-lengths spec for the region (e.g. `"10"`), or `""`.
pub fn possible_lengths(region: &str) -> String {
    shared().possible_lengths(region)
}

/// The main region id for a country calling code (`"44"` → `"GB"`), or `""`.
pub fn region_code_for_country_code(cc: &str) -> String {
    shared().region_code_for_country_code(cc)
}

/// `true` if the region belongs to the North American Numbering Plan.
pub fn is_nanpa_country(region: &str) -> bool {
    shared().is_nanpa_country(region)
}

/// The national-direct-dialling prefix for the region, or `""`.
pub fn ndd_prefix_for_region(region: &str, strip_non_digits: bool) -> String {
    shared().ndd_prefix_for_region(region, strip_non_digits)
}

/// How many regions the metadata carries.
pub fn region_count() -> i32 {
    shared().region_count()
}

/// The i-th region id, or `""` if out of range.
pub fn region_at(index: i32) -> String {
    shared().region_at(index)
}

/// Every region id the metadata carries, as ISO-3166 alpha-2 codes.
pub fn regions() -> Vec<String> {
    shared().regions()
}

/// Every region that shares a country calling code, main region first.
pub fn regions_for_country_code(cc: &str) -> Vec<String> {
    shared().regions_for_country_code(cc)
}

/// Parse raw input as dialled from `region`; check [`ParsedNumber::error`].
pub fn parse(input: &str, region: &str) -> ParsedNumber<'static> {
    shared().parse(input, region)
}

/// The national number extracted from raw input.
pub fn national_number(region: &str, input: &str) -> String {
    shared().national_number(region, input)
}

/// `true` if the national number is a length the region allows.
pub fn is_possible_number(region: &str, input: &str) -> bool {
    shared().is_possible_number(region, input)
}

/// Why a number is or isn't possible, as a raw [`ValidationResult`] `i32`.
pub fn is_possible_number_with_reason(region: &str, input: &str) -> i32 {
    shared().is_possible_number_with_reason(region, input)
}

/// Why a number is or isn't possible, as the typed [`ValidationResult`].
pub fn is_possible_number_with_reason_enum(region: &str, input: &str) -> ValidationResult {
    shared().is_possible_number_with_reason_enum(region, input)
}

/// `true` if the number matches the region's national-number patterns.
pub fn is_valid_number(region: &str, input: &str) -> bool {
    shared().is_valid_number(region, input)
}

/// `true` if the number is valid for the given region. Argument order is
/// `(input, region)`.
pub fn is_valid_number_for_region(input: &str, region: &str) -> bool {
    shared().is_valid_number_for_region(input, region)
}

/// The number type as a raw `i32` (`TYPE_*`; `-1` unknown).
pub fn number_type(region: &str, input: &str) -> i32 {
    shared().number_type(region, input)
}

/// The number type as the typed [`NumberType`] enum.
pub fn number_type_enum(region: &str, input: &str) -> NumberType {
    shared().number_type_enum(region, input)
}

/// `true` if the number can be dialled from outside its own country.
pub fn can_be_internationally_dialled(region: &str, input: &str) -> bool {
    shared().can_be_internationally_dialled(region, input)
}

/// Format the number in the given style ([`NATIONAL`] / [`INTERNATIONAL`] /
/// [`E164`] / [`RFC3966`]).
pub fn format(region: &str, input: &str, style: i32) -> String {
    shared().format(region, input, style)
}

/// Format in [`NATIONAL`] style.
pub fn format_national(region: &str, input: &str) -> String {
    shared().format_national(region, input)
}

/// Format in [`INTERNATIONAL`] style.
pub fn format_international(region: &str, input: &str) -> String {
    shared().format_international(region, input)
}

/// Format in [`E164`] style.
pub fn format_e164(region: &str, input: &str) -> String {
    shared().format_e164(region, input)
}

/// Format in [`RFC3966`] style.
pub fn format_rfc3966(region: &str, input: &str) -> String {
    shared().format_rfc3966(region, input)
}

/// Format the number as it would be dialled from `calling_from`.
pub fn format_out_of_country(region: &str, input: &str, calling_from: &str) -> String {
    shared().format_out_of_country(region, input, calling_from)
}

/// How well two numbers match, as a raw [`MatchType`] `i32`.
pub fn is_number_match(a: &str, b: &str) -> i32 {
    shared().is_number_match(a, b)
}

/// How well two numbers match, as the typed [`MatchType`].
pub fn is_number_match_enum(a: &str, b: &str) -> MatchType {
    shared().is_number_match_enum(a, b)
}

/// Drop trailing digits until the number is no longer too long for its region.
pub fn truncate_too_long(region: &str, input: &str) -> String {
    shared().truncate_too_long(region, input)
}

/// Keep only the digits of `s`.
pub fn normalize_digits_only(s: &str) -> String {
    shared().normalize_digits_only(s)
}

/// Replace vanity letters with their dialpad digits.
pub fn convert_alpha_characters(s: &str) -> String {
    shared().convert_alpha_characters(s)
}

/// `true` if `s` contains vanity letters.
pub fn is_alpha_number(s: &str) -> bool {
    shared().is_alpha_number(s)
}

/// A fresh [`AsYouTypeFormatter`] for `region`, over the shared engine.
pub fn as_you_type_formatter(region: &str) -> AsYouTypeFormatter<'static> {
    shared().as_you_type_formatter(region)
}

/// Find phone numbers in free text at the given [`Leniency`], over the shared
/// engine.
pub fn find_numbers(text: &str, region: &str, leniency: i32) -> Vec<Match> {
    shared().find_numbers(text, region, leniency)
}

// ---- ShortNumberInfo (short / emergency numbers) ----

/// `true` if the short number is a possible length for the region.
pub fn short_is_possible(region: &str, input: &str) -> bool {
    shared().short_is_possible(region, input)
}

/// `true` if the short number matches a short-number pattern for the region.
pub fn short_is_valid(region: &str, input: &str) -> bool {
    shared().short_is_valid(region, input)
}

/// `true` if the number is an emergency number for the region.
pub fn is_emergency_number(region: &str, input: &str) -> bool {
    shared().is_emergency_number(region, input)
}

/// `true` if dialling the number connects to an emergency service.
pub fn connects_to_emergency_number(region: &str, input: &str) -> bool {
    shared().connects_to_emergency_number(region, input)
}

/// `true` if the short number is carrier-specific.
pub fn short_is_carrier_specific(region: &str, input: &str) -> bool {
    shared().short_is_carrier_specific(region, input)
}

/// `true` if the short number is an SMS short code for the region.
pub fn short_is_sms_service(region: &str, input: &str) -> bool {
    shared().short_is_sms_service(region, input)
}

/// The expected cost of the short number as a raw [`Cost`] `i32` (`COST_*`).
pub fn short_expected_cost(region: &str, input: &str) -> i32 {
    shared().short_expected_cost(region, input)
}

/// The expected cost of the short number as the typed [`Cost`] enum.
pub fn short_expected_cost_enum(region: &str, input: &str) -> Cost {
    shared().short_expected_cost_enum(region, input)
}

/// An example short number for the region, or `""`.
pub fn short_example_number(region: &str) -> String {
    shared().short_example_number(region)
}

// ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----

/// The IANA time-zone ids a number maps to (a number with no known zone maps to
/// `["Etc/Unknown"]`).
pub fn time_zones_for_number(region: &str, input: &str) -> Vec<String> {
    shared().time_zones_for_number(region, input)
}

/// How many time zones a number maps to (`0` = only the unknown zone).
pub fn time_zone_count(region: &str, input: &str) -> i32 {
    shared().time_zone_count(region, input)
}

/// The unknown-zone sentinel, `"Etc/Unknown"`.
pub fn unknown_time_zone() -> String {
    shared().unknown_time_zone()
}

// ---- PhoneNumberToCarrierMapper (localized carrier names) ----

/// The carrier name for a number, or `""` if no carrier is known. `lang` is an
/// optional ISO code; pass `None` for the default `"en"`.
pub fn carrier_name_for_number<'a>(
    region: &str,
    input: &str,
    lang: impl Into<Option<&'a str>>,
) -> String {
    shared().carrier_name_for_number(region, input, lang)
}

/// The carrier name only when the number is valid, else `""`. `lang` is an
/// optional ISO code; `None` selects the default `"en"`.
pub fn carrier_name_for_valid_number<'a>(
    region: &str,
    input: &str,
    lang: impl Into<Option<&'a str>>,
) -> String {
    shared().carrier_name_for_valid_number(region, input, lang)
}

// ---- PhoneNumberOfflineGeocoder (localized geographic descriptions) ----

/// The geographic description for a number, or `""` if none is known. `lang` is
/// an optional ISO code; `None` selects the default `"en"`.
pub fn geo_description_for_number<'a>(
    region: &str,
    input: &str,
    lang: impl Into<Option<&'a str>>,
) -> String {
    shared().geo_description_for_number(region, input, lang)
}

/// The geographic description only when the number is valid, else `""`. `lang`
/// is an optional ISO code; `None` selects the default `"en"`.
pub fn geo_description_for_valid_number<'a>(
    region: &str,
    input: &str,
    lang: impl Into<Option<&'a str>>,
) -> String {
    shared().geo_description_for_valid_number(region, input, lang)
}
