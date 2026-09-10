<?php

/**
 * Short- and emergency-number queries over the phonenumber engine (ABI v5).
 *
 * Mirrors libphonenumber's `ShortNumberInfo`. Carries no phone-number logic —
 * every method marshals to an `aether_pn_embed_short_*` call in {@see Native}.
 * The expected-cost result is one of the COST_* ShortNumberCost ints.
 *
 *     use PhoneNumberAe\ShortNumberInfo;
 *
 *     ShortNumberInfo::isEmergencyNumber('US', '911');   // true
 *     ShortNumberInfo::isValid('US', '911');             // true
 *     ShortNumberInfo::expectedCost('US', '911');        // ShortNumberInfo::COST_TOLL_FREE
 *     ShortNumberInfo::exampleNumber('US');              // '112'
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class ShortNumberInfo
{
    // ---- ShortNumberCost (re-exported from Native for a one-import surface) ----

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

    /** True if $input is a possible short number for $region. */
    public static function isPossible(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_short_is_possible($region, $input) !== 0;
    }

    /** True if $input is a valid short number for $region. */
    public static function isValid(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_short_is_valid($region, $input) !== 0;
    }

    /** True if $input is an emergency number for $region. */
    public static function isEmergencyNumber(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_short_is_emergency($region, $input) !== 0;
    }

    /** True if dialling $input would connect to an emergency service in $region. */
    public static function connectsToEmergencyNumber(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_short_connects_to_emergency($region, $input) !== 0;
    }

    /** True if the short number is carrier-specific. */
    public static function isCarrierSpecific(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_short_is_carrier_specific($region, $input) !== 0;
    }

    /** True if the short number is an SMS service. */
    public static function isSmsService(string $region, string $input): bool
    {
        return self::ffi()->aether_pn_embed_short_is_sms_service($region, $input) !== 0;
    }

    /** The expected cost of dialling the short number — a COST_* ShortNumberCost int. */
    public static function expectedCost(string $region, string $input): int
    {
        return self::ffi()->aether_pn_embed_short_expected_cost($region, $input);
    }

    /** An example short number for $region, or "". */
    public static function exampleNumber(string $region): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_short_example_number($region));
    }
}
