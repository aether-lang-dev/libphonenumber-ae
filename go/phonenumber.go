// Package phonenumber validates and formats international phone numbers.
//
// It is a thin cgo binding over the monorepo's ONE shared native engine
// (core/native/libphonenumber_ae.so, compiled from pure Aether over Google
// libphonenumber's own metadata). No phone-number logic lives in this package —
// every function marshals to an `aether_pn_embed_*` call across the flat C ABI
// described in docs/abi.md (v3, full PhoneNumberUtil parity plus
// ShortNumberInfo). One engine, one set of behaviours, N language surfaces.
//
// The ABI is stateless and handle-free: a parsed number and an AsYouType state
// are themselves caller-owned STRINGS you pass back to accessor calls. Every
// returned char* is caller-owned — this package copies it out and frees it
// through aether_pn_embed_free_string before returning.
//
//	pn.IsValidNumber("US", "+1 201 555 0123")   // true
//	pn.Format("US", "2015550123", pn.NATIONAL)  // "(201) 555-0123"
//	num := pn.Parse("+1 201 555 0123 ext 42", "US")
//	num.NationalNumber()                        // "2015550123"
//	pn.NumberType("US", "2015550123")           // pn.TypeFixedLine
//	pn.CountryCode("JP")                        // "81"
package phonenumber

/*
#cgo LDFLAGS: -L${SRCDIR}/native -L${SRCDIR}/../core/native -lphonenumber_ae -Wl,-rpath,${SRCDIR}/native -Wl,-rpath,${SRCDIR}/../core/native

#include <stdlib.h>

// ---- the C ABI (core/embed.ae, docs/abi.md). Declared, not defined: we LINK
// the engine rather than dlopen it, so cgo resolves these at build time.
// Every returned char* is caller-owned — copy it out then free it through
// aether_pn_embed_free_string. There is no handle and there are no callbacks:
// a parsed number and an AsYouType state cross the seam as caller-owned STRINGS. ----

// lifecycle / metadata
int   aether_pn_embed_abi_version(void);
void  aether_pn_embed_free_string(char* s);
char* aether_pn_embed_country_code(const char* region);
char* aether_pn_embed_example_number(const char* region);
char* aether_pn_embed_example_number_for_type(const char* region, int type);
char* aether_pn_embed_invalid_example_number(const char* region);
char* aether_pn_embed_possible_lengths(const char* region);
char* aether_pn_embed_region_code_for_country_code(const char* cc);
int   aether_pn_embed_is_nanpa_country(const char* region);
char* aether_pn_embed_ndd_prefix_for_region(const char* region, int strip_non_digits);
int   aether_pn_embed_region_count(void);
char* aether_pn_embed_region_at(int index);
int   aether_pn_embed_cc_region_count(const char* cc);
char* aether_pn_embed_cc_region_at(const char* cc, int index);

// parse + parsed-number accessors
char* aether_pn_embed_parse(const char* input, const char* region);
char* aether_pn_embed_national_number(const char* region, const char* input);
char* aether_pn_embed_pn_region(const char* pn);
char* aether_pn_embed_pn_country_code(const char* pn);
char* aether_pn_embed_pn_national_number(const char* pn);
char* aether_pn_embed_pn_extension(const char* pn);
int   aether_pn_embed_pn_italian_leading_zero(const char* pn);
int   aether_pn_embed_pn_source(const char* pn);
char* aether_pn_embed_pn_error(const char* pn);
char* aether_pn_embed_region_code_for_number(const char* pn);
char* aether_pn_embed_national_significant_number(const char* pn);
int   aether_pn_embed_length_of_ndc(const char* pn);
int   aether_pn_embed_length_of_area_code(const char* pn);
int   aether_pn_embed_is_geographical(const char* pn);

// validation
int   aether_pn_embed_is_possible_number(const char* region, const char* input);
int   aether_pn_embed_is_possible_number_with_reason(const char* region, const char* input);
int   aether_pn_embed_is_valid_number(const char* region, const char* input);
int   aether_pn_embed_is_valid_number_for_region(const char* input, const char* region);
int   aether_pn_embed_number_type(const char* region, const char* input);
int   aether_pn_embed_can_be_internationally_dialled(const char* region, const char* input);

// formatting
char* aether_pn_embed_format(const char* region, const char* input, int fmt);
char* aether_pn_embed_format_out_of_country(const char* region, const char* input, const char* calling_from);
char* aether_pn_embed_format_in_original(const char* pn, const char* calling_from);

// relations / helpers
int   aether_pn_embed_is_number_match(const char* a, const char* b);
char* aether_pn_embed_truncate_too_long(const char* region, const char* input);
char* aether_pn_embed_normalize_digits_only(const char* s);
char* aether_pn_embed_convert_alpha_characters(const char* s);
int   aether_pn_embed_is_alpha_number(const char* s);

// AsYouTypeFormatter (state threaded as a caller-owned string)
char* aether_pn_embed_ayt_new(const char* region);
char* aether_pn_embed_ayt_input(const char* state, const char* ch);
char* aether_pn_embed_ayt_result(const char* state);
char* aether_pn_embed_ayt_clear(const char* state);

// PhoneNumberMatcher / findNumbers
int   aether_pn_embed_matcher_count(const char* text, const char* region, int leniency);
int   aether_pn_embed_matcher_start(const char* text, const char* region, int leniency, int idx);
int   aether_pn_embed_matcher_end(const char* text, const char* region, int leniency, int idx);
char* aether_pn_embed_matcher_raw(const char* text, const char* region, int leniency, int idx);

// ShortNumberInfo (short / emergency numbers)
int   aether_pn_embed_short_is_possible(const char* region, const char* input);
int   aether_pn_embed_short_is_valid(const char* region, const char* input);
int   aether_pn_embed_short_is_emergency(const char* region, const char* input);
int   aether_pn_embed_short_connects_to_emergency(const char* region, const char* input);
int   aether_pn_embed_short_is_carrier_specific(const char* region, const char* input);
int   aether_pn_embed_short_is_sms_service(const char* region, const char* input);
int   aether_pn_embed_short_expected_cost(const char* region, const char* input);
char* aether_pn_embed_short_example_number(const char* region);
*/
import "C"

import "unsafe"

// Style selects a phone-number display format. These are ABI constants —
// append only, never renumber.
type Style int

const (
	// E164 formats in the compact E.164 form, e.g. "+12015550123".
	E164 Style = 0
	// INTERNATIONAL formats with the country code, e.g. "+1 201-555-0123".
	INTERNATIONAL Style = 1
	// NATIONAL formats as a country would write it locally, e.g. "(201) 555-0123".
	NATIONAL Style = 2
	// RFC3966 formats as an RFC 3966 tel: URI, e.g. "tel:+1-201-555-0123".
	RFC3966 Style = 3
)

// Type is a phone number's kind, mirroring libphonenumber's PhoneNumberType,
// with TypeUnknown for "could not classify". These are ABI constants — append
// only, never renumber.
type Type int

const (
	TypeUnknown           Type = -1
	TypeFixedLine         Type = 0
	TypeMobile            Type = 1
	TypeTollFree          Type = 2
	TypePremiumRate       Type = 3
	TypeSharedCost        Type = 4
	TypeVoIP              Type = 5
	TypePersonalNumber    Type = 6
	TypePager             Type = 7
	TypeUAN               Type = 8
	TypeVoicemail         Type = 9
	TypeFixedLineOrMobile Type = 10
)

// ValidationResult is why IsPossibleNumberWithReason accepted or rejected a
// number. These are ABI constants — append only, never renumber.
type ValidationResult int

const (
	ResultIsPossible          ValidationResult = 0
	ResultIsPossibleLocalOnly ValidationResult = 4
	ResultInvalidCountryCode  ValidationResult = 1
	ResultTooShort            ValidationResult = 2
	ResultInvalidLength       ValidationResult = 5
	ResultTooLong             ValidationResult = 3
)

// MatchType is how closely two numbers match, from IsNumberMatch. These are ABI
// constants — append only, never renumber.
type MatchType int

const (
	MatchNotANumber MatchType = 0
	MatchNoMatch    MatchType = 1
	MatchShortNSN   MatchType = 2
	MatchNSN        MatchType = 3
	MatchExact      MatchType = 4
)

// Source is where a parsed number's country code came from
// (libphonenumber's CountryCodeSource). These are ABI constants — append only,
// never renumber.
type Source int

const (
	SourceFromNumberWithPlus    Source = 1
	SourceFromNumberWithIDD     Source = 5
	SourceFromNumberWithoutPlus Source = 10
	SourceFromDefaultCountry    Source = 20
)

// Leniency tunes how strict FindNumbers is about what counts as a number.
// These are ABI constants — append only, never renumber.
type Leniency int

const (
	// LeniencyPossible accepts anything the region considers a possible length.
	LeniencyPossible Leniency = 0
	// LeniencyValid accepts only numbers that pass full validation.
	LeniencyValid Leniency = 1
)

// Cost is the expected cost of dialling a short number, mirroring
// libphonenumber's ShortNumberInfo.ShortNumberCost. These are ABI constants —
// append only, never renumber.
type Cost int

const (
	CostTollFree     Cost = 0
	CostStandardRate Cost = 1
	CostPremiumRate  Cost = 2
	CostUnknown      Cost = 3
)

// takeString copies an ABI-returned string out and frees it through the ABI.
//
// Every char* the engine returns is caller-owned; leaking it is the single
// easiest mistake to make in any of these bindings, so every string result in
// this file goes through here.
func takeString(s *C.char) string {
	if s == nil {
		return ""
	}
	defer C.aether_pn_embed_free_string(s)
	return C.GoString(s)
}

// cStr is a small helper: a C string the caller must free. Go strings are not
// NUL-terminated, so every const char* argument crosses the FFI via C.CString
// (which malloc's) and is freed with C.free.
func cStr(s string) *C.char { return C.CString(s) }

// ---- metadata ----

// CountryCode returns the country calling code for a region ("1", "44", …),
// or "" if the region is unknown. region is an ISO-3166 alpha-2 code
// (case-insensitive).
func CountryCode(region string) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return takeString(C.aether_pn_embed_country_code(cr))
}

// ExampleNumber returns an example national number for the region, or "".
func ExampleNumber(region string) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return takeString(C.aether_pn_embed_example_number(cr))
}

// ExampleNumberForType returns an example national number of the given Type for
// the region, or "".
func ExampleNumberForType(region string, t Type) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return takeString(C.aether_pn_embed_example_number_for_type(cr, C.int(t)))
}

// InvalidExampleNumber returns an example number for the region that is invalid
// (useful for testing), or "".
func InvalidExampleNumber(region string) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return takeString(C.aether_pn_embed_invalid_example_number(cr))
}

// PossibleLengths returns the possible-lengths spec for the region
// (e.g. "9,10"), or "".
func PossibleLengths(region string) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return takeString(C.aether_pn_embed_possible_lengths(cr))
}

// RegionCodeForCountryCode returns the main region for a calling code
// ("44" -> "GB"), or "".
func RegionCodeForCountryCode(cc string) string {
	cc0 := cStr(cc)
	defer C.free(unsafe.Pointer(cc0))
	return takeString(C.aether_pn_embed_region_code_for_country_code(cc0))
}

// IsNanpaCountry reports whether the region is part of the North American
// Numbering Plan (calling code 1).
func IsNanpaCountry(region string) bool {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return C.aether_pn_embed_is_nanpa_country(cr) != 0
}

// NddPrefixForRegion returns the national direct dialling (trunk) prefix for the
// region. When stripNonDigits is true, non-digit characters (e.g. "~") are
// removed.
func NddPrefixForRegion(region string, stripNonDigits bool) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	strip := C.int(0)
	if stripNonDigits {
		strip = 1
	}
	return takeString(C.aether_pn_embed_ndd_prefix_for_region(cr, strip))
}

// RegionCount is how many regions the metadata carries.
func RegionCount() int { return int(C.aether_pn_embed_region_count()) }

// RegionAt returns the i-th region id, or "" if index is out of range.
func RegionAt(index int) string {
	return takeString(C.aether_pn_embed_region_at(C.int(index)))
}

// Regions returns every region id the metadata carries, as a slice of ISO-3166
// alpha-2 codes.
func Regions() []string {
	n := RegionCount()
	out := make([]string, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, RegionAt(i))
	}
	return out
}

// RegionsForCountryCode returns every region that shares a calling code
// ("1" -> "US", "CA", …), most-populous first.
func RegionsForCountryCode(cc string) []string {
	cc0 := cStr(cc)
	defer C.free(unsafe.Pointer(cc0))
	n := int(C.aether_pn_embed_cc_region_count(cc0))
	out := make([]string, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, takeString(C.aether_pn_embed_cc_region_at(cc0, C.int(i))))
	}
	return out
}

// ---- parsed number ----

// ParsedNumber is a parsed phone number. It wraps the caller-owned
// parsed-number STRING the ABI returns from Parse; its fields are read on
// demand by passing that string back to the pn_* accessor calls.
type ParsedNumber struct {
	pn string
}

// Parse parses a raw human-typed number in the context of region and returns a
// ParsedNumber. Read Error to tell whether parsing succeeded.
func Parse(input, region string) ParsedNumber {
	ci, cr := cStr(input), cStr(region)
	defer C.free(unsafe.Pointer(ci))
	defer C.free(unsafe.Pointer(cr))
	return ParsedNumber{pn: takeString(C.aether_pn_embed_parse(ci, cr))}
}

// cpn marshals the parsed-number string across the FFI. cgo function pointers
// cannot be passed as Go values, so each accessor below calls its ABI symbol
// directly on this pointer and frees it. The caller frees the returned *C.char.
func (p ParsedNumber) cpn() *C.char { return cStr(p.pn) }

// Region returns the region the number belongs to as recorded on the parse,
// or "".
func (p ParsedNumber) Region() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_pn_region(cp))
}

// CountryCode returns the number's country calling code ("1", "44", …).
func (p ParsedNumber) CountryCode() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_pn_country_code(cp))
}

// NationalNumber returns the national (significant) number, digits only.
func (p ParsedNumber) NationalNumber() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_pn_national_number(cp))
}

// Extension returns the parsed extension, or "" if there was none.
func (p ParsedNumber) Extension() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_pn_extension(cp))
}

// ItalianLeadingZero reports whether the number carries a significant leading
// zero (e.g. some Italian fixed lines).
func (p ParsedNumber) ItalianLeadingZero() bool {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return C.aether_pn_embed_pn_italian_leading_zero(cp) != 0
}

// Source is where the country code was inferred from during parsing.
func (p ParsedNumber) Source() Source {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return Source(C.aether_pn_embed_pn_source(cp))
}

// Error is a non-empty message if parsing failed, or "" on success.
func (p ParsedNumber) Error() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_pn_error(cp))
}

// RegionCode returns the region this number maps to ("US", "GB", …), or "".
func (p ParsedNumber) RegionCode() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_region_code_for_number(cp))
}

// NationalSignificantNumber returns the national significant number, as
// libphonenumber computes it (leading zeros handled).
func (p ParsedNumber) NationalSignificantNumber() string {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return takeString(C.aether_pn_embed_national_significant_number(cp))
}

// LengthOfNDC is the length of the national destination code, or 0.
func (p ParsedNumber) LengthOfNDC() int {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return int(C.aether_pn_embed_length_of_ndc(cp))
}

// LengthOfAreaCode is the length of the area code, or 0.
func (p ParsedNumber) LengthOfAreaCode() int {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return int(C.aether_pn_embed_length_of_area_code(cp))
}

// IsGeographical reports whether the number is geographically bound.
func (p ParsedNumber) IsGeographical() bool {
	cp := p.cpn()
	defer C.free(unsafe.Pointer(cp))
	return C.aether_pn_embed_is_geographical(cp) != 0
}

// NationalNumber returns the national number extracted from raw input, with the
// country code and punctuation stripped. input is a number as a human might
// type it — digits with optional spaces, dashes, parentheses, dots, and an
// optional leading "+countrycode".
func NationalNumber(region, input string) string {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return takeString(C.aether_pn_embed_national_number(cr, ci))
}

// ---- validation ----

// IsPossibleNumber reports whether the national number is a length the region
// allows — a cheap check that catches most typos.
func IsPossibleNumber(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_is_possible_number(cr, ci) != 0
}

// IsPossibleNumberWithReason is like IsPossibleNumber but returns a
// ValidationResult saying why.
func IsPossibleNumberWithReason(region, input string) ValidationResult {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return ValidationResult(C.aether_pn_embed_is_possible_number_with_reason(cr, ci))
}

// IsValidNumber reports whether the number matches the region's national-number
// patterns — the real "is this a phone number" answer.
func IsValidNumber(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_is_valid_number(cr, ci) != 0
}

// IsValidNumberForRegion reports whether the number is valid AND belongs to the
// given region (stricter than IsValidNumber for numbers whose calling code is
// shared by several regions).
func IsValidNumberForRegion(input, region string) bool {
	ci, cr := cStr(input), cStr(region)
	defer C.free(unsafe.Pointer(ci))
	defer C.free(unsafe.Pointer(cr))
	return C.aether_pn_embed_is_valid_number_for_region(ci, cr) != 0
}

// NumberType classifies the number, returning a Type (TypeUnknown for "could
// not classify").
func NumberType(region, input string) Type {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return Type(C.aether_pn_embed_number_type(cr, ci))
}

// CanBeInternationallyDialled reports whether the number can be dialled from
// outside its region.
func CanBeInternationallyDialled(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_can_be_internationally_dialled(cr, ci) != 0
}

// ---- formatting ----

// Format formats the number in the given style (E164 / INTERNATIONAL /
// NATIONAL / RFC3966). Any other Style value is treated as NATIONAL.
func Format(region, input string, fmt Style) string {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return takeString(C.aether_pn_embed_format(cr, ci, C.int(fmt)))
}

// FormatNational formats the number as a country would write it locally.
func FormatNational(region, input string) string { return Format(region, input, NATIONAL) }

// FormatInternational formats the number with its country code.
func FormatInternational(region, input string) string { return Format(region, input, INTERNATIONAL) }

// FormatE164 formats the number in the compact E.164 form.
func FormatE164(region, input string) string { return Format(region, input, E164) }

// FormatRFC3966 formats the number as an RFC 3966 tel: URI.
func FormatRFC3966(region, input string) string { return Format(region, input, RFC3966) }

// FormatOutOfCountry formats the number as it would be dialled from
// callingFrom, including the appropriate IDD prefix.
func FormatOutOfCountry(region, input, callingFrom string) string {
	cr, ci, cf := cStr(region), cStr(input), cStr(callingFrom)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	defer C.free(unsafe.Pointer(cf))
	return takeString(C.aether_pn_embed_format_out_of_country(cr, ci, cf))
}

// FormatInOriginal formats a ParsedNumber the way it was originally entered,
// dialled from callingFrom.
func FormatInOriginal(p ParsedNumber, callingFrom string) string {
	cp, cf := cStr(p.pn), cStr(callingFrom)
	defer C.free(unsafe.Pointer(cp))
	defer C.free(unsafe.Pointer(cf))
	return takeString(C.aether_pn_embed_format_in_original(cp, cf))
}

// ---- relations / helpers ----

// IsNumberMatch reports how closely two numbers match, as a MatchType.
func IsNumberMatch(a, b string) MatchType {
	ca, cb := cStr(a), cStr(b)
	defer C.free(unsafe.Pointer(ca))
	defer C.free(unsafe.Pointer(cb))
	return MatchType(C.aether_pn_embed_is_number_match(ca, cb))
}

// TruncateTooLong drops excess trailing digits from an over-long number until it
// is a valid length for the region, returning the truncated number (or "" if it
// cannot be salvaged).
func TruncateTooLong(region, input string) string {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return takeString(C.aether_pn_embed_truncate_too_long(cr, ci))
}

// NormalizeDigitsOnly strips everything but the digits from s.
func NormalizeDigitsOnly(s string) string {
	cs := cStr(s)
	defer C.free(unsafe.Pointer(cs))
	return takeString(C.aether_pn_embed_normalize_digits_only(cs))
}

// ConvertAlphaCharacters maps vanity letters to their dial-pad digits
// (e.g. "1-800-FLOWERS" -> "1-800-3569377"), leaving punctuation in place.
func ConvertAlphaCharacters(s string) string {
	cs := cStr(s)
	defer C.free(unsafe.Pointer(cs))
	return takeString(C.aether_pn_embed_convert_alpha_characters(cs))
}

// IsAlphaNumber reports whether s contains vanity (alpha) characters.
func IsAlphaNumber(s string) bool {
	cs := cStr(s)
	defer C.free(unsafe.Pointer(cs))
	return C.aether_pn_embed_is_alpha_number(cs) != 0
}

// ABIVersion is the ABI revision the linked engine reports (currently 3).
func ABIVersion() int { return int(C.aether_pn_embed_abi_version()) }

// ---- AsYouTypeFormatter ----

// AsYouTypeFormatter formats a number as it is typed, digit by digit. The ABI
// keeps no handle: its state is a caller-owned STRING threaded through each
// call, which this type carries for you.
type AsYouTypeFormatter struct {
	state string
}

// NewAsYouTypeFormatter starts an as-you-type formatter for the given region.
func NewAsYouTypeFormatter(region string) *AsYouTypeFormatter {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return &AsYouTypeFormatter{state: takeString(C.aether_pn_embed_ayt_new(cr))}
}

// InputDigit feeds one character and returns the formatted-so-far string.
func (a *AsYouTypeFormatter) InputDigit(ch rune) string {
	cs, cc := cStr(a.state), cStr(string(ch))
	defer C.free(unsafe.Pointer(cs))
	defer C.free(unsafe.Pointer(cc))
	a.state = takeString(C.aether_pn_embed_ayt_input(cs, cc))
	return a.Result()
}

// Result returns the formatted-so-far string without changing state.
func (a *AsYouTypeFormatter) Result() string {
	cs := cStr(a.state)
	defer C.free(unsafe.Pointer(cs))
	return takeString(C.aether_pn_embed_ayt_result(cs))
}

// Clear resets the formatter to its initial (empty) state.
func (a *AsYouTypeFormatter) Clear() {
	cs := cStr(a.state)
	defer C.free(unsafe.Pointer(cs))
	a.state = takeString(C.aether_pn_embed_ayt_clear(cs))
}

// ---- PhoneNumberMatcher / findNumbers ----

// Match is one phone number found in free text: its rune-agnostic byte offsets
// within the text (Start inclusive, End exclusive) and the Raw substring.
type Match struct {
	Start int
	End   int
	Raw   string
}

// FindNumbers finds phone numbers in free text and returns them as a slice of
// Match. leniency tunes how strict the matcher is (LeniencyPossible or
// LeniencyValid).
func FindNumbers(text, region string, leniency Leniency) []Match {
	ct, cr := cStr(text), cStr(region)
	defer C.free(unsafe.Pointer(ct))
	defer C.free(unsafe.Pointer(cr))
	n := int(C.aether_pn_embed_matcher_count(ct, cr, C.int(leniency)))
	out := make([]Match, 0, n)
	for i := 0; i < n; i++ {
		start := int(C.aether_pn_embed_matcher_start(ct, cr, C.int(leniency), C.int(i)))
		end := int(C.aether_pn_embed_matcher_end(ct, cr, C.int(leniency), C.int(i)))
		raw := takeString(C.aether_pn_embed_matcher_raw(ct, cr, C.int(leniency), C.int(i)))
		out = append(out, Match{Start: start, End: end, Raw: raw})
	}
	return out
}

// ---- ShortNumberInfo (short / emergency numbers) ----

// Short numbers are dialled as-is: no country code, no national prefix. Each
// function takes the raw short number plus a region.

// ShortIsPossible reports whether the short number is a possible length for the
// region.
func ShortIsPossible(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_short_is_possible(cr, ci) != 0
}

// ShortIsValid reports whether the short number matches a short-number pattern
// for the region.
func ShortIsValid(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_short_is_valid(cr, ci) != 0
}

// IsEmergencyNumber reports whether the number is an emergency number for the
// region (e.g. "911" in the US, "999" in the GB).
func IsEmergencyNumber(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_short_is_emergency(cr, ci) != 0
}

// ConnectsToEmergencyNumber reports whether dialling the number connects to an
// emergency service in the region (looser than IsEmergencyNumber).
func ConnectsToEmergencyNumber(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_short_connects_to_emergency(cr, ci) != 0
}

// ShortIsCarrierSpecific reports whether the short number is carrier-specific.
func ShortIsCarrierSpecific(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_short_is_carrier_specific(cr, ci) != 0
}

// ShortIsSMSService reports whether the short number is an SMS short code for
// the region.
func ShortIsSMSService(region, input string) bool {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return C.aether_pn_embed_short_is_sms_service(cr, ci) != 0
}

// ShortExpectedCost returns the expected cost of dialling the short number, as
// a Cost (CostTollFree / CostStandardRate / CostPremiumRate / CostUnknown).
func ShortExpectedCost(region, input string) Cost {
	cr, ci := cStr(region), cStr(input)
	defer C.free(unsafe.Pointer(cr))
	defer C.free(unsafe.Pointer(ci))
	return Cost(C.aether_pn_embed_short_expected_cost(cr, ci))
}

// ShortExampleNumber returns an example short number for the region, or "".
func ShortExampleNumber(region string) string {
	cr := cStr(region)
	defer C.free(unsafe.Pointer(cr))
	return takeString(C.aether_pn_embed_short_example_number(cr))
}
