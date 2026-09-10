// The 45-check binding conformance suite (docs/conformance.md, v7).
//
// Proves the Go binding marshals every value shape across the FFI. It is NOT a
// phone-number test suite — the behavioural cases live in the engine's own
// tests and run once, in Aether. A binding's suite samples each kind of value
// crossing the FFI, so it proves the marshalling, not the library.
package phonenumber

import "testing"

func eqStr(t *testing.T, what, got, want string) {
	t.Helper()
	if got != want {
		t.Errorf("%s:\n  got  %q\n  want %q", what, got, want)
	}
}

func eqBool(t *testing.T, what string, got, want bool) {
	t.Helper()
	if got != want {
		t.Errorf("%s: got %v, want %v", what, got, want)
	}
}

func eqInt(t *testing.T, what string, got, want int) {
	t.Helper()
	if got != want {
		t.Errorf("%s: got %d, want %d", what, got, want)
	}
}

func eqStrSlice(t *testing.T, what string, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("%s:\n  got  %q\n  want %q", what, got, want)
		return
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("%s:\n  got  %q\n  want %q", what, got, want)
			return
		}
	}
}

func Test01CountryCodeUS(t *testing.T) {
	eqStr(t, `CountryCode("US")`, CountryCode("US"), "1")
}

func Test02CountryCodeGB(t *testing.T) {
	eqStr(t, `CountryCode("GB")`, CountryCode("GB"), "44")
}

func Test03UnknownRegion(t *testing.T) {
	eqStr(t, `CountryCode("ZZ")`, CountryCode("ZZ"), "")
}

func Test04ExampleNumber(t *testing.T) {
	eqStr(t, `ExampleNumber("US")`, ExampleNumber("US"), "2015550123")
}

func Test05PossibleLengths(t *testing.T) {
	eqStr(t, `PossibleLengths("US")`, PossibleLengths("US"), "10")
}

func Test06RegionForCC(t *testing.T) {
	eqStr(t, `RegionCodeForCountryCode("44")`,
		RegionCodeForCountryCode("44"), "GB")
}

func Test07IsNanpa(t *testing.T) {
	eqBool(t, `IsNanpaCountry("US")`, IsNanpaCountry("US"), true)
}

func Test08RegionEnumeration(t *testing.T) {
	if got := RegionCount(); got < 200 {
		t.Errorf("RegionCount() = %d, want >= 200", got)
	}
	if r0 := RegionAt(0); len(r0) != 2 {
		t.Errorf("RegionAt(0) = %q, want a 2-letter region id", r0)
	}
	// Regions() must agree with the count/index accessors it wraps.
	if regs := Regions(); len(regs) != RegionCount() {
		t.Errorf("len(Regions()) = %d, want %d", len(regs), RegionCount())
	}
}

func Test09CCRegion(t *testing.T) {
	regs := RegionsForCountryCode("1")
	if len(regs) == 0 || regs[0] != "US" {
		t.Errorf(`RegionsForCountryCode("1")[0] = %v, want "US"`, regs)
	}
}

// Checks 10-14: parse "+1 201 555 0123 ext 42" in US and read the fields.
func Test10to14Parse(t *testing.T) {
	num := Parse("+1 201 555 0123 ext 42", "US")
	eqStr(t, "pn_error", num.Error(), "")
	eqStr(t, "pn_national_number", num.NationalNumber(), "2015550123")
	eqStr(t, "pn_extension", num.Extension(), "42")
	eqStr(t, "pn_country_code", num.CountryCode(), "1")
	if got := num.Source(); got != SourceFromNumberWithPlus {
		t.Errorf("pn_source = %d, want %d (SourceFromNumberWithPlus)", got, SourceFromNumberWithPlus)
	}
	eqStr(t, "region_code_for_number", num.RegionCode(), "US")
}

func Test15ParseTrunkPrefix(t *testing.T) {
	eqStr(t, `Parse("01212345678", "GB").NationalNumber()`,
		Parse("01212345678", "GB").NationalNumber(), "1212345678")
}

func Test16IsPossible(t *testing.T) {
	eqBool(t, `IsPossibleNumber("US", "2015550123")`,
		IsPossibleNumber("US", "2015550123"), true)
}

func Test17ReasonTooShort(t *testing.T) {
	if got := IsPossibleNumberWithReason("US", "201555"); got != ResultTooShort {
		t.Errorf(`IsPossibleNumberWithReason("US", "201555") = %d, want %d (ResultTooShort)`, got, ResultTooShort)
	}
}

func Test18IsValid(t *testing.T) {
	eqBool(t, `IsValidNumber("US", "2015550123")`,
		IsValidNumber("US", "2015550123"), true)
}

func Test19InvalidShape(t *testing.T) {
	eqBool(t, `IsValidNumber("US", "1015550123")`,
		IsValidNumber("US", "1015550123"), false)
}

func Test20ValidWithCC(t *testing.T) {
	eqBool(t, `IsValidNumber("US", "+12015550123")`,
		IsValidNumber("US", "+12015550123"), true)
}

func Test21NumberType(t *testing.T) {
	if got := NumberType("US", "2015550123"); got != TypeFixedLineOrMobile {
		t.Errorf(`NumberType("US", "2015550123") = %d, want %d (TypeFixedLineOrMobile)`, got, TypeFixedLineOrMobile)
	}
	if got := NumberType("GB", "2070313000"); got != TypeFixedLine {
		t.Errorf(`NumberType("GB", "2070313000") = %d, want %d (TypeFixedLine)`, got, TypeFixedLine)
	}
}

func Test22FormatNational(t *testing.T) {
	eqStr(t, "Format NATIONAL",
		Format("US", "2015550123", NATIONAL), "(201) 555-0123")
}

func Test23FormatE164(t *testing.T) {
	eqStr(t, "Format E164",
		Format("US", "2015550123", E164), "+12015550123")
}

func Test24FormatInternational(t *testing.T) {
	eqStr(t, "Format INTERNATIONAL",
		Format("US", "2015550123", INTERNATIONAL), "+1 201-555-0123")
}

func Test25FormatRFC3966(t *testing.T) {
	eqStr(t, "Format RFC3966",
		Format("US", "2015550123", RFC3966), "tel:+1-201-555-0123")
}

func Test26MatchExact(t *testing.T) {
	if got := IsNumberMatch("+12015550123", "+1 201 555 0123"); got != MatchExact {
		t.Errorf("IsNumberMatch(exact) = %d, want %d (MatchExact)", got, MatchExact)
	}
}

func Test27MatchNone(t *testing.T) {
	if got := IsNumberMatch("+12015550123", "+12025550123"); got != MatchNoMatch {
		t.Errorf("IsNumberMatch(none) = %d, want %d (MatchNoMatch)", got, MatchNoMatch)
	}
}

func Test28Normalize(t *testing.T) {
	eqStr(t, `NormalizeDigitsOnly("+1 (201) 555.0123")`,
		NormalizeDigitsOnly("+1 (201) 555.0123"), "12015550123")
}

func Test29Alpha(t *testing.T) {
	eqStr(t, `ConvertAlphaCharacters("1-800-FLOWERS")`,
		ConvertAlphaCharacters("1-800-FLOWERS"), "1-800-3569377")
}

func Test30Truncate(t *testing.T) {
	eqStr(t, `TruncateTooLong("US", "20155501239999")`,
		TruncateTooLong("US", "20155501239999"), "2015550123")
}

func Test31AsYouType(t *testing.T) {
	ayt := NewAsYouTypeFormatter("US")
	out := ""
	for _, c := range "2015550123" {
		out = ayt.InputDigit(c)
	}
	eqStr(t, "AsYouType result", out, "(201) 555-0123")
}

func Test32MatcherCount(t *testing.T) {
	matches := FindNumbers("call 201-555-0123 or +1 202 555 0199", "US", LeniencyValid)
	eqInt(t, "FindNumbers count", len(matches), 2)
}

func Test33MatcherRaw(t *testing.T) {
	matches := FindNumbers("call 201-555-0123 now", "US", LeniencyValid)
	if len(matches) == 0 {
		t.Fatalf("FindNumbers returned no matches")
	}
	eqStr(t, "FindNumbers[0].Raw", matches[0].Raw, "201-555-0123")
}

func Test34ABIVersion(t *testing.T) {
	eqInt(t, "ABIVersion()", ABIVersion(), 7)
}

func Test35ShortEmergencyUS(t *testing.T) {
	eqBool(t, `IsEmergencyNumber("US", "911")`, IsEmergencyNumber("US", "911"), true)
}

func Test36ShortNotEmergency(t *testing.T) {
	eqBool(t, `IsEmergencyNumber("US", "999")`, IsEmergencyNumber("US", "999"), false)
}

func Test37ShortEmergencyGB(t *testing.T) {
	eqBool(t, `IsEmergencyNumber("GB", "999")`, IsEmergencyNumber("GB", "999"), true)
}

func Test38ShortValid(t *testing.T) {
	eqBool(t, `ShortIsValid("US", "911")`, ShortIsValid("US", "911"), true)
}

func Test39ShortCost(t *testing.T) {
	if got := ShortExpectedCost("US", "911"); got != CostTollFree {
		t.Errorf(`ShortExpectedCost("US", "911") = %d, want %d (CostTollFree)`, got, CostTollFree)
	}
}

func Test40ShortExample(t *testing.T) {
	eqStr(t, `ShortExampleNumber("US")`, ShortExampleNumber("US"), "112")
}

func Test41TimeZonesUS(t *testing.T) {
	eqStrSlice(t, `TimeZonesForNumber("US", "2015550123")`,
		TimeZonesForNumber("US", "2015550123"), []string{"America/New_York"})
}

func Test42TimeZonesGB(t *testing.T) {
	eqStrSlice(t, `TimeZonesForNumber("GB", "2070313000")`,
		TimeZonesForNumber("GB", "2070313000"), []string{"Europe/London"})
}

func Test43UnknownTimeZone(t *testing.T) {
	eqStr(t, "UnknownTimeZone()", UnknownTimeZone(), "Etc/Unknown")
}

func Test44CarrierName(t *testing.T) {
	eqStr(t, `CarrierNameForNumber("GB", "7106000000")`,
		CarrierNameForNumber("GB", "7106000000"), "O2")
}

func Test45GeoDescription(t *testing.T) {
	eqStr(t, `GeoDescriptionForNumber("US", "6502530000")`,
		GeoDescriptionForNumber("US", "6502530000"), "Mountain View, CA")
}

// The DE candidate's three-group split matches no MAIN format but is
// legitimized by an alternate format, so STRICT_GROUPING accepts it.
func Test46StrictGroupingAlternateFormat(t *testing.T) {
	matches := FindNumbers("call 030 234 5678 now", "DE", LeniencyStrictGrouping)
	eqInt(t, "FindNumbers count (STRICT_GROUPING, DE)", len(matches), 1)
}

// The US digits are a VALID number but their grouping matches no US format, so
// EXACT_GROUPING rejects them; VALID (the contrast) accepts them.
func Test47ExactGroupingRejects(t *testing.T) {
	eqInt(t, "FindNumbers count (VALID, US)",
		len(FindNumbers("call 65 025 30000 today", "US", LeniencyValid)), 1)
	eqInt(t, "FindNumbers count (EXACT_GROUPING, US)",
		len(FindNumbers("call 65 025 30000 today", "US", LeniencyExactGrouping)), 0)
}

// The Format* convenience wrappers must agree with Format(..., style).
func TestFormatConveniences(t *testing.T) {
	eqStr(t, "FormatNational", FormatNational("US", "2015550123"), "(201) 555-0123")
	eqStr(t, "FormatInternational", FormatInternational("US", "2015550123"), "+1 201-555-0123")
	eqStr(t, "FormatE164", FormatE164("US", "2015550123"), "+12015550123")
	eqStr(t, "FormatRFC3966", FormatRFC3966("US", "2015550123"), "tel:+1-201-555-0123")
}
