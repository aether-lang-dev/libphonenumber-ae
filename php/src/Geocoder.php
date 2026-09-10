<?php

/**
 * Geographic-description lookup over the phonenumber engine (ABI v7).
 *
 * Mirrors libphonenumber's `PhoneNumberOfflineGeocoder`. Carries no
 * phone-number logic — every method marshals to an `aether_pn_embed_geo_*`
 * call in {@see Native}. "" means no description is known. The $lang argument
 * (an ISO code) localizes the result and defaults to English ("en"), which is
 * always available and the fallback for any other language.
 *
 *     use PhoneNumberAe\Geocoder;
 *
 *     Geocoder::geoDescriptionForNumber('US', '6502530000');            // 'Mountain View, CA'
 *     Geocoder::geoDescriptionForNumber('US', '6502530000', 'en');      // 'Mountain View, CA' ($lang optional)
 *     Geocoder::geoDescriptionForValidNumber('US', '6502530000');       // 'Mountain View, CA'
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

    /** A geographic description for $input in $region, or "" if none is known (localized by $lang, default "en"). */
    public static function geoDescriptionForNumber(string $region, string $input, string $lang = 'en'): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_geo_description($region, $input, $lang));
    }

    /** A geographic description only when $input is a valid number for $region, else "" (localized by $lang, default "en"). */
    public static function geoDescriptionForValidNumber(string $region, string $input, string $lang = 'en'): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_geo_description_for_valid($region, $input, $lang));
    }
}
