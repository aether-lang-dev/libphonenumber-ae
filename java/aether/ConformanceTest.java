package org.libphonenumber.ae;

import java.util.ArrayList;
import java.util.List;

/**
 * The 45-check binding conformance suite (docs/conformance.md, v6).
 *
 * <p>Proves the Java binding marshals every value shape across the FFI. It is
 * NOT a phone-number test suite — the behavioural cases live in the engine's
 * own tests and run once, in Aether. These checks sample each <em>kind</em> of
 * value crossing the FFI: strings, ints, booleans, enums, the parsed-number and
 * AsYouType state strings, and the matcher's spans.
 *
 * <h2>Why a main-method runner instead of JUnit</h2>
 * This suite must run with nothing but a JDK, so {@code java/aether/.tests.ae}
 * works offline and without Maven resolving anything. The assertions are a
 * couple of dozen lines; a test framework would be the only thing in the whole
 * binding that needed a network fetch.
 *
 * <p>Run:
 * <pre>{@code
 * javac -d out *.java
 * LIBPHONENUMBER_AE_LIB=... java --enable-native-access=ALL-UNNAMED \
 *     -cp out org.libphonenumber.ae.ConformanceTest
 * }</pre>
 */
public final class ConformanceTest {

    private static int passed = 0;
    private static final List<String> failures = new ArrayList<>();

    public static void main(String[] args) {
        // ---- the 45 required checks (docs/conformance.md v6) ----
        check("01 country_code US", () ->
                assertEquals("1", PhoneNumbers.countryCode("US")));
        check("02 country_code GB", () ->
                assertEquals("44", PhoneNumbers.countryCode("GB")));
        check("03 unknown region", () ->
                assertEquals("", PhoneNumbers.countryCode("ZZ")));
        check("04 example_number US", () ->
                assertEquals("2015550123", PhoneNumbers.exampleNumber("US")));
        check("05 possible_lengths US", () ->
                assertEquals("10", PhoneNumbers.possibleLengths("US")));
        check("06 region_code_for_country_code 44", () ->
                assertEquals("GB", PhoneNumbers.regionCodeForCountryCode("44")));
        check("07 is_nanpa_country US", () ->
                assertTrue("US is NANPA", PhoneNumbers.isNanpaCountry("US")));
        check("08 region enumeration", () -> {
            List<String> regs = PhoneNumbers.regions();
            assertTrue("region_count >= 200, got " + regs.size(), regs.size() >= 200);
            assertTrue("region_at(0) is 2 letters, got '" + regs.get(0) + "'",
                    regs.get(0).length() == 2);
        });
        check("09 cc_region_at 1,0", () ->
                assertEquals("US", PhoneNumbers.regionsForCountryCode("1").get(0)));

        // 10-14: parse "+1 201 555 0123 ext 42" in US
        ParsedNumber parsed = PhoneNumbers.parse("+1 201 555 0123 ext 42", "US");
        check("10 parse national_number", () ->
                assertEquals("2015550123", parsed.nationalNumber()));
        check("11 parse extension", () ->
                assertEquals("42", parsed.extension()));
        check("12 parse country_code", () ->
                assertEquals("1", parsed.countryCode()));
        check("13 parse source FROM_NUMBER_WITH_PLUS", () -> {
            assertEquals(Native.SRC_FROM_NUMBER_WITH_PLUS, parsed.sourceCode());
            assertEquals(CountryCodeSource.FROM_NUMBER_WITH_PLUS, parsed.source());
        });
        check("14 parse region_code_for_number", () ->
                assertEquals("US", parsed.regionCode()));

        check("15 parse GB trunk 0 stripped", () ->
                assertEquals("1212345678",
                        PhoneNumbers.parse("01212345678", "GB").nationalNumber()));
        check("16 is_possible_number US", () ->
                assertTrue("possible", PhoneNumbers.isPossibleNumber("US", "2015550123")));
        check("17 is_possible_with_reason TOO_SHORT", () -> {
            assertEquals(Native.VR_TOO_SHORT,
                    PhoneNumbers.isPossibleNumberWithReasonCode("US", "201555"));
            assertEquals(ValidationResult.TOO_SHORT,
                    PhoneNumbers.isPossibleNumberWithReason("US", "201555"));
        });
        check("18 is_valid_number US", () ->
                assertTrue("valid", PhoneNumbers.isValidNumber("US", "2015550123")));
        check("19 is_valid_number wrong shape", () ->
                assertTrue("invalid", !PhoneNumbers.isValidNumber("US", "1015550123")));
        check("20 is_valid_number with +cc", () ->
                assertTrue("valid with cc", PhoneNumbers.isValidNumber("US", "+12015550123")));
        check("21 number_type FIXED_LINE_OR_MOBILE / FIXED_LINE", () -> {
            assertEquals(Native.TYPE_FIXED_LINE_OR_MOBILE, PhoneNumbers.numberTypeCode("US", "2015550123"));
            assertEquals(NumberType.FIXED_LINE_OR_MOBILE, PhoneNumbers.numberType("US", "2015550123"));
            assertEquals(Native.TYPE_FIXED_LINE, PhoneNumbers.numberTypeCode("GB", "2070313000"));
            assertEquals(NumberType.FIXED_LINE, PhoneNumbers.numberType("GB", "2070313000"));
        });
        check("22 format NATIONAL", () ->
                assertEquals("(201) 555-0123",
                        PhoneNumbers.format("US", "2015550123", Format.NATIONAL)));
        check("23 format E164", () ->
                assertEquals("+12015550123",
                        PhoneNumbers.format("US", "2015550123", Format.E164)));
        check("24 format INTERNATIONAL", () ->
                assertEquals("+1 201-555-0123",
                        PhoneNumbers.format("US", "2015550123", Format.INTERNATIONAL)));
        check("25 format RFC3966", () ->
                assertEquals("tel:+1-201-555-0123",
                        PhoneNumbers.format("US", "2015550123", Format.RFC3966)));
        check("26 is_number_match EXACT", () -> {
            assertEquals(Native.MATCH_EXACT,
                    PhoneNumbers.isNumberMatchCode("+12015550123", "+1 201 555 0123"));
            assertEquals(MatchType.EXACT_MATCH,
                    PhoneNumbers.isNumberMatch("+12015550123", "+1 201 555 0123"));
        });
        check("27 is_number_match NO_MATCH", () -> {
            assertEquals(Native.MATCH_NO_MATCH,
                    PhoneNumbers.isNumberMatchCode("+12015550123", "+12025550123"));
            assertEquals(MatchType.NO_MATCH,
                    PhoneNumbers.isNumberMatch("+12015550123", "+12025550123"));
        });
        check("28 normalize_digits_only", () ->
                assertEquals("12015550123",
                        PhoneNumbers.normalizeDigitsOnly("+1 (201) 555.0123")));
        check("29 convert_alpha_characters", () ->
                assertEquals("1-800-3569377",
                        PhoneNumbers.convertAlphaCharacters("1-800-FLOWERS")));
        check("30 truncate_too_long", () ->
                assertEquals("2015550123",
                        PhoneNumbers.truncateTooLong("US", "20155501239999")));
        check("31 AsYouType", () -> {
            AsYouTypeFormatter f = new AsYouTypeFormatter("US");
            String out = "";
            for (char c : "2015550123".toCharArray()) out = f.inputDigit(c);
            assertEquals("(201) 555-0123", out);
        });
        check("32 matcher_count", () -> {
            List<Matcher.Match> ms = PhoneNumbers.findNumbers(
                    "call 201-555-0123 or +1 202 555 0199", "US", Leniency.VALID);
            assertEquals(2, ms.size());
        });
        check("33 matcher_raw", () -> {
            List<Matcher.Match> ms = PhoneNumbers.findNumbers(
                    "call 201-555-0123 now", "US", Leniency.VALID);
            assertEquals("201-555-0123", ms.get(0).raw());
        });
        check("34 abi_version", () ->
                assertEquals(6, PhoneNumbers.abiVersion()));
        check("35 is_emergency_number US 911", () ->
                assertTrue("911 emergency in US", ShortNumberInfo.isEmergencyNumber("US", "911")));
        check("36 is_emergency_number US 999", () ->
                assertTrue("999 not emergency in US", !ShortNumberInfo.isEmergencyNumber("US", "999")));
        check("37 is_emergency_number GB 999", () ->
                assertTrue("999 emergency in GB", ShortNumberInfo.isEmergencyNumber("GB", "999")));
        check("38 short_is_valid US 911", () ->
                assertTrue("911 valid short in US", ShortNumberInfo.isValidShortNumber("US", "911")));
        check("39 short_expected_cost US 911 TOLL_FREE", () -> {
            assertEquals(Native.COST_TOLL_FREE,
                    ShortNumberInfo.expectedCostCode("US", "911"));
            assertEquals(ShortNumberCost.TOLL_FREE,
                    ShortNumberInfo.expectedCost("US", "911"));
        });
        check("40 short_example_number US", () ->
                assertEquals("112", ShortNumberInfo.exampleNumber("US")));
        check("41 time_zones_for_number US", () ->
                assertEquals(List.of("America/New_York"),
                        TimeZones.timeZonesForNumber("US", "2015550123")));
        check("42 time_zones_for_number GB", () ->
                assertEquals(List.of("Europe/London"),
                        TimeZones.timeZonesForNumber("GB", "2070313000")));
        check("43 unknown_time_zone", () ->
                assertEquals("Etc/Unknown", TimeZones.unknownTimeZone()));
        check("44 carrier_name_for_number GB", () ->
                assertEquals("O2", Carrier.carrierNameForNumber("GB", "7106000000")));
        check("45 geo_description_for_number US", () ->
                assertEquals("Mountain View, CA",
                        Geocoder.geoDescriptionForNumber("US", "6502530000")));

        // ---- extras: the convenience / value-object surface ----
        check("format helpers agree with format()", () -> {
            assertEquals("(201) 555-0123", PhoneNumbers.formatNational("US", "2015550123"));
            assertEquals("+1 201-555-0123", PhoneNumbers.formatInternational("US", "2015550123"));
            assertEquals("+12015550123", PhoneNumbers.formatE164("US", "2015550123"));
            assertEquals("tel:+1-201-555-0123", PhoneNumbers.formatRfc3966("US", "2015550123"));
        });
        check("parse of a good number has no error", () ->
                assertTrue("no error", parsed.error().isEmpty() && parsed.isValid()));
        check("NumberType.of tolerates an unknown code", () ->
                assertEquals(NumberType.UNKNOWN, NumberType.of(9999)));
        check("Format.E164 is ABI code 0", () ->
                assertEquals(0, Format.E164.code()));
        check("PhoneNumbers delegates the short surface", () -> {
            assertTrue("PhoneNumbers.isEmergencyNumber", PhoneNumbers.isEmergencyNumber("US", "911"));
            assertEquals(ShortNumberCost.TOLL_FREE, PhoneNumbers.shortExpectedCost("US", "911"));
            assertEquals("112", PhoneNumbers.shortExampleNumber("US"));
        });
        check("ShortNumberCost.of tolerates an unknown code", () ->
                assertEquals(ShortNumberCost.UNKNOWN, ShortNumberCost.of(9999)));
        check("PhoneNumbers delegates the timezone + carrier + geocoder surface", () -> {
            assertEquals(List.of("America/New_York"),
                    PhoneNumbers.timeZonesForNumber("US", "2015550123"));
            assertEquals("Etc/Unknown", PhoneNumbers.unknownTimeZone());
            assertEquals("O2", PhoneNumbers.carrierNameForNumber("GB", "7106000000"));
            assertEquals("Mountain View, CA",
                    PhoneNumbers.geoDescriptionForNumber("US", "6502530000"));
        });

        // ---- report ----
        System.out.println();
        if (failures.isEmpty()) {
            System.out.println("PASS (v6, timezones + carrier + geocoder) — " + passed + " checks");
            System.exit(0);
        }
        System.out.println("FAIL (v6) — " + failures.size() + " of "
                + (passed + failures.size()) + " checks failed:");
        for (String f : failures) System.out.println("  " + f);
        System.exit(1);
    }

    private static void check(String name, Runnable body) {
        try {
            body.run();
            passed++;
            System.out.println("  ok   " + name);
        } catch (Throwable t) {
            failures.add(name + ": " + t);
            System.out.println("  FAIL " + name + ": " + t);
        }
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!String.valueOf(expected).equals(String.valueOf(actual))) {
            throw new AssertionError("expected <" + expected + "> but was <" + actual + ">");
        }
    }

    private static void assertTrue(String what, boolean cond) {
        if (!cond) throw new AssertionError("expected " + what);
    }

    private ConformanceTest() {
    }
}
