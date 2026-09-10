package org.libphonenumber.ae;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.MethodHandle;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

/**
 * The 1:1 symbol table for the phonenumber C ABI ({@code core/embed.ae}) —
 * <b>ABI v7, full {@code PhoneNumberUtil} parity plus {@code ShortNumberInfo},
 * the timezone mapper, the carrier mapper and the offline geocoder</b> — bound
 * with the Java 22+ Foreign Function &amp; Memory API (JEP 454).
 *
 * <p>This class is the ONLY place in the Java binding that knows about the C
 * ABI. Everything above it ({@link PhoneNumbers} and the value classes) is
 * idiomatic Java over these handles. No phone-number logic lives here or
 * anywhere else in this package — the engine is the pure-Aether
 * {@code core/phonenumber.ae}, shared by every language binding in this
 * monorepo.
 *
 * <h2>The one ownership rule</h2>
 * Every {@code char*} this ABI returns is <b>caller-owned</b> and must come
 * back through {@code free_string}. {@link #takeString} does exactly that;
 * leaking it is the single easiest mistake to make in any of these bindings.
 *
 * <p>There are <b>no opaque handles</b>: a parsed number and an AsYouType state
 * are themselves caller-owned <em>strings</em>. You get one back, pass it to
 * accessor calls, and free it like any other returned string. Every call is
 * independent — this ABI is a pure {@code (scalar…) -> answer} transform, and
 * every signature is {@code const char*}/{@code int} only.
 *
 * <h2>Running</h2>
 * FFM needs {@code --enable-native-access=ALL-UNNAMED} on the command line.
 * It does <b>not</b> need {@code --enable-preview}: FFM is final since JDK 22.
 */
public final class Native {

    // ---- format styles (ABI constants — append only, never renumber) ----
    // NB v2: E164 is 0 (it was 2 in v1). INTERNATIONAL=1, NATIONAL=2, RFC3966=3.
    public static final int FMT_E164 = 0;
    public static final int FMT_INTERNATIONAL = 1;
    public static final int FMT_NATIONAL = 2;
    public static final int FMT_RFC3966 = 3;

    // ---- number types (number_type result; -1 = unknown) ----
    public static final int TYPE_UNKNOWN = -1;
    public static final int TYPE_FIXED_LINE = 0;
    public static final int TYPE_MOBILE = 1;
    public static final int TYPE_TOLL_FREE = 2;
    public static final int TYPE_PREMIUM_RATE = 3;
    public static final int TYPE_SHARED_COST = 4;
    public static final int TYPE_VOIP = 5;
    public static final int TYPE_PERSONAL_NUMBER = 6;
    public static final int TYPE_PAGER = 7;
    public static final int TYPE_UAN = 8;
    public static final int TYPE_VOICEMAIL = 9;
    public static final int TYPE_FIXED_LINE_OR_MOBILE = 10;

    // ---- ValidationResult (is_possible_number_with_reason) ----
    public static final int VR_IS_POSSIBLE = 0;
    public static final int VR_IS_POSSIBLE_LOCAL_ONLY = 4;
    public static final int VR_INVALID_COUNTRY_CODE = 1;
    public static final int VR_TOO_SHORT = 2;
    public static final int VR_INVALID_LENGTH = 5;
    public static final int VR_TOO_LONG = 3;

    // ---- MatchType (is_number_match) ----
    public static final int MATCH_NOT_A_NUMBER = 0;
    public static final int MATCH_NO_MATCH = 1;
    public static final int MATCH_SHORT_NSN = 2;
    public static final int MATCH_NSN = 3;
    public static final int MATCH_EXACT = 4;

    // ---- CountryCodeSource (pn_source) ----
    public static final int SRC_FROM_NUMBER_WITH_PLUS = 1;
    public static final int SRC_FROM_NUMBER_WITH_IDD = 5;
    public static final int SRC_FROM_NUMBER_WITHOUT_PLUS = 10;
    public static final int SRC_FROM_DEFAULT_COUNTRY = 20;

    // ---- matcher leniency ----
    public static final int LENIENCY_POSSIBLE = 0;
    public static final int LENIENCY_VALID = 1;
    public static final int LENIENCY_STRICT_GROUPING = 2;
    public static final int LENIENCY_EXACT_GROUPING = 3;

    // ---- ShortNumberCost (short_expected_cost) ----
    public static final int COST_TOLL_FREE = 0;
    public static final int COST_STANDARD_RATE = 1;
    public static final int COST_PREMIUM_RATE = 2;
    public static final int COST_UNKNOWN = 3;

    private static final ValueLayout.OfInt I = ValueLayout.JAVA_INT;
    private static final java.lang.foreign.AddressLayout P = ValueLayout.ADDRESS;

    /** The platform's shared-library file name for the engine. */
    public static final String LIB_NAME = libName();

    private static String libName() {
        String os = System.getProperty("os.name", "").toLowerCase();
        if (os.contains("mac")) return "libphonenumber_ae.dylib";
        if (os.contains("win")) return "phonenumber_ae.dll";
        return "libphonenumber_ae.so";
    }

    public final Linker linker;
    private final SymbolLookup lookup;

    // ---- the ABI symbols, one MethodHandle each (66 total) ----

    // lifecycle / metadata
    public final MethodHandle abiVersion;
    public final MethodHandle freeString;
    public final MethodHandle countryCode;
    public final MethodHandle exampleNumber;
    public final MethodHandle exampleNumberForType;
    public final MethodHandle invalidExampleNumber;
    public final MethodHandle possibleLengths;
    public final MethodHandle regionCodeForCountryCode;
    public final MethodHandle isNanpaCountry;
    public final MethodHandle nddPrefixForRegion;
    public final MethodHandle regionCount;
    public final MethodHandle regionAt;
    public final MethodHandle ccRegionCount;
    public final MethodHandle ccRegionAt;

    // parse + parsed-number accessors
    public final MethodHandle parse;
    public final MethodHandle nationalNumber;
    public final MethodHandle pnRegion;
    public final MethodHandle pnCountryCode;
    public final MethodHandle pnNationalNumber;
    public final MethodHandle pnExtension;
    public final MethodHandle pnItalianLeadingZero;
    public final MethodHandle pnSource;
    public final MethodHandle pnError;
    public final MethodHandle regionCodeForNumber;
    public final MethodHandle nationalSignificantNumber;
    public final MethodHandle lengthOfNdc;
    public final MethodHandle lengthOfAreaCode;
    public final MethodHandle isGeographical;

    // validation
    public final MethodHandle isPossibleNumber;
    public final MethodHandle isPossibleNumberWithReason;
    public final MethodHandle isValidNumber;
    public final MethodHandle isValidNumberForRegion;
    public final MethodHandle numberType;
    public final MethodHandle canBeInternationallyDialled;

    // formatting
    public final MethodHandle format;
    public final MethodHandle formatOutOfCountry;
    public final MethodHandle formatInOriginal;

    // relations / helpers
    public final MethodHandle isNumberMatch;
    public final MethodHandle truncateTooLong;
    public final MethodHandle normalizeDigitsOnly;
    public final MethodHandle convertAlphaCharacters;
    public final MethodHandle isAlphaNumber;

    // AsYouTypeFormatter
    public final MethodHandle aytNew;
    public final MethodHandle aytInput;
    public final MethodHandle aytResult;
    public final MethodHandle aytClear;

    // matcher / findNumbers
    public final MethodHandle matcherCount;
    public final MethodHandle matcherStart;
    public final MethodHandle matcherEnd;
    public final MethodHandle matcherRaw;

    // ShortNumberInfo
    public final MethodHandle shortIsPossible;
    public final MethodHandle shortIsValid;
    public final MethodHandle shortIsEmergency;
    public final MethodHandle shortConnectsToEmergency;
    public final MethodHandle shortIsCarrierSpecific;
    public final MethodHandle shortIsSmsService;
    public final MethodHandle shortExpectedCost;
    public final MethodHandle shortExampleNumber;

    // PhoneNumberToTimeZonesMapper
    public final MethodHandle tzCount;
    public final MethodHandle tzAt;
    public final MethodHandle tzAll;
    public final MethodHandle tzUnknown;

    // PhoneNumberToCarrierMapper
    public final MethodHandle carrierName;
    public final MethodHandle carrierNameForValid;

    // PhoneNumberOfflineGeocoder
    public final MethodHandle geoDescription;
    public final MethodHandle geoDescriptionForValid;

    private static volatile Native cached;

    /**
     * Load the engine and bind every symbol, caching the result process-wide.
     *
     * <p>Resolution order, matching every other binding in the monorepo:
     * <ol>
     *   <li>{@code explicitPath}, when non-null</li>
     *   <li>{@code $LIBPHONENUMBER_AE_LIB}</li>
     *   <li>the {@code libphonenumber_ae.lib} system property</li>
     *   <li>{@code native/} beside the jar</li>
     *   <li>the OS loader's own search path</li>
     * </ol>
     */
    public static Native load(String explicitPath) {
        if (explicitPath == null) {
            Native c = cached;
            if (c != null) return c;
        }
        Native n = new Native(explicitPath);
        if (explicitPath == null) cached = n;
        return n;
    }

    private Native(String explicitPath) {
        this.linker = Linker.nativeLinker();
        this.lookup = openLibrary(explicitPath);

        // lifecycle / metadata
        abiVersion = downcall("aether_pn_embed_abi_version", FunctionDescriptor.of(I));
        freeString = downcall("aether_pn_embed_free_string", FunctionDescriptor.ofVoid(P));
        countryCode = downcall("aether_pn_embed_country_code", FunctionDescriptor.of(P, P));
        exampleNumber = downcall("aether_pn_embed_example_number", FunctionDescriptor.of(P, P));
        exampleNumberForType = downcall("aether_pn_embed_example_number_for_type",
                FunctionDescriptor.of(P, P, I));
        invalidExampleNumber = downcall("aether_pn_embed_invalid_example_number",
                FunctionDescriptor.of(P, P));
        possibleLengths = downcall("aether_pn_embed_possible_lengths", FunctionDescriptor.of(P, P));
        regionCodeForCountryCode = downcall("aether_pn_embed_region_code_for_country_code",
                FunctionDescriptor.of(P, P));
        isNanpaCountry = downcall("aether_pn_embed_is_nanpa_country", FunctionDescriptor.of(I, P));
        nddPrefixForRegion = downcall("aether_pn_embed_ndd_prefix_for_region",
                FunctionDescriptor.of(P, P, I));
        regionCount = downcall("aether_pn_embed_region_count", FunctionDescriptor.of(I));
        regionAt = downcall("aether_pn_embed_region_at", FunctionDescriptor.of(P, I));
        ccRegionCount = downcall("aether_pn_embed_cc_region_count", FunctionDescriptor.of(I, P));
        ccRegionAt = downcall("aether_pn_embed_cc_region_at", FunctionDescriptor.of(P, P, I));

        // parse + accessors
        parse = downcall("aether_pn_embed_parse", FunctionDescriptor.of(P, P, P));
        nationalNumber = downcall("aether_pn_embed_national_number", FunctionDescriptor.of(P, P, P));
        pnRegion = downcall("aether_pn_embed_pn_region", FunctionDescriptor.of(P, P));
        pnCountryCode = downcall("aether_pn_embed_pn_country_code", FunctionDescriptor.of(P, P));
        pnNationalNumber = downcall("aether_pn_embed_pn_national_number", FunctionDescriptor.of(P, P));
        pnExtension = downcall("aether_pn_embed_pn_extension", FunctionDescriptor.of(P, P));
        pnItalianLeadingZero = downcall("aether_pn_embed_pn_italian_leading_zero",
                FunctionDescriptor.of(I, P));
        pnSource = downcall("aether_pn_embed_pn_source", FunctionDescriptor.of(I, P));
        pnError = downcall("aether_pn_embed_pn_error", FunctionDescriptor.of(P, P));
        regionCodeForNumber = downcall("aether_pn_embed_region_code_for_number",
                FunctionDescriptor.of(P, P));
        nationalSignificantNumber = downcall("aether_pn_embed_national_significant_number",
                FunctionDescriptor.of(P, P));
        lengthOfNdc = downcall("aether_pn_embed_length_of_ndc", FunctionDescriptor.of(I, P));
        lengthOfAreaCode = downcall("aether_pn_embed_length_of_area_code",
                FunctionDescriptor.of(I, P));
        isGeographical = downcall("aether_pn_embed_is_geographical", FunctionDescriptor.of(I, P));

        // validation
        isPossibleNumber = downcall("aether_pn_embed_is_possible_number",
                FunctionDescriptor.of(I, P, P));
        isPossibleNumberWithReason = downcall("aether_pn_embed_is_possible_number_with_reason",
                FunctionDescriptor.of(I, P, P));
        isValidNumber = downcall("aether_pn_embed_is_valid_number",
                FunctionDescriptor.of(I, P, P));
        isValidNumberForRegion = downcall("aether_pn_embed_is_valid_number_for_region",
                FunctionDescriptor.of(I, P, P));
        numberType = downcall("aether_pn_embed_number_type", FunctionDescriptor.of(I, P, P));
        canBeInternationallyDialled = downcall("aether_pn_embed_can_be_internationally_dialled",
                FunctionDescriptor.of(I, P, P));

        // formatting
        format = downcall("aether_pn_embed_format", FunctionDescriptor.of(P, P, P, I));
        formatOutOfCountry = downcall("aether_pn_embed_format_out_of_country",
                FunctionDescriptor.of(P, P, P, P));
        formatInOriginal = downcall("aether_pn_embed_format_in_original",
                FunctionDescriptor.of(P, P, P));

        // relations / helpers
        isNumberMatch = downcall("aether_pn_embed_is_number_match", FunctionDescriptor.of(I, P, P));
        truncateTooLong = downcall("aether_pn_embed_truncate_too_long",
                FunctionDescriptor.of(P, P, P));
        normalizeDigitsOnly = downcall("aether_pn_embed_normalize_digits_only",
                FunctionDescriptor.of(P, P));
        convertAlphaCharacters = downcall("aether_pn_embed_convert_alpha_characters",
                FunctionDescriptor.of(P, P));
        isAlphaNumber = downcall("aether_pn_embed_is_alpha_number", FunctionDescriptor.of(I, P));

        // AsYouTypeFormatter
        aytNew = downcall("aether_pn_embed_ayt_new", FunctionDescriptor.of(P, P));
        aytInput = downcall("aether_pn_embed_ayt_input", FunctionDescriptor.of(P, P, P));
        aytResult = downcall("aether_pn_embed_ayt_result", FunctionDescriptor.of(P, P));
        aytClear = downcall("aether_pn_embed_ayt_clear", FunctionDescriptor.of(P, P));

        // matcher
        matcherCount = downcall("aether_pn_embed_matcher_count", FunctionDescriptor.of(I, P, P, I));
        matcherStart = downcall("aether_pn_embed_matcher_start",
                FunctionDescriptor.of(I, P, P, I, I));
        matcherEnd = downcall("aether_pn_embed_matcher_end", FunctionDescriptor.of(I, P, P, I, I));
        matcherRaw = downcall("aether_pn_embed_matcher_raw", FunctionDescriptor.of(P, P, P, I, I));

        // ShortNumberInfo
        shortIsPossible = downcall("aether_pn_embed_short_is_possible",
                FunctionDescriptor.of(I, P, P));
        shortIsValid = downcall("aether_pn_embed_short_is_valid",
                FunctionDescriptor.of(I, P, P));
        shortIsEmergency = downcall("aether_pn_embed_short_is_emergency",
                FunctionDescriptor.of(I, P, P));
        shortConnectsToEmergency = downcall("aether_pn_embed_short_connects_to_emergency",
                FunctionDescriptor.of(I, P, P));
        shortIsCarrierSpecific = downcall("aether_pn_embed_short_is_carrier_specific",
                FunctionDescriptor.of(I, P, P));
        shortIsSmsService = downcall("aether_pn_embed_short_is_sms_service",
                FunctionDescriptor.of(I, P, P));
        shortExpectedCost = downcall("aether_pn_embed_short_expected_cost",
                FunctionDescriptor.of(I, P, P));
        shortExampleNumber = downcall("aether_pn_embed_short_example_number",
                FunctionDescriptor.of(P, P));

        // PhoneNumberToTimeZonesMapper
        tzCount = downcall("aether_pn_embed_tz_count", FunctionDescriptor.of(I, P, P));
        tzAt = downcall("aether_pn_embed_tz_at", FunctionDescriptor.of(P, P, P, I));
        tzAll = downcall("aether_pn_embed_tz_all", FunctionDescriptor.of(P, P, P));
        tzUnknown = downcall("aether_pn_embed_tz_unknown", FunctionDescriptor.of(P));

        // PhoneNumberToCarrierMapper — (region, input, lang) -> char*
        carrierName = downcall("aether_pn_embed_carrier_name", FunctionDescriptor.of(P, P, P, P));
        carrierNameForValid = downcall("aether_pn_embed_carrier_name_for_valid",
                FunctionDescriptor.of(P, P, P, P));

        // PhoneNumberOfflineGeocoder — (region, input, lang) -> char*
        geoDescription = downcall("aether_pn_embed_geo_description",
                FunctionDescriptor.of(P, P, P, P));
        geoDescriptionForValid = downcall("aether_pn_embed_geo_description_for_valid",
                FunctionDescriptor.of(P, P, P, P));
    }

    private SymbolLookup openLibrary(String explicitPath) {
        List<String> candidates = new ArrayList<>();
        if (explicitPath != null) {
            candidates.add(explicitPath);
        } else {
            String env = System.getenv("LIBPHONENUMBER_AE_LIB");
            if (env != null && !env.isEmpty()) candidates.add(env);
            String prop = System.getProperty("libphonenumber_ae.lib");
            if (prop != null && !prop.isEmpty()) candidates.add(prop);
            candidates.add(Paths.get("native", LIB_NAME).toString());
            candidates.add(LIB_NAME);
        }

        RuntimeException last = null;
        for (String cand : candidates) {
            try {
                Path p = Paths.get(cand);
                // libraryLookup(String) goes through the OS loader; give it a
                // Path only when the file really is there, so a bare name
                // still falls through to the loader's search path.
                if (Files.exists(p)) {
                    return SymbolLookup.libraryLookup(p, Arena.global());
                }
                return SymbolLookup.libraryLookup(cand, Arena.global());
            } catch (RuntimeException e) {
                last = e;
            }
        }

        // Last resort: a fat jar bundles the engine at /native/<lib> as a
        // classpath resource. Panama's libraryLookup needs a real file, so
        // extract the resource to a temp file and open that. This is what makes
        // the self-contained `java -jar phonenumber-ae.jar` case work with no
        // external .so and no LIBPHONENUMBER_AE_LIB.
        if (explicitPath == null) {
            try {
                Path extracted = extractBundledLibrary();
                if (extracted != null) {
                    return SymbolLookup.libraryLookup(extracted, Arena.global());
                }
            } catch (RuntimeException e) {
                last = e;
            }
        }

        throw new IllegalStateException(
                "could not load the phonenumber engine (" + LIB_NAME + "). Set "
                        + "LIBPHONENUMBER_AE_LIB to its absolute path. Last error: "
                        + (last == null ? "no candidates" : last.getMessage()), last);
    }

    /**
     * Extract the engine bundled at {@code /native/<lib>} on the classpath (as a
     * fat jar ships it) to a temp file, returning its path, or {@code null} if no
     * such resource is present. The temp file is deleted on JVM exit.
     */
    private Path extractBundledLibrary() {
        String resource = "/native/" + LIB_NAME;
        try (InputStream in = Native.class.getResourceAsStream(resource)) {
            if (in == null) return null;
            int dot = LIB_NAME.lastIndexOf('.');
            String prefix = (dot > 0 ? LIB_NAME.substring(0, dot) : LIB_NAME) + "-";
            String suffix = (dot > 0 ? LIB_NAME.substring(dot) : ".so");
            Path tmp = Files.createTempFile(prefix, suffix);
            tmp.toFile().deleteOnExit();
            Files.copy(in, tmp, StandardCopyOption.REPLACE_EXISTING);
            return tmp;
        } catch (IOException e) {
            throw new IllegalStateException(
                    "failed to extract bundled engine from " + resource, e);
        }
    }

    private MethodHandle downcall(String name, FunctionDescriptor fd) {
        MemorySegment sym = lookup.find(name).orElseThrow(
                () -> new IllegalStateException("missing symbol " + name + " (engine too old?)"));
        return linker.downcallHandle(sym, fd);
    }

    // ---- string marshalling ----

    /**
     * Copy an ABI-returned string out and free it through the ABI.
     *
     * <p>Every {@code char*} the engine returns is caller-owned; leaking it is
     * the single easiest mistake to make in any of these bindings.
     */
    public String takeString(MemorySegment ptr) {
        if (ptr == null || ptr.equals(MemorySegment.NULL)) return "";
        try {
            // A returned pointer has zero byteSize; reinterpret so the string
            // can actually be read from it.
            return ptr.reinterpret(Long.MAX_VALUE).getString(0);
        } finally {
            try {
                freeString.invokeExact(ptr);
            } catch (Throwable t) {
                throw wrap(t);
            }
        }
    }

    // ---- typed downcall wrappers ------------------------------------------
    //
    // Each mirrors one ABI symbol at its Java-natural signature, keeping the
    // Arena/allocate/takeString ritual in ONE place so PhoneNumbers and the
    // value classes read as plain calls. Wrappers below take Strings and hand
    // back Strings/ints/booleans; the "new v2" symbols get one apiece.

    /** A string-returning symbol of one string arg: {@code char* (s)}. */
    String call1s(MethodHandle h, String a) {
        try (Arena arena = Arena.ofConfined()) {
            return takeString((MemorySegment) h.invokeExact(alloc(arena, a)));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** A string-returning symbol of two string args: {@code char* (a, b)}. */
    String call2s(MethodHandle h, String a, String b) {
        try (Arena arena = Arena.ofConfined()) {
            return takeString(
                    (MemorySegment) h.invokeExact(alloc(arena, a), alloc(arena, b)));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** A string-returning symbol of {@code char* (a, b, int)}. */
    String call2s1i(MethodHandle h, String a, String b, int i) {
        try (Arena arena = Arena.ofConfined()) {
            return takeString(
                    (MemorySegment) h.invokeExact(alloc(arena, a), alloc(arena, b), i));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** A string-returning symbol of {@code char* (a, b, c)}. */
    String call3s(MethodHandle h, String a, String b, String c) {
        try (Arena arena = Arena.ofConfined()) {
            return takeString((MemorySegment) h.invokeExact(
                    alloc(arena, a), alloc(arena, b), alloc(arena, c)));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** A string-returning symbol of {@code char* (s, int)}. */
    String call1s1i(MethodHandle h, String a, int i) {
        try (Arena arena = Arena.ofConfined()) {
            return takeString((MemorySegment) h.invokeExact(alloc(arena, a), i));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** An int-returning symbol of one string arg: {@code int (s)}. */
    int calli1s(MethodHandle h, String a) {
        try (Arena arena = Arena.ofConfined()) {
            return (int) h.invokeExact(alloc(arena, a));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** An int-returning symbol of two string args: {@code int (a, b)}. */
    int calli2s(MethodHandle h, String a, String b) {
        try (Arena arena = Arena.ofConfined()) {
            return (int) h.invokeExact(alloc(arena, a), alloc(arena, b));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** An int-returning symbol of {@code int (a, b, int)}. */
    int calli2s1i(MethodHandle h, String a, String b, int i) {
        try (Arena arena = Arena.ofConfined()) {
            return (int) h.invokeExact(alloc(arena, a), alloc(arena, b), i);
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** An int-returning symbol of {@code int (a, b, int, int)}. */
    int calli2s2i(MethodHandle h, String a, String b, int i, int j) {
        try (Arena arena = Arena.ofConfined()) {
            return (int) h.invokeExact(alloc(arena, a), alloc(arena, b), i, j);
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    /** A string-returning symbol of {@code char* (a, b, int, int)}. */
    String call2s2i(MethodHandle h, String a, String b, int i, int j) {
        try (Arena arena = Arena.ofConfined()) {
            return takeString(
                    (MemorySegment) h.invokeExact(alloc(arena, a), alloc(arena, b), i, j));
        } catch (Throwable t) {
            throw wrap(t);
        }
    }

    private static MemorySegment alloc(Arena arena, String s) {
        return arena.allocateFrom(s == null ? "" : s);
    }

    /** MethodHandle invocation throws Throwable; funnel it into an unchecked type. */
    public static RuntimeException wrap(Throwable t) {
        if (t instanceof RuntimeException re) return re;
        if (t instanceof Error e) throw e;
        return new RuntimeException(t);
    }
}
