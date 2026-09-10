'use strict';
/**
 * The 34-check binding conformance suite (docs/conformance.md, v2).
 *
 * Proves the JavaScript binding marshals every value shape across the FFI. It
 * is NOT a phone-number test suite — the behavioural cases live in the engine's
 * own tests and run once, in Aether.
 *
 * Uses node:test + node:assert so no test framework has to be installed.
 */

const test = require('node:test');
const assert = require('node:assert');

const pn = require('..');

test('01 country_code US', () => {
  assert.strictEqual(pn.countryCode('US'), '1');
});

test('02 country_code GB', () => {
  assert.strictEqual(pn.countryCode('GB'), '44');
});

test('03 unknown region', () => {
  assert.strictEqual(pn.countryCode('ZZ'), '');
});

test('04 example_number US', () => {
  assert.strictEqual(pn.exampleNumber('US'), '2015550123');
});

test('05 possible_lengths US', () => {
  assert.strictEqual(pn.possibleLengths('US'), '10');
});

test('06 region_code_for_country_code 44', () => {
  assert.strictEqual(pn.regionCodeForCountryCode('44'), 'GB');
});

test('07 is_nanpa_country US', () => {
  assert.strictEqual(pn.isNanpaCountry('US'), true);
});

test('08 region enumeration', () => {
  const regs = pn.regions();
  assert.ok(regs.length >= 200, `expected >= 200 regions, got ${regs.length}`);
  assert.strictEqual(regs[0].length, 2, `region_at(0) should be 2 letters: ${regs[0]}`);
});

test('09 cc_region_at 1,0', () => {
  assert.strictEqual(pn.regionsForCountryCode('1')[0], 'US');
});

test('10-14 parse', () => {
  const num = pn.parse('+1 201 555 0123 ext 42', 'US');
  assert.strictEqual(num.error, '');
  assert.strictEqual(num.nationalNumber, '2015550123');       // 10
  assert.strictEqual(num.extension, '42');                    // 11
  assert.strictEqual(num.countryCode, '1');                   // 12
  assert.strictEqual(num.source, pn.SRC_FROM_NUMBER_WITH_PLUS); // 13
  assert.strictEqual(num.regionCode, 'US');                   // 14
});

test('15 parse trunk-prefix strip (GB)', () => {
  assert.strictEqual(pn.parse('01212345678', 'GB').nationalNumber, '1212345678');
});

test('16 is_possible yes', () => {
  assert.strictEqual(pn.isPossibleNumber('US', '2015550123'), true);
});

test('17 reason too short', () => {
  assert.strictEqual(
    pn.isPossibleNumberWithReason('US', '201555'), pn.VR_TOO_SHORT);
});

test('18 is_valid yes', () => {
  assert.strictEqual(pn.isValidNumber('US', '2015550123'), true);
});

test('19 is_valid wrong shape', () => {
  assert.strictEqual(pn.isValidNumber('US', '1015550123'), false);
});

test('20 is_valid with +cc', () => {
  assert.strictEqual(pn.isValidNumber('US', '+12015550123'), true);
});

test('21 number_type fixed line', () => {
  assert.strictEqual(pn.numberType('US', '2015550123'), pn.TYPE_FIXED_LINE);
  assert.strictEqual(pn.TYPE_FIXED_LINE, 0);
});

test('22 format national', () => {
  assert.strictEqual(pn.format('US', '2015550123', pn.NATIONAL), '(201) 555-0123');
});

test('23 format E164', () => {
  assert.strictEqual(pn.format('US', '2015550123', pn.E164), '+12015550123');
  assert.strictEqual(pn.E164, 0);
});

test('24 format international', () => {
  assert.strictEqual(
    pn.format('US', '2015550123', pn.INTERNATIONAL), '+1 201-555-0123');
});

test('25 format RFC3966', () => {
  assert.strictEqual(
    pn.format('US', '2015550123', pn.RFC3966), 'tel:+1-201-555-0123');
});

test('26 is_number_match exact', () => {
  assert.strictEqual(
    pn.isNumberMatch('+12015550123', '+1 201 555 0123'), pn.MATCH_EXACT);
});

test('27 is_number_match none', () => {
  assert.strictEqual(
    pn.isNumberMatch('+12015550123', '+12025550123'), pn.MATCH_NO_MATCH);
});

test('28 normalize_digits_only', () => {
  assert.strictEqual(
    pn.normalizeDigitsOnly('+1 (201) 555.0123'), '12015550123');
});

test('29 convert_alpha_characters', () => {
  assert.strictEqual(
    pn.convertAlphaCharacters('1-800-FLOWERS'), '1-800-3569377');
});

test('30 truncate_too_long', () => {
  assert.strictEqual(pn.truncateTooLong('US', '20155501239999'), '2015550123');
});

test('31 as-you-type', () => {
  const ayt = new pn.AsYouTypeFormatter('US');
  let out = '';
  for (const c of '2015550123') out = ayt.inputDigit(c);
  assert.strictEqual(out, '(201) 555-0123');
});

test('32 matcher count', () => {
  const matches = pn.findNumbers(
    'call 201-555-0123 or +1 202 555 0199', 'US', pn.LENIENCY_VALID);
  assert.strictEqual(matches.length, 2);
});

test('33 matcher raw', () => {
  const matches = pn.findNumbers('call 201-555-0123 now', 'US', pn.LENIENCY_VALID);
  assert.strictEqual(matches[0].raw, '201-555-0123');
});

test('34 abi version', () => {
  assert.strictEqual(pn.abiVersion(), 2);
});

// ---- a few extras exercising the idiomatic surface ----

test('format helpers agree with format()', () => {
  assert.strictEqual(pn.formatNational('US', '2015550123'), '(201) 555-0123');
  assert.strictEqual(pn.formatInternational('US', '2015550123'), '+1 201-555-0123');
  assert.strictEqual(pn.formatE164('US', '2015550123'), '+12015550123');
  assert.strictEqual(pn.formatRfc3966('US', '2015550123'), 'tel:+1-201-555-0123');
});

test('type constants are the documented ints', () => {
  assert.strictEqual(pn.TYPE_UNKNOWN, -1);
  assert.strictEqual(pn.TYPE_MOBILE, 1);
  assert.strictEqual(pn.TYPE_VOICEMAIL, 9);
});

test('matcher reports start/end offsets', () => {
  const [m] = pn.findNumbers('call 201-555-0123 now', 'US', pn.LENIENCY_VALID);
  assert.strictEqual(m.start, 5);
  assert.strictEqual(m.end, 17);
});
