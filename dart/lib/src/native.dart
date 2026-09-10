/// The 1:1 symbol table for the phonenumber C ABI (`core/embed.ae`), v2.
///
/// This library is the ONLY place in the Dart binding that knows about the C
/// ABI. Everything above it (`phonenumber.dart`) is idiomatic Dart over these
/// symbols. No phone-number logic lives here or anywhere else in this package —
/// the engine is `core/phonenumber.ae`, shared by every language binding.
///
/// ## Naming
///
/// `core/embed.ae` names its exports `pn_embed_<name>`; building with
/// `--emit=lib` mangles them to **`aether_pn_embed_<name>`**. That mangled name
/// is what we look up.
///
/// ## Ownership
///
/// **Every `char*` this ABI returns is caller-owned** and must be handed back
/// to `aether_pn_embed_free_string`. Leaking it is the single most common bug
/// in a binding — [Api.takeString] does the right thing.
///
/// ## No opaque handles
///
/// v2 is the full PhoneNumberUtil-parity ABI (50 symbols), but every signature
/// is still scalar-only (`const char*` and `int`). A parsed number and an
/// AsYouType state are themselves caller-owned *strings*: you get one back, pass
/// it to the accessor calls, and free it like any other returned string. There
/// are still no trampolines, no keepalive, and nothing to close.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Directory, Platform;

import 'package:ffi/ffi.dart' as pkgffi;

// ---- format styles (ABI constants — append only, never renumber) ----
// NOTE: v2 renumbered these. E164 is now 0 (was 2 in v1).

/// `E164`
const int kE164 = 0;

/// `INTERNATIONAL`
const int kInternational = 1;

/// `NATIONAL`
const int kNational = 2;

/// `RFC3966`
const int kRfc3966 = 3;

// ---- number types (number_type result; -1 = unknown) ----

const int kTypeUnknown = -1;
const int kTypeFixedLine = 0;
const int kTypeMobile = 1;
const int kTypeTollFree = 2;
const int kTypePremiumRate = 3;
const int kTypeSharedCost = 4;
const int kTypeVoip = 5;
const int kTypePersonalNumber = 6;
const int kTypePager = 7;
const int kTypeUan = 8;
const int kTypeVoicemail = 9;

// ---- ValidationResult (is_possible_number_with_reason) ----

const int kVrIsPossible = 0;
const int kVrIsPossibleLocalOnly = 4;
const int kVrInvalidCountryCode = 1;
const int kVrTooShort = 2;
const int kVrInvalidLength = 5;
const int kVrTooLong = 3;

// ---- MatchType (is_number_match) ----

const int kMatchNotANumber = 0;
const int kMatchNoMatch = 1;
const int kMatchShortNsn = 2;
const int kMatchNsn = 3;
const int kMatchExact = 4;

// ---- CountryCodeSource (pn_source) ----

const int kSrcFromNumberWithPlus = 1;
const int kSrcFromNumberWithIdd = 5;
const int kSrcFromNumberWithoutPlus = 10;
const int kSrcFromDefaultCountry = 20;

// ---- matcher leniency ----

const int kLeniencyPossible = 0;
const int kLeniencyValid = 1;

typedef _Utf8 = ffi.Pointer<pkgffi.Utf8>;

// ---- the C signatures, grouped by shape ----

typedef _AbiVersionC = ffi.Int Function();
typedef _FreeStringC = ffi.Void Function(_Utf8);
typedef _Str1C = _Utf8 Function(_Utf8);
typedef _Str2C = _Utf8 Function(_Utf8, _Utf8);
typedef _Str3C = _Utf8 Function(_Utf8, _Utf8, _Utf8);
typedef _Int1C = ffi.Int Function(_Utf8);
typedef _Int2C = ffi.Int Function(_Utf8, _Utf8);
typedef _Str1IntC = _Utf8 Function(_Utf8, ffi.Int);
typedef _Int1IntC = ffi.Int Function(_Utf8, ffi.Int);
typedef _Str2IntC = _Utf8 Function(_Utf8, _Utf8, ffi.Int);
typedef _CountC = ffi.Int Function();
typedef _AtC = _Utf8 Function(ffi.Int);
typedef _Int2IntC = ffi.Int Function(_Utf8, _Utf8, ffi.Int);
typedef _MatcherIntC = ffi.Int Function(_Utf8, _Utf8, ffi.Int, ffi.Int);
typedef _MatcherStrC = _Utf8 Function(_Utf8, _Utf8, ffi.Int, ffi.Int);

// The Dart-side counterparts.
typedef _AbiVersion = int Function();
typedef _FreeString = void Function(_Utf8);
typedef _Str1 = _Utf8 Function(_Utf8);
typedef _Str2 = _Utf8 Function(_Utf8, _Utf8);
typedef _Str3 = _Utf8 Function(_Utf8, _Utf8, _Utf8);
typedef _Int1 = int Function(_Utf8);
typedef _Int2 = int Function(_Utf8, _Utf8);
typedef _Str1Int = _Utf8 Function(_Utf8, int);
typedef _Int1Int = int Function(_Utf8, int);
typedef _Str2Int = _Utf8 Function(_Utf8, _Utf8, int);
typedef _Count = int Function();
typedef _At = _Utf8 Function(int);
typedef _Int2Int = int Function(_Utf8, _Utf8, int);
typedef _MatcherInt = int Function(_Utf8, _Utf8, int, int);
typedef _MatcherStr = _Utf8 Function(_Utf8, _Utf8, int, int);

/// The default library file name for this platform.
String get defaultLibraryName {
  if (Platform.isMacOS) return 'libphonenumber_ae.dylib';
  if (Platform.isWindows) return 'phonenumber_ae.dll';
  return 'libphonenumber_ae.so';
}

/// Candidate paths, in resolution order:
///
///  1. an explicit path passed to [Api.open]
///  2. `$LIBPHONENUMBER_AE_LIB` (what the in-tree `.tests.ae` leaf sets)
///  3. `native/` bundled next to this package
///  4. `../core/native/` (the in-tree monorepo layout)
///  5. the OS loader's own search path
Iterable<String> libraryCandidates([String? explicit]) sync* {
  if (explicit != null && explicit.isNotEmpty) {
    yield explicit;
    return;
  }
  final env = Platform.environment['LIBPHONENUMBER_AE_LIB'];
  if (env != null && env.isNotEmpty) yield env;

  final name = defaultLibraryName;
  final cwd = Directory.current.path;
  // A bundled copy next to the package, then the in-tree monorepo layout
  // (dart/ and core/ are siblings), from both the cwd and its parent so a
  // `dart test` run from either place resolves.
  yield '$cwd/native/$name';
  yield '$cwd/../core/native/$name';
  yield '$cwd/core/native/$name';
  yield name;
}

/// A loaded engine: the `DynamicLibrary` plus every symbol bound once.
///
/// Binding the symbols eagerly (rather than per call) keeps the hot path free
/// of repeated `lookupFunction` work and turns a missing symbol into a clear
/// load-time failure instead of a mysterious one mid-call.
class Api {
  Api._(this.lib, this.path)
      : abiVersion = lib.lookupFunction<_AbiVersionC, _AbiVersion>(
            'aether_pn_embed_abi_version'),
        freeString = lib.lookupFunction<_FreeStringC, _FreeString>(
            'aether_pn_embed_free_string'),
        // ---- metadata ----
        countryCode = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_country_code'),
        exampleNumber = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_example_number'),
        exampleNumberForType = lib.lookupFunction<_Str1IntC, _Str1Int>(
            'aether_pn_embed_example_number_for_type'),
        invalidExampleNumber = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_invalid_example_number'),
        possibleLengths = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_possible_lengths'),
        regionCodeForCountryCode = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_region_code_for_country_code'),
        isNanpaCountry = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_is_nanpa_country'),
        nddPrefixForRegion = lib.lookupFunction<_Str1IntC, _Str1Int>(
            'aether_pn_embed_ndd_prefix_for_region'),
        regionCount = lib.lookupFunction<_CountC, _Count>(
            'aether_pn_embed_region_count'),
        regionAt =
            lib.lookupFunction<_AtC, _At>('aether_pn_embed_region_at'),
        ccRegionCount = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_cc_region_count'),
        ccRegionAt = lib.lookupFunction<_Str1IntC, _Str1Int>(
            'aether_pn_embed_cc_region_at'),
        // ---- parse + parsed-number accessors ----
        parse = lib.lookupFunction<_Str2C, _Str2>('aether_pn_embed_parse'),
        nationalNumber = lib.lookupFunction<_Str2C, _Str2>(
            'aether_pn_embed_national_number'),
        pnRegion = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_pn_region'),
        pnCountryCode = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_pn_country_code'),
        pnNationalNumber = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_pn_national_number'),
        pnExtension = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_pn_extension'),
        pnItalianLeadingZero = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_pn_italian_leading_zero'),
        pnSource = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_pn_source'),
        pnError = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_pn_error'),
        regionCodeForNumber = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_region_code_for_number'),
        nationalSignificantNumber = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_national_significant_number'),
        lengthOfNdc = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_length_of_ndc'),
        lengthOfAreaCode = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_length_of_area_code'),
        isGeographical = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_is_geographical'),
        // ---- validation ----
        isPossibleNumber = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_is_possible_number'),
        isPossibleNumberWithReason = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_is_possible_number_with_reason'),
        isValidNumber = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_is_valid_number'),
        isValidNumberForRegion = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_is_valid_number_for_region'),
        numberType = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_number_type'),
        canBeInternationallyDialled = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_can_be_internationally_dialled'),
        // ---- formatting ----
        format =
            lib.lookupFunction<_Str2IntC, _Str2Int>('aether_pn_embed_format'),
        formatOutOfCountry = lib.lookupFunction<_Str3C, _Str3>(
            'aether_pn_embed_format_out_of_country'),
        formatInOriginal = lib.lookupFunction<_Str2C, _Str2>(
            'aether_pn_embed_format_in_original'),
        // ---- relations / helpers ----
        isNumberMatch = lib.lookupFunction<_Int2C, _Int2>(
            'aether_pn_embed_is_number_match'),
        truncateTooLong = lib.lookupFunction<_Str2C, _Str2>(
            'aether_pn_embed_truncate_too_long'),
        normalizeDigitsOnly = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_normalize_digits_only'),
        convertAlphaCharacters = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_convert_alpha_characters'),
        isAlphaNumber = lib.lookupFunction<_Int1C, _Int1>(
            'aether_pn_embed_is_alpha_number'),
        // ---- AsYouTypeFormatter ----
        aytNew = lib.lookupFunction<_Str1C, _Str1>('aether_pn_embed_ayt_new'),
        aytInput = lib.lookupFunction<_Str2C, _Str2>(
            'aether_pn_embed_ayt_input'),
        aytResult = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_ayt_result'),
        aytClear = lib.lookupFunction<_Str1C, _Str1>(
            'aether_pn_embed_ayt_clear'),
        // ---- matcher ----
        matcherCount = lib.lookupFunction<_Int2IntC, _Int2Int>(
            'aether_pn_embed_matcher_count'),
        matcherStart = lib.lookupFunction<_MatcherIntC, _MatcherInt>(
            'aether_pn_embed_matcher_start'),
        matcherEnd = lib.lookupFunction<_MatcherIntC, _MatcherInt>(
            'aether_pn_embed_matcher_end'),
        matcherRaw = lib.lookupFunction<_MatcherStrC, _MatcherStr>(
            'aether_pn_embed_matcher_raw');

  final ffi.DynamicLibrary lib;

  /// The path the engine was actually loaded from.
  final String path;

  final _AbiVersion abiVersion;
  final _FreeString freeString;

  // metadata
  final _Str1 countryCode;
  final _Str1 exampleNumber;
  final _Str1Int exampleNumberForType;
  final _Str1 invalidExampleNumber;
  final _Str1 possibleLengths;
  final _Str1 regionCodeForCountryCode;
  final _Int1 isNanpaCountry;
  final _Str1Int nddPrefixForRegion;
  final _Count regionCount;
  final _At regionAt;
  final _Int1 ccRegionCount;
  final _Str1Int ccRegionAt;

  // parse + accessors
  final _Str2 parse;
  final _Str2 nationalNumber;
  final _Str1 pnRegion;
  final _Str1 pnCountryCode;
  final _Str1 pnNationalNumber;
  final _Str1 pnExtension;
  final _Int1 pnItalianLeadingZero;
  final _Int1 pnSource;
  final _Str1 pnError;
  final _Str1 regionCodeForNumber;
  final _Str1 nationalSignificantNumber;
  final _Int1 lengthOfNdc;
  final _Int1 lengthOfAreaCode;
  final _Int1 isGeographical;

  // validation
  final _Int2 isPossibleNumber;
  final _Int2 isPossibleNumberWithReason;
  final _Int2 isValidNumber;
  final _Int2 isValidNumberForRegion;
  final _Int2 numberType;
  final _Int2 canBeInternationallyDialled;

  // formatting
  final _Str2Int format;
  final _Str3 formatOutOfCountry;
  final _Str2 formatInOriginal;

  // relations / helpers
  final _Int2 isNumberMatch;
  final _Str2 truncateTooLong;
  final _Str1 normalizeDigitsOnly;
  final _Str1 convertAlphaCharacters;
  final _Int1 isAlphaNumber;

  // AsYouType
  final _Str1 aytNew;
  final _Str2 aytInput;
  final _Str1 aytResult;
  final _Str1 aytClear;

  // matcher
  final _Int2Int matcherCount;
  final _MatcherInt matcherStart;
  final _MatcherInt matcherEnd;
  final _MatcherStr matcherRaw;

  static Api? _cached;

  /// Load the engine, caching it process-wide when no explicit [path] is
  /// given. Throws [StateError] with every candidate tried when it cannot.
  static Api open([String? path]) {
    if (path == null && _cached != null) return _cached!;

    final tried = <String>[];
    Object? last;
    for (final cand in libraryCandidates(path)) {
      tried.add(cand);
      try {
        final api = Api._(ffi.DynamicLibrary.open(cand), cand);
        if (path == null) _cached = api;
        return api;
      } catch (e) {
        last = e;
      }
    }
    throw StateError(
        'could not load the phonenumber engine ($defaultLibraryName). Set '
        'LIBPHONENUMBER_AE_LIB to its absolute path, or build it with:\n'
        '  aeb core/.build.ae\n'
        'Tried: ${tried.join(", ")}\nLast error: $last');
  }

  /// Copy an ABI-returned string out and free it through the ABI.
  ///
  /// Every `char*` the engine returns is caller-owned; leaking it is the
  /// single easiest mistake to make in any of these bindings. Every string
  /// result in this package goes through here.
  String takeString(_Utf8 p) {
    if (p == ffi.nullptr) return '';
    try {
      return p.toDartString();
    } finally {
      freeString(p);
    }
  }
}
