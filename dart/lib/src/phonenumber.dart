/// The idiomatic Dart surface over the phonenumber engine (ABI v5).
///
/// Carries no phone-number logic — every member here marshals to an
/// `aether_pn_embed_*` call in `native.dart`. Most of the surface is top-level
/// functions; the stateful pieces (a parsed number, the as-you-type formatter,
/// the free-text matcher) are small classes over caller-owned ABI strings.
library;

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' as pkgffi;

import 'native.dart' as n;

/// How to render a number with [format].
enum PhoneFormat {
  e164(n.kE164),
  international(n.kInternational),
  national(n.kNational),
  rfc3966(n.kRfc3966);

  const PhoneFormat(this.code);

  /// The ABI integer.
  final int code;
}

/// The kind of number [numberType] reports.
enum PhoneNumberType {
  unknown(n.kTypeUnknown),
  fixedLine(n.kTypeFixedLine),
  mobile(n.kTypeMobile),
  tollFree(n.kTypeTollFree),
  premiumRate(n.kTypePremiumRate),
  sharedCost(n.kTypeSharedCost),
  voip(n.kTypeVoip),
  personalNumber(n.kTypePersonalNumber),
  pager(n.kTypePager),
  uan(n.kTypeUan),
  voicemail(n.kTypeVoicemail),
  fixedLineOrMobile(n.kTypeFixedLineOrMobile);

  const PhoneNumberType(this.code);

  /// The ABI integer.
  final int code;

  /// Map an ABI integer back to a [PhoneNumberType]; unknown codes fall back to
  /// [PhoneNumberType.unknown].
  static PhoneNumberType fromCode(int code) {
    for (final t in PhoneNumberType.values) {
      if (t.code == code) return t;
    }
    return PhoneNumberType.unknown;
  }
}

/// The outcome of [isPossibleNumberWithReason].
enum ValidationResult {
  isPossible(n.kVrIsPossible),
  isPossibleLocalOnly(n.kVrIsPossibleLocalOnly),
  invalidCountryCode(n.kVrInvalidCountryCode),
  tooShort(n.kVrTooShort),
  invalidLength(n.kVrInvalidLength),
  tooLong(n.kVrTooLong);

  const ValidationResult(this.code);

  /// The ABI integer.
  final int code;

  /// Map an ABI integer back to a [ValidationResult]; unknown codes fall back
  /// to [ValidationResult.invalidLength].
  static ValidationResult fromCode(int code) {
    for (final v in ValidationResult.values) {
      if (v.code == code) return v;
    }
    return ValidationResult.invalidLength;
  }
}

/// The outcome of [isNumberMatch].
enum MatchType {
  notANumber(n.kMatchNotANumber),
  noMatch(n.kMatchNoMatch),
  shortNsn(n.kMatchShortNsn),
  nsn(n.kMatchNsn),
  exact(n.kMatchExact);

  const MatchType(this.code);

  /// The ABI integer.
  final int code;

  /// Map an ABI integer back to a [MatchType]; unknown codes fall back to
  /// [MatchType.notANumber].
  static MatchType fromCode(int code) {
    for (final m in MatchType.values) {
      if (m.code == code) return m;
    }
    return MatchType.notANumber;
  }
}

/// Where a parsed number's country code came from ([ParsedNumber.source]).
enum CountryCodeSource {
  fromNumberWithPlus(n.kSrcFromNumberWithPlus),
  fromNumberWithIdd(n.kSrcFromNumberWithIdd),
  fromNumberWithoutPlus(n.kSrcFromNumberWithoutPlus),
  fromDefaultCountry(n.kSrcFromDefaultCountry);

  const CountryCodeSource(this.code);

  /// The ABI integer.
  final int code;

  /// Map an ABI integer back to a [CountryCodeSource]; unknown codes fall back
  /// to [CountryCodeSource.fromDefaultCountry].
  static CountryCodeSource fromCode(int code) {
    for (final s in CountryCodeSource.values) {
      if (s.code == code) return s;
    }
    return CountryCodeSource.fromDefaultCountry;
  }
}

/// How hard [findNumbers] tries when scanning free text.
enum Leniency {
  possible(n.kLeniencyPossible),
  valid(n.kLeniencyValid);

  const Leniency(this.code);

  /// The ABI integer.
  final int code;
}

/// The expected cost of dialling a short number ([ShortNumberInfo.expectedCost]).
enum ShortNumberCost {
  tollFree(n.kCostTollFree),
  standardRate(n.kCostStandardRate),
  premiumRate(n.kCostPremiumRate),
  unknown(n.kCostUnknown);

  const ShortNumberCost(this.code);

  /// The ABI integer.
  final int code;

  /// Map an ABI integer back to a [ShortNumberCost]; unknown codes fall back to
  /// [ShortNumberCost.unknown].
  static ShortNumberCost fromCode(int code) {
    for (final c in ShortNumberCost.values) {
      if (c.code == code) return c;
    }
    return ShortNumberCost.unknown;
  }
}

n.Api get _api => n.Api.open();

/// Marshal a Dart string into a native UTF-8 buffer, run [body], then free it.
T _withUtf8<T>(String s, T Function(ffi.Pointer<pkgffi.Utf8>) body) {
  final p = s.toNativeUtf8();
  try {
    return body(p);
  } finally {
    pkgffi.calloc.free(p);
  }
}

T _withUtf8x2<T>(String a, String b,
    T Function(ffi.Pointer<pkgffi.Utf8>, ffi.Pointer<pkgffi.Utf8>) body) {
  final pa = a.toNativeUtf8();
  final pb = b.toNativeUtf8();
  try {
    return body(pa, pb);
  } finally {
    pkgffi.calloc.free(pa);
    pkgffi.calloc.free(pb);
  }
}

T _withUtf8x3<T>(
    String a,
    String b,
    String c,
    T Function(ffi.Pointer<pkgffi.Utf8>, ffi.Pointer<pkgffi.Utf8>,
            ffi.Pointer<pkgffi.Utf8>)
        body) {
  final pa = a.toNativeUtf8();
  final pb = b.toNativeUtf8();
  final pc = c.toNativeUtf8();
  try {
    return body(pa, pb, pc);
  } finally {
    pkgffi.calloc.free(pa);
    pkgffi.calloc.free(pb);
    pkgffi.calloc.free(pc);
  }
}

// ---- metadata ----

/// The country calling code for a region ("1", "44", …), or "" if unknown.
String countryCode(String region) {
  final api = _api;
  return _withUtf8(region, (r) => api.takeString(api.countryCode(r)));
}

/// An example national number for the region, or "".
String exampleNumber(String region) {
  final api = _api;
  return _withUtf8(region, (r) => api.takeString(api.exampleNumber(r)));
}

/// An example national number of the given [type] for the region, or "".
String exampleNumberForType(String region, PhoneNumberType type) {
  final api = _api;
  return _withUtf8(
      region, (r) => api.takeString(api.exampleNumberForType(r, type.code)));
}

/// An example number that is *invalid* for the region, or "".
String invalidExampleNumber(String region) {
  final api = _api;
  return _withUtf8(region, (r) => api.takeString(api.invalidExampleNumber(r)));
}

/// The possible-lengths spec for the region (e.g. "9,10"), or "".
String possibleLengths(String region) {
  final api = _api;
  return _withUtf8(region, (r) => api.takeString(api.possibleLengths(r)));
}

/// The main region for a country calling code ("44" -> "GB"), or "".
String regionCodeForCountryCode(String cc) {
  final api = _api;
  return _withUtf8(cc, (c) => api.takeString(api.regionCodeForCountryCode(c)));
}

/// True if the region is part of the North American Numbering Plan.
bool isNanpaCountry(String region) {
  final api = _api;
  return _withUtf8(region, (r) => api.isNanpaCountry(r) != 0);
}

/// The national-direct-dialling prefix for a region ("0", "1", …), or "".
String nddPrefixForRegion(String region, {bool stripNonDigits = false}) {
  final api = _api;
  return _withUtf8(region,
      (r) => api.takeString(api.nddPrefixForRegion(r, stripNonDigits ? 1 : 0)));
}

/// Every region id the metadata carries, as a list of ISO-3166 codes.
List<String> regions() {
  final api = _api;
  final count = api.regionCount();
  return [for (var i = 0; i < count; i++) api.takeString(api.regionAt(i))];
}

/// How many regions share a country calling code.
int ccRegionCount(String cc) {
  final api = _api;
  return _withUtf8(cc, (c) => api.ccRegionCount(c));
}

/// The regions that share a country calling code, in metadata order.
List<String> regionsForCountryCode(String cc) {
  final api = _api;
  return _withUtf8(cc, (c) {
    final count = api.ccRegionCount(c);
    return [for (var i = 0; i < count; i++) api.takeString(api.ccRegionAt(c, i))];
  });
}

// ---- parsed number ----

/// A parsed phone number.
///
/// Wraps the caller-owned parsed-number string the ABI returns from [parse];
/// its fields are read on demand through the pn_* accessors.
class ParsedNumber {
  /// The opaque parsed-number blob the ABI handed back. Only [format]-family
  /// helpers and the accessors here should touch it.
  final String blob;

  /// Wrap a parsed-number blob. Prefer [parse].
  const ParsedNumber(this.blob);

  String _s(
      ffi.Pointer<pkgffi.Utf8> Function(ffi.Pointer<pkgffi.Utf8>) f) {
    final api = _api;
    return _withUtf8(blob, (p) => api.takeString(f(p)));
  }

  int _i(int Function(ffi.Pointer<pkgffi.Utf8>) f) {
    return _withUtf8(blob, (p) => f(p));
  }

  /// The region the number was parsed against ("US"), or "".
  String get region => _s(_api.pnRegion);

  /// The country calling code ("1"), or "".
  String get countryCode => _s(_api.pnCountryCode);

  /// The national (significant) number ("2015550123"), or "".
  String get nationalNumber => _s(_api.pnNationalNumber);

  /// The parsed extension ("42"), or "".
  String get extension => _s(_api.pnExtension);

  /// True if the number keeps an Italian leading zero.
  bool get italianLeadingZero => _i(_api.pnItalianLeadingZero) != 0;

  /// How the country code was determined.
  CountryCodeSource get source =>
      CountryCodeSource.fromCode(_i(_api.pnSource));

  /// A non-empty error string if the parse failed, else "".
  String get error => _s(_api.pnError);

  /// The region the parsed number belongs to ("US"), or "".
  String get regionCode => _s(_api.regionCodeForNumber);

  /// The national significant number.
  String get nationalSignificantNumber => _s(_api.nationalSignificantNumber);

  /// The length of the national destination code (0 if none).
  int get lengthOfNdc => _i(_api.lengthOfNdc);

  /// The length of the area code (0 if none).
  int get lengthOfAreaCode => _i(_api.lengthOfAreaCode);

  /// True if the number is geographically associated with an area.
  bool get isGeographical => _i(_api.isGeographical) != 0;

  /// Format this parsed number as originally dialled, from [callingFrom].
  String formatInOriginal(String callingFrom) {
    final api = _api;
    return _withUtf8x2(
        blob, callingFrom, (p, c) => api.takeString(api.formatInOriginal(p, c)));
  }
}

/// Parse raw [input] against a default [region] into a [ParsedNumber].
ParsedNumber parse(String input, String region) {
  final api = _api;
  return _withUtf8x2(
      input, region, (i, r) => ParsedNumber(api.takeString(api.parse(i, r))));
}

/// The national number extracted from raw input (cc + punctuation stripped).
String nationalNumber(String region, String input) {
  final api = _api;
  return _withUtf8x2(
      region, input, (r, i) => api.takeString(api.nationalNumber(r, i)));
}

// ---- validation ----

/// True if the national number is a length the region allows.
bool isPossibleNumber(String region, String input) {
  final api = _api;
  return _withUtf8x2(region, input, (r, i) => api.isPossibleNumber(r, i) != 0);
}

/// Why (or that) a number is possible.
ValidationResult isPossibleNumberWithReason(String region, String input) {
  final api = _api;
  return _withUtf8x2(region, input,
      (r, i) => ValidationResult.fromCode(api.isPossibleNumberWithReason(r, i)));
}

/// True if the number matches the region's national-number patterns.
bool isValidNumber(String region, String input) {
  final api = _api;
  return _withUtf8x2(region, input, (r, i) => api.isValidNumber(r, i) != 0);
}

/// True if the number is valid *for* the given region.
bool isValidNumberForRegion(String input, String region) {
  final api = _api;
  return _withUtf8x2(
      input, region, (i, r) => api.isValidNumberForRegion(i, r) != 0);
}

/// The [PhoneNumberType] of the number.
PhoneNumberType numberType(String region, String input) {
  final api = _api;
  return _withUtf8x2(region, input,
      (r, i) => PhoneNumberType.fromCode(api.numberType(r, i)));
}

/// True if the number can be dialled from outside its country.
bool canBeInternationallyDialled(String region, String input) {
  final api = _api;
  return _withUtf8x2(
      region, input, (r, i) => api.canBeInternationallyDialled(r, i) != 0);
}

// ---- formatting ----

/// Format the number in the given [style] (defaults to national).
String format(String region, String input,
    [PhoneFormat style = PhoneFormat.national]) {
  final api = _api;
  return _withUtf8x2(
      region, input, (r, i) => api.takeString(api.format(r, i, style.code)));
}

/// Format the number in the national style.
String formatNational(String region, String input) =>
    format(region, input, PhoneFormat.national);

/// Format the number in the international style.
String formatInternational(String region, String input) =>
    format(region, input, PhoneFormat.international);

/// Format the number in E.164.
String formatE164(String region, String input) =>
    format(region, input, PhoneFormat.e164);

/// Format the number as an RFC 3966 tel: URI.
String formatRfc3966(String region, String input) =>
    format(region, input, PhoneFormat.rfc3966);

/// Format [input] as dialled from [callingFrom].
String formatOutOfCountry(String region, String input, String callingFrom) {
  final api = _api;
  return _withUtf8x3(region, input, callingFrom,
      (r, i, c) => api.takeString(api.formatOutOfCountry(r, i, c)));
}

// ---- relations / helpers ----

/// Compare two numbers.
MatchType isNumberMatch(String a, String b) {
  final api = _api;
  return _withUtf8x2(a, b, (pa, pb) => MatchType.fromCode(api.isNumberMatch(pa, pb)));
}

/// Drop digits past the region's maximum length.
String truncateTooLong(String region, String input) {
  final api = _api;
  return _withUtf8x2(
      region, input, (r, i) => api.takeString(api.truncateTooLong(r, i)));
}

/// Keep only the digits of a string (Unicode digits included).
String normalizeDigitsOnly(String s) {
  final api = _api;
  return _withUtf8(s, (p) => api.takeString(api.normalizeDigitsOnly(p)));
}

/// Convert vanity letters to their dial-pad digits.
String convertAlphaCharacters(String s) {
  final api = _api;
  return _withUtf8(s, (p) => api.takeString(api.convertAlphaCharacters(p)));
}

/// True if the string contains vanity (alpha) characters.
bool isAlphaNumber(String s) {
  final api = _api;
  return _withUtf8(s, (p) => api.isAlphaNumber(p) != 0);
}

/// The ABI revision the loaded engine reports.
int abiVersion() => _api.abiVersion();

/// The path the engine `.so` was loaded from.
String get nativeLibraryPath => _api.path;

// ---- AsYouTypeFormatter ----

/// Formats a number as it is typed, digit by digit.
///
/// The formatter state is a caller-owned ABI string; each [inputDigit] threads
/// a new state and frees the old one.
class AsYouTypeFormatter {
  String _state;

  /// A formatter primed for the given [region].
  AsYouTypeFormatter(String region)
      : _state = _withUtf8(region, (r) => n.Api.open().takeString(
            n.Api.open().aytNew(r)));

  /// Feed one character; return the formatted-so-far string.
  String inputDigit(String ch) {
    final api = _api;
    _state = _withUtf8x2(
        _state, ch, (s, c) => api.takeString(api.aytInput(s, c)));
    return result();
  }

  /// The formatted-so-far string.
  String result() {
    final api = _api;
    return _withUtf8(_state, (s) => api.takeString(api.aytResult(s)));
  }

  /// Reset the formatter.
  void clear() {
    final api = _api;
    _state = _withUtf8(_state, (s) => api.takeString(api.aytClear(s)));
  }
}

// ---- PhoneNumberMatcher / findNumbers ----

/// One phone number found in free text.
class PhoneNumberMatch {
  /// 0-based start offset of the match in the source text.
  final int start;

  /// 0-based end offset (exclusive) of the match.
  final int end;

  /// The raw substring that matched.
  final String raw;

  const PhoneNumberMatch(this.start, this.end, this.raw);

  @override
  String toString() => 'PhoneNumberMatch($start, $end, "$raw")';
}

/// Find phone numbers in free [text]. Returns them in order.
List<PhoneNumberMatch> findNumbers(String text, String region,
    {Leniency leniency = Leniency.valid}) {
  final api = _api;
  return _withUtf8x2(text, region, (t, r) {
    final count = api.matcherCount(t, r, leniency.code);
    return [
      for (var i = 0; i < count; i++)
        PhoneNumberMatch(
          api.matcherStart(t, r, leniency.code, i),
          api.matcherEnd(t, r, leniency.code, i),
          api.takeString(api.matcherRaw(t, r, leniency.code, i)),
        ),
    ];
  });
}

// ---- ShortNumberInfo (short / emergency numbers) ----

/// Short- and emergency-number queries, mirroring libphonenumber's
/// `ShortNumberInfo`.
///
/// Every member marshals to an `aether_pn_embed_short_*` call. The class is
/// never instantiated — like the rest of this surface it is stateless.
abstract final class ShortNumberInfo {
  /// True if [input] is a possible short number for [region].
  static bool isPossible(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input, (r, i) => api.shortIsPossible(r, i) != 0);
  }

  /// True if [input] is a valid short number for [region].
  static bool isValid(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input, (r, i) => api.shortIsValid(r, i) != 0);
  }

  /// True if [input] is an emergency number for [region].
  static bool isEmergencyNumber(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input, (r, i) => api.shortIsEmergency(r, i) != 0);
  }

  /// True if dialling [input] would connect to an emergency service in [region].
  static bool connectsToEmergencyNumber(String region, String input) {
    final api = _api;
    return _withUtf8x2(
        region, input, (r, i) => api.shortConnectsToEmergency(r, i) != 0);
  }

  /// True if the short number is carrier-specific.
  static bool isCarrierSpecific(String region, String input) {
    final api = _api;
    return _withUtf8x2(
        region, input, (r, i) => api.shortIsCarrierSpecific(r, i) != 0);
  }

  /// True if the short number is an SMS service.
  static bool isSmsService(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input, (r, i) => api.shortIsSmsService(r, i) != 0);
  }

  /// The expected cost of dialling the short number.
  static ShortNumberCost expectedCost(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input,
        (r, i) => ShortNumberCost.fromCode(api.shortExpectedCost(r, i)));
  }

  /// An example short number for [region], or "".
  static String exampleNumber(String region) {
    final api = _api;
    return _withUtf8(region, (r) => api.takeString(api.shortExampleNumber(r)));
  }
}

// ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----

/// IANA time-zone lookup for a number, mirroring libphonenumber's
/// `PhoneNumberToTimeZonesMapper`.
///
/// Every member marshals to an `aether_pn_embed_tz_*` call. The unknown-zone
/// sentinel is `"Etc/Unknown"`. The class is never instantiated — like the rest
/// of this surface it is stateless.
abstract final class TimeZones {
  /// The IANA time-zone ids for [input] in [region], in order.
  ///
  /// A number with no known zone maps to a single-element list of the unknown
  /// zone (`['Etc/Unknown']`).
  static List<String> timeZonesForNumber(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input, (r, i) {
      final count = api.tzCount(r, i);
      if (count == 0) return [unknownTimeZone()];
      return [for (var k = 0; k < count; k++) api.takeString(api.tzAt(r, i, k))];
    });
  }

  /// How many time zones [input] maps to in [region] (0 = only the unknown zone).
  static int timeZoneCount(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input, (r, i) => api.tzCount(r, i));
  }

  /// The unknown-zone sentinel, `"Etc/Unknown"`.
  static String unknownTimeZone() {
    final api = _api;
    return api.takeString(api.tzUnknown());
  }
}

// ---- PhoneNumberToCarrierMapper (English carrier names) ----

/// English carrier-name lookup for a number, mirroring libphonenumber's
/// `PhoneNumberToCarrierMapper`.
///
/// Every member marshals to an `aether_pn_embed_carrier_*` call. `""` means no
/// carrier is known. The class is never instantiated — it is stateless.
abstract final class Carrier {
  /// The carrier name for [input] in [region] (English), or "" if none is known.
  static String carrierNameForNumber(String region, String input) {
    final api = _api;
    return _withUtf8x2(
        region, input, (r, i) => api.takeString(api.carrierName(r, i)));
  }

  /// The carrier name only when [input] is a valid number for [region], else "".
  static String carrierNameForValidNumber(String region, String input) {
    final api = _api;
    return _withUtf8x2(region, input,
        (r, i) => api.takeString(api.carrierNameForValid(r, i)));
  }
}
