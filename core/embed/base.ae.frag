// FRAGMENT: base — the core PhoneNumberUtil C ABI (validation, parse, format,
// match, AsYouType, matcher, helpers). Assembled into an embed_*.ae by
// core/gen/assemble_embed.sh; NOT built directly. The base is the validation
// minimum; feature fragments (short/tz/carrier/geo) are added on top.
//
// pn_embed_abi_version() reports the ABI *revision* (6), a property of the
// symbol definitions — not of which features are present. A consumer discovers
// which features a given .so carries by dlsym-ing the feature's symbols; a
// missing symbol means that feature was not assembled in.

import core.phonenumber
import std.string
import std.list

extern pn_raw_dup(s: string) -> string
extern pn_raw_free(s: string)

exports(
    pn_embed_abi_version, pn_embed_free_string,
    pn_embed_country_code, pn_embed_example_number, pn_embed_example_number_for_type,
    pn_embed_invalid_example_number, pn_embed_possible_lengths,
    pn_embed_region_code_for_country_code, pn_embed_is_nanpa_country,
    pn_embed_ndd_prefix_for_region, pn_embed_region_count, pn_embed_region_at,
    pn_embed_cc_region_count, pn_embed_cc_region_at,
    pn_embed_parse, pn_embed_pn_region, pn_embed_pn_country_code,
    pn_embed_pn_national_number, pn_embed_pn_extension,
    pn_embed_pn_italian_leading_zero, pn_embed_pn_source, pn_embed_pn_error,
    pn_embed_national_number, pn_embed_region_code_for_number,
    pn_embed_national_significant_number, pn_embed_length_of_ndc,
    pn_embed_length_of_area_code, pn_embed_is_geographical,
    pn_embed_is_possible_number, pn_embed_is_possible_number_with_reason,
    pn_embed_is_valid_number, pn_embed_is_valid_number_for_region,
    pn_embed_number_type, pn_embed_can_be_internationally_dialled,
    pn_embed_format, pn_embed_format_out_of_country, pn_embed_format_in_original,
    pn_embed_is_number_match, pn_embed_truncate_too_long,
    pn_embed_normalize_digits_only, pn_embed_convert_alpha_characters,
    pn_embed_is_alpha_number,
    pn_embed_ayt_new, pn_embed_ayt_input, pn_embed_ayt_result, pn_embed_ayt_clear,
    pn_embed_matcher_count, pn_embed_matcher_start, pn_embed_matcher_end,
    pn_embed_matcher_raw,
    // shared by the tz/carrier/geo fragments (harmless if unused):
    e164_digits_for
)

// ABI revision (see the header note).
pn_embed_abi_version() -> int { return 7 }

pn_embed_free_string(s: string) { pn_raw_free(s) }

// Parse a raw (region, input) to its E.164 digit string ("<cc><national>") for
// the tz/carrier/geo fragments; "" on a parse error. Defined in the base so the
// feature fragments need not duplicate it.
e164_digits_for(region: string, input: string) -> string {
    pn = phonenumber.parse(input, region)
    if phonenumber.pn_error(pn) != "" { return "" }
    return "${phonenumber.pn_country_code(pn)}${phonenumber.pn_national_number(pn)}"
}

// ---- metadata queries ----

pn_embed_country_code(region: string) -> string {
    return pn_raw_dup(phonenumber.country_code(region))
}
pn_embed_example_number(region: string) -> string {
    return pn_raw_dup(phonenumber.example_number(region))
}
pn_embed_example_number_for_type(region: string, ty: int) -> string {
    return pn_raw_dup(phonenumber.example_number_for_type(region, ty))
}
pn_embed_invalid_example_number(region: string) -> string {
    return pn_raw_dup(phonenumber.invalid_example_number(region))
}
pn_embed_possible_lengths(region: string) -> string {
    return pn_raw_dup(phonenumber.possible_lengths(region))
}
pn_embed_region_code_for_country_code(cc: string) -> string {
    return pn_raw_dup(phonenumber.region_code_for_country_code(cc))
}
pn_embed_is_nanpa_country(region: string) -> int {
    return phonenumber.is_nanpa_country(region)
}
pn_embed_ndd_prefix_for_region(region: string, strip: int) -> string {
    return pn_raw_dup(phonenumber.ndd_prefix_for_region(region, strip))
}
pn_embed_region_count() -> int { return phonenumber.region_count() }
pn_embed_region_at(idx: int) -> string {
    return pn_raw_dup(phonenumber.region_at(idx))
}
pn_embed_cc_region_count(cc: string) -> int {
    l = phonenumber.regions_for_country_code(cc)
    n = list.size(l)
    list.free(l)
    return n
}
pn_embed_cc_region_at(cc: string, idx: int) -> string {
    l = phonenumber.regions_for_country_code(cc)
    dupd = pn_raw_dup("")
    if idx >= 0 && idx < list.size(l) {
        v, _ = list.get(l, idx)
        pn_raw_free(dupd)
        dupd = pn_raw_dup(v)
    }
    list.free(l)
    return dupd
}

// ---- parse + parsed-number accessors ----

pn_embed_parse(input: string, region: string) -> string {
    return pn_raw_dup(phonenumber.parse(input, region))
}
pn_embed_pn_region(pn: string) -> string { return pn_raw_dup(phonenumber.pn_region(pn)) }
pn_embed_pn_country_code(pn: string) -> string { return pn_raw_dup(phonenumber.pn_country_code(pn)) }
pn_embed_pn_national_number(pn: string) -> string { return pn_raw_dup(phonenumber.pn_national_number(pn)) }
pn_embed_pn_extension(pn: string) -> string { return pn_raw_dup(phonenumber.pn_extension(pn)) }
pn_embed_pn_italian_leading_zero(pn: string) -> int { return phonenumber.pn_italian_leading_zero(pn) }
pn_embed_pn_source(pn: string) -> int { return phonenumber.pn_source(pn) }
pn_embed_pn_error(pn: string) -> string { return pn_raw_dup(phonenumber.pn_error(pn)) }
pn_embed_national_number(region: string, input: string) -> string {
    return pn_raw_dup(phonenumber.national_number(region, input))
}
pn_embed_region_code_for_number(pn: string) -> string {
    return pn_raw_dup(phonenumber.region_code_for_number(pn))
}
pn_embed_national_significant_number(pn: string) -> string {
    return pn_raw_dup(phonenumber.national_significant_number(pn))
}
pn_embed_length_of_ndc(pn: string) -> int { return phonenumber.length_of_ndc(pn) }
pn_embed_length_of_area_code(pn: string) -> int { return phonenumber.length_of_area_code(pn) }
pn_embed_is_geographical(pn: string) -> int { return phonenumber.is_geographical(pn) }

// ---- validation ----

pn_embed_is_possible_number(region: string, input: string) -> int {
    return phonenumber.is_possible_number(region, input)
}
pn_embed_is_possible_number_with_reason(region: string, input: string) -> int {
    return phonenumber.is_possible_number_with_reason(region, input)
}
pn_embed_is_valid_number(region: string, input: string) -> int {
    return phonenumber.is_valid_number(region, input)
}
pn_embed_is_valid_number_for_region(input: string, region: string) -> int {
    return phonenumber.is_valid_number_for_region(input, region)
}
pn_embed_number_type(region: string, input: string) -> int {
    return phonenumber.number_type(region, input)
}
pn_embed_can_be_internationally_dialled(region: string, input: string) -> int {
    return phonenumber.can_be_internationally_dialled(region, input)
}

// ---- formatting ----

pn_embed_format(region: string, input: string, fmt: int) -> string {
    return pn_raw_dup(phonenumber.format(region, input, fmt))
}
pn_embed_format_out_of_country(region: string, input: string, calling_from: string) -> string {
    return pn_raw_dup(phonenumber.format_out_of_country(region, input, calling_from))
}
pn_embed_format_in_original(pn: string, calling_from: string) -> string {
    return pn_raw_dup(phonenumber.format_in_original(pn, calling_from))
}

// ---- number relations / helpers ----

pn_embed_is_number_match(a: string, b: string) -> int {
    return phonenumber.is_number_match(a, b)
}
pn_embed_truncate_too_long(region: string, input: string) -> string {
    return pn_raw_dup(phonenumber.truncate_too_long(region, input))
}
pn_embed_normalize_digits_only(s: string) -> string {
    return pn_raw_dup(phonenumber.normalize_digits_only(s))
}
pn_embed_convert_alpha_characters(s: string) -> string {
    return pn_raw_dup(phonenumber.convert_alpha_characters(s))
}
pn_embed_is_alpha_number(s: string) -> int {
    return phonenumber.is_alpha_number(s)
}

// ---- AsYouTypeFormatter ----

pn_embed_ayt_new(region: string) -> string { return pn_raw_dup(phonenumber.ayt_new(region)) }
pn_embed_ayt_input(state: string, ch: string) -> string { return pn_raw_dup(phonenumber.ayt_input(state, ch)) }
pn_embed_ayt_result(state: string) -> string { return pn_raw_dup(phonenumber.ayt_result(state)) }
pn_embed_ayt_clear(state: string) -> string { return pn_raw_dup(phonenumber.ayt_clear(state)) }

// ---- PhoneNumberMatcher / findNumbers ----

pn_embed_matcher_count(text: string, region: string, leniency: int) -> int {
    return phonenumber.matcher_count(text, region, leniency)
}
pn_embed_matcher_start(text: string, region: string, leniency: int, idx: int) -> int {
    return phonenumber.matcher_start(text, region, leniency, idx)
}
pn_embed_matcher_end(text: string, region: string, leniency: int, idx: int) -> int {
    return phonenumber.matcher_end(text, region, leniency, idx)
}
pn_embed_matcher_raw(text: string, region: string, leniency: int, idx: int) -> string {
    return pn_raw_dup(phonenumber.matcher_raw(text, region, leniency, idx))
}
