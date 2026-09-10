package org.libphonenumber.ae.kotlin

import org.libphonenumber.ae.CountryCodeSource
import org.libphonenumber.ae.Format
import org.libphonenumber.ae.Leniency
import org.libphonenumber.ae.MatchType
import org.libphonenumber.ae.NumberType
import org.libphonenumber.ae.ValidationResult

/**
 * The 34-check binding conformance suite (docs/conformance.md, v2), in Kotlin.
 *
 * Proves the **Kotlin layer** reaches the same engine behaviour the Java and
 * Python suites see. Since that layer sits on the Java binding rather than on
 * its own FFI, what this really pins down is that the Kotlin sugar — the
 * top-level functions, the [Format]-keyed `format`, the `regions` property, the
 * re-exported value types — marshals every value shape correctly.
 *
 * It is NOT a phone-number test suite — the behavioural cases live in the
 * engine's own tests and run once, in Aether.
 *
 * A plain main method, not JUnit, for the same reason the Java suite is: the run
 * then needs nothing but a JDK and a Kotlin compiler, so it works offline and
 * cannot fail resolving a test-framework artifact.
 */
object ConformanceTest {

    private var passed = 0
    private val failures = mutableListOf<String>()

    @JvmStatic
    fun main(args: Array<String>) {
        // ---- the 34 required checks ----
        check("01 countryCode US") { assertEquals("1", countryCode("US")) }
        check("02 countryCode GB") { assertEquals("44", countryCode("GB")) }
        check("03 unknown region") { assertEquals("", countryCode("ZZ")) }
        check("04 exampleNumber US") { assertEquals("2015550123", exampleNumber("US")) }
        check("05 possibleLengths US") { assertEquals("10", possibleLengths("US")) }
        check("06 regionCodeForCountryCode 44") { assertEquals("GB", regionCodeForCountryCode("44")) }
        check("07 isNanpaCountry US") { assertTrue("US NANPA", isNanpaCountry("US")) }
        check("08 region enumeration") {
            val regs = regions
            assertTrue("region count >= 200, got ${regs.size}", regs.size >= 200)
            assertTrue("region[0] is 2 letters, got '${regs[0]}'", regs[0].length == 2)
        }
        check("09 regionsForCountryCode 1") {
            assertEquals("US", regionsForCountryCode("1")[0])
        }

        val parsed = parse("+1 201 555 0123 ext 42", "US")
        check("10 parse nationalNumber") { assertEquals("2015550123", parsed.nationalNumber()) }
        check("11 parse extension") { assertEquals("42", parsed.extension()) }
        check("12 parse countryCode") { assertEquals("1", parsed.countryCode()) }
        check("13 parse source FROM_NUMBER_WITH_PLUS") {
            assertEquals(CountryCodeSource.FROM_NUMBER_WITH_PLUS, parsed.source())
        }
        check("14 parse regionCode") { assertEquals("US", parsed.regionCode()) }

        check("15 parse GB trunk 0 stripped") {
            assertEquals("1212345678", parse("01212345678", "GB").nationalNumber())
        }
        check("16 isPossibleNumber US") { assertTrue("possible", isPossibleNumber("US", "2015550123")) }
        check("17 isPossibleWithReason TOO_SHORT") {
            assertEquals(ValidationResult.TOO_SHORT, isPossibleNumberWithReason("US", "201555"))
        }
        check("18 isValidNumber US") { assertTrue("valid", isValidNumber("US", "2015550123")) }
        check("19 isValidNumber wrong shape") {
            assertTrue("invalid", !isValidNumber("US", "1015550123"))
        }
        check("20 isValidNumber with +cc") { assertTrue("valid", isValidNumber("US", "+12015550123")) }
        check("21 numberType FIXED_LINE") {
            assertEquals(NumberType.FIXED_LINE, numberType("US", "2015550123"))
        }
        check("22 format NATIONAL") {
            assertEquals("(201) 555-0123", format("US", "2015550123", Format.NATIONAL))
        }
        check("23 format E164") {
            assertEquals("+12015550123", format("US", "2015550123", Format.E164))
        }
        check("24 format INTERNATIONAL") {
            assertEquals("+1 201-555-0123", format("US", "2015550123", Format.INTERNATIONAL))
        }
        check("25 format RFC3966") {
            assertEquals("tel:+1-201-555-0123", format("US", "2015550123", Format.RFC3966))
        }
        check("26 isNumberMatch EXACT") {
            assertEquals(MatchType.EXACT_MATCH, isNumberMatch("+12015550123", "+1 201 555 0123"))
        }
        check("27 isNumberMatch NO_MATCH") {
            assertEquals(MatchType.NO_MATCH, isNumberMatch("+12015550123", "+12025550123"))
        }
        check("28 normalizeDigitsOnly") {
            assertEquals("12015550123", normalizeDigitsOnly("+1 (201) 555.0123"))
        }
        check("29 convertAlphaCharacters") {
            assertEquals("1-800-3569377", convertAlphaCharacters("1-800-FLOWERS"))
        }
        check("30 truncateTooLong") {
            assertEquals("2015550123", truncateTooLong("US", "20155501239999"))
        }
        check("31 AsYouType") {
            val f = AsYouType("US")
            var out = ""
            for (c in "2015550123") out = f.inputDigit(c)
            assertEquals("(201) 555-0123", out)
        }
        check("32 findNumbers count") {
            val ms = findNumbers("call 201-555-0123 or +1 202 555 0199", "US", Leniency.VALID)
            assertEquals(2, ms.size)
        }
        check("33 findNumbers raw") {
            val ms = findNumbers("call 201-555-0123 now", "US", Leniency.VALID)
            assertEquals("201-555-0123", ms[0].raw())
        }
        check("34 abiVersion") { assertEquals(2, abiVersion()) }

        // ---- extras specific to the Kotlin layer ----
        check("format default style is NATIONAL") {
            assertEquals("(201) 555-0123", format("US", "2015550123"))
        }
        check("format helpers agree") {
            assertEquals("+12015550123", formatE164("US", "2015550123"))
            assertEquals("+1 201-555-0123", formatInternational("US", "2015550123"))
            assertEquals("tel:+1-201-555-0123", formatRfc3966("US", "2015550123"))
        }
        check("PhoneNumber typealias reads fields") {
            val n: PhoneNumber = parse("+1 201 555 0123", "US")
            assertTrue("valid parse", n.error().isEmpty())
        }

        // ---- report ----
        println()
        if (failures.isEmpty()) {
            println("PASS (v2) — $passed checks")
            System.exit(0)
        }
        println("FAIL (v2) — ${failures.size} of ${passed + failures.size} checks failed:")
        failures.forEach { println("  $it") }
        System.exit(1)
    }

    private fun check(name: String, body: () -> Unit) {
        try {
            body()
            passed++
            println("  ok   $name")
        } catch (t: Throwable) {
            failures += "$name: $t"
            println("  FAIL $name: $t")
        }
    }

    private fun assertEquals(expected: Any?, actual: Any?) {
        if (expected.toString() != actual.toString()) {
            throw AssertionError("expected <$expected> but was <$actual>")
        }
    }

    private fun assertTrue(what: String, cond: Boolean) {
        if (!cond) throw AssertionError("expected $what")
    }
}
