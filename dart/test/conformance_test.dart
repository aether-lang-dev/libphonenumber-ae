/// The 34-check binding conformance suite (docs/conformance.md, v2).
///
/// Proves the Dart binding marshals every value shape across the FFI. It is NOT
/// a phone-number test suite — the behavioural cases live in the engine's own
/// tests and run once, in Aether.
@TestOn('vm')
library;

import 'package:phonenumber_ae/phonenumber_ae.dart' as pn;
import 'package:test/test.dart';

void main() {
  test('01 country_code US', () {
    expect(pn.countryCode('US'), equals('1'));
  });

  test('02 country_code GB', () {
    expect(pn.countryCode('GB'), equals('44'));
  });

  test('03 unknown region', () {
    expect(pn.countryCode('ZZ'), equals(''));
  });

  test('04 example_number US', () {
    expect(pn.exampleNumber('US'), equals('2015550123'));
  });

  test('05 possible_lengths US', () {
    expect(pn.possibleLengths('US'), equals('10'));
  });

  test('06 region_code_for_country_code 44', () {
    expect(pn.regionCodeForCountryCode('44'), equals('GB'));
  });

  test('07 is_nanpa_country US', () {
    expect(pn.isNanpaCountry('US'), isTrue);
  });

  test('08 region enumeration', () {
    final regs = pn.regions();
    expect(regs.length, greaterThanOrEqualTo(200));
    expect(regs[0].length, equals(2));
  });

  test('09 cc_region_at 1,0', () {
    expect(pn.regionsForCountryCode('1')[0], equals('US'));
  });

  test('10-14 parse', () {
    final num = pn.parse('+1 201 555 0123 ext 42', 'US');
    expect(num.error, equals(''));
    expect(num.nationalNumber, equals('2015550123')); // 10
    expect(num.extension, equals('42')); // 11
    expect(num.countryCode, equals('1')); // 12
    expect(num.source, equals(pn.CountryCodeSource.fromNumberWithPlus)); // 13
    expect(num.regionCode, equals('US')); // 14
  });

  test('15 parse trunk-prefix strip (GB)', () {
    expect(pn.parse('01212345678', 'GB').nationalNumber, equals('1212345678'));
  });

  test('16 is_possible yes', () {
    expect(pn.isPossibleNumber('US', '2015550123'), isTrue);
  });

  test('17 reason too short', () {
    expect(pn.isPossibleNumberWithReason('US', '201555'),
        equals(pn.ValidationResult.tooShort));
  });

  test('18 is_valid yes', () {
    expect(pn.isValidNumber('US', '2015550123'), isTrue);
  });

  test('19 is_valid wrong shape', () {
    expect(pn.isValidNumber('US', '1015550123'), isFalse);
  });

  test('20 is_valid with +cc', () {
    expect(pn.isValidNumber('US', '+12015550123'), isTrue);
  });

  test('21 number_type fixed line or mobile', () {
    // US fixedLine==mobile -> fixedLineOrMobile; GB has distinct patterns.
    expect(pn.numberType('US', '2015550123'),
        equals(pn.PhoneNumberType.fixedLineOrMobile));
    expect(pn.PhoneNumberType.fixedLineOrMobile.code, equals(10));
    expect(
        pn.numberType('GB', '2070313000'), equals(pn.PhoneNumberType.fixedLine));
    expect(pn.PhoneNumberType.fixedLine.code, equals(0));
  });

  test('22 format national', () {
    expect(pn.format('US', '2015550123', pn.PhoneFormat.national),
        equals('(201) 555-0123'));
  });

  test('23 format E164', () {
    expect(pn.format('US', '2015550123', pn.PhoneFormat.e164),
        equals('+12015550123'));
    expect(pn.PhoneFormat.e164.code, equals(0));
  });

  test('24 format international', () {
    expect(pn.format('US', '2015550123', pn.PhoneFormat.international),
        equals('+1 201-555-0123'));
  });

  test('25 format RFC3966', () {
    expect(pn.format('US', '2015550123', pn.PhoneFormat.rfc3966),
        equals('tel:+1-201-555-0123'));
  });

  test('26 is_number_match exact', () {
    expect(pn.isNumberMatch('+12015550123', '+1 201 555 0123'),
        equals(pn.MatchType.exact));
  });

  test('27 is_number_match none', () {
    expect(pn.isNumberMatch('+12015550123', '+12025550123'),
        equals(pn.MatchType.noMatch));
  });

  test('28 normalize_digits_only', () {
    expect(pn.normalizeDigitsOnly('+1 (201) 555.0123'), equals('12015550123'));
  });

  test('29 convert_alpha_characters', () {
    expect(pn.convertAlphaCharacters('1-800-FLOWERS'), equals('1-800-3569377'));
  });

  test('30 truncate_too_long', () {
    expect(pn.truncateTooLong('US', '20155501239999'), equals('2015550123'));
  });

  test('31 as-you-type', () {
    final ayt = pn.AsYouTypeFormatter('US');
    var out = '';
    for (final c in '2015550123'.split('')) {
      out = ayt.inputDigit(c);
    }
    expect(out, equals('(201) 555-0123'));
  });

  test('32 matcher count', () {
    final matches = pn.findNumbers(
        'call 201-555-0123 or +1 202 555 0199', 'US',
        leniency: pn.Leniency.valid);
    expect(matches.length, equals(2));
  });

  test('33 matcher raw', () {
    final matches = pn.findNumbers('call 201-555-0123 now', 'US',
        leniency: pn.Leniency.valid);
    expect(matches[0].raw, equals('201-555-0123'));
  });

  test('34 abi version', () {
    expect(pn.abiVersion(), equals(2));
  });

  // ---- a few extras exercising the idiomatic surface ----

  test('format helpers agree with format()', () {
    expect(pn.formatNational('US', '2015550123'), equals('(201) 555-0123'));
    expect(pn.formatInternational('US', '2015550123'),
        equals('+1 201-555-0123'));
    expect(pn.formatE164('US', '2015550123'), equals('+12015550123'));
    expect(pn.formatRfc3966('US', '2015550123'), equals('tel:+1-201-555-0123'));
  });

  test('type enum round-trips its codes', () {
    expect(pn.PhoneNumberType.fromCode(-1), equals(pn.PhoneNumberType.unknown));
    expect(pn.PhoneNumberType.fromCode(1), equals(pn.PhoneNumberType.mobile));
    expect(pn.PhoneNumberType.fromCode(9), equals(pn.PhoneNumberType.voicemail));
    expect(pn.PhoneNumberType.fromCode(10),
        equals(pn.PhoneNumberType.fixedLineOrMobile));
  });

  test('matcher reports start/end offsets', () {
    final matches =
        pn.findNumbers('call 201-555-0123 now', 'US', leniency: pn.Leniency.valid);
    expect(matches[0].start, equals(5));
    expect(matches[0].end, equals(17));
  });
}
