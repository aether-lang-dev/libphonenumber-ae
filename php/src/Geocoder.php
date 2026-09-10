<?php

/**
 * English geographic-description lookup over the phonenumber engine (ABI v6).
 *
 * Mirrors libphonenumber's `PhoneNumberOfflineGeocoder`. Carries no
 * phone-number logic — every method marshals to an `aether_pn_embed_geo_*`
 * call in {@see Native}. English descriptions only; "" means no description is
 * known.
 *
 *     use PhoneNumberAe\Geocoder;
 *
 *     Geocoder::geoDescriptionForNumber('US', '6502530000');      // 'Mountain View, CA'
 *     Geocoder::geoDescriptionForValidNumber('US', '6502530000'); // 'Mountain View, CA'
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class Geocoder
{
    /** This class is never instantiated — the stateless ABI has no state to hold. */
    private function __construct()
    {
    }

    private static function ffi(): FFI
    {
        return Native::load();
    }

    /** A geographic description for $input in $region (English), or "" if none is known. */
    public static function geoDescriptionForNumber(string $region, string $input): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_geo_description($region, $input));
    }

    /** A geographic description only when $input is a valid number for $region, else "". */
    public static function geoDescriptionForValidNumber(string $region, string $input): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_geo_description_for_valid($region, $input));
    }
}
