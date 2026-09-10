// A short tour of the Dart binding. Run it with the engine built:
//
//   aeb core/.build.ae
//   cd dart && dart pub get
//   LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
//       dart run example/main.dart

import 'package:phonenumber_ae/phonenumber_ae.dart' as pn;

void main() {
  print('engine: ${pn.nativeLibraryPath} (ABI v${pn.abiVersion()})');

  // 1. country codes
  print('US -> +${pn.countryCode('US')}, GB -> +${pn.countryCode('GB')}');

  // 2. validate and classify
  print('US 2015550123 valid? ${pn.isValidNumber('US', '2015550123')}');
  print('US 2015550123 type:  ${pn.numberType('US', '2015550123').name}');

  // 3. extract a national number from noisy input
  print('national: ${pn.nationalNumber('US', '+1 201 555 0123')}');

  // 4. format it four ways
  print('national:      ${pn.formatNational('US', '2015550123')}');
  print('international:  ${pn.formatInternational('US', '2015550123')}');
  print('e164:          ${pn.formatE164('US', '2015550123')}');
  print('rfc3966:       ${pn.formatRfc3966('US', '2015550123')}');

  // 5. format as it is typed
  final ayt = pn.AsYouTypeFormatter('US');
  var typed = '';
  for (final c in '6502530000'.split('')) {
    typed = ayt.inputDigit(c);
  }
  print('as-you-type:   $typed');

  // 6. find numbers in free text
  final matches = pn.findNumbers('call 201-555-0123 or +1 202 555 0199', 'US');
  print('${matches.length} matches, first raw: ${matches.first.raw}');

  // 7. the region table
  final regs = pn.regions();
  print('${regs.length} regions, first: ${regs.first}');
}
