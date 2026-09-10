'use strict';
/**
 * phonenumber_ae — JavaScript binding for the shared phonenumber engine (ABI v2).
 *
 * The engine (Google libphonenumber's metadata, parse, isPossible/isValid,
 * number typing, formatting, as-you-type, matcher) is pure Aether in
 * core/phonenumber.ae and is shared by every language binding in this monorepo.
 * This package is marshalling only.
 *
 *     const pn = require('phonenumber_ae');
 *
 *     const num = pn.parse('+1 650 253 0000', 'US');
 *     num.nationalNumber;                            // '6502530000'
 *     pn.isValidNumber('US', '+1 201 555 0123');     // true
 *     pn.format('US', '2015550123', pn.INTERNATIONAL); // '+1 201-555-0123'
 *
 *     const ayt = new pn.AsYouTypeFormatter('US');
 *     let last;
 *     for (const c of '6502530000') last = ayt.inputDigit(c); // '(650) 253-0000'
 *
 *     pn.findNumbers('call 201-555-0123 today', 'US');
 */

const fns = require('./lib/phonenumber');
const native = require('./lib/native');

module.exports = {
  ...fns,

  // ---- format styles ----
  E164: native.E164,
  INTERNATIONAL: native.INTERNATIONAL,
  NATIONAL: native.NATIONAL,
  RFC3966: native.RFC3966,

  // ---- number types ----
  TYPE_UNKNOWN: native.TYPE_UNKNOWN,
  TYPE_FIXED_LINE: native.TYPE_FIXED_LINE,
  TYPE_MOBILE: native.TYPE_MOBILE,
  TYPE_TOLL_FREE: native.TYPE_TOLL_FREE,
  TYPE_PREMIUM_RATE: native.TYPE_PREMIUM_RATE,
  TYPE_SHARED_COST: native.TYPE_SHARED_COST,
  TYPE_VOIP: native.TYPE_VOIP,
  TYPE_PERSONAL_NUMBER: native.TYPE_PERSONAL_NUMBER,
  TYPE_PAGER: native.TYPE_PAGER,
  TYPE_UAN: native.TYPE_UAN,
  TYPE_VOICEMAIL: native.TYPE_VOICEMAIL,

  // ---- ValidationResult (is_possible_number_with_reason) ----
  VR_IS_POSSIBLE: native.VR_IS_POSSIBLE,
  VR_IS_POSSIBLE_LOCAL_ONLY: native.VR_IS_POSSIBLE_LOCAL_ONLY,
  VR_INVALID_COUNTRY_CODE: native.VR_INVALID_COUNTRY_CODE,
  VR_TOO_SHORT: native.VR_TOO_SHORT,
  VR_INVALID_LENGTH: native.VR_INVALID_LENGTH,
  VR_TOO_LONG: native.VR_TOO_LONG,

  // ---- MatchType (is_number_match) ----
  MATCH_NOT_A_NUMBER: native.MATCH_NOT_A_NUMBER,
  MATCH_NO_MATCH: native.MATCH_NO_MATCH,
  MATCH_SHORT_NSN: native.MATCH_SHORT_NSN,
  MATCH_NSN: native.MATCH_NSN,
  MATCH_EXACT: native.MATCH_EXACT,

  // ---- CountryCodeSource (pn.source) ----
  SRC_FROM_NUMBER_WITH_PLUS: native.SRC_FROM_NUMBER_WITH_PLUS,
  SRC_FROM_NUMBER_WITH_IDD: native.SRC_FROM_NUMBER_WITH_IDD,
  SRC_FROM_NUMBER_WITHOUT_PLUS: native.SRC_FROM_NUMBER_WITHOUT_PLUS,
  SRC_FROM_DEFAULT_COUNTRY: native.SRC_FROM_DEFAULT_COUNTRY,

  // ---- matcher leniency ----
  LENIENCY_POSSIBLE: native.LENIENCY_POSSIBLE,
  LENIENCY_VALID: native.LENIENCY_VALID,
};
