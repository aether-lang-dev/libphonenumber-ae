//! The binding conformance suite (docs/conformance.md, v6 — 45 checks).
//!
//! Proves the Rust binding marshals every value shape across the FFI. It is
//! NOT a phone-number test suite — the behavioural cases live in the engine's
//! own tests and run once, in Aether.
//!
//! Each test loads its own engine over `$LIBPHONENUMBER_AE_LIB`, mirroring the
//! other bindings' suites. A couple of extras exercise the typed idiomatic
//! surface (enums, the `PhoneNumbers` object, the `AsYouTypeFormatter` class,
//! the matcher iterator) that still bottoms out at these calls.

use phonenumber_ae as pn;
use phonenumber_ae::PhoneNumbers;

fn engine() -> PhoneNumbers {
    PhoneNumbers::new().expect("load the engine (set LIBPHONENUMBER_AE_LIB)")
}

#[test]
fn t01_country_code_us() {
    assert_eq!(engine().country_code("US"), "1");
}

#[test]
fn t02_country_code_gb() {
    assert_eq!(engine().country_code("GB"), "44");
}

#[test]
fn t03_unknown_region() {
    assert_eq!(engine().country_code("ZZ"), "");
}

#[test]
fn t04_example_number() {
    assert_eq!(engine().example_number("US"), "2015550123");
}

#[test]
fn t05_possible_lengths() {
    assert_eq!(engine().possible_lengths("US"), "10");
}

#[test]
fn t06_region_for_cc() {
    assert_eq!(engine().region_code_for_country_code("44"), "GB");
}

#[test]
fn t07_is_nanpa() {
    assert!(engine().is_nanpa_country("US"));
}

#[test]
fn t08_region_enumeration() {
    let pn = engine();
    assert!(pn.region_count() >= 200, "region_count={}", pn.region_count());
    assert_eq!(pn.region_at(0).len(), 2, "region_at(0)={:?}", pn.region_at(0));
}

#[test]
fn t09_cc_region() {
    assert_eq!(engine().regions_for_country_code("1")[0], "US");
}

#[test]
fn t10_to_14_parse() {
    let pn = engine();
    let num = pn.parse("+1 201 555 0123 ext 42", "US");
    assert_eq!(num.error(), "");
    assert_eq!(num.national_number(), "2015550123"); // #10
    assert_eq!(num.extension(), "42"); // #11
    assert_eq!(num.country_code(), "1"); // #12
    assert_eq!(num.source(), pn::SRC_FROM_NUMBER_WITH_PLUS); // #13
    assert_eq!(num.region_code(), "US"); // #14
}

#[test]
fn t15_parse_trunk_prefix() {
    assert_eq!(
        engine().parse("01212345678", "GB").national_number(),
        "1212345678"
    );
}

#[test]
fn t16_is_possible() {
    assert!(engine().is_possible_number("US", "2015550123"));
}

#[test]
fn t17_reason_too_short() {
    assert_eq!(
        engine().is_possible_number_with_reason("US", "201555"),
        pn::VR_TOO_SHORT
    );
}

#[test]
fn t18_is_valid() {
    assert!(engine().is_valid_number("US", "2015550123"));
}

#[test]
fn t19_invalid_shape() {
    assert!(!engine().is_valid_number("US", "1015550123"));
}

#[test]
fn t20_valid_with_cc() {
    assert!(engine().is_valid_number("US", "+12015550123"));
}

#[test]
fn t21_number_type() {
    // US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns.
    assert_eq!(
        engine().number_type("US", "2015550123"),
        pn::TYPE_FIXED_LINE_OR_MOBILE
    );
    assert_eq!(engine().number_type("GB", "2070313000"), pn::TYPE_FIXED_LINE);
}

#[test]
fn t22_format_national() {
    assert_eq!(
        engine().format("US", "2015550123", pn::NATIONAL),
        "(201) 555-0123"
    );
}

#[test]
fn t23_format_e164() {
    assert_eq!(
        engine().format("US", "2015550123", pn::E164),
        "+12015550123"
    );
}

#[test]
fn t24_format_international() {
    assert_eq!(
        engine().format("US", "2015550123", pn::INTERNATIONAL),
        "+1 201-555-0123"
    );
}

#[test]
fn t25_format_rfc3966() {
    assert_eq!(
        engine().format("US", "2015550123", pn::RFC3966),
        "tel:+1-201-555-0123"
    );
}

#[test]
fn t26_match_exact() {
    assert_eq!(
        engine().is_number_match("+12015550123", "+1 201 555 0123"),
        pn::MATCH_EXACT
    );
}

#[test]
fn t27_match_none() {
    assert_eq!(
        engine().is_number_match("+12015550123", "+12025550123"),
        pn::MATCH_NO_MATCH
    );
}

#[test]
fn t28_normalize() {
    assert_eq!(
        engine().normalize_digits_only("+1 (201) 555.0123"),
        "12015550123"
    );
}

#[test]
fn t29_alpha() {
    assert_eq!(
        engine().convert_alpha_characters("1-800-FLOWERS"),
        "1-800-3569377"
    );
}

#[test]
fn t30_truncate() {
    assert_eq!(
        engine().truncate_too_long("US", "20155501239999"),
        "2015550123"
    );
}

#[test]
fn t31_as_you_type() {
    let pn = engine();
    let mut ayt = pn.as_you_type_formatter("US");
    let mut out = String::new();
    for c in "2015550123".chars() {
        out = ayt.input_digit(c);
    }
    assert_eq!(out, "(201) 555-0123");
}

#[test]
fn t32_matcher_count() {
    let matches = engine().find_numbers(
        "call 201-555-0123 or +1 202 555 0199",
        "US",
        pn::LENIENCY_VALID,
    );
    assert_eq!(matches.len(), 2);
}

#[test]
fn t33_matcher_raw() {
    let matches = engine().find_numbers("call 201-555-0123 now", "US", pn::LENIENCY_VALID);
    assert_eq!(matches[0].raw, "201-555-0123");
}

#[test]
fn t34_abi_version() {
    assert_eq!(engine().abi_version(), 6);
}

#[test]
fn t35_short_emergency_us() {
    assert!(engine().is_emergency_number("US", "911"));
}

#[test]
fn t36_short_not_emergency() {
    assert!(!engine().is_emergency_number("US", "999"));
}

#[test]
fn t37_short_emergency_gb() {
    assert!(engine().is_emergency_number("GB", "999"));
}

#[test]
fn t38_short_valid() {
    assert!(engine().short_is_valid("US", "911"));
}

#[test]
fn t39_short_cost() {
    assert_eq!(engine().short_expected_cost("US", "911"), pn::COST_TOLL_FREE);
}

#[test]
fn t40_short_example() {
    assert_eq!(engine().short_example_number("US"), "112");
}

#[test]
fn t41_time_zones_us() {
    assert_eq!(
        engine().time_zones_for_number("US", "2015550123"),
        vec!["America/New_York".to_string()]
    );
}

#[test]
fn t42_time_zones_gb() {
    assert_eq!(
        engine().time_zones_for_number("GB", "2070313000"),
        vec!["Europe/London".to_string()]
    );
}

#[test]
fn t43_unknown_time_zone() {
    assert_eq!(engine().unknown_time_zone(), "Etc/Unknown");
}

#[test]
fn t44_carrier_name() {
    assert_eq!(engine().carrier_name_for_number("GB", "7106000000"), "O2");
}

#[test]
fn t45_geo_description() {
    assert_eq!(
        engine().geo_description_for_number("US", "6502530000"),
        "Mountain View, CA"
    );
}

// ---- extras exercising the typed idiomatic surface ----

#[test]
fn number_type_enum_matches_raw() {
    assert_eq!(
        engine().number_type_enum("US", "2015550123"),
        pn::NumberType::FixedLineOrMobile
    );
}

#[test]
fn reason_enum_matches_raw() {
    assert_eq!(
        engine().is_possible_number_with_reason_enum("US", "201555"),
        pn::ValidationResult::TooShort
    );
}

#[test]
fn match_enum_matches_raw() {
    assert_eq!(
        engine().is_number_match_enum("+12015550123", "+1 201 555 0123"),
        pn::MatchType::Exact
    );
}

#[test]
fn source_enum_matches_raw() {
    let pn = engine();
    let num = pn.parse("+1 201 555 0123", "US");
    assert_eq!(num.source_enum(), pn::CountryCodeSource::FromNumberWithPlus);
}

#[test]
fn regions_vec_matches_count() {
    let pn = engine();
    assert_eq!(pn.regions().len() as i32, pn.region_count());
}

#[test]
fn cost_enum_matches_raw() {
    assert_eq!(
        engine().short_expected_cost_enum("US", "911"),
        pn::Cost::TollFree
    );
}

#[test]
fn free_functions_share_one_engine() {
    // The crate-level free functions load one process-wide engine.
    assert_eq!(pn::abi_version(), 6);
    assert_eq!(pn::country_code("US"), "1");
    let num = pn::parse("+1 201 555 0123", "US");
    assert_eq!(num.national_number(), "2015550123");
}
