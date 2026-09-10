// The 45-check binding conformance suite (docs/conformance.md, v7).
//
// Proves the .NET binding marshals every value shape across the P/Invoke
// boundary — a parsed number and its accessors, an AsYouType formatter, the
// matcher, the stateless calls and every constant group. It is NOT a
// phone-number test suite — the behavioural cases live in the engine's own
// tests and run once, in Aether.
//
// ## Why a console runner and not xunit/NUnit
//
// Every .NET test framework arrives as a NuGet package, so `dotnet test` cannot
// run without a restore — a network round trip (or a pre-warmed cache) before a
// single assertion executes. The rest of this monorepo's bindings test with
// whatever is already on the box, so this project does too: `dotnet run` on a
// self-contained runner, no packages, no restore, and the process exit code is
// the result.

using System;
using System.Collections.Generic;
using System.Linq;

using PhoneNumbers;

internal static class Conformance
{
    private static int _passed;
    private static readonly List<string> Failures = new();

    private static void Check(string name, Action body)
    {
        try
        {
            body();
            _passed++;
            Console.WriteLine($"  PASS {name}");
        }
        catch (Exception ex)
        {
            Failures.Add($"{name}: {ex.Message}");
            Console.WriteLine($"  FAIL {name}");
            Console.WriteLine($"       {ex.Message}");
        }
    }

    private static void Eq(string got, string want, string what = "value")
    {
        if (!string.Equals(got, want, StringComparison.Ordinal))
            throw new Exception($"{what}:\n         got  \"{got}\"\n         want \"{want}\"");
    }

    private static void Eq(int got, int want, string what = "value")
    {
        if (got != want) throw new Exception($"{what}: got {got}, want {want}");
    }

    private static void IsTrue(bool got, string what)
    {
        if (!got) throw new Exception($"{what}: expected true");
    }

    private static void IsFalse(bool got, string what)
    {
        if (got) throw new Exception($"{what}: expected false");
    }

    private static void EqList(IReadOnlyList<string> got, IReadOnlyList<string> want, string what = "list")
    {
        if (got.Count != want.Count)
            throw new Exception($"{what}: length got {got.Count}, want {want.Count}");
        for (int i = 0; i < want.Count; i++)
            if (!string.Equals(got[i], want[i], StringComparison.Ordinal))
                throw new Exception($"{what}[{i}]:\n         got  \"{got[i]}\"\n         want \"{want[i]}\"");
    }

    public static int Main()
    {
        Console.WriteLine("=== phonenumber_ae .NET binding conformance (v7) ===");
        Console.WriteLine($"engine: {PhoneNumber.NativeLibraryPath ?? "(default probing)"} " +
                          $"(ABI v{PhoneNumber.AbiVersion})");

        // ---- the forty-five (docs/conformance.md) ----

        Check("01 country_code US == 1", () => Eq(PhoneNumber.CountryCode("US"), "1"));

        Check("02 country_code GB == 44", () => Eq(PhoneNumber.CountryCode("GB"), "44"));

        Check("03 country_code ZZ == empty", () => Eq(PhoneNumber.CountryCode("ZZ"), ""));

        Check("04 example_number US", () => Eq(PhoneNumber.ExampleNumber("US"), "2015550123"));

        Check("05 possible_lengths US", () => Eq(PhoneNumber.PossibleLengths("US"), "10"));

        Check("06 region_code_for_country_code 44 == GB", () =>
            Eq(PhoneNumber.RegionCodeForCountryCode("44"), "GB"));

        Check("07 is_nanpa US", () => IsTrue(PhoneNumber.IsNanpaCountry("US"), "is_nanpa"));

        Check("08 region enumeration", () =>
        {
            var regs = PhoneNumber.Regions();
            IsTrue(regs.Count >= 200, "region count >= 200");
            Eq(regs[0].Length, 2, "first region id is 2 letters");
        });

        Check("09 cc_region_at 1[0] == US", () =>
            Eq(PhoneNumber.RegionsForCountryCode("1")[0], "US"));

        // 10-14: parse "+1 201 555 0123 ext 42" in US
        var parsed = PhoneNumber.Parse("+1 201 555 0123 ext 42", "US");

        Check("10 parse -> national_number", () => Eq(parsed.NationalNumber, "2015550123"));

        Check("11 parse -> extension", () => Eq(parsed.Extension, "42"));

        Check("12 parse -> country_code", () => Eq(parsed.CountryCode, "1"));

        Check("13 parse -> source FROM_NUMBER_WITH_PLUS", () =>
            Eq((int)parsed.Source, (int)CountryCodeSource.FromNumberWithPlus, "source"));

        Check("14 parse -> region_code_for_number US", () => Eq(parsed.RegionCode, "US"));

        Check("15 parse trunk prefix GB", () =>
            Eq(PhoneNumber.Parse("01212345678", "GB").NationalNumber, "1212345678"));

        Check("16 is_possible yes", () =>
            IsTrue(PhoneNumber.IsPossibleNumber("US", "2015550123"), "is_possible"));

        Check("17 reason TOO_SHORT", () =>
            Eq((int)PhoneNumber.IsPossibleNumberWithReason("US", "201555"),
               (int)ValidationResult.TooShort, "reason"));

        Check("18 is_valid yes", () =>
            IsTrue(PhoneNumber.IsValidNumber("US", "2015550123"), "is_valid"));

        Check("19 is_valid wrong shape", () =>
            IsFalse(PhoneNumber.IsValidNumber("US", "1015550123"), "is_valid"));

        Check("20 is_valid with +cc", () =>
            IsTrue(PhoneNumber.IsValidNumber("US", "+12015550123"), "is_valid"));

        Check("21 number_type fixed-line-or-mobile / fixed line", () =>
        {
            // An `int`/`long` width mismatch shows up here as a garbage type.
            // US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns.
            Eq((int)PhoneNumber.NumberType("US", "2015550123"),
               (int)PhoneNumberType.FixedLineOrMobile, "number_type US");
            Eq((int)PhoneNumber.NumberType("GB", "2070313000"),
               (int)PhoneNumberType.FixedLine, "number_type GB");
        });

        Check("22 format NATIONAL", () =>
            Eq(PhoneNumber.Format("US", "2015550123", FormatStyle.National), "(201) 555-0123"));

        Check("23 format E164", () =>
            Eq(PhoneNumber.Format("US", "2015550123", FormatStyle.E164), "+12015550123"));

        Check("24 format INTERNATIONAL", () =>
            Eq(PhoneNumber.Format("US", "2015550123", FormatStyle.International), "+1 201-555-0123"));

        Check("25 format RFC3966", () =>
            Eq(PhoneNumber.Format("US", "2015550123", FormatStyle.Rfc3966), "tel:+1-201-555-0123"));

        Check("26 match EXACT", () =>
            Eq((int)PhoneNumber.IsNumberMatch("+12015550123", "+1 201 555 0123"),
               (int)MatchType.Exact, "match"));

        Check("27 match NO_MATCH", () =>
            Eq((int)PhoneNumber.IsNumberMatch("+12015550123", "+12025550123"),
               (int)MatchType.NoMatch, "match"));

        Check("28 normalize_digits_only", () =>
            Eq(PhoneNumber.NormalizeDigitsOnly("+1 (201) 555.0123"), "12015550123"));

        Check("29 convert_alpha_characters", () =>
            Eq(PhoneNumber.ConvertAlphaCharacters("1-800-FLOWERS"), "1-800-3569377"));

        Check("30 truncate_too_long", () =>
            Eq(PhoneNumber.TruncateTooLong("US", "20155501239999"), "2015550123"));

        Check("31 AsYouType", () =>
        {
            var ayt = new AsYouTypeFormatter("US");
            string outp = "";
            foreach (var c in "2015550123") outp = ayt.InputDigit(c);
            Eq(outp, "(201) 555-0123", "as_you_type");
        });

        Check("32 matcher count", () =>
        {
            var matches = PhoneNumber.FindNumbers("call 201-555-0123 or +1 202 555 0199", "US");
            Eq(matches.Count, 2, "match count");
        });

        Check("33 matcher raw", () =>
        {
            var matches = PhoneNumber.FindNumbers("call 201-555-0123 now", "US");
            IsTrue(matches.Count >= 1, "at least one match");
            Eq(matches[0].Raw, "201-555-0123", "raw");
        });

        Check("34 abi_version == 7", () => Eq(PhoneNumber.AbiVersion, 7, "abi_version"));

        Check("35 short is_emergency US 911", () =>
            IsTrue(PhoneNumber.IsEmergencyNumber("US", "911"), "is_emergency_number"));

        Check("36 short not-emergency US 999", () =>
            IsFalse(PhoneNumber.IsEmergencyNumber("US", "999"), "is_emergency_number"));

        Check("37 short is_emergency GB 999", () =>
            IsTrue(PhoneNumber.IsEmergencyNumber("GB", "999"), "is_emergency_number"));

        Check("38 short is_valid US 911", () =>
            IsTrue(PhoneNumber.ShortIsValid("US", "911"), "short_is_valid"));

        Check("39 short expected_cost US 911 toll-free", () =>
            Eq((int)PhoneNumber.ShortExpectedCost("US", "911"),
               (int)ShortNumberCost.TollFree, "short_expected_cost"));

        Check("40 short example_number US == 112", () =>
            Eq(PhoneNumber.ShortExampleNumber("US"), "112"));

        Check("41 time_zones_for_number US == America/New_York", () =>
            EqList(PhoneNumber.TimeZonesForNumber("US", "2015550123"),
                   new[] { "America/New_York" }, "time_zones US"));

        Check("42 time_zones_for_number GB == Europe/London", () =>
            EqList(PhoneNumber.TimeZonesForNumber("GB", "2070313000"),
                   new[] { "Europe/London" }, "time_zones GB"));

        Check("43 unknown_time_zone == Etc/Unknown", () =>
            Eq(PhoneNumber.UnknownTimeZone(), "Etc/Unknown"));

        Check("44 carrier_name_for_number GB 7106000000 == O2", () =>
            Eq(PhoneNumber.CarrierNameForNumber("GB", "7106000000"), "O2"));

        Check("45 geo_description_for_number US 6502530000 == Mountain View, CA", () =>
            Eq(PhoneNumber.GeoDescriptionForNumber("US", "6502530000"), "Mountain View, CA"));

        // ---- a few surface extras ----

        Check("format style aliases agree", () =>
        {
            Eq(PhoneNumber.FormatNational("US", "2015550123"), "(201) 555-0123");
            Eq(PhoneNumber.FormatInternational("US", "2015550123"), "+1 201-555-0123");
            Eq(PhoneNumber.FormatE164("US", "2015550123"), "+12015550123");
            Eq(PhoneNumber.FormatRfc3966("US", "2015550123"), "tel:+1-201-555-0123");
        });

        Check("parse reports no error on a good number", () =>
        {
            Eq(PhoneNumber.Parse("+1 201 555 0123", "US").Error, "");
        });

        Check("region_at out of range is empty", () =>
        {
            Eq(PhoneNumber.RegionAt(1000000), "", "out of range");
            Eq(PhoneNumber.RegionAt(-1), "", "negative index");
        });

        Check("SortedRegions is deterministic", () =>
        {
            var sorted = PhoneNumber.SortedRegions();
            Eq(sorted.Count, PhoneNumber.Regions().Count, "same count");
            IsTrue(string.CompareOrdinal(sorted[0], sorted[^1]) <= 0, "ordered");
        });

        Check("time_zone_count agrees with the list length", () =>
        {
            Eq(PhoneNumber.TimeZoneCount("US", "2015550123"), 1, "time_zone_count");
            Eq(PhoneNumber.TimeZonesForNumber("US", "2015550123").Count, 1, "list length");
        });

        Check("carrier_name_for_valid agrees for a valid number", () =>
            Eq(PhoneNumber.CarrierNameForValidNumber("GB", "7106000000"), "O2"));

        Check("geo_description_for_valid agrees for a valid number", () =>
            Eq(PhoneNumber.GeoDescriptionForValidNumber("US", "6502530000"), "Mountain View, CA"));

        Check("carrier/geo explicit lang arg agrees with the en default", () =>
        {
            // v7 added a trailing lang ISO code; passing "en" explicitly must
            // match the default (lang omitted -> "en").
            Eq(PhoneNumber.CarrierNameForNumber("GB", "7106000000", "en"), "O2");
            Eq(PhoneNumber.GeoDescriptionForNumber("US", "6502530000", "en"), "Mountain View, CA");
        });

        Check("many calls do not leak or crash", () =>
        {
            // A returned char* that was never freed would show up here as
            // steadily growing RSS; a double free would crash. Cheap insurance
            // over the TakeString contract, now exercising parse accessors too.
            for (int i = 0; i < 5000; i++)
            {
                _ = PhoneNumber.Format("US", "2015550123", FormatStyle.International);
                _ = PhoneNumber.Parse("+1 201 555 0123", "US").NationalNumber;
            }
            Eq(PhoneNumber.CountryCode("US"), "1");
        });

        Console.WriteLine($"=== {_passed} passed, {Failures.Count} failed ===");
        if (Failures.Count > 0)
        {
            Console.WriteLine("failures:");
            foreach (var f in Failures) Console.WriteLine($"  - {f}");
            return 1;
        }
        return 0;
    }
}
