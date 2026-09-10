//// The binding conformance suite (docs/conformance.md, v5).
////
//// Proves the Gleam surface marshals every value shape across the FFI. It is
//// NOT a phone-number test suite — the behavioural cases live in the engine's
//// own tests and run once, in Aether. Here we sample each KIND of value
//// crossing the FFI so the marshalling is proven, not the library.

import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import phonenumber_ae.{
  CostTollFree, E164, Exact, FixedLine, FixedLineOrMobile, FromNumberWithPlus,
  International, National, NoMatch, Rfc3966, TooShort, Valid,
}

pub fn main() {
  gleeunit.main()
}

// ---- the 40 checks (docs/conformance.md, v3) ----

pub fn t01_country_code_us_test() {
  phonenumber_ae.country_code("US")
  |> should.equal("1")
}

pub fn t02_country_code_gb_test() {
  phonenumber_ae.country_code("GB")
  |> should.equal("44")
}

pub fn t03_unknown_region_test() {
  phonenumber_ae.country_code("ZZ")
  |> should.equal("")
}

pub fn t04_example_number_test() {
  phonenumber_ae.example_number("US")
  |> should.equal("2015550123")
}

pub fn t05_possible_lengths_test() {
  phonenumber_ae.possible_lengths("US")
  |> should.equal("10")
}

pub fn t06_region_for_cc_test() {
  phonenumber_ae.region_code_for_country_code("44")
  |> should.equal("GB")
}

pub fn t07_is_nanpa_test() {
  phonenumber_ae.is_nanpa_country("US")
  |> should.be_true
}

pub fn t08_region_enumeration_test() {
  { phonenumber_ae.region_count() >= 200 }
  |> should.be_true

  let regs = phonenumber_ae.regions()

  list.length(regs)
  |> should.equal(phonenumber_ae.region_count())

  // region_at(0) agrees with the list's head, and is a 2-letter id.
  let assert [first, ..] = regs
  phonenumber_ae.region_at(0)
  |> should.equal(first)

  string.length(first)
  |> should.equal(2)
}

pub fn t09_cc_region_test() {
  phonenumber_ae.cc_region_at("1", 0)
  |> should.equal("US")

  let assert [first, ..] = phonenumber_ae.regions_for_country_code("1")
  first
  |> should.equal("US")
}

pub fn t10_14_parse_test() {
  let num = phonenumber_ae.parse("+1 201 555 0123 ext 42", "US")

  phonenumber_ae.pn_error(num)
  |> should.equal("")

  phonenumber_ae.pn_national_number(num)
  |> should.equal("2015550123")

  phonenumber_ae.pn_extension(num)
  |> should.equal("42")

  phonenumber_ae.pn_country_code(num)
  |> should.equal("1")

  phonenumber_ae.pn_source(num)
  |> should.equal(FromNumberWithPlus)

  phonenumber_ae.region_code_for_number(num)
  |> should.equal("US")
}

pub fn t15_parse_trunk_prefix_test() {
  let num = phonenumber_ae.parse("01212345678", "GB")
  phonenumber_ae.pn_national_number(num)
  |> should.equal("1212345678")
}

pub fn t16_is_possible_test() {
  phonenumber_ae.is_possible_number("US", "2015550123")
  |> should.be_true
}

pub fn t17_reason_too_short_test() {
  phonenumber_ae.is_possible_number_with_reason("US", "201555")
  |> should.equal(TooShort)
}

pub fn t18_is_valid_test() {
  phonenumber_ae.is_valid_number("US", "2015550123")
  |> should.be_true
}

pub fn t19_invalid_shape_test() {
  phonenumber_ae.is_valid_number("US", "1015550123")
  |> should.be_false
}

pub fn t20_valid_with_cc_test() {
  phonenumber_ae.is_valid_number("US", "+12015550123")
  |> should.be_true
}

pub fn t21_number_type_test() {
  // US fixedLine==mobile -> FixedLineOrMobile; GB has distinct patterns.
  phonenumber_ae.number_type("US", "2015550123")
  |> should.equal(FixedLineOrMobile)

  phonenumber_ae.number_type_code("US", "2015550123")
  |> should.equal(10)

  phonenumber_ae.number_type("GB", "2070313000")
  |> should.equal(FixedLine)

  phonenumber_ae.number_type_code("GB", "2070313000")
  |> should.equal(0)
}

pub fn t22_format_national_test() {
  phonenumber_ae.format("US", "2015550123", National)
  |> should.equal("(201) 555-0123")
}

pub fn t23_format_e164_test() {
  phonenumber_ae.format("US", "2015550123", E164)
  |> should.equal("+12015550123")
}

pub fn t24_format_international_test() {
  phonenumber_ae.format("US", "2015550123", International)
  |> should.equal("+1 201-555-0123")
}

pub fn t25_format_rfc3966_test() {
  phonenumber_ae.format("US", "2015550123", Rfc3966)
  |> should.equal("tel:+1-201-555-0123")
}

pub fn t26_match_exact_test() {
  phonenumber_ae.is_number_match("+12015550123", "+1 201 555 0123")
  |> should.equal(Exact)
}

pub fn t27_match_none_test() {
  phonenumber_ae.is_number_match("+12015550123", "+12025550123")
  |> should.equal(NoMatch)
}

pub fn t28_normalize_test() {
  phonenumber_ae.normalize_digits_only("+1 (201) 555.0123")
  |> should.equal("12015550123")
}

pub fn t29_alpha_test() {
  phonenumber_ae.convert_alpha_characters("1-800-FLOWERS")
  |> should.equal("1-800-3569377")
}

pub fn t30_truncate_test() {
  phonenumber_ae.truncate_too_long("US", "20155501239999")
  |> should.equal("2015550123")
}

pub fn t31_as_you_type_test() {
  let f =
    "2015550123"
    |> string.to_graphemes()
    |> list.fold(phonenumber_ae.ayt_new("US"), fn(f, c) {
      phonenumber_ae.ayt_input(f, c)
    })

  phonenumber_ae.ayt_result(f)
  |> should.equal("(201) 555-0123")
}

pub fn t32_matcher_count_test() {
  phonenumber_ae.find_numbers("call 201-555-0123 or +1 202 555 0199", "US", Valid)
  |> list.length
  |> should.equal(2)
}

pub fn t33_matcher_raw_test() {
  let assert [first, ..] =
    phonenumber_ae.find_numbers("call 201-555-0123 now", "US", Valid)
  first.raw
  |> should.equal("201-555-0123")
}

pub fn t34_abi_version_test() {
  phonenumber_ae.abi_version()
  |> should.equal(7)
}

// ---- ShortNumberInfo (docs/conformance.md #35–40, v5) ----

pub fn t35_short_emergency_us_test() {
  phonenumber_ae.is_emergency_number("US", "911")
  |> should.be_true
}

pub fn t36_short_not_emergency_test() {
  phonenumber_ae.is_emergency_number("US", "999")
  |> should.be_false
}

pub fn t37_short_emergency_gb_test() {
  phonenumber_ae.is_emergency_number("GB", "999")
  |> should.be_true
}

pub fn t38_short_valid_test() {
  phonenumber_ae.short_is_valid("US", "911")
  |> should.be_true
}

pub fn t39_short_cost_test() {
  phonenumber_ae.short_expected_cost("US", "911")
  |> should.equal(CostTollFree)

  phonenumber_ae.short_expected_cost_code("US", "911")
  |> should.equal(0)
}

pub fn t40_short_example_test() {
  phonenumber_ae.short_example_number("US")
  |> should.equal("112")
}

// ---- TimeZones + Carrier + Geocoder (docs/conformance.md #41–45, v6) ----

pub fn t41_tz_us_test() {
  phonenumber_ae.time_zones_for_number("US", "2015550123")
  |> should.equal(["America/New_York"])
}

pub fn t42_tz_gb_test() {
  phonenumber_ae.time_zones_for_number("GB", "2070313000")
  |> should.equal(["Europe/London"])
}

pub fn t43_tz_unknown_test() {
  phonenumber_ae.unknown_time_zone()
  |> should.equal("Etc/Unknown")
}

pub fn t44_carrier_test() {
  phonenumber_ae.carrier_name_for_number("GB", "7106000000")
  |> should.equal("O2")
}

pub fn t45_geocoder_test() {
  phonenumber_ae.geo_description_for_number("US", "6502530000")
  |> should.equal("Mountain View, CA")
}

// ---- extras: the marshalling corners the 45 do not reach ----

pub fn format_helpers_test() {
  phonenumber_ae.format_national("US", "2015550123")
  |> should.equal("(201) 555-0123")

  phonenumber_ae.format_e164("US", "2015550123")
  |> should.equal("+12015550123")

  phonenumber_ae.format_international("US", "2015550123")
  |> should.equal("+1 201-555-0123")

  phonenumber_ae.format_rfc3966("US", "2015550123")
  |> should.equal("tel:+1-201-555-0123")
}

pub fn match_offsets_test() {
  let assert [first, ..] =
    phonenumber_ae.find_numbers("call 201-555-0123 now", "US", Valid)
  first.raw
  |> should.equal("201-555-0123")

  { first.end > first.start }
  |> should.be_true
}
