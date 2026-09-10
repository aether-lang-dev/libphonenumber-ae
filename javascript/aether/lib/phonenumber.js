'use strict';
/**
 * Idiomatic JavaScript surface over the phonenumber engine (ABI v2).
 *
 * Carries no phone-number logic — see the monorepo's one rule. Every function
 * here marshals to an `aether_pn_embed_*` call in `native.js`.
 */

const native = require('./native');
const {
  E164, INTERNATIONAL, NATIONAL, RFC3966,
  LENIENCY_POSSIBLE, LENIENCY_VALID,
} = native;

function _str(s) {
  return s === null || s === undefined ? '' : String(s);
}

function _api() {
  return native.load();
}

/** Call a string-returning ABI function `name` and take (copy+free) the result. */
function _s(name, ...args) {
  const api = _api();
  return native.takeString(api, api[name](...args));
}

// ---- metadata ----

/** The country calling code for a region ("1", "44", …), or "" if unknown. */
function countryCode(region) {
  return _s('countryCode', _str(region));
}

/** An example national number for the region, or "". */
function exampleNumber(region) {
  return _s('exampleNumber', _str(region));
}

/** An example national number of the given TYPE_* for the region, or "". */
function exampleNumberForType(region, type) {
  return _s('exampleNumberForType', _str(region), Number(type) | 0);
}

/** An example number that is invalid for the region, or "". */
function invalidExampleNumber(region) {
  return _s('invalidExampleNumber', _str(region));
}

/** The possible-lengths spec for the region (e.g. "9,10"), or "". */
function possibleLengths(region) {
  return _s('possibleLengths', _str(region));
}

/** The main region for a country calling code ("44" -> "GB"), or "". */
function regionCodeForCountryCode(cc) {
  return _s('regionCodeForCountryCode', _str(cc));
}

/** True if the region is part of the North American Numbering Plan. */
function isNanpaCountry(region) {
  return _api().isNanpaCountry(_str(region)) !== 0;
}

/** The national-direct-dialling prefix for a region ("0", "1", …), or "". */
function nddPrefixForRegion(region, stripNonDigits = false) {
  return _s('nddPrefixForRegion', _str(region), stripNonDigits ? 1 : 0);
}

/** Every region id the metadata carries, as an array of ISO-3166 codes. */
function regions() {
  const api = _api();
  const n = api.regionCount();
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(native.takeString(api, api.regionAt(i)));
  }
  return out;
}

/** How many regions share a country calling code. */
function ccRegionCount(cc) {
  return _api().ccRegionCount(_str(cc));
}

/** The regions that share a country calling code, in metadata order. */
function regionsForCountryCode(cc) {
  const api = _api();
  const n = api.ccRegionCount(_str(cc));
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(native.takeString(api, api.ccRegionAt(_str(cc), i)));
  }
  return out;
}

// ---- parsed number ----

/**
 * A parsed phone number. Wraps the caller-owned parsed-number string the ABI
 * returns; its fields are read on demand via the pn_* accessors.
 */
class ParsedNumber {
  constructor(pnString) {
    this._pn = pnString;
  }

  /** The region the number was parsed against ("US"), or "". */
  get region() {
    return _s('pnRegion', this._pn);
  }

  /** The country calling code ("1"), or "". */
  get countryCode() {
    return _s('pnCountryCode', this._pn);
  }

  /** The national (significant) number ("2015550123"), or "". */
  get nationalNumber() {
    return _s('pnNationalNumber', this._pn);
  }

  /** The parsed extension ("42"), or "". */
  get extension() {
    return _s('pnExtension', this._pn);
  }

  /** True if the number keeps an Italian leading zero. */
  get italianLeadingZero() {
    return _api().pnItalianLeadingZero(this._pn) !== 0;
  }

  /** How the country code was determined (a SRC_* CountryCodeSource). */
  get source() {
    return _api().pnSource(this._pn);
  }

  /** A non-empty error string if the parse failed, else "". */
  get error() {
    return _s('pnError', this._pn);
  }

  /** The region the parsed number belongs to ("US"), or "". */
  get regionCode() {
    return _s('regionCodeForNumber', this._pn);
  }

  /** The national significant number. */
  get nationalSignificantNumber() {
    return _s('nationalSignificantNumber', this._pn);
  }

  /** The length of the national destination code (0 if none). */
  get lengthOfNdc() {
    return _api().lengthOfNdc(this._pn);
  }

  /** The length of the area code (0 if none). */
  get lengthOfAreaCode() {
    return _api().lengthOfAreaCode(this._pn);
  }

  /** True if the number is geographically associated with an area. */
  get isGeographical() {
    return _api().isGeographical(this._pn) !== 0;
  }
}

/** Parse raw input against a default region into a {@link ParsedNumber}. */
function parse(input, region) {
  return new ParsedNumber(_s('parse', _str(input), _str(region)));
}

/** The national number extracted from raw input (cc + punctuation stripped). */
function nationalNumber(region, input) {
  return _s('nationalNumber', _str(region), _str(input));
}

// ---- validation ----

/** True if the national number is a length the region allows. */
function isPossibleNumber(region, input) {
  return _api().isPossibleNumber(_str(region), _str(input)) !== 0;
}

/** Why (or that) a number is possible — a VR_* ValidationResult. */
function isPossibleNumberWithReason(region, input) {
  return _api().isPossibleNumberWithReason(_str(region), _str(input));
}

/** True if the number matches the region's national-number patterns. */
function isValidNumber(region, input) {
  return _api().isValidNumber(_str(region), _str(input)) !== 0;
}

/** True if the number is valid *for* the given region. */
function isValidNumberForRegion(input, region) {
  return _api().isValidNumberForRegion(_str(input), _str(region)) !== 0;
}

/** The PhoneNumberType (a TYPE_* int; -1 for unknown). */
function numberType(region, input) {
  return _api().numberType(_str(region), _str(input));
}

/** True if the number can be dialled from outside its country. */
function canBeInternationallyDialled(region, input) {
  return _api().canBeInternationallyDialled(_str(region), _str(input)) !== 0;
}

// ---- formatting ----

/** Format the number in the given style (E164 / INTERNATIONAL / NATIONAL / RFC3966). */
function format(region, input, style = NATIONAL) {
  return _s('format', _str(region), _str(input), Number(style) | 0);
}

function formatNational(region, input) {
  return format(region, input, NATIONAL);
}

function formatInternational(region, input) {
  return format(region, input, INTERNATIONAL);
}

function formatE164(region, input) {
  return format(region, input, E164);
}

function formatRfc3966(region, input) {
  return format(region, input, RFC3966);
}

/** Format `input` as dialled from `callingFrom`. */
function formatOutOfCountry(region, input, callingFrom) {
  return _s('formatOutOfCountry', _str(region), _str(input), _str(callingFrom));
}

/** Format a {@link ParsedNumber} as originally dialled, from `callingFrom`. */
function formatInOriginal(parsed, callingFrom) {
  return _s('formatInOriginal', parsed._pn, _str(callingFrom));
}

// ---- relations / helpers ----

/** Compare two numbers — a MATCH_* MatchType. */
function isNumberMatch(a, b) {
  return _api().isNumberMatch(_str(a), _str(b));
}

/** Drop digits past the region's maximum length. */
function truncateTooLong(region, input) {
  return _s('truncateTooLong', _str(region), _str(input));
}

/** Keep only the digits of a string (Unicode digits included). */
function normalizeDigitsOnly(s) {
  return _s('normalizeDigitsOnly', _str(s));
}

/** Convert vanity letters to their dial-pad digits. */
function convertAlphaCharacters(s) {
  return _s('convertAlphaCharacters', _str(s));
}

/** True if the string contains vanity (alpha) characters. */
function isAlphaNumber(s) {
  return _api().isAlphaNumber(_str(s)) !== 0;
}

/** The ABI revision the loaded engine reports. */
function abiVersion() {
  return _api().abiVersion();
}

// ---- AsYouTypeFormatter ----

/**
 * Formats a number as it is typed, digit by digit.
 *
 * The formatter state is a caller-owned ABI string; each `inputDigit` threads a
 * new state and frees the old one.
 */
class AsYouTypeFormatter {
  constructor(region) {
    this._state = _s('aytNew', _str(region));
  }

  /** Feed one character; return the formatted-so-far string. */
  inputDigit(ch) {
    this._state = _s('aytInput', this._state, _str(ch));
    return this.result();
  }

  /** The formatted-so-far string. */
  result() {
    return _s('aytResult', this._state);
  }

  /** Reset the formatter. */
  clear() {
    this._state = _s('aytClear', this._state);
  }
}

// ---- PhoneNumberMatcher / findNumbers ----

/** One phone number found in free text: 0-based `start`/`end` and the `raw` text. */
class Match {
  constructor(start, end, raw) {
    this.start = start;
    this.end = end;
    this.raw = raw;
  }
}

/** Find phone numbers in free text. Returns an array of {@link Match}. */
function findNumbers(text, region, leniency = LENIENCY_VALID) {
  const api = _api();
  const t = _str(text);
  const r = _str(region);
  const len = Number(leniency) | 0;
  const n = api.matcherCount(t, r, len);
  const out = [];
  for (let i = 0; i < n; i++) {
    const start = api.matcherStart(t, r, len, i);
    const end = api.matcherEnd(t, r, len, i);
    const raw = native.takeString(api, api.matcherRaw(t, r, len, i));
    out.push(new Match(start, end, raw));
  }
  return out;
}

module.exports = {
  // metadata
  countryCode, exampleNumber, exampleNumberForType, invalidExampleNumber,
  possibleLengths, regionCodeForCountryCode, isNanpaCountry, nddPrefixForRegion,
  regions, ccRegionCount, regionsForCountryCode,
  // parse
  ParsedNumber, parse, nationalNumber,
  // validation
  isPossibleNumber, isPossibleNumberWithReason, isValidNumber,
  isValidNumberForRegion, numberType, canBeInternationallyDialled,
  // formatting
  format, formatNational, formatInternational, formatE164, formatRfc3966,
  formatOutOfCountry, formatInOriginal,
  // helpers
  isNumberMatch, truncateTooLong, normalizeDigitsOnly, convertAlphaCharacters,
  isAlphaNumber, abiVersion,
  // stateful / matcher
  AsYouTypeFormatter, Match, findNumbers,
};
