package org.libphonenumber.ae.groovy

import org.libphonenumber.ae.AsYouTypeFormatter
import org.libphonenumber.ae.Carrier
import org.libphonenumber.ae.Format
import org.libphonenumber.ae.Leniency
import org.libphonenumber.ae.MatchType
import org.libphonenumber.ae.Matcher
import org.libphonenumber.ae.NumberType
import org.libphonenumber.ae.ParsedNumber
import org.libphonenumber.ae.ShortNumberCost
import org.libphonenumber.ae.ShortNumberInfo
import org.libphonenumber.ae.TimeZones
import org.libphonenumber.ae.ValidationResult

/**
 * Idiomatic Groovy over the Java binding (ABI v5, full PhoneNumberUtil parity
 * plus ShortNumberInfo, the timezone mapper and the carrier mapper).
 *
 * There is <b>no second FFI here</b>. The one JVM binding to the shared Aether
 * engine is {@code java/aether/} (FFM / Panama); everything in this file is
 * ordinary Groovy/Java interop on top of those classes. A Groovy-specific FFI
 * would be a second copy of the marshalling rules to keep in step with
 * {@code core/embed.ae}, and the first thing to drift.
 *
 * These are thin static delegators — Groovy's dynamic typing and named-argument
 * ergonomics do the rest at the call site. The Java {@code PhoneNumbers} class
 * remains available and unchanged; this is a Groovy-friendly facade over it,
 * mirroring the shape of the Java surface (a {@code format} defaulting to
 * NATIONAL, {@code regions()} returning a list, the value types re-exposed).
 */
class PhoneNumbers {

    // ---- metadata ----

    static String countryCode(String region) {
        org.libphonenumber.ae.PhoneNumbers.countryCode(region)
    }

    static String exampleNumber(String region) {
        org.libphonenumber.ae.PhoneNumbers.exampleNumber(region)
    }

    static String exampleNumberForType(String region, NumberType type) {
        org.libphonenumber.ae.PhoneNumbers.exampleNumberForType(region, type)
    }

    static String invalidExampleNumber(String region) {
        org.libphonenumber.ae.PhoneNumbers.invalidExampleNumber(region)
    }

    static String possibleLengths(String region) {
        org.libphonenumber.ae.PhoneNumbers.possibleLengths(region)
    }

    static String regionCodeForCountryCode(String cc) {
        org.libphonenumber.ae.PhoneNumbers.regionCodeForCountryCode(cc)
    }

    static boolean isNanpaCountry(String region) {
        org.libphonenumber.ae.PhoneNumbers.isNanpaCountry(region)
    }

    static String nddPrefixForRegion(String region, boolean stripNonDigits = false) {
        org.libphonenumber.ae.PhoneNumbers.nddPrefixForRegion(region, stripNonDigits)
    }

    static List<String> regions() {
        org.libphonenumber.ae.PhoneNumbers.regions()
    }

    static List<String> regionsForCountryCode(String cc) {
        org.libphonenumber.ae.PhoneNumbers.regionsForCountryCode(cc)
    }

    // ---- parse ----

    static ParsedNumber parse(String input, String region) {
        org.libphonenumber.ae.PhoneNumbers.parse(input, region)
    }

    static String nationalNumber(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.nationalNumber(region, input)
    }

    // ---- validation ----

    static boolean isPossibleNumber(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.isPossibleNumber(region, input)
    }

    static ValidationResult isPossibleNumberWithReason(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.isPossibleNumberWithReason(region, input)
    }

    static boolean isValidNumber(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.isValidNumber(region, input)
    }

    static boolean isValidNumberForRegion(String input, String region) {
        org.libphonenumber.ae.PhoneNumbers.isValidNumberForRegion(input, region)
    }

    static NumberType numberType(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.numberType(region, input)
    }

    static boolean canBeInternationallyDialled(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.canBeInternationallyDialled(region, input)
    }

    // ---- formatting ----

    /** Format the number, defaulting to {@link Format#NATIONAL}. */
    static String format(String region, String input, Format style = Format.NATIONAL) {
        org.libphonenumber.ae.PhoneNumbers.format(region, input, style)
    }

    static String formatNational(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.formatNational(region, input)
    }

    static String formatInternational(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.formatInternational(region, input)
    }

    static String formatE164(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.formatE164(region, input)
    }

    static String formatRfc3966(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.formatRfc3966(region, input)
    }

    static String formatOutOfCountry(String region, String input, String callingFrom) {
        org.libphonenumber.ae.PhoneNumbers.formatOutOfCountry(region, input, callingFrom)
    }

    // ---- relations / helpers ----

    static MatchType isNumberMatch(String a, String b) {
        org.libphonenumber.ae.PhoneNumbers.isNumberMatch(a, b)
    }

    static String truncateTooLong(String region, String input) {
        org.libphonenumber.ae.PhoneNumbers.truncateTooLong(region, input)
    }

    static String normalizeDigitsOnly(String s) {
        org.libphonenumber.ae.PhoneNumbers.normalizeDigitsOnly(s)
    }

    static String convertAlphaCharacters(String s) {
        org.libphonenumber.ae.PhoneNumbers.convertAlphaCharacters(s)
    }

    static boolean isAlphaNumber(String s) {
        org.libphonenumber.ae.PhoneNumbers.isAlphaNumber(s)
    }

    // ---- find numbers ----

    static List<Matcher.Match> findNumbers(String text, String region, Leniency leniency = Leniency.VALID) {
        org.libphonenumber.ae.PhoneNumbers.findNumbers(text, region, leniency)
    }

    // ---- as-you-type ----

    static AsYouTypeFormatter asYouType(String region) {
        new AsYouTypeFormatter(region)
    }

    // ---- short numbers ----
    //
    // Short numbers (emergency, directory, premium SMS, …) are dialled as-is:
    // no country code and no national prefix. These reach the Java
    // ShortNumberInfo.

    static boolean isPossibleShortNumber(String region, String input) {
        ShortNumberInfo.isPossibleShortNumber(region, input)
    }

    static boolean isValidShortNumber(String region, String input) {
        ShortNumberInfo.isValidShortNumber(region, input)
    }

    static boolean isEmergencyNumber(String region, String input) {
        ShortNumberInfo.isEmergencyNumber(region, input)
    }

    static boolean connectsToEmergencyNumber(String region, String input) {
        ShortNumberInfo.connectsToEmergencyNumber(region, input)
    }

    static boolean isCarrierSpecific(String region, String input) {
        ShortNumberInfo.isCarrierSpecific(region, input)
    }

    static boolean isSmsService(String region, String input) {
        ShortNumberInfo.isSmsService(region, input)
    }

    static ShortNumberCost shortExpectedCost(String region, String input) {
        ShortNumberInfo.expectedCost(region, input)
    }

    static String shortExampleNumber(String region) {
        ShortNumberInfo.exampleNumber(region)
    }

    // ---- timezones ----
    //
    // A longest-prefix match over the number's E.164 digits. These reach the
    // Java TimeZones mapper.

    static List<String> timeZonesForNumber(String region, String input) {
        TimeZones.timeZonesForNumber(region, input)
    }

    static int timeZoneCount(String region, String input) {
        TimeZones.timeZoneCount(region, input)
    }

    static String unknownTimeZone() {
        TimeZones.unknownTimeZone()
    }

    // ---- carrier ----
    //
    // English carrier names by longest-prefix match over the E.164 digits.
    // These reach the Java Carrier mapper.

    static String carrierNameForNumber(String region, String input) {
        Carrier.carrierNameForNumber(region, input)
    }

    static String carrierNameForValidNumber(String region, String input) {
        Carrier.carrierNameForValidNumber(region, input)
    }

    // ---- version ----

    static int abiVersion() {
        org.libphonenumber.ae.PhoneNumbers.abiVersion()
    }
}
