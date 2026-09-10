<?php

/**
 * The idiomatic PHP surface over the phonenumber engine (ABI v5).
 *
 * Carries no phone-number logic — every method here marshals to an
 * `aether_pn_embed_*` call in {@see Native}.
 *
 * Most of the surface is static methods; the stateful pieces are small classes:
 * {@see ParsedNumber} (over a caller-owned parsed-number string), {@see
 * AsYouTypeFormatter} (over a caller-owned formatter state), and {@see
 * PhoneNumberMatch} (the value {@see PhoneNumber::findNumbers()} returns).
 *
 *     use PhoneNumberAe\PhoneNumber;
 *
 *     $num = PhoneNumber::parse('+1 201 555 0123 ext 42', 'US');
 *     $num->nationalNumber();                                 // '2015550123'
 *     PhoneNumber::isValidNumber('US', '+1 201 555 0123');    // true
 *     PhoneNumber::format('US', '2015550123', PhoneNumber::INTERNATIONAL);
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class PhoneNumber
{
    // ---- format styles (re-exported from Native for a one-import surface) ----
    // NOTE: v2 renumbered these. E164 is now 0 (was 2 in v1).

    public const E164 = Native::E164;
    public const INTERNATIONAL = Native::INTERNATIONAL;
    public const NATIONAL = Native::NATIONAL;
    public const RFC3966 = Native::RFC3966;

    // ---- number types ----

    public const TYPE_UNKNOWN = Native::TYPE_UNKNOWN;
    public const TYPE_FIXED_LINE = Native::TYPE_FIXED_LINE;
    public const TYPE_MOBILE = Native::TYPE_MOBILE;
    public const TYPE_TOLL_FREE = Native::TYPE_TOLL_FREE;
    public const TYPE_PREMIUM_RATE = Native::TYPE_PREMIUM_RATE;
    public const TYPE_SHARED_COST = Native::TYPE_SHARED_COST;
    public const TYPE_VOIP = Native::TYPE_VOIP;
    public const TYPE_PERSONAL_NUMBER = Native::TYPE_PERSONAL_NUMBER;
    public const TYPE_PAGER = Native::TYPE_PAGER;
    public const TYPE_UAN = Native::TYPE_UAN;
    public const TYPE_VOICEMAIL = Native::TYPE_VOICEMAIL;
    public const TYPE_FIXED_LINE_OR_MOBILE = Native::TYPE_FIXED_LINE_OR_MOBILE;

    // ---- ValidationResult (isPossibleNumberWithReason) ----

    public const VR_IS_POSSIBLE = Native::VR_IS_POSSIBLE;
    public const VR_IS_POSSIBLE_LOCAL_ONLY = Native::VR_IS_POSSIBLE_LOCAL_ONLY;
    public const VR_INVALID_COUNTRY_CODE = Native::VR_INVALID_COUNTRY_CODE;
    public const VR_TOO_SHORT = Native::VR_TOO_SHORT;
    public const VR_INVALID_LENGTH = Native::VR_INVALID_LENGTH;
    public const VR_TOO_LONG = Native::VR_TOO_LONG;

    // ---- MatchType (isNumberMatch) ----

    public const MATCH_NOT_A_NUMBER = Native::MATCH_NOT_A_NUMBER;
    public const MATCH_NO_MATCH = Native::MATCH_NO_MATCH;
    public const MATCH_SHORT_NSN = Native::MATCH_SHORT_NSN;
    public const MATCH_NSN = Native::MATCH_NSN;
    public const MATCH_EXACT = Native::MATCH_EXACT;

    // ---- CountryCodeSource (ParsedNumber::source) ----

    public const SRC_FROM_NUMBER_WITH_PLUS = Native::SRC_FROM_NUMBER_WITH_PLUS;
    public const SRC_FROM_NUMBER_WITH_IDD = Native::SRC_FROM_NUMBER_WITH_IDD;
    public const SRC_FROM_NUMBER_WITHOUT_PLUS = Native::SRC_FROM_NUMBER_WITHOUT_PLUS;
    public const SRC_FROM_DEFAULT_COUNTRY = Native::SRC_FROM_DEFAULT_COUNTRY;

    // ---- matcher leniency ----

    public const LENIENCY_POSSIBLE = Native::LENIENCY_POSSIBLE;
    public const LENIENCY_VALID = Native::LENIENCY_VALID;
    public const LENIENCY_STRICT_GROUPING = Native::LENIENCY_STRICT_GROUPING;
    public const LENIENCY_EXACT_GROUPING = Native::LENIENCY_EXACT_GROUPING;

    // ---- ShortNumberCost (ShortNumberInfo::expectedCost) ----

    public const COST_TOLL_FREE = Native::COST_TOLL_FREE;
    public const COST_STANDARD_RATE = Native::COST_STANDARD_RATE;
    public const COST_PREMIUM_RATE = Native::COST_PREMIUM_RATE;
    public const COST_UNKNOWN = Native::COST_UNKNOWN;

    /** This class is never instantiated — the stateless ABI has no state to hold. */
    private function __construct()
    {
    }

    private static function ffi(): FFI
    {
        return Native::load();
    }

    // ---- metadata ----

    /** The country calling code for a region ("1", "44", …), or "" if unknown. */
    public static function countryCode(string $region): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_country_code($region));
    }

    /** An example national number for the region, or "". */
    public static function exampleNumber(string $region): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_example_number($region));
    }

    /** An example national number of the given TYPE_* for the region, or "". */
    public static function exampleNumberForType(string $region, int $type): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_example_number_for_type($region, $type));
    }

    /** An example number that is invalid for the region, or "". */
    public static function invalidExampleNumber(string $region): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_invalid_example_number($region));
    }

    /** The possible-lengths spec for the region (e.g. "9,10"), or "". */
    public static function possibleLengths(string $region): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_possible_lengths($region));
    }

    /** The main region for a country calling code ("44" -> "GB"), or "". */
    public static function regionCodeForCountryCode(string $cc): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_region_code_for_country_code($cc));
    }

    /** True if the region is part of the North American Numbering Plan. */
    public static function isNanpaCountry(string $region): bool
    {
        return self::ffi()->aether_pn_embed_is_nanpa_country($region) !== 0;
    }

    /** The national-direct-dialling prefix for a region ("0", "1", …), or "". */
    public static function nddPrefixForRegion(string $region, bool $stripNonDigits = false): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_ndd_prefix_for_region($region, $stripNonDigits ? 1 : 0));
    }

    /**
     * Every region id the metadata carries, as a list of ISO-3166 codes.
     *
     * @return list<string>
     */
    public static function regions(): array
    {
        $ffi = self::ffi();
        $n = $ffi->aether_pn_embed_region_count();
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = Native::takeString($ffi, $ffi->aether_pn_embed_region_at($i));
        }
        return $out;
    }

    /** How many regions share a country calling code. */
    public static function ccRegionCount(string $cc): int
    {
        return self::ffi()->aether_pn_embed_cc_region_count($cc);
    }

    /**
     * The regions that share a country calling code, in metadata order.
     *
     * @return list<string>
     */
    public static function regionsForCountryCode(string $cc): array
    {
        $ffi = self::ffi();
        $n = $ffi->aether_pn_embed_cc_region_count($cc);
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = Native::takeString($ffi, $ffi->aether_pn_embed_cc_region_at($cc, $i));
        }
        return $out;
    }

    // ---- parse ----

    /** Parse raw input against a default region into a {@see ParsedNumber}. */
    public static function parse(string $input, string $region): ParsedNumber
    {
        $ffi = self::ffi();
        return new ParsedNumber(Native::takeString($ffi, $ffi->aether_pn_embed_parse($input, $region)));
    }

    /** The national number extracted from raw input (cc + punctuation stripped). */
    public static function nationalNumber(string $region, string $input): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_national_number($region, $input));
    }

    // ---- validation ----

    /** True if the national number is a length the region allows. */
    public static function isPossibleNumber(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_is_possible_number($region, $input) !== 0;
    }

    /** Why (or that) a number is possible — a VR_* ValidationResult. */
    public static function isPossibleNumberWithReason(string $region, string $input): int
    {
        return self::ffi()->aether_pn_embed_is_possible_number_with_reason($region, $input);
    }

    /** True if the number matches the region's national-number patterns. */
    public static function isValidNumber(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_is_valid_number($region, $input) !== 0;
    }

    /** True if the number is valid *for* the given region. */
    public static function isValidNumberForRegion(string $input, string $region): bool
    {
        return self::ffi()->aether_pn_embed_is_valid_number_for_region($input, $region) !== 0;
    }

    /** The PhoneNumberType (a TYPE_* int; -1 for unknown). */
    public static function numberType(string $region, string $input): int
    {
        return self::ffi()->aether_pn_embed_number_type($region, $input);
    }

    /** True if the number can be dialled from outside its country. */
    public static function canBeInternationallyDialled(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_can_be_internationally_dialled($region, $input) !== 0;
    }

    // ---- formatting ----

    /** Format the number in the given style (E164 / INTERNATIONAL / NATIONAL / RFC3966). */
    public static function format(string $region, string $input, int $style = self::NATIONAL): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_format($region, $input, $style));
    }

    public static function formatNational(string $region, string $input): string
    {
        return self::format($region, $input, self::NATIONAL);
    }

    public static function formatInternational(string $region, string $input): string
    {
        return self::format($region, $input, self::INTERNATIONAL);
    }

    public static function formatE164(string $region, string $input): string
    {
        return self::format($region, $input, self::E164);
    }

    public static function formatRfc3966(string $region, string $input): string
    {
        return self::format($region, $input, self::RFC3966);
    }

    /** Format $input as dialled from $callingFrom. */
    public static function formatOutOfCountry(string $region, string $input, string $callingFrom): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_format_out_of_country($region, $input, $callingFrom));
    }

    // ---- relations / helpers ----

    /** Compare two numbers — a MATCH_* MatchType. */
    public static function isNumberMatch(string $a, string $b): int
    {
        return self::ffi()->aether_pn_embed_is_number_match($a, $b);
    }

    /** Drop digits past the region's maximum length. */
    public static function truncateTooLong(string $region, string $input): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_truncate_too_long($region, $input));
    }

    /** Keep only the digits of a string (Unicode digits included). */
    public static function normalizeDigitsOnly(string $s): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_normalize_digits_only($s));
    }

    /** Convert vanity letters to their dial-pad digits. */
    public static function convertAlphaCharacters(string $s): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_convert_alpha_characters($s));
    }

    /** True if the string contains vanity (alpha) characters. */
    public static function isAlphaNumber(string $s): bool
    {
        return self::ffi()->aether_pn_embed_is_alpha_number($s) !== 0;
    }

    /** The ABI revision the loaded engine reports. */
    public static function abiVersion(): int
    {
        return self::ffi()->aether_pn_embed_abi_version();
    }

    /** Where the engine .so was actually loaded from. */
    public static function nativeLibraryPath(): ?string
    {
        self::ffi(); // ensure it is loaded so path() is populated
        return Native::path();
    }

    // ---- matcher / findNumbers ----

    /**
     * Find phone numbers in free text.
     *
     * @return list<PhoneNumberMatch>
     */
    public static function findNumbers(string $text, string $region, int $leniency = self::LENIENCY_VALID): array
    {
        $ffi = self::ffi();
        $n = $ffi->aether_pn_embed_matcher_count($text, $region, $leniency);
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = new PhoneNumberMatch(
                $ffi->aether_pn_embed_matcher_start($text, $region, $leniency, $i),
                $ffi->aether_pn_embed_matcher_end($text, $region, $leniency, $i),
                Native::takeString($ffi, $ffi->aether_pn_embed_matcher_raw($text, $region, $leniency, $i)),
            );
        }
        return $out;
    }
}
