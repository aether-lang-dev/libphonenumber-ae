<?php

/**
 * Carrier-name lookup over the phonenumber engine (ABI v7).
 *
 * Mirrors libphonenumber's `PhoneNumberToCarrierMapper`. Carries no
 * phone-number logic — every method marshals to an `aether_pn_embed_carrier_*`
 * call in {@see Native}. "" means no carrier is known. The $lang argument (an
 * ISO code) localizes the result and defaults to English ("en"), which is
 * always available and the fallback for any other language.
 *
 *     use PhoneNumberAe\Carrier;
 *
 *     Carrier::carrierNameForNumber('GB', '7106000000');            // 'O2'
 *     Carrier::carrierNameForNumber('GB', '7106000000', 'en');      // 'O2' ($lang optional)
 *     Carrier::carrierNameForValidNumber('GB', '7106000000');       // 'O2'
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

    /** The carrier name for $input in $region, or "" if none is known (localized by $lang, default "en"). */
    public static function carrierNameForNumber(string $region, string $input, string $lang = 'en'): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_carrier_name($region, $input, $lang));
    }

    /** The carrier name only when $input is a valid number for $region, else "" (localized by $lang, default "en"). */
    public static function carrierNameForValidNumber(string $region, string $input, string $lang = 'en'): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_carrier_name_for_valid($region, $input, $lang));
    }
}
