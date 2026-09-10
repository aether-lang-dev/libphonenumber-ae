"""phonenumber_ae — validate, parse and format international phone numbers.

A thin Python binding over one shared native engine (pure Aether, compiled from
Google libphonenumber's own metadata), the same artifact every other language
binding in this monorepo uses. Cross-language behaviour is identical by
construction, not by test.

    import phonenumber_ae as pn

    num = pn.parse("+1 650 253 0000", "US")
    num.national_number                       # "6502530000"
    pn.is_valid_number("US", "+1 650 253 0000")
    pn.format("US", "6502530000", pn.INTERNATIONAL)   # "+1 650-253-0000"

    ayt = pn.AsYouTypeFormatter("US")
    for c in "6502530000": last = ayt.input_digit(c)   # "(650) 253-0000"

    pn.find_numbers("call 201-555-0123 today", "US")
"""

from ._native import (
    E164, INTERNATIONAL, NATIONAL, RFC3966,
    TYPE_UNKNOWN, TYPE_FIXED_LINE, TYPE_MOBILE, TYPE_TOLL_FREE,
    TYPE_PREMIUM_RATE, TYPE_SHARED_COST, TYPE_VOIP, TYPE_PERSONAL_NUMBER,
    TYPE_PAGER, TYPE_UAN, TYPE_VOICEMAIL, TYPE_FIXED_LINE_OR_MOBILE,
    VR_IS_POSSIBLE, VR_IS_POSSIBLE_LOCAL_ONLY, VR_INVALID_COUNTRY_CODE,
    VR_TOO_SHORT, VR_INVALID_LENGTH, VR_TOO_LONG,
    MATCH_NOT_A_NUMBER, MATCH_NO_MATCH, MATCH_SHORT_NSN, MATCH_NSN, MATCH_EXACT,
    SRC_FROM_NUMBER_WITH_PLUS, SRC_FROM_NUMBER_WITH_IDD,
    SRC_FROM_NUMBER_WITHOUT_PLUS, SRC_FROM_DEFAULT_COUNTRY,
    LENIENCY_POSSIBLE, LENIENCY_VALID,
    COST_TOLL_FREE, COST_STANDARD_RATE, COST_PREMIUM_RATE, COST_UNKNOWN,
)
from ._phonenumber import (
    country_code, example_number, example_number_for_type,
    invalid_example_number, possible_lengths, region_code_for_country_code,
    is_nanpa_country, ndd_prefix_for_region, region_count, region_at, regions,
    regions_for_country_code,
    ParsedNumber, parse, national_number,
    is_possible_number, is_possible_number_with_reason, is_valid_number,
    is_valid_number_for_region, number_type, can_be_internationally_dialled,
    format, format_national, format_international, format_e164, format_rfc3966,
    format_out_of_country, format_in_original,
    is_number_match, truncate_too_long, normalize_digits_only,
    convert_alpha_characters, is_alpha_number, abi_version,
    AsYouTypeFormatter, Match, find_numbers,
    short_is_possible, short_is_valid, is_emergency_number,
    connects_to_emergency_number, short_is_carrier_specific,
    short_is_sms_service, short_expected_cost, short_example_number,
)

__version__ = "0.2.0"

__all__ = [
    "country_code", "example_number", "example_number_for_type",
    "invalid_example_number", "possible_lengths", "region_code_for_country_code",
    "is_nanpa_country", "ndd_prefix_for_region", "region_count", "region_at",
    "regions", "regions_for_country_code",
    "ParsedNumber", "parse", "national_number",
    "is_possible_number", "is_possible_number_with_reason", "is_valid_number",
    "is_valid_number_for_region", "number_type", "can_be_internationally_dialled",
    "format", "format_national", "format_international", "format_e164",
    "format_rfc3966", "format_out_of_country", "format_in_original",
    "is_number_match", "truncate_too_long", "normalize_digits_only",
    "convert_alpha_characters", "is_alpha_number", "abi_version",
    "AsYouTypeFormatter", "Match", "find_numbers",
    "short_is_possible", "short_is_valid", "is_emergency_number",
    "connects_to_emergency_number", "short_is_carrier_specific",
    "short_is_sms_service", "short_expected_cost", "short_example_number",
    "COST_TOLL_FREE", "COST_STANDARD_RATE", "COST_PREMIUM_RATE", "COST_UNKNOWN",
    "E164", "INTERNATIONAL", "NATIONAL", "RFC3966",
    "TYPE_UNKNOWN", "TYPE_FIXED_LINE", "TYPE_MOBILE", "TYPE_TOLL_FREE",
    "TYPE_PREMIUM_RATE", "TYPE_SHARED_COST", "TYPE_VOIP", "TYPE_PERSONAL_NUMBER",
    "TYPE_PAGER", "TYPE_UAN", "TYPE_VOICEMAIL", "TYPE_FIXED_LINE_OR_MOBILE",
    "VR_IS_POSSIBLE", "VR_IS_POSSIBLE_LOCAL_ONLY", "VR_INVALID_COUNTRY_CODE",
    "VR_TOO_SHORT", "VR_INVALID_LENGTH", "VR_TOO_LONG",
    "MATCH_NOT_A_NUMBER", "MATCH_NO_MATCH", "MATCH_SHORT_NSN", "MATCH_NSN",
    "MATCH_EXACT",
    "SRC_FROM_NUMBER_WITH_PLUS", "SRC_FROM_NUMBER_WITH_IDD",
    "SRC_FROM_NUMBER_WITHOUT_PLUS", "SRC_FROM_DEFAULT_COUNTRY",
    "LENIENCY_POSSIBLE", "LENIENCY_VALID",
]
