// The 1:1 symbol table for the phonenumber C ABI (core/embed.ae) — v2.
//
// This file is the ONLY place in the .NET binding that knows about the C ABI.
// Everything above it (PhoneNumber.cs) is idiomatic C# over these symbols. No
// phone-number logic lives here or anywhere else in this assembly — the engine
// is core/phonenumber.ae, shared by every language binding.
//
// The ABI is scalar-only (`const char*` and `int`): every export is a pure
// value-in / value-out transform. There are no opaque handles — a parsed number
// and an AsYouType state are themselves caller-owned STRINGS you pass back to
// the accessor calls, then free like any other returned string. There are
// therefore no delegates, no UnmanagedFunctionPointer types and no keepalive
// list here — just a flat P/Invoke surface over a dlopen'd engine.
//
// ## Naming
//
// core/embed.ae names its exports `pn_embed_<name>`; building with
// `--emit=lib` mangles them to **`aether_pn_embed_<name>`**. That mangled name
// is what these DllImports bind.
//
// ## The one ownership rule
//
// Every char* this ABI returns is caller-owned and must be handed back to
// `aether_pn_embed_free_string`. Note the returns are declared `IntPtr`, *not*
// `string`: the default marshaller would copy the string and then free it with
// `Marshal.FreeCoTaskMem`, which is the wrong allocator and corrupts the heap.
// `Native.TakeString` does the right thing.

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace PhoneNumbers;

/// <summary>A phone-number format style (ABI constant — append only, never renumber).</summary>
public enum FormatStyle
{
    /// <summary>E.164 format, e.g. "+12015550123".</summary>
    E164 = 0,
    /// <summary>International format, e.g. "+1 201-555-0123".</summary>
    International = 1,
    /// <summary>National format, e.g. "(201) 555-0123".</summary>
    National = 2,
    /// <summary>RFC 3966 (tel: URI), e.g. "tel:+1-201-555-0123".</summary>
    Rfc3966 = 3,
}

/// <summary>The kind of number <see cref="Native.NumberType"/> reports.</summary>
public enum PhoneNumberType
{
    /// <summary>Unknown (the ABI's -1).</summary>
    Unknown = -1,
    /// <summary>A fixed-line number.</summary>
    FixedLine = 0,
    /// <summary>A mobile number.</summary>
    Mobile = 1,
    /// <summary>A toll-free number.</summary>
    TollFree = 2,
    /// <summary>A premium-rate number.</summary>
    PremiumRate = 3,
    /// <summary>A shared-cost number.</summary>
    SharedCost = 4,
    /// <summary>A VoIP number.</summary>
    Voip = 5,
    /// <summary>A personal number.</summary>
    PersonalNumber = 6,
    /// <summary>A pager number.</summary>
    Pager = 7,
    /// <summary>A UAN (universal access number).</summary>
    Uan = 8,
    /// <summary>A voicemail-access number.</summary>
    Voicemail = 9,
    /// <summary>A number whose fixed-line and mobile patterns are indistinguishable.</summary>
    FixedLineOrMobile = 10,
}

/// <summary>
/// The reason a number is or is not possible
/// (<see cref="Native.IsPossibleNumberWithReason"/>).
/// </summary>
public enum ValidationResult
{
    /// <summary>The number length matches a valid pattern.</summary>
    IsPossible = 0,
    /// <summary>The number length matches only a local-only pattern.</summary>
    IsPossibleLocalOnly = 4,
    /// <summary>The country calling code was not recognised.</summary>
    InvalidCountryCode = 1,
    /// <summary>The number is shorter than any valid length.</summary>
    TooShort = 2,
    /// <summary>The number length is not in the valid set (but between min and max).</summary>
    InvalidLength = 5,
    /// <summary>The number is longer than any valid length.</summary>
    TooLong = 3,
}

/// <summary>How two numbers compare (<see cref="Native.IsNumberMatch"/>).</summary>
public enum MatchType
{
    /// <summary>At least one argument was not a number.</summary>
    NotANumber = 0,
    /// <summary>The numbers do not match.</summary>
    NoMatch = 1,
    /// <summary>One national number is a suffix of the other (short NSN).</summary>
    ShortNsn = 2,
    /// <summary>The national significant numbers match.</summary>
    Nsn = 3,
    /// <summary>The numbers match exactly.</summary>
    Exact = 4,
}

/// <summary>How the country code was derived when parsing (<see cref="ParsedNumber.Source"/>).</summary>
public enum CountryCodeSource
{
    /// <summary>From a leading "+".</summary>
    FromNumberWithPlus = 1,
    /// <summary>From an international dialing prefix (IDD).</summary>
    FromNumberWithIdd = 5,
    /// <summary>From a country-code-looking prefix without a "+".</summary>
    FromNumberWithoutPlus = 10,
    /// <summary>From the default region passed to parse.</summary>
    FromDefaultCountry = 20,
}

/// <summary>How strict the matcher is when scanning free text.</summary>
public enum Leniency
{
    /// <summary>Accept anything that could possibly be a number.</summary>
    Possible = 0,
    /// <summary>Accept only valid numbers.</summary>
    Valid = 1,
}

/// <summary>
/// The raw P/Invoke surface. Public so an advanced caller can reach it, but
/// <see cref="PhoneNumber"/> is the supported API.
/// </summary>
public static class Native
{
    /// <summary>
    /// The name .NET resolves. A bare name (no "lib" prefix, no extension)
    /// lets the default probing find libphonenumber_ae.so / .dylib /
    /// phonenumber_ae.dll per platform; <see cref="EnsureResolver"/> installs
    /// the explicit-path and $LIBPHONENUMBER_AE_LIB rules on top.
    /// </summary>
    public const string Lib = "phonenumber_ae";

    // ---- version / introspection ----

    [DllImport(Lib, EntryPoint = "aether_pn_embed_abi_version", CallingConvention = CallingConvention.Cdecl)]
    public static extern int AbiVersion();

    [DllImport(Lib, EntryPoint = "aether_pn_embed_free_string", CallingConvention = CallingConvention.Cdecl)]
    public static extern void FreeString(IntPtr str);

    // ---- the surface ----
    //
    // String arguments are byte[] (UTF-8 the binding encodes itself) rather
    // than `string`: .NET's default marshalling of `string` on a DllImport is
    // ANSI on some platforms, which mangles non-ASCII input. The returns are
    // IntPtr — see the ownership note at the top of this file. Every integer is
    // C `int`.

    // -- metadata --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_country_code", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr CountryCode(byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_example_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr ExampleNumber(byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_example_number_for_type", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr ExampleNumberForType(byte[] region, int type);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_invalid_example_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr InvalidExampleNumber(byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_possible_lengths", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr PossibleLengths(byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_region_code_for_country_code", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr RegionCodeForCountryCode(byte[] cc);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_nanpa_country", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsNanpaCountry(byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_ndd_prefix_for_region", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr NddPrefixForRegion(byte[] region, int stripNonDigits);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_region_count", CallingConvention = CallingConvention.Cdecl)]
    public static extern int RegionCount();

    [DllImport(Lib, EntryPoint = "aether_pn_embed_region_at", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr RegionAt(int index);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_cc_region_count", CallingConvention = CallingConvention.Cdecl)]
    public static extern int CcRegionCount(byte[] cc);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_cc_region_at", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr CcRegionAt(byte[] cc, int index);

    // -- parse + parsed-number accessors --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_parse", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr Parse(byte[] input, byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_national_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr NationalNumber(byte[] region, byte[] input);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_region", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr PnRegion(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_country_code", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr PnCountryCode(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_national_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr PnNationalNumber(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_extension", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr PnExtension(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_italian_leading_zero", CallingConvention = CallingConvention.Cdecl)]
    public static extern int PnItalianLeadingZero(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_source", CallingConvention = CallingConvention.Cdecl)]
    public static extern int PnSource(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_pn_error", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr PnError(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_region_code_for_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr RegionCodeForNumber(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_national_significant_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr NationalSignificantNumber(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_length_of_ndc", CallingConvention = CallingConvention.Cdecl)]
    public static extern int LengthOfNdc(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_length_of_area_code", CallingConvention = CallingConvention.Cdecl)]
    public static extern int LengthOfAreaCode(byte[] pn);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_geographical", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsGeographical(byte[] pn);

    // -- validation --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_possible_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsPossibleNumber(byte[] region, byte[] input);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_possible_number_with_reason", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsPossibleNumberWithReason(byte[] region, byte[] input);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_valid_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsValidNumber(byte[] region, byte[] input);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_valid_number_for_region", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsValidNumberForRegion(byte[] input, byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_number_type", CallingConvention = CallingConvention.Cdecl)]
    public static extern int NumberType(byte[] region, byte[] input);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_can_be_internationally_dialled", CallingConvention = CallingConvention.Cdecl)]
    public static extern int CanBeInternationallyDialled(byte[] region, byte[] input);

    // -- formatting --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_format", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr Format(byte[] region, byte[] input, int fmt);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_format_out_of_country", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr FormatOutOfCountry(byte[] region, byte[] input, byte[] callingFrom);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_format_in_original", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr FormatInOriginal(byte[] pn, byte[] callingFrom);

    // -- relations / helpers --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_number_match", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsNumberMatch(byte[] a, byte[] b);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_truncate_too_long", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr TruncateTooLong(byte[] region, byte[] input);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_normalize_digits_only", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr NormalizeDigitsOnly(byte[] s);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_convert_alpha_characters", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr ConvertAlphaCharacters(byte[] s);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_is_alpha_number", CallingConvention = CallingConvention.Cdecl)]
    public static extern int IsAlphaNumber(byte[] s);

    // -- AsYouTypeFormatter (state threaded as a caller-owned string) --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_ayt_new", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr AytNew(byte[] region);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_ayt_input", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr AytInput(byte[] state, byte[] ch);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_ayt_result", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr AytResult(byte[] state);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_ayt_clear", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr AytClear(byte[] state);

    // -- PhoneNumberMatcher / findNumbers --

    [DllImport(Lib, EntryPoint = "aether_pn_embed_matcher_count", CallingConvention = CallingConvention.Cdecl)]
    public static extern int MatcherCount(byte[] text, byte[] region, int leniency);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_matcher_start", CallingConvention = CallingConvention.Cdecl)]
    public static extern int MatcherStart(byte[] text, byte[] region, int leniency, int idx);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_matcher_end", CallingConvention = CallingConvention.Cdecl)]
    public static extern int MatcherEnd(byte[] text, byte[] region, int leniency, int idx);

    [DllImport(Lib, EntryPoint = "aether_pn_embed_matcher_raw", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr MatcherRaw(byte[] text, byte[] region, int leniency, int idx);

    // ---- string marshalling ----

    /// <summary>NUL-terminated UTF-8 for a string argument.</summary>
    public static byte[] Encode(string? value)
    {
        value ??= string.Empty;
        int n = Encoding.UTF8.GetByteCount(value);
        var buf = new byte[n + 1];
        Encoding.UTF8.GetBytes(value, 0, value.Length, buf, 0);
        buf[n] = 0;
        return buf;
    }

    /// <summary>
    /// Copy an ABI-returned string out and free it through the ABI.
    ///
    /// Every char* the engine returns is caller-owned; leaking it is the single
    /// easiest mistake to make in any of these bindings. Every string result in
    /// this assembly goes through here.
    /// </summary>
    public static string TakeString(IntPtr ptr)
    {
        if (ptr == IntPtr.Zero) return string.Empty;
        try
        {
            return Marshal.PtrToStringUTF8(ptr) ?? string.Empty;
        }
        finally
        {
            FreeString(ptr);
        }
    }

    // ---- library resolution ----

    private static readonly object ResolverLock = new();
    private static bool _resolverInstalled;
    private static string? _explicitPath;

    /// <summary>The path the engine was actually loaded from, once known.</summary>
    public static string? ResolvedPath { get; private set; }

    /// <summary>
    /// Install the DllImport resolver, in resolution order:
    /// <list type="number">
    ///   <item>an explicit path passed here</item>
    ///   <item>$LIBPHONENUMBER_AE_LIB (what the in-tree .tests.ae leaf sets)</item>
    ///   <item>native/ next to the assembly, then ../core/native/</item>
    ///   <item>the OS loader's own search path (the default probing)</item>
    /// </list>
    /// </summary>
    public static void EnsureResolver(string? explicitPath = null)
    {
        lock (ResolverLock)
        {
            if (explicitPath is { Length: > 0 }) _explicitPath = explicitPath;
            if (_resolverInstalled) return;
            _resolverInstalled = true;

            NativeLibrary.SetDllImportResolver(
                typeof(Native).Assembly,
                (name, assembly, searchPath) =>
                {
                    if (name != Lib) return IntPtr.Zero;
                    foreach (var candidate in Candidates())
                    {
                        if (NativeLibrary.TryLoad(candidate, out var handle))
                        {
                            ResolvedPath = candidate;
                            return handle;
                        }
                    }
                    return IntPtr.Zero;   // fall back to the default probing
                });
        }
    }

    private static string FileName =>
        RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "phonenumber_ae.dll"
        : RuntimeInformation.IsOSPlatform(OSPlatform.OSX) ? "libphonenumber_ae.dylib"
        : "libphonenumber_ae.so";

    private static IEnumerable<string> Candidates()
    {
        if (_explicitPath is { Length: > 0 })
        {
            yield return _explicitPath;
            yield break;
        }

        var env = Environment.GetEnvironmentVariable("LIBPHONENUMBER_AE_LIB");
        if (!string.IsNullOrEmpty(env)) yield return env;

        var name = FileName;
        var dir = Path.GetDirectoryName(typeof(Native).Assembly.Location);
        if (!string.IsNullOrEmpty(dir))
        {
            yield return Path.Combine(dir, "native", name);
            yield return Path.Combine(dir, name);
        }

        var cwd = Directory.GetCurrentDirectory();
        yield return Path.Combine(cwd, "native", name);
        yield return Path.Combine(cwd, "..", "core", "native", name);
        yield return Path.Combine(cwd, "..", "..", "core", "native", name);
    }
}
