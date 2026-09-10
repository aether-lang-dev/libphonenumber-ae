//! The 1:1 symbol table for the phonenumber C ABI (`core/embed.ae`), **v5**.
//!
//! This module is the ONLY place in the Rust binding that knows about the C
//! ABI, and it is the canonical cross-binding reference: every symbol the
//! engine exports appears here once, with the exact C signature, in the order
//! `core/embed.ae` declares it. No phone-number logic lives here or anywhere
//! else in this crate — the engine is `core/phonenumber.ae`, shared by every
//! language binding in this monorepo.
//!
//! ## Naming
//!
//! `core/embed.ae` names its exports `pn_embed_<name>`; building with
//! `--emit=lib` mangles them to **`aether_pn_embed_<name>`**. That mangled
//! name is what we `dlsym`.
//!
//! ## The two ownership rules
//!
//! 1. **Every `*mut c_char` this ABI returns is caller-owned** and must be
//!    handed back to [`Api::free_string`]. Leaking it is the single most common
//!    bug in a binding. [`Api::take_string`] does the right thing: it copies
//!    the bytes into a Rust `String`, then frees the pointer through the ABI.
//! 2. **No opaque handles.** A parsed number and an AsYouType state are
//!    themselves caller-owned *strings*: you get one back, pass it to accessor
//!    calls, and free it like any other returned string. Every call is
//!    independent.

use std::ffi::{c_char, c_int, CStr, CString};
use std::path::Path;

use libloading::{Library, Symbol};

// ---- format styles (the `fmt` argument — ABI constants, append only) ----
//
// NOTE: v2 renumbers these. E164 is now 0 (it was 2 under v1).

/// E.164 format, e.g. `+12015550123`.
pub const E164: c_int = 0;
/// International format, e.g. `+1 201-555-0123`.
pub const INTERNATIONAL: c_int = 1;
/// National format, e.g. `(201) 555-0123`.
pub const NATIONAL: c_int = 2;
/// RFC 3966 `tel:` URI, e.g. `tel:+1-201-555-0123`.
pub const RFC3966: c_int = 3;

// ---- number types (`number_type` result; -1 = unknown) ----

pub const TYPE_UNKNOWN: c_int = -1;
pub const TYPE_FIXED_LINE: c_int = 0;
pub const TYPE_MOBILE: c_int = 1;
pub const TYPE_TOLL_FREE: c_int = 2;
pub const TYPE_PREMIUM_RATE: c_int = 3;
pub const TYPE_SHARED_COST: c_int = 4;
pub const TYPE_VOIP: c_int = 5;
pub const TYPE_PERSONAL_NUMBER: c_int = 6;
pub const TYPE_PAGER: c_int = 7;
pub const TYPE_UAN: c_int = 8;
pub const TYPE_VOICEMAIL: c_int = 9;
pub const TYPE_FIXED_LINE_OR_MOBILE: c_int = 10;

// ---- ValidationResult (`is_possible_number_with_reason` result) ----

pub const VR_IS_POSSIBLE: c_int = 0;
pub const VR_IS_POSSIBLE_LOCAL_ONLY: c_int = 4;
pub const VR_INVALID_COUNTRY_CODE: c_int = 1;
pub const VR_TOO_SHORT: c_int = 2;
pub const VR_INVALID_LENGTH: c_int = 5;
pub const VR_TOO_LONG: c_int = 3;

// ---- MatchType (`is_number_match` result) ----

pub const MATCH_NOT_A_NUMBER: c_int = 0;
pub const MATCH_NO_MATCH: c_int = 1;
pub const MATCH_SHORT_NSN: c_int = 2;
pub const MATCH_NSN: c_int = 3;
pub const MATCH_EXACT: c_int = 4;

// ---- CountryCodeSource (`pn_source` result) ----

pub const SRC_FROM_NUMBER_WITH_PLUS: c_int = 1;
pub const SRC_FROM_NUMBER_WITH_IDD: c_int = 5;
pub const SRC_FROM_NUMBER_WITHOUT_PLUS: c_int = 10;
pub const SRC_FROM_DEFAULT_COUNTRY: c_int = 20;

// ---- matcher leniency (`matcher_*` argument) ----

pub const LENIENCY_POSSIBLE: c_int = 0;
pub const LENIENCY_VALID: c_int = 1;

// ---- ShortNumberCost (`short_expected_cost` result) ----

pub const COST_TOLL_FREE: c_int = 0;
pub const COST_STANDARD_RATE: c_int = 1;
pub const COST_PREMIUM_RATE: c_int = 2;
pub const COST_UNKNOWN: c_int = 3;

/// The platform's shared-library file name for the engine.
pub const LIB_NAME: &str = if cfg!(target_os = "macos") {
    "libphonenumber_ae.dylib"
} else if cfg!(target_os = "windows") {
    "phonenumber_ae.dll"
} else {
    "libphonenumber_ae.so"
};

/// Errors from loading the engine.
#[derive(Debug)]
pub enum Error {
    /// The shared library could not be found or opened.
    Load(String),
    /// The library opened but an expected symbol was missing.
    Symbol(String),
    /// A Rust string contained an interior NUL and cannot cross the ABI.
    NulByte,
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Load(m) => write!(
                f,
                "could not load the phonenumber engine ({LIB_NAME}). Set \
                 LIBPHONENUMBER_AE_LIB to its absolute path. Last error: {m}"
            ),
            Error::Symbol(s) => write!(f, "missing symbol {s} (engine too old?)"),
            Error::NulByte => write!(f, "string contains an interior NUL byte"),
        }
    }
}

impl std::error::Error for Error {}

/// Every exported symbol, resolved once at load time.
///
/// Field order mirrors `core/embed.ae` so the two can be diffed by eye.
/// `_lib` is last and must stay last: the `Symbol` values borrow from it, so
/// it has to outlive them (Rust drops fields in declaration order).
pub struct Api {
    // ---- version / lifecycle ----
    pub abi_version: unsafe extern "C" fn() -> c_int,
    pub free_string: unsafe extern "C" fn(*mut c_char),

    // ---- region metadata ----
    pub country_code: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub example_number: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub example_number_for_type: unsafe extern "C" fn(*const c_char, c_int) -> *mut c_char,
    pub invalid_example_number: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub possible_lengths: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub region_code_for_country_code: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub is_nanpa_country: unsafe extern "C" fn(*const c_char) -> c_int,
    pub ndd_prefix_for_region: unsafe extern "C" fn(*const c_char, c_int) -> *mut c_char,
    pub region_count: unsafe extern "C" fn() -> c_int,
    pub region_at: unsafe extern "C" fn(c_int) -> *mut c_char,
    pub cc_region_count: unsafe extern "C" fn(*const c_char) -> c_int,
    pub cc_region_at: unsafe extern "C" fn(*const c_char, c_int) -> *mut c_char,

    // ---- parse + parsed-number accessors ----
    pub parse: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
    pub national_number: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
    pub pn_region: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub pn_country_code: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub pn_national_number: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub pn_extension: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub pn_italian_leading_zero: unsafe extern "C" fn(*const c_char) -> c_int,
    pub pn_source: unsafe extern "C" fn(*const c_char) -> c_int,
    pub pn_error: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub region_code_for_number: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub national_significant_number: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub length_of_ndc: unsafe extern "C" fn(*const c_char) -> c_int,
    pub length_of_area_code: unsafe extern "C" fn(*const c_char) -> c_int,
    pub is_geographical: unsafe extern "C" fn(*const c_char) -> c_int,

    // ---- validation ----
    pub is_possible_number: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub is_possible_number_with_reason: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub is_valid_number: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub is_valid_number_for_region: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub number_type: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub can_be_internationally_dialled: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,

    // ---- formatting ----
    pub format: unsafe extern "C" fn(*const c_char, *const c_char, c_int) -> *mut c_char,
    pub format_out_of_country:
        unsafe extern "C" fn(*const c_char, *const c_char, *const c_char) -> *mut c_char,
    pub format_in_original: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,

    // ---- relations / helpers ----
    pub is_number_match: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub truncate_too_long: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
    pub normalize_digits_only: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub convert_alpha_characters: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub is_alpha_number: unsafe extern "C" fn(*const c_char) -> c_int,

    // ---- AsYouTypeFormatter (state threaded as a caller-owned string) ----
    pub ayt_new: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub ayt_input: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
    pub ayt_result: unsafe extern "C" fn(*const c_char) -> *mut c_char,
    pub ayt_clear: unsafe extern "C" fn(*const c_char) -> *mut c_char,

    // ---- PhoneNumberMatcher / findNumbers ----
    pub matcher_count: unsafe extern "C" fn(*const c_char, *const c_char, c_int) -> c_int,
    pub matcher_start: unsafe extern "C" fn(*const c_char, *const c_char, c_int, c_int) -> c_int,
    pub matcher_end: unsafe extern "C" fn(*const c_char, *const c_char, c_int, c_int) -> c_int,
    pub matcher_raw:
        unsafe extern "C" fn(*const c_char, *const c_char, c_int, c_int) -> *mut c_char,

    // ---- ShortNumberInfo (short / emergency numbers) ----
    pub short_is_possible: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_is_valid: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_is_emergency: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_connects_to_emergency: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_is_carrier_specific: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_is_sms_service: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_expected_cost: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub short_example_number: unsafe extern "C" fn(*const c_char) -> *mut c_char,

    // ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----
    pub tz_count: unsafe extern "C" fn(*const c_char, *const c_char) -> c_int,
    pub tz_at: unsafe extern "C" fn(*const c_char, *const c_char, c_int) -> *mut c_char,
    pub tz_all: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
    pub tz_unknown: unsafe extern "C" fn() -> *mut c_char,

    // ---- PhoneNumberToCarrierMapper (English carrier names) ----
    pub carrier_name: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,
    pub carrier_name_for_valid: unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char,

    /// Keeps the `dlopen` handle alive. MUST be the last field — every fn
    /// pointer above points into this library's mapping.
    _lib: Library,
}

/// Resolve one symbol out of the library, transmuting it to the fn-pointer
/// type the field expects.
macro_rules! sym {
    ($lib:expr, $name:literal) => {{
        let s: Symbol<_> = unsafe { $lib.get(concat!($name, "\0").as_bytes()) }
            .map_err(|_| Error::Symbol($name.to_string()))?;
        // Deref copies the fn pointer out of the Symbol's borrow of `lib`;
        // the pointer stays valid because `Api` keeps the Library alive.
        *s
    }};
}

impl Api {
    /// Load the engine and resolve every symbol.
    ///
    /// Resolution order, matching every other binding in the monorepo:
    ///   1. `explicit`, when given
    ///   2. `$LIBPHONENUMBER_AE_LIB`
    ///   3. `native/` next to the crate
    ///   4. the OS loader's own search path
    pub fn load(explicit: Option<&Path>) -> Result<Api, Error> {
        let mut candidates: Vec<String> = Vec::new();
        if let Some(p) = explicit {
            candidates.push(p.display().to_string());
        } else {
            if let Ok(env) = std::env::var("LIBPHONENUMBER_AE_LIB") {
                if !env.is_empty() {
                    candidates.push(env);
                }
            }
            candidates.push(
                Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("native")
                    .join(LIB_NAME)
                    .display()
                    .to_string(),
            );
            candidates.push(LIB_NAME.to_string());
        }

        let mut last = String::from("no candidates");
        for cand in &candidates {
            match unsafe { Library::new(cand) } {
                Ok(lib) => return Api::bind(lib),
                Err(e) => last = e.to_string(),
            }
        }
        Err(Error::Load(last))
    }

    fn bind(lib: Library) -> Result<Api, Error> {
        Ok(Api {
            abi_version: sym!(lib, "aether_pn_embed_abi_version"),
            free_string: sym!(lib, "aether_pn_embed_free_string"),

            country_code: sym!(lib, "aether_pn_embed_country_code"),
            example_number: sym!(lib, "aether_pn_embed_example_number"),
            example_number_for_type: sym!(lib, "aether_pn_embed_example_number_for_type"),
            invalid_example_number: sym!(lib, "aether_pn_embed_invalid_example_number"),
            possible_lengths: sym!(lib, "aether_pn_embed_possible_lengths"),
            region_code_for_country_code: sym!(lib, "aether_pn_embed_region_code_for_country_code"),
            is_nanpa_country: sym!(lib, "aether_pn_embed_is_nanpa_country"),
            ndd_prefix_for_region: sym!(lib, "aether_pn_embed_ndd_prefix_for_region"),
            region_count: sym!(lib, "aether_pn_embed_region_count"),
            region_at: sym!(lib, "aether_pn_embed_region_at"),
            cc_region_count: sym!(lib, "aether_pn_embed_cc_region_count"),
            cc_region_at: sym!(lib, "aether_pn_embed_cc_region_at"),

            parse: sym!(lib, "aether_pn_embed_parse"),
            national_number: sym!(lib, "aether_pn_embed_national_number"),
            pn_region: sym!(lib, "aether_pn_embed_pn_region"),
            pn_country_code: sym!(lib, "aether_pn_embed_pn_country_code"),
            pn_national_number: sym!(lib, "aether_pn_embed_pn_national_number"),
            pn_extension: sym!(lib, "aether_pn_embed_pn_extension"),
            pn_italian_leading_zero: sym!(lib, "aether_pn_embed_pn_italian_leading_zero"),
            pn_source: sym!(lib, "aether_pn_embed_pn_source"),
            pn_error: sym!(lib, "aether_pn_embed_pn_error"),
            region_code_for_number: sym!(lib, "aether_pn_embed_region_code_for_number"),
            national_significant_number: sym!(lib, "aether_pn_embed_national_significant_number"),
            length_of_ndc: sym!(lib, "aether_pn_embed_length_of_ndc"),
            length_of_area_code: sym!(lib, "aether_pn_embed_length_of_area_code"),
            is_geographical: sym!(lib, "aether_pn_embed_is_geographical"),

            is_possible_number: sym!(lib, "aether_pn_embed_is_possible_number"),
            is_possible_number_with_reason: sym!(
                lib,
                "aether_pn_embed_is_possible_number_with_reason"
            ),
            is_valid_number: sym!(lib, "aether_pn_embed_is_valid_number"),
            is_valid_number_for_region: sym!(lib, "aether_pn_embed_is_valid_number_for_region"),
            number_type: sym!(lib, "aether_pn_embed_number_type"),
            can_be_internationally_dialled: sym!(
                lib,
                "aether_pn_embed_can_be_internationally_dialled"
            ),

            format: sym!(lib, "aether_pn_embed_format"),
            format_out_of_country: sym!(lib, "aether_pn_embed_format_out_of_country"),
            format_in_original: sym!(lib, "aether_pn_embed_format_in_original"),

            is_number_match: sym!(lib, "aether_pn_embed_is_number_match"),
            truncate_too_long: sym!(lib, "aether_pn_embed_truncate_too_long"),
            normalize_digits_only: sym!(lib, "aether_pn_embed_normalize_digits_only"),
            convert_alpha_characters: sym!(lib, "aether_pn_embed_convert_alpha_characters"),
            is_alpha_number: sym!(lib, "aether_pn_embed_is_alpha_number"),

            ayt_new: sym!(lib, "aether_pn_embed_ayt_new"),
            ayt_input: sym!(lib, "aether_pn_embed_ayt_input"),
            ayt_result: sym!(lib, "aether_pn_embed_ayt_result"),
            ayt_clear: sym!(lib, "aether_pn_embed_ayt_clear"),

            matcher_count: sym!(lib, "aether_pn_embed_matcher_count"),
            matcher_start: sym!(lib, "aether_pn_embed_matcher_start"),
            matcher_end: sym!(lib, "aether_pn_embed_matcher_end"),
            matcher_raw: sym!(lib, "aether_pn_embed_matcher_raw"),

            short_is_possible: sym!(lib, "aether_pn_embed_short_is_possible"),
            short_is_valid: sym!(lib, "aether_pn_embed_short_is_valid"),
            short_is_emergency: sym!(lib, "aether_pn_embed_short_is_emergency"),
            short_connects_to_emergency: sym!(lib, "aether_pn_embed_short_connects_to_emergency"),
            short_is_carrier_specific: sym!(lib, "aether_pn_embed_short_is_carrier_specific"),
            short_is_sms_service: sym!(lib, "aether_pn_embed_short_is_sms_service"),
            short_expected_cost: sym!(lib, "aether_pn_embed_short_expected_cost"),
            short_example_number: sym!(lib, "aether_pn_embed_short_example_number"),

            tz_count: sym!(lib, "aether_pn_embed_tz_count"),
            tz_at: sym!(lib, "aether_pn_embed_tz_at"),
            tz_all: sym!(lib, "aether_pn_embed_tz_all"),
            tz_unknown: sym!(lib, "aether_pn_embed_tz_unknown"),

            carrier_name: sym!(lib, "aether_pn_embed_carrier_name"),
            carrier_name_for_valid: sym!(lib, "aether_pn_embed_carrier_name_for_valid"),

            _lib: lib,
        })
    }

    /// Copy an ABI-returned string out and free it through the ABI.
    ///
    /// # Safety
    /// `ptr` must be a string this ABI returned, and must not be used again.
    pub unsafe fn take_string(&self, ptr: *mut c_char) -> String {
        if ptr.is_null() {
            return String::new();
        }
        let out = unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned();
        unsafe { (self.free_string)(ptr) };
        out
    }
}

/// Convert a Rust string for the ABI. Interior NULs are an error, not a
/// silent truncation.
pub fn to_c(s: &str) -> Result<CString, Error> {
    CString::new(s).map_err(|_| Error::NulByte)
}
