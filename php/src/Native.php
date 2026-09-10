<?php

/**
 * The 1:1 symbol table for the phonenumber C ABI (core/embed.ae), v3.
 *
 * This file is the ONLY place in the PHP binding that knows about the C ABI.
 * Everything above it (PhoneNumber.php) is idiomatic PHP over these symbols.
 * No phone-number logic lives here or anywhere else in this package — the
 * engine is core/phonenumber.ae, shared by every language binding.
 *
 * ## Naming
 *
 * core/embed.ae names its exports `pn_embed_<name>`; building with
 * `--emit=lib` mangles them to **`aether_pn_embed_<name>`**. That mangled name
 * is what the cdef below declares.
 *
 * ## Ownership
 *
 * **Every char* this ABI returns is caller-owned** and must be handed back to
 * `aether_pn_embed_free_string`. Leaking it is the single most common bug in a
 * binding. {@see Native::takeString()} does the right thing.
 *
 * ## No opaque handles
 *
 * v3 adds the ShortNumberInfo side-library (8 symbols) on top of the full
 * PhoneNumberUtil-parity ABI (now 58 symbols), but every signature is still
 * scalar-only (`const char*` and `int`). A parsed number and an as-you-type
 * state are themselves caller-owned *strings*: you get one back, pass it to the
 * accessor calls, and free it like any other returned string. There is still no
 * cdef for function-pointer typedefs, no keepalive, and nothing to close.
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;
use RuntimeException;

/**
 * Loads libphonenumber_ae and owns the single FFI handle.
 *
 * @psalm-suppress UndefinedClass FFI is only defined when ext-ffi is loaded.
 */
final class Native
{
    // ---- format styles (ABI constants — append only, never renumber) ----
    // NOTE: v2 renumbered these. E164 is now 0 (was 2 in v1).

    public const E164 = 0;
    public const INTERNATIONAL = 1;
    public const NATIONAL = 2;
    public const RFC3966 = 3;

    // ---- number types (number_type result; -1 = unknown) ----

    public const TYPE_UNKNOWN = -1;
    public const TYPE_FIXED_LINE = 0;
    public const TYPE_MOBILE = 1;
    public const TYPE_TOLL_FREE = 2;
    public const TYPE_PREMIUM_RATE = 3;
    public const TYPE_SHARED_COST = 4;
    public const TYPE_VOIP = 5;
    public const TYPE_PERSONAL_NUMBER = 6;
    public const TYPE_PAGER = 7;
    public const TYPE_UAN = 8;
    public const TYPE_VOICEMAIL = 9;
    public const TYPE_FIXED_LINE_OR_MOBILE = 10;

    // ---- ValidationResult (is_possible_number_with_reason) ----

    public const VR_IS_POSSIBLE = 0;
    public const VR_IS_POSSIBLE_LOCAL_ONLY = 4;
    public const VR_INVALID_COUNTRY_CODE = 1;
    public const VR_TOO_SHORT = 2;
    public const VR_INVALID_LENGTH = 5;
    public const VR_TOO_LONG = 3;

    // ---- MatchType (is_number_match) ----

    public const MATCH_NOT_A_NUMBER = 0;
    public const MATCH_NO_MATCH = 1;
    public const MATCH_SHORT_NSN = 2;
    public const MATCH_NSN = 3;
    public const MATCH_EXACT = 4;

    // ---- CountryCodeSource (pn_source) ----

    public const SRC_FROM_NUMBER_WITH_PLUS = 1;
    public const SRC_FROM_NUMBER_WITH_IDD = 5;
    public const SRC_FROM_NUMBER_WITHOUT_PLUS = 10;
    public const SRC_FROM_DEFAULT_COUNTRY = 20;

    // ---- matcher leniency ----

    public const LENIENCY_POSSIBLE = 0;
    public const LENIENCY_VALID = 1;

    // ---- ShortNumberCost (short_expected_cost) ----

    public const COST_TOLL_FREE = 0;
    public const COST_STANDARD_RATE = 1;
    public const COST_PREMIUM_RATE = 2;
    public const COST_UNKNOWN = 3;

    /**
     * The ABI, grouped the way core/embed.ae declares it.
     *
     * Comments inside use C block syntax, not line comments: PHP's FFI cdef
     * parser is a small C parser and does not accept the latter.
     */
    private const CDEF = <<<'C'
        /* ---- version / introspection ---- */
        int    aether_pn_embed_abi_version(void);

        /* ---- the caller-owned-string bridge ---- */
        void   aether_pn_embed_free_string(char* s);

        /* ---- metadata ---- */
        char*  aether_pn_embed_country_code(const char* region);
        char*  aether_pn_embed_example_number(const char* region);
        char*  aether_pn_embed_example_number_for_type(const char* region, int type);
        char*  aether_pn_embed_invalid_example_number(const char* region);
        char*  aether_pn_embed_possible_lengths(const char* region);
        char*  aether_pn_embed_region_code_for_country_code(const char* cc);
        int    aether_pn_embed_is_nanpa_country(const char* region);
        char*  aether_pn_embed_ndd_prefix_for_region(const char* region, int strip_non_digits);
        int    aether_pn_embed_region_count(void);
        char*  aether_pn_embed_region_at(int index);
        int    aether_pn_embed_cc_region_count(const char* cc);
        char*  aether_pn_embed_cc_region_at(const char* cc, int index);

        /* ---- parse + parsed-number accessors ---- */
        char*  aether_pn_embed_parse(const char* input, const char* region);
        char*  aether_pn_embed_national_number(const char* region, const char* input);
        char*  aether_pn_embed_pn_region(const char* pn);
        char*  aether_pn_embed_pn_country_code(const char* pn);
        char*  aether_pn_embed_pn_national_number(const char* pn);
        char*  aether_pn_embed_pn_extension(const char* pn);
        int    aether_pn_embed_pn_italian_leading_zero(const char* pn);
        int    aether_pn_embed_pn_source(const char* pn);
        char*  aether_pn_embed_pn_error(const char* pn);
        char*  aether_pn_embed_region_code_for_number(const char* pn);
        char*  aether_pn_embed_national_significant_number(const char* pn);
        int    aether_pn_embed_length_of_ndc(const char* pn);
        int    aether_pn_embed_length_of_area_code(const char* pn);
        int    aether_pn_embed_is_geographical(const char* pn);

        /* ---- validation ---- */
        int    aether_pn_embed_is_possible_number(const char* region, const char* input);
        int    aether_pn_embed_is_possible_number_with_reason(const char* region, const char* input);
        int    aether_pn_embed_is_valid_number(const char* region, const char* input);
        int    aether_pn_embed_is_valid_number_for_region(const char* input, const char* region);
        int    aether_pn_embed_number_type(const char* region, const char* input);
        int    aether_pn_embed_can_be_internationally_dialled(const char* region, const char* input);

        /* ---- formatting ---- */
        char*  aether_pn_embed_format(const char* region, const char* input, int fmt);
        char*  aether_pn_embed_format_out_of_country(const char* region, const char* input, const char* calling_from);
        char*  aether_pn_embed_format_in_original(const char* pn, const char* calling_from);

        /* ---- relations / helpers ---- */
        int    aether_pn_embed_is_number_match(const char* a, const char* b);
        char*  aether_pn_embed_truncate_too_long(const char* region, const char* input);
        char*  aether_pn_embed_normalize_digits_only(const char* s);
        char*  aether_pn_embed_convert_alpha_characters(const char* s);
        int    aether_pn_embed_is_alpha_number(const char* s);

        /* ---- AsYouTypeFormatter (state threaded as a caller-owned string) ---- */
        char*  aether_pn_embed_ayt_new(const char* region);
        char*  aether_pn_embed_ayt_input(const char* state, const char* ch);
        char*  aether_pn_embed_ayt_result(const char* state);
        char*  aether_pn_embed_ayt_clear(const char* state);

        /* ---- PhoneNumberMatcher / findNumbers ---- */
        int    aether_pn_embed_matcher_count(const char* text, const char* region, int leniency);
        int    aether_pn_embed_matcher_start(const char* text, const char* region, int leniency, int idx);
        int    aether_pn_embed_matcher_end(const char* text, const char* region, int leniency, int idx);
        char*  aether_pn_embed_matcher_raw(const char* text, const char* region, int leniency, int idx);

        /* ---- ShortNumberInfo (short / emergency numbers) ---- */
        int    aether_pn_embed_short_is_possible(const char* region, const char* input);
        int    aether_pn_embed_short_is_valid(const char* region, const char* input);
        int    aether_pn_embed_short_is_emergency(const char* region, const char* input);
        int    aether_pn_embed_short_connects_to_emergency(const char* region, const char* input);
        int    aether_pn_embed_short_is_carrier_specific(const char* region, const char* input);
        int    aether_pn_embed_short_is_sms_service(const char* region, const char* input);
        int    aether_pn_embed_short_expected_cost(const char* region, const char* input);
        char*  aether_pn_embed_short_example_number(const char* region);
        C;

    private static ?FFI $ffi = null;
    private static ?string $path = null;

    /**
     * Load the engine, caching it process-wide when no explicit path is given.
     *
     * Resolution order:
     *   1. an explicit $path passed here
     *   2. $LIBPHONENUMBER_AE_LIB (what the in-tree .tests.ae leaf sets)
     *   3. native/ next to this package, then ../core/native/
     *   4. the OS loader's own search path
     *
     * @throws RuntimeException when ext-ffi is missing or no candidate loads.
     */
    public static function load(?string $path = null): FFI
    {
        if ($path === null && self::$ffi !== null) {
            return self::$ffi;
        }

        if (!\extension_loaded('ffi')) {
            throw new RuntimeException(
                'phonenumber_ae: ext-ffi is not loaded. Enable it in php.ini '
                . '(extension=ffi) and make sure ffi.enable is "true" for CLI.'
            );
        }

        $tried = [];
        $last = null;
        foreach (self::candidates($path) as $candidate) {
            $tried[] = $candidate;
            try {
                $ffi = FFI::cdef(self::CDEF, $candidate);
            } catch (\Throwable $e) {
                $last = $e;
                continue;
            }
            if ($path === null) {
                self::$ffi = $ffi;
                self::$path = $candidate;
            }
            return $ffi;
        }

        throw new RuntimeException(sprintf(
            "phonenumber_ae: could not load the engine (%s). Set "
            . "LIBPHONENUMBER_AE_LIB to its absolute path, or build it with:\n"
            . "  aeb core/.build.ae\nTried: %s\nLast error: %s",
            self::fileName(),
            implode(', ', $tried),
            $last !== null ? $last->getMessage() : '(none)'
        ));
    }

    /** Where the engine was actually loaded from, once known. */
    public static function path(): ?string
    {
        return self::$path;
    }

    /** The platform's library file name. */
    public static function fileName(): string
    {
        return match (PHP_OS_FAMILY) {
            'Darwin'  => 'libphonenumber_ae.dylib',
            'Windows' => 'phonenumber_ae.dll',
            default   => 'libphonenumber_ae.so',
        };
    }

    /**
     * @return list<string>
     */
    private static function candidates(?string $explicit): array
    {
        if ($explicit !== null && $explicit !== '') {
            return [$explicit];
        }

        $out = [];
        $env = \getenv('LIBPHONENUMBER_AE_LIB');
        if (\is_string($env) && $env !== '') {
            $out[] = $env;
        }

        $name = self::fileName();
        $here = __DIR__;
        $out[] = $here . '/../native/' . $name;
        $out[] = $here . '/../../core/native/' . $name;
        $out[] = \getcwd() . '/native/' . $name;
        $out[] = \getcwd() . '/../core/native/' . $name;
        $out[] = $name;

        return $out;
    }

    /**
     * Copy an ABI-returned string out and free it through the ABI.
     *
     * Every char* the engine returns is caller-owned; leaking it is the single
     * easiest mistake to make in any of these bindings. Every string result in
     * this package goes through here.
     *
     * @param FFI\CData|null $ptr
     */
    public static function takeString(FFI $ffi, $ptr): string
    {
        if ($ptr === null || FFI::isNull($ptr)) {
            return '';
        }
        try {
            return FFI::string($ptr);
        } finally {
            $ffi->aether_pn_embed_free_string($ptr);
        }
    }
}
