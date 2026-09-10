<?php

/**
 * English carrier-name lookup over the phonenumber engine (ABI v5).
 *
 * Mirrors libphonenumber's `PhoneNumberToCarrierMapper`. Carries no
 * phone-number logic — every method marshals to an `aether_pn_embed_carrier_*`
 * call in {@see Native}. English names only; "" means no carrier is known.
 *
 *     use PhoneNumberAe\Carrier;
 *
 *     Carrier::carrierNameForNumber('GB', '7106000000');      // 'O2'
 *     Carrier::carrierNameForValidNumber('GB', '7106000000'); // 'O2'
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class Carrier
{
    /** This class is never instantiated — the stateless ABI has no state to hold. */
    private function __construct()
    {
    }

    private static function ffi(): FFI
    {
        return Native::load();
    }

    /** The carrier name for $input in $region (English), or "" if none is known. */
    public static function carrierNameForNumber(string $region, string $input): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_carrier_name($region, $input));
    }

    /** The carrier name only when $input is a valid number for $region, else "". */
    public static function carrierNameForValidNumber(string $region, string $input): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_carrier_name_for_valid($region, $input));
    }
}
