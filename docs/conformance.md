# Binding conformance checks (v2)

Every language binding runs the same suite. These sample each *kind* of value
crossing the FFI — they prove the marshalling, not the library (the phone
behaviour is proven once in the engine, `core_tests/probe.ae`, and once over the
raw ABI, `core_tests/abi_smoke.c`). Canonical numbers come from the shared
engine over Google's metadata.

| # | Call | Expected |
|---|---|---|
| 1 | `country_code("US")` | `"1"` |
| 2 | `country_code("GB")` | `"44"` |
| 3 | `country_code("ZZ")` | `""` |
| 4 | `example_number("US")` | `"2015550123"` |
| 5 | `possible_lengths("US")` | `"10"` |
| 6 | `region_code_for_country_code("44")` | `"GB"` |
| 7 | `is_nanpa_country("US")` | true |
| 8 | `region_count()` ≥ 200 and `region_at(0)` is a 2-letter id | — |
| 9 | `cc_region_at("1", 0)` | `"US"` |
| 10 | parse `"+1 201 555 0123 ext 42"` in US → `pn_national_number` | `"2015550123"` |
| 11 | …and `pn_extension` | `"42"` |
| 12 | …and `pn_country_code` | `"1"` |
| 13 | …and `pn_source` | FROM_NUMBER_WITH_PLUS (1) |
| 14 | …and `region_code_for_number` | `"US"` |
| 15 | parse `"01212345678"` in GB → `pn_national_number` | `"1212345678"` (trunk 0 stripped) |
| 16 | `is_possible_number("US", "2015550123")` | true |
| 17 | `is_possible_number_with_reason("US", "201555")` | TOO_SHORT (2) |
| 18 | `is_valid_number("US", "2015550123")` | true |
| 19 | `is_valid_number("US", "1015550123")` | false |
| 20 | `is_valid_number("US", "+12015550123")` | true |
| 21 | `number_type("US", "2015550123")` | FIXED_LINE_OR_MOBILE (10) — US fixedLine==mobile |
| 22 | `format("US", "2015550123", NATIONAL)` | `"(201) 555-0123"` |
| 23 | `format("US", "2015550123", E164)` | `"+12015550123"` |
| 24 | `format("US", "2015550123", INTERNATIONAL)` | `"+1 201-555-0123"` |
| 25 | `format("US", "2015550123", RFC3966)` | `"tel:+1-201-555-0123"` |
| 26 | `is_number_match("+12015550123", "+1 201 555 0123")` | EXACT (4) |
| 27 | `is_number_match("+12015550123", "+12025550123")` | NO_MATCH (1) |
| 28 | `normalize_digits_only("+1 (201) 555.0123")` | `"12015550123"` |
| 29 | `convert_alpha_characters("1-800-FLOWERS")` | `"1-800-3569377"` |
| 30 | `truncate_too_long("US", "20155501239999")` | `"2015550123"` |
| 31 | AsYouType: feed `"2015550123"` digit-by-digit, `ayt_result` | `"(201) 555-0123"` |
| 32 | `matcher_count("call 201-555-0123 or +1 202 555 0199", "US", VALID)` | `2` |
| 33 | `matcher_raw("call 201-555-0123 now", "US", VALID, 0)` | `"201-555-0123"` |
| 34 | `abi_version()` | `7` |
| 35 | `short_is_emergency("US", "911")` | true |
| 36 | `short_is_emergency("US", "999")` | false (that's GB) |
| 37 | `short_is_emergency("GB", "999")` | true |
| 38 | `short_is_valid("US", "911")` | true |
| 39 | `short_expected_cost("US", "911")` | toll-free (0) |
| 40 | `short_example_number("US")` | `"112"` |
| 41 | `tz_all("US", "2015550123")` | `"America/New_York"` |
| 42 | `tz_all("GB", "2070313000")` | `"Europe/London"` |
| 43 | `tz_unknown()` | `"Etc/Unknown"` |
| 44 | `carrier_name("GB", "7106000000")` | `"O2"` |
| 45 | `geo_description("US", "6502530000")` | `"Mountain View, CA"` |

A binding that exposes idiomatic wrappers (enums, a PhoneNumber object, an
AsYouTypeFormatter class, a matcher iterator) still bottoms out at these calls.
Free every returned string.
