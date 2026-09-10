// The idiomatic C# surface over the phonenumber engine (ABI v3).
//
// Carries no phone-number logic — every member here marshals to an
// aether_pn_embed_* call in Native.cs. The stateless calls hang off the static
// PhoneNumber class; the two stateful shapes the ABI grows — a parsed
// number and an AsYouType formatter — are wrapped as small objects
// (ParsedNumber, AsYouTypeFormatter) whose state is the caller-owned string the
// ABI handed back. Nothing here allocates unmanaged memory beyond the
// caller-owned result strings TakeString discharges.

using System;
using System.Collections.Generic;

namespace PhoneNumbers;

/// <summary>
/// Validate, parse and format international phone numbers.
/// </summary>
/// <remarks>
/// <code>
/// var num = PhoneNumber.Parse("+1 650 253 0000", "US");
/// num.NationalNumber;                                  // "6502530000"
/// PhoneNumber.IsValidNumber("US", "+1 201 555 0123");  // true
/// PhoneNumber.Format("US", "2015550123", FormatStyle.International); // "+1 201-555-0123"
///
/// var ayt = new AsYouTypeFormatter("US");
/// string shown = "";
/// foreach (var c in "6502530000") shown = ayt.InputDigit(c); // "(650) 253-0000"
///
/// PhoneNumber.FindNumbers("call 201-555-0123 today", "US");
/// </code>
/// A thin binding over one shared native engine (pure Aether, compiled from
/// Google libphonenumber's own metadata). Cross-language behaviour is identical
/// by construction, not by test.
/// </remarks>
public static class PhoneNumber
{
    private static void Init() => Native.EnsureResolver();

    /// <summary>Where the engine was loaded from, once known.</summary>
    public static string? NativeLibraryPath => Native.ResolvedPath;

    /// <summary>The engine's ABI revision.</summary>
    public static int AbiVersion
    {
        get
        {
            Init();
            return Native.AbiVersion();
        }
    }

    /// <summary>
    /// Override the engine path (before first use). Otherwise:
    /// $LIBPHONENUMBER_AE_LIB, then native/ next to the assembly, then
    /// ../core/native/, then the OS loader.
    /// </summary>
    public static void UseNativeLibrary(string path) => Native.EnsureResolver(path);

    // ---- metadata ----

    /// <summary>The country calling code for a region ("1", "44", …), or "" if unknown.</summary>
    public static string CountryCode(string region)
    {
        Init();
        return Native.TakeString(Native.CountryCode(Native.Encode(region)));
    }

    /// <summary>An example national number for the region, or "".</summary>
    public static string ExampleNumber(string region)
    {
        Init();
        return Native.TakeString(Native.ExampleNumber(Native.Encode(region)));
    }

    /// <summary>An example number of a given type for the region, or "".</summary>
    public static string ExampleNumberForType(string region, PhoneNumberType type)
    {
        Init();
        return Native.TakeString(Native.ExampleNumberForType(Native.Encode(region), (int)type));
    }

    /// <summary>An example number that is possible but not valid for the region, or "".</summary>
    public static string InvalidExampleNumber(string region)
    {
        Init();
        return Native.TakeString(Native.InvalidExampleNumber(Native.Encode(region)));
    }

    /// <summary>The possible-lengths spec for the region (e.g. "9,10"), or "".</summary>
    public static string PossibleLengths(string region)
    {
        Init();
        return Native.TakeString(Native.PossibleLengths(Native.Encode(region)));
    }

    /// <summary>The main region for a country calling code ("44" → "GB"), or "".</summary>
    public static string RegionCodeForCountryCode(string cc)
    {
        Init();
        return Native.TakeString(Native.RegionCodeForCountryCode(Native.Encode(cc)));
    }

    /// <summary>The main region for a country calling code (int overload).</summary>
    public static string RegionCodeForCountryCode(int cc) =>
        RegionCodeForCountryCode(cc.ToString(System.Globalization.CultureInfo.InvariantCulture));

    /// <summary>True if the region is part of the North American Numbering Plan.</summary>
    public static bool IsNanpaCountry(string region)
    {
        Init();
        return Native.IsNanpaCountry(Native.Encode(region)) != 0;
    }

    /// <summary>The national-dialling (trunk) prefix for the region, or "".</summary>
    public static string NddPrefixForRegion(string region, bool stripNonDigits = false)
    {
        Init();
        return Native.TakeString(Native.NddPrefixForRegion(Native.Encode(region), stripNonDigits ? 1 : 0));
    }

    /// <summary>How many region ids the metadata carries.</summary>
    public static int RegionCount
    {
        get
        {
            Init();
            return Native.RegionCount();
        }
    }

    /// <summary>The region id at <paramref name="index"/> (0-based), or "" when out of range.</summary>
    public static string RegionAt(int index)
    {
        Init();
        return Native.TakeString(Native.RegionAt(index));
    }

    /// <summary>Every region id the metadata carries, in the engine's own order.</summary>
    public static IReadOnlyList<string> Regions()
    {
        Init();
        int n = Native.RegionCount();
        var list = new List<string>(n);
        for (int i = 0; i < n; i++)
            list.Add(Native.TakeString(Native.RegionAt(i)));
        return list;
    }

    /// <summary>The regions, sorted — the deterministic enumeration.</summary>
    public static List<string> SortedRegions()
    {
        var list = new List<string>(Regions());
        list.Sort(StringComparer.Ordinal);
        return list;
    }

    /// <summary>The regions that share a country calling code ("1" → US, CA, …).</summary>
    public static IReadOnlyList<string> RegionsForCountryCode(string cc)
    {
        Init();
        var bytes = Native.Encode(cc);
        int n = Native.CcRegionCount(bytes);
        var list = new List<string>(n);
        for (int i = 0; i < n; i++)
            list.Add(Native.TakeString(Native.CcRegionAt(bytes, i)));
        return list;
    }

    /// <summary>The regions that share a country calling code (int overload).</summary>
    public static IReadOnlyList<string> RegionsForCountryCode(int cc) =>
        RegionsForCountryCode(cc.ToString(System.Globalization.CultureInfo.InvariantCulture));

    // ---- parse ----

    /// <summary>
    /// Parse a raw human-typed number for a default region into a
    /// <see cref="PhoneNumbers.ParsedNumber"/> whose fields are read on demand.
    /// </summary>
    public static ParsedNumber Parse(string input, string region)
    {
        Init();
        return new ParsedNumber(Native.TakeString(Native.Parse(Native.Encode(input), Native.Encode(region))));
    }

    /// <summary>The national number extracted from raw input (cc + punctuation stripped).</summary>
    public static string NationalNumber(string region, string input)
    {
        Init();
        return Native.TakeString(Native.NationalNumber(Native.Encode(region), Native.Encode(input)));
    }

    // ---- validation ----

    /// <summary>True if the national number is a length the region allows.</summary>
    public static bool IsPossibleNumber(string region, string input)
    {
        Init();
        return Native.IsPossibleNumber(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>Why a number is or is not possible, as a <see cref="ValidationResult"/>.</summary>
    public static ValidationResult IsPossibleNumberWithReason(string region, string input)
    {
        Init();
        return (ValidationResult)Native.IsPossibleNumberWithReason(Native.Encode(region), Native.Encode(input));
    }

    /// <summary>True if the number matches the region's national-number patterns.</summary>
    public static bool IsValidNumber(string region, string input)
    {
        Init();
        return Native.IsValidNumber(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>True if the number is valid for the given region specifically.</summary>
    public static bool IsValidNumberForRegion(string input, string region)
    {
        Init();
        return Native.IsValidNumberForRegion(Native.Encode(input), Native.Encode(region)) != 0;
    }

    /// <summary>The kind of number (<see cref="PhoneNumberType.Unknown"/> for unknown).</summary>
    public static PhoneNumberType NumberType(string region, string input)
    {
        Init();
        return (PhoneNumberType)Native.NumberType(Native.Encode(region), Native.Encode(input));
    }

    /// <summary>The raw ABI number-type int (-1 for unknown).</summary>
    public static int NumberTypeInt(string region, string input)
    {
        Init();
        return Native.NumberType(Native.Encode(region), Native.Encode(input));
    }

    /// <summary>True if the number can be dialled from outside its region.</summary>
    public static bool CanBeInternationallyDialled(string region, string input)
    {
        Init();
        return Native.CanBeInternationallyDialled(Native.Encode(region), Native.Encode(input)) != 0;
    }

    // ---- formatting ----

    /// <summary>Format the number in the given style.</summary>
    public static string Format(string region, string input, FormatStyle style = FormatStyle.National)
    {
        Init();
        return Native.TakeString(Native.Format(Native.Encode(region), Native.Encode(input), (int)style));
    }

    /// <summary>Format in national style, e.g. "(201) 555-0123".</summary>
    public static string FormatNational(string region, string input) =>
        Format(region, input, FormatStyle.National);

    /// <summary>Format in international style, e.g. "+1 201-555-0123".</summary>
    public static string FormatInternational(string region, string input) =>
        Format(region, input, FormatStyle.International);

    /// <summary>Format in E.164 style, e.g. "+12015550123".</summary>
    public static string FormatE164(string region, string input) =>
        Format(region, input, FormatStyle.E164);

    /// <summary>Format as an RFC 3966 tel: URI, e.g. "tel:+1-201-555-0123".</summary>
    public static string FormatRfc3966(string region, string input) =>
        Format(region, input, FormatStyle.Rfc3966);

    /// <summary>Format the number as dialled from <paramref name="callingFrom"/>.</summary>
    public static string FormatOutOfCountry(string region, string input, string callingFrom)
    {
        Init();
        return Native.TakeString(Native.FormatOutOfCountry(
            Native.Encode(region), Native.Encode(input), Native.Encode(callingFrom)));
    }

    /// <summary>Format a parsed number preserving its original raw shape, dialled from <paramref name="callingFrom"/>.</summary>
    public static string FormatInOriginal(ParsedNumber parsed, string callingFrom)
    {
        Init();
        return Native.TakeString(Native.FormatInOriginal(Native.Encode(parsed.Handle), Native.Encode(callingFrom)));
    }

    // ---- relations / helpers ----

    /// <summary>How two numbers compare, as a <see cref="MatchType"/>.</summary>
    public static MatchType IsNumberMatch(string a, string b)
    {
        Init();
        return (MatchType)Native.IsNumberMatch(Native.Encode(a), Native.Encode(b));
    }

    /// <summary>Trim a too-long number down to a valid length, or "" if it cannot be.</summary>
    public static string TruncateTooLong(string region, string input)
    {
        Init();
        return Native.TakeString(Native.TruncateTooLong(Native.Encode(region), Native.Encode(input)));
    }

    /// <summary>Strip everything but the digits (and convert wide/Arabic digits).</summary>
    public static string NormalizeDigitsOnly(string s)
    {
        Init();
        return Native.TakeString(Native.NormalizeDigitsOnly(Native.Encode(s)));
    }

    /// <summary>Convert vanity letters to their dial-pad digits (keeping other chars).</summary>
    public static string ConvertAlphaCharacters(string s)
    {
        Init();
        return Native.TakeString(Native.ConvertAlphaCharacters(Native.Encode(s)));
    }

    /// <summary>True if the string contains vanity letters.</summary>
    public static bool IsAlphaNumber(string s)
    {
        Init();
        return Native.IsAlphaNumber(Native.Encode(s)) != 0;
    }

    // ---- find numbers ----

    /// <summary>Find phone numbers in free text.</summary>
    public static IReadOnlyList<PhoneNumberMatch> FindNumbers(string text, string region, Leniency leniency = Leniency.Valid)
    {
        Init();
        var t = Native.Encode(text);
        var r = Native.Encode(region);
        int ln = (int)leniency;
        int n = Native.MatcherCount(t, r, ln);
        var list = new List<PhoneNumberMatch>(n);
        for (int i = 0; i < n; i++)
        {
            int start = Native.MatcherStart(t, r, ln, i);
            int end = Native.MatcherEnd(t, r, ln, i);
            string raw = Native.TakeString(Native.MatcherRaw(t, r, ln, i));
            list.Add(new PhoneNumberMatch(start, end, raw));
        }
        return list;
    }

    // ---- short numbers (ShortNumberInfo) ----
    //
    // Short numbers are dialled as-is — no country code, no national prefix —
    // so the input is the raw short number plus a region.

    /// <summary>True if <paramref name="input"/> is a possible short number for the region.</summary>
    public static bool ShortIsPossible(string region, string input)
    {
        Init();
        return Native.ShortIsPossible(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>True if <paramref name="input"/> matches a short-number pattern for the region.</summary>
    public static bool ShortIsValid(string region, string input)
    {
        Init();
        return Native.ShortIsValid(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>True if <paramref name="input"/> is an emergency number for the region (e.g. US "911").</summary>
    public static bool IsEmergencyNumber(string region, string input)
    {
        Init();
        return Native.ShortIsEmergency(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>True if dialling <paramref name="input"/> connects to an emergency number for the region.</summary>
    public static bool ConnectsToEmergencyNumber(string region, string input)
    {
        Init();
        return Native.ShortConnectsToEmergency(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>True if the short number is specific to a single carrier.</summary>
    public static bool ShortIsCarrierSpecific(string region, string input)
    {
        Init();
        return Native.ShortIsCarrierSpecific(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>True if the short number is usable as an SMS service.</summary>
    public static bool ShortIsSmsService(string region, string input)
    {
        Init();
        return Native.ShortIsSmsService(Native.Encode(region), Native.Encode(input)) != 0;
    }

    /// <summary>The expected cost of dialling the short number, as a <see cref="PhoneNumbers.ShortNumberCost"/>.</summary>
    public static ShortNumberCost ShortExpectedCost(string region, string input)
    {
        Init();
        return (ShortNumberCost)Native.ShortExpectedCost(Native.Encode(region), Native.Encode(input));
    }

    /// <summary>An example short number for the region, or "".</summary>
    public static string ShortExampleNumber(string region)
    {
        Init();
        return Native.TakeString(Native.ShortExampleNumber(Native.Encode(region)));
    }
}

/// <summary>
/// A parsed phone number. Wraps the caller-owned parsed-number string the ABI
/// returns from <see cref="PhoneNumber.Parse"/>; its fields are read on demand.
/// </summary>
public sealed class ParsedNumber
{
    /// <summary>The opaque parsed-number string the ABI handed back.</summary>
    public string Handle { get; }

    internal ParsedNumber(string handle)
    {
        Handle = handle;
    }

    private byte[] Bytes => Native.Encode(Handle);

    /// <summary>The region the number was parsed for.</summary>
    public string Region => Native.TakeString(Native.PnRegion(Bytes));

    /// <summary>The country calling code ("1", "44", …).</summary>
    public string CountryCode => Native.TakeString(Native.PnCountryCode(Bytes));

    /// <summary>The national (significant) number.</summary>
    public string NationalNumber => Native.TakeString(Native.PnNationalNumber(Bytes));

    /// <summary>The extension, or "".</summary>
    public string Extension => Native.TakeString(Native.PnExtension(Bytes));

    /// <summary>True if the number has an Italian-style leading zero.</summary>
    public bool ItalianLeadingZero => Native.PnItalianLeadingZero(Bytes) != 0;

    /// <summary>How the country code was derived when parsing.</summary>
    public CountryCodeSource Source => (CountryCodeSource)Native.PnSource(Bytes);

    /// <summary>A non-empty parse error message, or "" on success.</summary>
    public string Error => Native.TakeString(Native.PnError(Bytes));

    /// <summary>The region code inferred for this number ("US", …), or "".</summary>
    public string RegionCode => Native.TakeString(Native.RegionCodeForNumber(Bytes));

    /// <summary>The national significant number.</summary>
    public string NationalSignificantNumber => Native.TakeString(Native.NationalSignificantNumber(Bytes));

    /// <summary>The length of the national destination code, or 0.</summary>
    public int LengthOfNdc => Native.LengthOfNdc(Bytes);

    /// <summary>The length of the area code, or 0.</summary>
    public int LengthOfAreaCode => Native.LengthOfAreaCode(Bytes);

    /// <summary>True if the number is geographically bound.</summary>
    public bool IsGeographical => Native.IsGeographical(Bytes) != 0;
}

/// <summary>
/// Formats a number as it is typed, digit by digit. The ABI threads the
/// formatter's state as a caller-owned string; this class holds the current
/// state and swaps it for the new one on every keystroke.
/// </summary>
public sealed class AsYouTypeFormatter
{
    private string _state;

    /// <summary>Start a new formatter for the given default region.</summary>
    public AsYouTypeFormatter(string region)
    {
        Native.EnsureResolver();
        _state = Native.TakeString(Native.AytNew(Native.Encode(region)));
    }

    /// <summary>Feed one character; return the formatted-so-far string.</summary>
    public string InputDigit(char ch)
    {
        _state = Native.TakeString(Native.AytInput(Native.Encode(_state), Native.Encode(ch.ToString())));
        return Result();
    }

    /// <summary>The formatted-so-far string.</summary>
    public string Result() => Native.TakeString(Native.AytResult(Native.Encode(_state)));

    /// <summary>Reset the formatter to empty.</summary>
    public void Clear() => _state = Native.TakeString(Native.AytClear(Native.Encode(_state)));
}

/// <summary>A phone number found in free text by <see cref="PhoneNumber.FindNumbers"/>.</summary>
public sealed class PhoneNumberMatch
{
    /// <summary>The start offset of the match in the text.</summary>
    public int Start { get; }

    /// <summary>The end offset (exclusive) of the match in the text.</summary>
    public int End { get; }

    /// <summary>The raw substring that matched.</summary>
    public string Raw { get; }

    internal PhoneNumberMatch(int start, int end, string raw)
    {
        Start = start;
        End = end;
        Raw = raw;
    }
}
