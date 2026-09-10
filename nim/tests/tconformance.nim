## The 45-check binding conformance suite (docs/conformance.md, v6), in Nim.
##
## Proves this binding marshals every value shape across the FFI. It is NOT a
## phone-number test suite — the behavioural cases live in the engine's own
## tests and run once, in Aether (`core_tests/`).
##
## Run it directly (no nimble needed):
##
##     nim c -r tests/tconformance.nim
##
## The engine must be linkable: `nim/.tests.ae` stages it into `nim/native/`,
## and an in-tree checkout also has `core/native/libphonenumber_ae.so` once the
## engine is built. Both directories are baked into the binary as rpath by
## `src/phonenumber_ae.nim`.

import std/unittest
import ../src/phonenumber_ae

suite "conformance":

  test "01 country_code US == 1":
    check countryCode("US") == "1"

  test "02 country_code GB == 44":
    check countryCode("GB") == "44"

  test "03 country_code ZZ == \"\"":
    # The classic NULL-vs-"" bug: an unknown region must come back as an empty
    # string, not a null pointer that decodes to garbage or crashes.
    check countryCode("ZZ") == ""

  test "04 example_number US":
    check exampleNumber("US") == "2015550123"

  test "05 possible_lengths US":
    check possibleLengths("US") == "10"

  test "06 region_code_for_country_code 44 == GB":
    check regionCodeForCountryCode("44") == "GB"

  test "07 is_nanpa_country US":
    check isNanpaCountry("US") == true

  test "08 region enumeration":
    let regs = regions()
    check regs.len >= 200
    check regs[0].len == 2

  test "09 cc_region_at 1,0 == US":
    check regionsForCountryCode("1")[0] == "US"

  test "10-14 parse +1 201 555 0123 ext 42 in US":
    let num = parse("+1 201 555 0123 ext 42", "US")
    check num.error == ""
    check num.nationalNumber == "2015550123"              # 10
    check num.extension == "42"                           # 11
    check num.countryCode == "1"                          # 12
    check num.source == srcFromNumberWithPlus             # 13
    check num.sourceInt == 1
    check num.regionCode == "US"                          # 14

  test "15 parse trunk prefix stripped (GB)":
    check parse("01212345678", "GB").nationalNumber == "1212345678"

  test "16 is_possible yes":
    check isPossibleNumber("US", "2015550123") == true

  test "17 is_possible_number_with_reason TOO_SHORT":
    check isPossibleNumberWithReason("US", "201555") == vrTooShort
    check isPossibleNumberWithReasonInt("US", "201555") == 2

  test "18 is_valid yes":
    check isValidNumber("US", "2015550123") == true

  test "19 is_valid wrong shape":
    check isValidNumber("US", "1015550123") == false

  test "20 is_valid with +cc":
    check isValidNumber("US", "+12015550123") == true

  test "21 number_type fixed_line_or_mobile":
    # US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns
    check numberType("US", "2015550123") == ntFixedLineOrMobile
    check numberTypeInt("US", "2015550123") == 10
    check numberType("GB", "2070313000") == ntFixedLine
    check numberTypeInt("GB", "2070313000") == 0

  test "22 format NATIONAL":
    check format("US", "2015550123", fmtNational) == "(201) 555-0123"

  test "23 format E164":
    check format("US", "2015550123", fmtE164) == "+12015550123"

  test "24 format INTERNATIONAL":
    check format("US", "2015550123", fmtInternational) == "+1 201-555-0123"

  test "25 format RFC3966":
    check format("US", "2015550123", fmtRfc3966) == "tel:+1-201-555-0123"

  test "26 is_number_match EXACT":
    check isNumberMatch("+12015550123", "+1 201 555 0123") == matchExact

  test "27 is_number_match NO_MATCH":
    check isNumberMatch("+12015550123", "+12025550123") == matchNoMatch

  test "28 normalize_digits_only":
    check normalizeDigitsOnly("+1 (201) 555.0123") == "12015550123"

  test "29 convert_alpha_characters":
    check convertAlphaCharacters("1-800-FLOWERS") == "1-800-3569377"

  test "30 truncate_too_long":
    check truncateTooLong("US", "20155501239999") == "2015550123"

  test "31 AsYouType 2015550123":
    var ayt = initAsYouTypeFormatter("US")
    var outp = ""
    for c in "2015550123":
      outp = ayt.inputDigit(c)
    check outp == "(201) 555-0123"

  test "32 matcher_count == 2":
    let matches = findNumbers("call 201-555-0123 or +1 202 555 0199", "US", lenValid)
    check matches.len == 2

  test "33 matcher_raw":
    let matches = findNumbers("call 201-555-0123 now", "US", lenValid)
    check matches[0].raw == "201-555-0123"

  test "34 abi_version == 6":
    check abiVersion() == 6

  test "35 short is_emergency US 911":
    check isEmergencyNumber("US", "911") == true

  test "36 short not-emergency US 999":
    check isEmergencyNumber("US", "999") == false

  test "37 short is_emergency GB 999":
    check isEmergencyNumber("GB", "999") == true

  test "38 short is_valid US 911":
    check shortIsValid("US", "911") == true

  test "39 short expected_cost US 911 toll-free":
    check shortExpectedCost("US", "911") == costTollFree
    check shortExpectedCostInt("US", "911") == 0

  test "40 short example_number US == 112":
    check shortExampleNumber("US") == "112"

  test "41 time_zones_for_number US == America/New_York":
    check timeZonesForNumber("US", "2015550123") == @["America/New_York"]

  test "42 time_zones_for_number GB == Europe/London":
    check timeZonesForNumber("GB", "2070313000") == @["Europe/London"]

  test "43 unknown_time_zone == Etc/Unknown":
    check unknownTimeZone() == "Etc/Unknown"

  test "44 carrier_name_for_number GB 7106000000 == O2":
    check carrierNameForNumber("GB", "7106000000") == "O2"

  test "45 geo_description_for_number US 6502530000 == Mountain View, CA":
    check geoDescriptionForNumber("US", "6502530000") == "Mountain View, CA"

suite "surface":

  test "format style aliases agree":
    check formatNational("US", "2015550123") == "(201) 555-0123"
    check formatInternational("US", "2015550123") == "+1 201-555-0123"
    check formatE164("US", "2015550123") == "+12015550123"
    check formatRfc3966("US", "2015550123") == "tel:+1-201-555-0123"

  test "format raw-int overload agrees with the enum":
    check format("US", "2015550123", NATIONAL) == format("US", "2015550123", fmtNational)
    check format("US", "2015550123", E164) == format("US", "2015550123", fmtE164)
    check format("US", "2015550123", RFC3966) == format("US", "2015550123", fmtRfc3966)

  test "region_at out of range is an empty string":
    check regionAt(1_000_000) == ""

  test "sortedRegions is the deterministic view":
    let s = sortedRegions()
    check s.len == regions().len
    check s[0] <= s[^1]

  test "AsYouType clear resets":
    var ayt = initAsYouTypeFormatter("US")
    discard ayt.inputDigit('2')
    discard ayt.inputDigit('0')
    ayt.clear()
    check ayt.result == ""

  test "time_zone_count agrees with the list length":
    check timeZoneCount("US", "2015550123") == 1
    check timeZonesForNumber("US", "2015550123").len == 1

  test "carrier_name_for_valid agrees for a valid number":
    check carrierNameForValidNumber("GB", "7106000000") == "O2"

  test "geo_description_for_valid agrees for a valid number":
    check geoDescriptionForValidNumber("US", "6502530000") == "Mountain View, CA"

  test "no leak across many string round trips":
    # Not a leak detector, but it exercises takeString several thousand times;
    # a double-free or a missing free shows up here under valgrind/ASan.
    for i in 0 ..< 3000:
      check countryCode("US") == "1"
