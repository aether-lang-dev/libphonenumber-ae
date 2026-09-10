'use strict';
/**
 * koffi bindings for the phonenumber engine (libphonenumber_ae.so), ABI v7.
 *
 * This module is the ONLY place in the JavaScript binding that knows about the
 * C ABI. Everything above it (`phonenumber.js`) is idiomatic JavaScript over
 * these symbols. No phone-number logic lives here or anywhere else in this
 * package — the engine is `core/phonenumber.ae`, shared by every binding.
 *
 * v7 makes the carrier + geocoder mappers multi-language: the four
 * PhoneNumberToCarrierMapper / PhoneNumberOfflineGeocoder symbols each gained a
 * trailing `const char *lang` (ISO code; "en" is always available and the
 * fallback). No new symbols — still 66. v6 added the PhoneNumberOfflineGeocoder
 * (2 symbols) on top of the v5 PhoneNumberToTimeZonesMapper (4 symbols) and
 * PhoneNumberToCarrierMapper (2 symbols) side-libraries and the v3
 * ShortNumberInfo ABI.
 * Every signature is still scalar-only
 * (`const char *` and `int`), and every returned `char*` is caller-owned. There
 * are still no opaque handles: a parsed number and an AsYouType state are
 * themselves caller-owned *strings* you hand back to the accessor calls and
 * free like any other returned string.
 *
 * Library resolution, in order:
 *   1. an explicit path passed to `load(path)`
 *   2. $LIBPHONENUMBER_AE_LIB          (what the in-tree .tests.ae leaf sets)
 *   3. native/ bundled next to this package (what an installed tarball ships)
 *   4. the OS loader's own search path
 */

const koffi = require('koffi');
const path = require('path');

const LIB_NAME = {
  darwin: 'libphonenumber_ae.dylib',
  win32: 'phonenumber_ae.dll',
}[process.platform] || 'libphonenumber_ae.so';

// ---- format styles (ABI constants — append only, never renumber) ----
// NOTE: v2 renumbered these. E164 is now 0 (was 2 in v1).
const E164 = 0;
const INTERNATIONAL = 1;
const NATIONAL = 2;
const RFC3966 = 3;

// ---- number types (number_type result; -1 = unknown) ----
const TYPE_UNKNOWN = -1;
const TYPE_FIXED_LINE = 0;
const TYPE_MOBILE = 1;
const TYPE_TOLL_FREE = 2;
const TYPE_PREMIUM_RATE = 3;
const TYPE_SHARED_COST = 4;
const TYPE_VOIP = 5;
const TYPE_PERSONAL_NUMBER = 6;
const TYPE_PAGER = 7;
const TYPE_UAN = 8;
const TYPE_VOICEMAIL = 9;
const TYPE_FIXED_LINE_OR_MOBILE = 10;

// ---- ValidationResult (is_possible_number_with_reason) ----
const VR_IS_POSSIBLE = 0;
const VR_IS_POSSIBLE_LOCAL_ONLY = 4;
const VR_INVALID_COUNTRY_CODE = 1;
const VR_TOO_SHORT = 2;
const VR_INVALID_LENGTH = 5;
const VR_TOO_LONG = 3;

// ---- MatchType (is_number_match) ----
const MATCH_NOT_A_NUMBER = 0;
const MATCH_NO_MATCH = 1;
const MATCH_SHORT_NSN = 2;
const MATCH_NSN = 3;
const MATCH_EXACT = 4;

// ---- CountryCodeSource (pn_source) ----
const SRC_FROM_NUMBER_WITH_PLUS = 1;
const SRC_FROM_NUMBER_WITH_IDD = 5;
const SRC_FROM_NUMBER_WITHOUT_PLUS = 10;
const SRC_FROM_DEFAULT_COUNTRY = 20;

// ---- matcher leniency ----
const LENIENCY_POSSIBLE = 0;
const LENIENCY_VALID = 1;

// ---- ShortNumberCost (short_expected_cost) ----
const COST_TOLL_FREE = 0;
const COST_STANDARD_RATE = 1;
const COST_PREMIUM_RATE = 2;
const COST_UNKNOWN = 3;

let cached = null;

function* candidates(explicit) {
  if (explicit) {
    yield explicit;
    return;
  }
  const env = process.env.LIBPHONENUMBER_AE_LIB;
  if (env) yield env;
  yield path.join(__dirname, '..', 'native', LIB_NAME);
  yield LIB_NAME;
}

/**
 * Load the engine .so, caching it process-wide. Returns the symbol table.
 */
function load(explicit) {
  if (cached !== null && !explicit) return cached;

  let lib = null;
  let last = null;
  for (const cand of candidates(explicit)) {
    try {
      lib = koffi.load(cand);
      break;
    } catch (err) {
      last = err;
    }
  }
  if (lib === null) {
    throw new Error(
      `could not load the phonenumber engine (${LIB_NAME}). Set ` +
      'LIBPHONENUMBER_AE_LIB to its absolute path, or install a package that ' +
      `bundles it. Last error: ${last && last.message}`);
  }

  const api = declare(lib);
  if (!explicit) cached = api;
  return api;
}

/**
 * Bind every exported symbol. Signature shapes come straight from
 * core/embed.ae; the mangled `aether_pn_embed_` prefix is what `--emit=lib`
 * produces.
 *
 * Note the return type of every string-returning ABI call is `void *`, not
 * `const char *`: koffi would otherwise decode-and-forget the pointer and we
 * could never hand it back to aether_pn_embed_free_string. Every one of those
 * is caller-owned, and leaking it is the single easiest mistake in a binding.
 */
function declare(lib) {
  const f = (sig) => lib.func(sig);
  return {
    _lib: lib,

    abiVersion: f('int aether_pn_embed_abi_version()'),
    freeString: f('void aether_pn_embed_free_string(void *s)'),

    // ---- metadata ----
    countryCode: f('void *aether_pn_embed_country_code(const char *region)'),
    exampleNumber: f('void *aether_pn_embed_example_number(const char *region)'),
    exampleNumberForType: f('void *aether_pn_embed_example_number_for_type(const char *region, int type)'),
    invalidExampleNumber: f('void *aether_pn_embed_invalid_example_number(const char *region)'),
    possibleLengths: f('void *aether_pn_embed_possible_lengths(const char *region)'),
    regionCodeForCountryCode: f('void *aether_pn_embed_region_code_for_country_code(const char *cc)'),
    isNanpaCountry: f('int aether_pn_embed_is_nanpa_country(const char *region)'),
    nddPrefixForRegion: f('void *aether_pn_embed_ndd_prefix_for_region(const char *region, int stripNonDigits)'),
    regionCount: f('int aether_pn_embed_region_count()'),
    regionAt: f('void *aether_pn_embed_region_at(int index)'),
    ccRegionCount: f('int aether_pn_embed_cc_region_count(const char *cc)'),
    ccRegionAt: f('void *aether_pn_embed_cc_region_at(const char *cc, int index)'),

    // ---- parse + parsed-number accessors ----
    parse: f('void *aether_pn_embed_parse(const char *input, const char *region)'),
    nationalNumber: f('void *aether_pn_embed_national_number(const char *region, const char *input)'),
    pnRegion: f('void *aether_pn_embed_pn_region(const char *pn)'),
    pnCountryCode: f('void *aether_pn_embed_pn_country_code(const char *pn)'),
    pnNationalNumber: f('void *aether_pn_embed_pn_national_number(const char *pn)'),
    pnExtension: f('void *aether_pn_embed_pn_extension(const char *pn)'),
    pnItalianLeadingZero: f('int aether_pn_embed_pn_italian_leading_zero(const char *pn)'),
    pnSource: f('int aether_pn_embed_pn_source(const char *pn)'),
    pnError: f('void *aether_pn_embed_pn_error(const char *pn)'),
    regionCodeForNumber: f('void *aether_pn_embed_region_code_for_number(const char *pn)'),
    nationalSignificantNumber: f('void *aether_pn_embed_national_significant_number(const char *pn)'),
    lengthOfNdc: f('int aether_pn_embed_length_of_ndc(const char *pn)'),
    lengthOfAreaCode: f('int aether_pn_embed_length_of_area_code(const char *pn)'),
    isGeographical: f('int aether_pn_embed_is_geographical(const char *pn)'),

    // ---- validation ----
    isPossibleNumber: f('int aether_pn_embed_is_possible_number(const char *region, const char *input)'),
    isPossibleNumberWithReason: f('int aether_pn_embed_is_possible_number_with_reason(const char *region, const char *input)'),
    isValidNumber: f('int aether_pn_embed_is_valid_number(const char *region, const char *input)'),
    isValidNumberForRegion: f('int aether_pn_embed_is_valid_number_for_region(const char *input, const char *region)'),
    numberType: f('int aether_pn_embed_number_type(const char *region, const char *input)'),
    canBeInternationallyDialled: f('int aether_pn_embed_can_be_internationally_dialled(const char *region, const char *input)'),

    // ---- formatting ----
    format: f('void *aether_pn_embed_format(const char *region, const char *input, int fmt)'),
    formatOutOfCountry: f('void *aether_pn_embed_format_out_of_country(const char *region, const char *input, const char *callingFrom)'),
    formatInOriginal: f('void *aether_pn_embed_format_in_original(const char *pn, const char *callingFrom)'),

    // ---- relations / helpers ----
    isNumberMatch: f('int aether_pn_embed_is_number_match(const char *a, const char *b)'),
    truncateTooLong: f('void *aether_pn_embed_truncate_too_long(const char *region, const char *input)'),
    normalizeDigitsOnly: f('void *aether_pn_embed_normalize_digits_only(const char *s)'),
    convertAlphaCharacters: f('void *aether_pn_embed_convert_alpha_characters(const char *s)'),
    isAlphaNumber: f('int aether_pn_embed_is_alpha_number(const char *s)'),

    // ---- AsYouTypeFormatter (state threaded as a caller-owned string) ----
    aytNew: f('void *aether_pn_embed_ayt_new(const char *region)'),
    aytInput: f('void *aether_pn_embed_ayt_input(const char *state, const char *ch)'),
    aytResult: f('void *aether_pn_embed_ayt_result(const char *state)'),
    aytClear: f('void *aether_pn_embed_ayt_clear(const char *state)'),

    // ---- PhoneNumberMatcher / findNumbers ----
    matcherCount: f('int aether_pn_embed_matcher_count(const char *text, const char *region, int leniency)'),
    matcherStart: f('int aether_pn_embed_matcher_start(const char *text, const char *region, int leniency, int idx)'),
    matcherEnd: f('int aether_pn_embed_matcher_end(const char *text, const char *region, int leniency, int idx)'),
    matcherRaw: f('void *aether_pn_embed_matcher_raw(const char *text, const char *region, int leniency, int idx)'),

    // ---- ShortNumberInfo (short / emergency numbers) ----
    shortIsPossible: f('int aether_pn_embed_short_is_possible(const char *region, const char *input)'),
    shortIsValid: f('int aether_pn_embed_short_is_valid(const char *region, const char *input)'),
    shortIsEmergency: f('int aether_pn_embed_short_is_emergency(const char *region, const char *input)'),
    shortConnectsToEmergency: f('int aether_pn_embed_short_connects_to_emergency(const char *region, const char *input)'),
    shortIsCarrierSpecific: f('int aether_pn_embed_short_is_carrier_specific(const char *region, const char *input)'),
    shortIsSmsService: f('int aether_pn_embed_short_is_sms_service(const char *region, const char *input)'),
    shortExpectedCost: f('int aether_pn_embed_short_expected_cost(const char *region, const char *input)'),
    shortExampleNumber: f('void *aether_pn_embed_short_example_number(const char *region)'),

    // ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----
    tzCount: f('int aether_pn_embed_tz_count(const char *region, const char *input)'),
    tzAt: f('void *aether_pn_embed_tz_at(const char *region, const char *input, int idx)'),
    tzAll: f('void *aether_pn_embed_tz_all(const char *region, const char *input)'),
    tzUnknown: f('void *aether_pn_embed_tz_unknown()'),

    // ---- PhoneNumberToCarrierMapper (localized carrier names) ----
    carrierName: f('void *aether_pn_embed_carrier_name(const char *region, const char *input, const char *lang)'),
    carrierNameForValid: f('void *aether_pn_embed_carrier_name_for_valid(const char *region, const char *input, const char *lang)'),

    // ---- PhoneNumberOfflineGeocoder (localized geographic descriptions) ----
    geoDescription: f('void *aether_pn_embed_geo_description(const char *region, const char *input, const char *lang)'),
    geoDescriptionForValid: f('void *aether_pn_embed_geo_description_for_valid(const char *region, const char *input, const char *lang)'),
  };
}

/**
 * Copy an ABI-returned string out and free it through the ABI.
 *
 * Every char* the engine returns is caller-owned; leaking it is the single
 * easiest mistake to make in any of these bindings.
 *
 * Koffi 3 represents pointers as BigInt, and a null pointer as `null` — so the
 * falsy check covers both `null` and `0n`.
 */
function takeString(api, ptr) {
  if (!ptr) return '';
  try {
    return koffi.decode.string(ptr);
  } finally {
    api.freeString(ptr);
  }
}

module.exports = {
  load,
  takeString,
  koffi,
  LIB_NAME,
  E164, INTERNATIONAL, NATIONAL, RFC3966,
  TYPE_UNKNOWN, TYPE_FIXED_LINE, TYPE_MOBILE, TYPE_TOLL_FREE,
  TYPE_PREMIUM_RATE, TYPE_SHARED_COST, TYPE_VOIP, TYPE_PERSONAL_NUMBER,
  TYPE_PAGER, TYPE_UAN, TYPE_VOICEMAIL, TYPE_FIXED_LINE_OR_MOBILE,
  VR_IS_POSSIBLE, VR_IS_POSSIBLE_LOCAL_ONLY, VR_INVALID_COUNTRY_CODE,
  VR_TOO_SHORT, VR_INVALID_LENGTH, VR_TOO_LONG,
  MATCH_NOT_A_NUMBER, MATCH_NO_MATCH, MATCH_SHORT_NSN, MATCH_NSN, MATCH_EXACT,
  SRC_FROM_NUMBER_WITH_PLUS, SRC_FROM_NUMBER_WITH_IDD,
  SRC_FROM_NUMBER_WITHOUT_PLUS, SRC_FROM_DEFAULT_COUNTRY,
  LENIENCY_POSSIBLE, LENIENCY_VALID,
  COST_TOLL_FREE, COST_STANDARD_RATE, COST_PREMIUM_RATE, COST_UNKNOWN,
};
