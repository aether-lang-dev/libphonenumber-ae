package org.libphonenumber.ae;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Validate, parse and format international phone numbers — the idiomatic Java
 * entry point over the shared Aether engine (ABI v5, full
 * {@code PhoneNumberUtil} parity plus {@code ShortNumberInfo}, the timezone
 * mapper and the carrier mapper).
 *
 * <pre>{@code
 * ParsedNumber n = PhoneNumbers.parse("+1 650 253 0000", "US");
 * n.nationalNumber();                                  // "6502530000"
 * PhoneNumbers.isValidNumber("US", "+1 650 253 0000"); // true
 * PhoneNumbers.format("US", "6502530000", Format.INTERNATIONAL); // "+1 650-253-0000"
 *
 * AsYouTypeFormatter f = new AsYouTypeFormatter("US");
 * for (char c : "6502530000".toCharArray()) f.inputDigit(c); // "(650) 253-0000"
 *
 * Matcher.find("call 201-555-0123 today", "US");
 * }</pre>
 *
 * <p>This class carries <b>no phone-number logic</b>. The engine — the metadata
 * table, {@code isPossible}/{@code isValid}, number-type classification, the
 * formatter and the matcher — is the pure-Aether {@code core/phonenumber.ae},
 * shared by every language binding in this monorepo. Cross-language behaviour is
 * therefore identical by construction, not by test. Everything here marshals to
 * an {@code aether_pn_embed_*} call in {@link Native}.
 *
 * <p>All methods are static and stateless: the ABI has no handle. The engine is
 * loaded lazily and cached on first use via {@link Native#load}.
 *
 * <p>Requires {@code --enable-native-access=ALL-UNNAMED} on the command line.
 */
public final class PhoneNumbers {

    private PhoneNumbers() {
    }

    private static Native api() {
        return Native.load(null);
    }

    // ---- metadata ---------------------------------------------------------

    /** The country calling code for a region ({@code "1"}, {@code "44"}, …), or {@code ""} if unknown. */
    public static String countryCode(String region) {
        Native a = api();
        return a.call1s(a.countryCode, region);
    }

    /** An example national number for the region, or {@code ""}. */
    public static String exampleNumber(String region) {
        Native a = api();
        return a.call1s(a.exampleNumber, region);
    }

    /** An example number of the given {@link NumberType} for the region, or {@code ""}. */
    public static String exampleNumberForType(String region, NumberType type) {
        return exampleNumberForType(region, type.code());
    }

    /** An example number of the given type code for the region, or {@code ""}. */
    public static String exampleNumberForType(String region, int typeCode) {
        Native a = api();
        return a.call1s1i(a.exampleNumberForType, region, typeCode);
    }

    /** An example number that is deliberately <em>invalid</em> for the region, or {@code ""}. */
    public static String invalidExampleNumber(String region) {
        Native a = api();
        return a.call1s(a.invalidExampleNumber, region);
    }

    /** The possible-lengths spec for the region (e.g. {@code "10"}), or {@code ""}. */
    public static String possibleLengths(String region) {
        Native a = api();
        return a.call1s(a.possibleLengths, region);
    }

    /** The main region for a country calling code (e.g. {@code "GB"} for {@code "44"}), or {@code ""}. */
    public static String regionCodeForCountryCode(String cc) {
        Native a = api();
        return a.call1s(a.regionCodeForCountryCode, cc);
    }

    /** True if the region belongs to the North American Numbering Plan. */
    public static boolean isNanpaCountry(String region) {
        Native a = api();
        return a.calli1s(a.isNanpaCountry, region) != 0;
    }

    /** The national-direct-dialling prefix for the region, or {@code ""}. */
    public static String nddPrefixForRegion(String region, boolean stripNonDigits) {
        Native a = api();
        return a.call1s1i(a.nddPrefixForRegion, region, stripNonDigits ? 1 : 0);
    }

    /** Every region id the metadata carries, as a list of ISO-3166 codes. */
    public static List<String> regions() {
        Native a = api();
        try {
            int n = (int) a.regionCount.invokeExact();
            List<String> out = new ArrayList<>(n);
            for (int i = 0; i < n; i++) {
                out.add(a.takeString((java.lang.foreign.MemorySegment) a.regionAt.invokeExact(i)));
            }
            return Collections.unmodifiableList(out);
        } catch (Throwable t) {
            throw Native.wrap(t);
        }
    }

    /** The number of region ids the metadata carries. */
    public static int regionCount() {
        Native a = api();
        try {
            return (int) a.regionCount.invokeExact();
        } catch (Throwable t) {
            throw Native.wrap(t);
        }
    }

    /** The regions served by a country calling code, main region first. */
    public static List<String> regionsForCountryCode(String cc) {
        Native a = api();
        int n = a.calli1s(a.ccRegionCount, cc);
        List<String> out = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            out.add(a.call1s1i(a.ccRegionAt, cc, i));
        }
        return Collections.unmodifiableList(out);
    }

    // ---- parse ------------------------------------------------------------

    /** Parse raw input into a {@link ParsedNumber}. Read {@link ParsedNumber#error()} for failures. */
    public static ParsedNumber parse(String input, String region) {
        Native a = api();
        return new ParsedNumber(a.call2s(a.parse, input, region));
    }

    /** The national number extracted from raw input (calling code + punctuation stripped). */
    public static String nationalNumber(String region, String input) {
        Native a = api();
        return a.call2s(a.nationalNumber, region, input);
    }

    // ---- validation -------------------------------------------------------

    /** True if the national number is a length the region allows. */
    public static boolean isPossibleNumber(String region, String input) {
        Native a = api();
        return a.calli2s(a.isPossibleNumber, region, input) != 0;
    }

    /** Why (or why not) the number is possible, as an ABI int. */
    public static int isPossibleNumberWithReasonCode(String region, String input) {
        Native a = api();
        return a.calli2s(a.isPossibleNumberWithReason, region, input);
    }

    /** Why (or why not) the number is possible, as a {@link ValidationResult} (may be {@code null}). */
    public static ValidationResult isPossibleNumberWithReason(String region, String input) {
        return ValidationResult.of(isPossibleNumberWithReasonCode(region, input));
    }

    /** True if the number matches the region's national-number patterns. */
    public static boolean isValidNumber(String region, String input) {
        Native a = api();
        return a.calli2s(a.isValidNumber, region, input) != 0;
    }

    /** True if the number is valid <em>and</em> belongs to the given region. Note arg order: {@code (input, region)}. */
    public static boolean isValidNumberForRegion(String input, String region) {
        Native a = api();
        return a.calli2s(a.isValidNumberForRegion, input, region) != 0;
    }

    /** The number's type as an ABI int ({@code -1} for unknown). */
    public static int numberTypeCode(String region, String input) {
        Native a = api();
        return a.calli2s(a.numberType, region, input);
    }

    /** The number's {@link NumberType}. Never throws on an unrecognised code — see {@link NumberType#of}. */
    public static NumberType numberType(String region, String input) {
        return NumberType.of(numberTypeCode(region, input));
    }

    /** True if the number can be dialled from outside its country. */
    public static boolean canBeInternationallyDialled(String region, String input) {
        Native a = api();
        return a.calli2s(a.canBeInternationallyDialled, region, input) != 0;
    }

    // ---- formatting -------------------------------------------------------

    /** Format the number in the given style. */
    public static String format(String region, String input, Format style) {
        Native a = api();
        return a.call2s1i(a.format, region, input, style.code());
    }

    public static String formatNational(String region, String input) {
        return format(region, input, Format.NATIONAL);
    }

    public static String formatInternational(String region, String input) {
        return format(region, input, Format.INTERNATIONAL);
    }

    public static String formatE164(String region, String input) {
        return format(region, input, Format.E164);
    }

    public static String formatRfc3966(String region, String input) {
        return format(region, input, Format.RFC3966);
    }

    /** Format {@code input} (of {@code region}) as it would be dialled from {@code callingFrom}. */
    public static String formatOutOfCountry(String region, String input, String callingFrom) {
        Native a = api();
        return a.call3s(a.formatOutOfCountry, region, input, callingFrom);
    }

    /** Re-render a parsed number the way it was originally dialled, from {@code callingFrom}. */
    public static String formatInOriginal(ParsedNumber number, String callingFrom) {
        return number.formatInOriginal(callingFrom);
    }

    // ---- relations / helpers ---------------------------------------------

    /** How well two numbers match, as an ABI int. */
    public static int isNumberMatchCode(String a, String b) {
        Native api = api();
        return api.calli2s(api.isNumberMatch, a, b);
    }

    /** How well two numbers match, as a {@link MatchType}. */
    public static MatchType isNumberMatch(String a, String b) {
        return MatchType.of(isNumberMatchCode(a, b));
    }

    /** Trim a too-long number down to a possible length for the region. */
    public static String truncateTooLong(String region, String input) {
        Native a = api();
        return a.call2s(a.truncateTooLong, region, input);
    }

    /** Strip everything but the digits, mapping any wide/Arabic digits to ASCII. */
    public static String normalizeDigitsOnly(String s) {
        Native a = api();
        return a.call1s(a.normalizeDigitsOnly, s);
    }

    /** Convert vanity letters to their dial-pad digits (e.g. {@code FLOWERS -> 3569377}). */
    public static String convertAlphaCharacters(String s) {
        Native a = api();
        return a.call1s(a.convertAlphaCharacters, s);
    }

    /** True if the input contains vanity letters. */
    public static boolean isAlphaNumber(String s) {
        Native a = api();
        return a.calli1s(a.isAlphaNumber, s) != 0;
    }

    // ---- find numbers -----------------------------------------------------

    /** Find phone numbers in free text (see {@link Matcher}). */
    public static List<Matcher.Match> findNumbers(String text, String region) {
        return Matcher.find(text, region);
    }

    /** Find phone numbers in free text at the given leniency. */
    public static List<Matcher.Match> findNumbers(String text, String region, Leniency leniency) {
        return Matcher.find(text, region, leniency);
    }

    // ---- short numbers ----------------------------------------------------
    //
    // Short numbers (emergency, directory, premium SMS, …) are dialled as-is:
    // no country code and no national prefix. These delegate to
    // {@link ShortNumberInfo}, which also stands on its own.

    /** True if the input is a possible short number for the region. See {@link ShortNumberInfo}. */
    public static boolean isPossibleShortNumber(String region, String input) {
        return ShortNumberInfo.isPossibleShortNumber(region, input);
    }

    /** True if the input is a valid short number for the region. */
    public static boolean isValidShortNumber(String region, String input) {
        return ShortNumberInfo.isValidShortNumber(region, input);
    }

    /** True if the input is an emergency number for the region. */
    public static boolean isEmergencyNumber(String region, String input) {
        return ShortNumberInfo.isEmergencyNumber(region, input);
    }

    /** True if dialling the input in the region connects to an emergency service. */
    public static boolean connectsToEmergencyNumber(String region, String input) {
        return ShortNumberInfo.connectsToEmergencyNumber(region, input);
    }

    /** True if the short number is carrier-specific for the region. */
    public static boolean isCarrierSpecific(String region, String input) {
        return ShortNumberInfo.isCarrierSpecific(region, input);
    }

    /** True if the short number is an SMS service for the region. */
    public static boolean isSmsService(String region, String input) {
        return ShortNumberInfo.isSmsService(region, input);
    }

    /** The expected cost of the short number, as a {@link ShortNumberCost}. */
    public static ShortNumberCost shortExpectedCost(String region, String input) {
        return ShortNumberInfo.expectedCost(region, input);
    }

    /** An example short number for the region, or {@code ""}. */
    public static String shortExampleNumber(String region) {
        return ShortNumberInfo.exampleNumber(region);
    }

    // ---- timezones --------------------------------------------------------
    //
    // A longest-prefix match over the number's E.164 digits. These delegate to
    // {@link TimeZones}, which also stands on its own.

    /** The IANA timezone ids for a number (empty-ish maps to {@code ["Etc/Unknown"]}). See {@link TimeZones}. */
    public static List<String> timeZonesForNumber(String region, String input) {
        return TimeZones.timeZonesForNumber(region, input);
    }

    /** The number of zones for the number ({@code 0} = only the unknown zone). */
    public static int timeZoneCount(String region, String input) {
        return TimeZones.timeZoneCount(region, input);
    }

    /** The unknown-zone sentinel, {@code "Etc/Unknown"}. */
    public static String unknownTimeZone() {
        return TimeZones.unknownTimeZone();
    }

    // ---- carrier ----------------------------------------------------------
    //
    // English carrier names by longest-prefix match over the E.164 digits.
    // These delegate to {@link Carrier}, which also stands on its own.

    /** The carrier name for a number (English), or {@code ""}. See {@link Carrier}. */
    public static String carrierNameForNumber(String region, String input) {
        return Carrier.carrierNameForNumber(region, input);
    }

    /** The carrier name only when the number is valid, else {@code ""}. */
    public static String carrierNameForValidNumber(String region, String input) {
        return Carrier.carrierNameForValidNumber(region, input);
    }

    // ---- version ----------------------------------------------------------

    /** The ABI revision the loaded engine reports ({@code 5} for this build). */
    public static int abiVersion() {
        Native a = api();
        try {
            return (int) a.abiVersion.invokeExact();
        } catch (Throwable t) {
            throw Native.wrap(t);
        }
    }
}
