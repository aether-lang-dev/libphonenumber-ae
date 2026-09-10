package org.libphonenumber.ae.groovy

import org.libphonenumber.ae.AsYouTypeFormatter
import org.libphonenumber.ae.CountryCodeSource
import org.libphonenumber.ae.Format
import org.libphonenumber.ae.Leniency
import org.libphonenumber.ae.MatchType
import org.libphonenumber.ae.NumberType
import org.libphonenumber.ae.ValidationResult

import static org.libphonenumber.ae.groovy.PhoneNumbers.abiVersion
import static org.libphonenumber.ae.groovy.PhoneNumbers.convertAlphaCharacters
import static org.libphonenumber.ae.groovy.PhoneNumbers.countryCode
import static org.libphonenumber.ae.groovy.PhoneNumbers.exampleNumber
import static org.libphonenumber.ae.groovy.PhoneNumbers.findNumbers
import static org.libphonenumber.ae.groovy.PhoneNumbers.format
import static org.libphonenumber.ae.groovy.PhoneNumbers.formatE164
import static org.libphonenumber.ae.groovy.PhoneNumbers.formatInternational
import static org.libphonenumber.ae.groovy.PhoneNumbers.formatRfc3966
import static org.libphonenumber.ae.groovy.PhoneNumbers.isNanpaCountry
import static org.libphonenumber.ae.groovy.PhoneNumbers.isNumberMatch
import static org.libphonenumber.ae.groovy.PhoneNumbers.isPossibleNumber
import static org.libphonenumber.ae.groovy.PhoneNumbers.isPossibleNumberWithReason
import static org.libphonenumber.ae.groovy.PhoneNumbers.isValidNumber
import static org.libphonenumber.ae.groovy.PhoneNumbers.normalizeDigitsOnly
import static org.libphonenumber.ae.groovy.PhoneNumbers.numberType
import static org.libphonenumber.ae.groovy.PhoneNumbers.parse
import static org.libphonenumber.ae.groovy.PhoneNumbers.possibleLengths
import static org.libphonenumber.ae.groovy.PhoneNumbers.regionCodeForCountryCode
import static org.libphonenumber.ae.groovy.PhoneNumbers.regions
import static org.libphonenumber.ae.groovy.PhoneNumbers.regionsForCountryCode
import static org.libphonenumber.ae.groovy.PhoneNumbers.truncateTooLong

/**
 * The 34-check binding conformance suite (docs/conformance.md, v2), in Groovy.
 *
 * Proves the <b>Groovy layer</b> reaches the same engine behaviour the Java and
 * Python suites see. Since that layer sits on the Java binding rather than on
 * its own FFI, what this really pins down is that the Groovy facade marshals
 * every value shape correctly.
 *
 * It is NOT a phone-number test suite — the behavioural cases live in the
 * engine's own tests and run once, in Aether.
 *
 * A plain main method, not Spock/JUnit, for the same reason the Java suite is:
 * the run then needs nothing but a JDK and the Groovy jar, so it works offline
 * and cannot fail resolving a test-framework artifact.
 */
class ConformanceTest {

    static int passed = 0
    static List<String> failures = []

    static void main(String[] args) {
        // ---- the 34 required checks ----
        check('01 countryCode US') { assertEquals('1', countryCode('US')) }
        check('02 countryCode GB') { assertEquals('44', countryCode('GB')) }
        check('03 unknown region') { assertEquals('', countryCode('ZZ')) }
        check('04 exampleNumber US') { assertEquals('2015550123', exampleNumber('US')) }
        check('05 possibleLengths US') { assertEquals('10', possibleLengths('US')) }
        check('06 regionCodeForCountryCode 44') { assertEquals('GB', regionCodeForCountryCode('44')) }
        check('07 isNanpaCountry US') { assertTrue('US NANPA', isNanpaCountry('US')) }
        check('08 region enumeration') {
            List regs = regions()
            assertTrue("region count >= 200, got ${regs.size()}", regs.size() >= 200)
            assertTrue("region[0] is 2 letters, got '${regs[0]}'", regs[0].length() == 2)
        }
        check('09 regionsForCountryCode 1') {
            assertEquals('US', regionsForCountryCode('1')[0])
        }

        def parsed = parse('+1 201 555 0123 ext 42', 'US')
        check('10 parse nationalNumber') { assertEquals('2015550123', parsed.nationalNumber()) }
        check('11 parse extension') { assertEquals('42', parsed.extension()) }
        check('12 parse countryCode') { assertEquals('1', parsed.countryCode()) }
        check('13 parse source FROM_NUMBER_WITH_PLUS') {
            assertEquals(CountryCodeSource.FROM_NUMBER_WITH_PLUS, parsed.source())
        }
        check('14 parse regionCode') { assertEquals('US', parsed.regionCode()) }

        check('15 parse GB trunk 0 stripped') {
            assertEquals('1212345678', parse('01212345678', 'GB').nationalNumber())
        }
        check('16 isPossibleNumber US') { assertTrue('possible', isPossibleNumber('US', '2015550123')) }
        check('17 isPossibleWithReason TOO_SHORT') {
            assertEquals(ValidationResult.TOO_SHORT, isPossibleNumberWithReason('US', '201555'))
        }
        check('18 isValidNumber US') { assertTrue('valid', isValidNumber('US', '2015550123')) }
        check('19 isValidNumber wrong shape') {
            assertTrue('invalid', !isValidNumber('US', '1015550123'))
        }
        check('20 isValidNumber with +cc') { assertTrue('valid', isValidNumber('US', '+12015550123')) }
        check('21 numberType FIXED_LINE') {
            assertEquals(NumberType.FIXED_LINE, numberType('US', '2015550123'))
        }
        check('22 format NATIONAL') {
            assertEquals('(201) 555-0123', format('US', '2015550123', Format.NATIONAL))
        }
        check('23 format E164') {
            assertEquals('+12015550123', format('US', '2015550123', Format.E164))
        }
        check('24 format INTERNATIONAL') {
            assertEquals('+1 201-555-0123', format('US', '2015550123', Format.INTERNATIONAL))
        }
        check('25 format RFC3966') {
            assertEquals('tel:+1-201-555-0123', format('US', '2015550123', Format.RFC3966))
        }
        check('26 isNumberMatch EXACT') {
            assertEquals(MatchType.EXACT_MATCH, isNumberMatch('+12015550123', '+1 201 555 0123'))
        }
        check('27 isNumberMatch NO_MATCH') {
            assertEquals(MatchType.NO_MATCH, isNumberMatch('+12015550123', '+12025550123'))
        }
        check('28 normalizeDigitsOnly') {
            assertEquals('12015550123', normalizeDigitsOnly('+1 (201) 555.0123'))
        }
        check('29 convertAlphaCharacters') {
            assertEquals('1-800-3569377', convertAlphaCharacters('1-800-FLOWERS'))
        }
        check('30 truncateTooLong') {
            assertEquals('2015550123', truncateTooLong('US', '20155501239999'))
        }
        check('31 AsYouType') {
            def f = new AsYouTypeFormatter('US')
            String out = ''
            '2015550123'.each { out = f.inputDigit(it as char) }
            assertEquals('(201) 555-0123', out)
        }
        check('32 findNumbers count') {
            def ms = findNumbers('call 201-555-0123 or +1 202 555 0199', 'US', Leniency.VALID)
            assertEquals(2, ms.size())
        }
        check('33 findNumbers raw') {
            def ms = findNumbers('call 201-555-0123 now', 'US', Leniency.VALID)
            assertEquals('201-555-0123', ms[0].raw())
        }
        check('34 abiVersion') { assertEquals(2, abiVersion()) }

        // ---- extras specific to the Groovy layer ----
        check('format default style is NATIONAL') {
            assertEquals('(201) 555-0123', format('US', '2015550123'))
        }
        check('format helpers agree') {
            assertEquals('+12015550123', formatE164('US', '2015550123'))
            assertEquals('+1 201-555-0123', formatInternational('US', '2015550123'))
            assertEquals('tel:+1-201-555-0123', formatRfc3966('US', '2015550123'))
        }

        // ---- report ----
        println()
        if (failures.isEmpty()) {
            println("PASS (v2) — $passed checks")
            System.exit(0)
        }
        println("FAIL (v2) — ${failures.size()} of ${passed + failures.size()} checks failed:")
        failures.each { println("  $it") }
        System.exit(1)
    }

    static void check(String name, Closure body) {
        try {
            body.call()
            passed++
            println("  ok   $name")
        } catch (Throwable t) {
            failures << "$name: $t"
            println("  FAIL $name: $t")
        }
    }

    static void assertEquals(Object expected, Object actual) {
        if (String.valueOf(expected) != String.valueOf(actual)) {
            throw new AssertionError("expected <$expected> but was <$actual>" as Object)
        }
    }

    static void assertTrue(String what, boolean cond) {
        if (!cond) throw new AssertionError("expected $what" as Object)
    }
}
