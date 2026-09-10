@file:JvmName("PhoneNumbersKt")

package org.libphonenumber.ae.kotlin

import org.libphonenumber.ae.AsYouTypeFormatter
import org.libphonenumber.ae.Format
import org.libphonenumber.ae.Leniency
import org.libphonenumber.ae.MatchType
import org.libphonenumber.ae.Matcher
import org.libphonenumber.ae.NumberType
import org.libphonenumber.ae.ParsedNumber
import org.libphonenumber.ae.PhoneNumbers
import org.libphonenumber.ae.ValidationResult

/**
 * Idiomatic Kotlin over the Java binding (ABI v2, full PhoneNumberUtil parity).
 *
 * There is **no second FFI here**. The one JVM binding to the shared Aether
 * engine is `java/aether/` (FFM / Panama); everything in this file is ordinary
 * Kotlin/Java interop on top of those classes. That is deliberate — a
 * Kotlin-specific FFI would be a second copy of the marshalling rules to keep in
 * sync with `core/embed.ae`, and the first thing to drift.
 *
 * What Kotlin adds, and all it adds:
 *
 *  * top-level functions, so `countryCode("US")` reads without the `PhoneNumbers.`
 *    qualifier;
 *  * a [format] overload keyed on the [Format] enum, defaulting to NATIONAL;
 *  * `regions` exposed as a property;
 *  * the value types ([ParsedNumber], [AsYouTypeFormatter], [Matcher]) re-exported
 *    by typealias so callers need not name the Java package.
 *
 * The engine carries the logic; this file carries none.
 */

typealias PhoneNumber = ParsedNumber
typealias AsYouType = AsYouTypeFormatter
typealias Match = Matcher.Match

// ---- metadata ----

fun countryCode(region: String): String = PhoneNumbers.countryCode(region)

fun exampleNumber(region: String): String = PhoneNumbers.exampleNumber(region)

fun exampleNumberForType(region: String, type: NumberType): String =
    PhoneNumbers.exampleNumberForType(region, type)

fun invalidExampleNumber(region: String): String = PhoneNumbers.invalidExampleNumber(region)

fun possibleLengths(region: String): String = PhoneNumbers.possibleLengths(region)

fun regionCodeForCountryCode(cc: String): String = PhoneNumbers.regionCodeForCountryCode(cc)

fun isNanpaCountry(region: String): Boolean = PhoneNumbers.isNanpaCountry(region)

fun nddPrefixForRegion(region: String, stripNonDigits: Boolean = false): String =
    PhoneNumbers.nddPrefixForRegion(region, stripNonDigits)

/** Every region id the metadata carries. */
val regions: List<String> get() = PhoneNumbers.regions()

fun regionsForCountryCode(cc: String): List<String> = PhoneNumbers.regionsForCountryCode(cc)

// ---- parse ----

fun parse(input: String, region: String): ParsedNumber = PhoneNumbers.parse(input, region)

fun nationalNumber(region: String, input: String): String =
    PhoneNumbers.nationalNumber(region, input)

// ---- validation ----

fun isPossibleNumber(region: String, input: String): Boolean =
    PhoneNumbers.isPossibleNumber(region, input)

/** Why (or why not) the number is possible; `null` for an unrecognised code. */
fun isPossibleNumberWithReason(region: String, input: String): ValidationResult? =
    PhoneNumbers.isPossibleNumberWithReason(region, input)

fun isValidNumber(region: String, input: String): Boolean =
    PhoneNumbers.isValidNumber(region, input)

fun isValidNumberForRegion(input: String, region: String): Boolean =
    PhoneNumbers.isValidNumberForRegion(input, region)

/** The number's type as a [NumberType]; never throws on an unknown code. */
fun numberType(region: String, input: String): NumberType =
    PhoneNumbers.numberType(region, input)

fun canBeInternationallyDialled(region: String, input: String): Boolean =
    PhoneNumbers.canBeInternationallyDialled(region, input)

// ---- formatting ----

/** Format the number, defaulting to [Format.NATIONAL]. */
fun format(region: String, input: String, style: Format = Format.NATIONAL): String =
    PhoneNumbers.format(region, input, style)

fun formatNational(region: String, input: String): String =
    PhoneNumbers.formatNational(region, input)

fun formatInternational(region: String, input: String): String =
    PhoneNumbers.formatInternational(region, input)

fun formatE164(region: String, input: String): String =
    PhoneNumbers.formatE164(region, input)

fun formatRfc3966(region: String, input: String): String =
    PhoneNumbers.formatRfc3966(region, input)

fun formatOutOfCountry(region: String, input: String, callingFrom: String): String =
    PhoneNumbers.formatOutOfCountry(region, input, callingFrom)

// ---- relations / helpers ----

/** How well two numbers match, as a [MatchType]. */
fun isNumberMatch(a: String, b: String): MatchType = PhoneNumbers.isNumberMatch(a, b)

fun truncateTooLong(region: String, input: String): String =
    PhoneNumbers.truncateTooLong(region, input)

fun normalizeDigitsOnly(s: String): String = PhoneNumbers.normalizeDigitsOnly(s)

fun convertAlphaCharacters(s: String): String = PhoneNumbers.convertAlphaCharacters(s)

fun isAlphaNumber(s: String): Boolean = PhoneNumbers.isAlphaNumber(s)

// ---- find numbers ----

fun findNumbers(text: String, region: String, leniency: Leniency = Leniency.VALID): List<Match> =
    PhoneNumbers.findNumbers(text, region, leniency)

// ---- version ----

fun abiVersion(): Int = PhoneNumbers.abiVersion()
