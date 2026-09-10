"""The binding conformance suite (docs/conformance.md, v2).

Proves the Python binding marshals every value shape across the FFI. Not a
phone-number test suite — behaviour is proven in the engine.
"""

import phonenumber_ae as pn


def test_01_country_code_us():
    assert pn.country_code("US") == "1"

def test_02_country_code_gb():
    assert pn.country_code("GB") == "44"

def test_03_unknown_region():
    assert pn.country_code("ZZ") == ""

def test_04_example_number():
    assert pn.example_number("US") == "2015550123"

def test_05_possible_lengths():
    assert pn.possible_lengths("US") == "10"

def test_06_region_for_cc():
    assert pn.region_code_for_country_code("44") == "GB"

def test_07_is_nanpa():
    assert pn.is_nanpa_country("US") is True

def test_08_region_enumeration():
    regs = pn.regions()
    assert len(regs) >= 200
    assert len(regs[0]) == 2

def test_09_cc_region():
    assert pn.regions_for_country_code("1")[0] == "US"

def test_10_to_14_parse():
    num = pn.parse("+1 201 555 0123 ext 42", "US")
    assert num.error == ""
    assert num.national_number == "2015550123"
    assert num.extension == "42"
    assert num.country_code == "1"
    assert num.source == pn.SRC_FROM_NUMBER_WITH_PLUS
    assert num.region_code == "US"

def test_15_parse_trunk_prefix():
    assert pn.parse("01212345678", "GB").national_number == "1212345678"

def test_16_is_possible():
    assert pn.is_possible_number("US", "2015550123") is True

def test_17_reason_too_short():
    assert pn.is_possible_number_with_reason("US", "201555") == pn.VR_TOO_SHORT

def test_18_is_valid():
    assert pn.is_valid_number("US", "2015550123") is True

def test_19_invalid_shape():
    assert pn.is_valid_number("US", "1015550123") is False

def test_20_valid_with_cc():
    assert pn.is_valid_number("US", "+12015550123") is True

def test_21_number_type():
    # US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns
    assert pn.number_type("US", "2015550123") == pn.TYPE_FIXED_LINE_OR_MOBILE
    assert pn.number_type("GB", "2070313000") == pn.TYPE_FIXED_LINE

def test_22_format_national():
    assert pn.format("US", "2015550123", pn.NATIONAL) == "(201) 555-0123"

def test_23_format_e164():
    assert pn.format("US", "2015550123", pn.E164) == "+12015550123"

def test_24_format_international():
    assert pn.format("US", "2015550123", pn.INTERNATIONAL) == "+1 201-555-0123"

def test_25_format_rfc3966():
    assert pn.format("US", "2015550123", pn.RFC3966) == "tel:+1-201-555-0123"

def test_26_match_exact():
    assert pn.is_number_match("+12015550123", "+1 201 555 0123") == pn.MATCH_EXACT

def test_27_match_none():
    assert pn.is_number_match("+12015550123", "+12025550123") == pn.MATCH_NO_MATCH

def test_28_normalize():
    assert pn.normalize_digits_only("+1 (201) 555.0123") == "12015550123"

def test_29_alpha():
    assert pn.convert_alpha_characters("1-800-FLOWERS") == "1-800-3569377"

def test_30_truncate():
    assert pn.truncate_too_long("US", "20155501239999") == "2015550123"

def test_31_as_you_type():
    ayt = pn.AsYouTypeFormatter("US")
    out = ""
    for c in "2015550123":
        out = ayt.input_digit(c)
    assert out == "(201) 555-0123"

def test_32_matcher_count():
    matches = pn.find_numbers("call 201-555-0123 or +1 202 555 0199", "US")
    assert len(matches) == 2

def test_33_matcher_raw():
    matches = pn.find_numbers("call 201-555-0123 now", "US")
    assert matches[0].raw == "201-555-0123"

def test_34_abi_version():
    assert pn.abi_version() == 3


def test_35_short_emergency_us():
    assert pn.is_emergency_number("US", "911") is True


def test_36_short_not_emergency():
    assert pn.is_emergency_number("US", "999") is False


def test_37_short_emergency_gb():
    assert pn.is_emergency_number("GB", "999") is True


def test_38_short_valid():
    assert pn.short_is_valid("US", "911") is True


def test_39_short_cost():
    assert pn.short_expected_cost("US", "911") == pn.COST_TOLL_FREE


def test_40_short_example():
    assert pn.short_example_number("US") == "112" 
