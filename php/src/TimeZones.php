<?php

/**
 * IANA time-zone lookup over the phonenumber engine (ABI v5).
 *
 * Mirrors libphonenumber's `PhoneNumberToTimeZonesMapper`. Carries no
 * phone-number logic — every method marshals to an `aether_pn_embed_tz_*` call
 * in {@see Native}. The unknown-zone sentinel is `"Etc/Unknown"`.
 *
 *     use PhoneNumberAe\TimeZones;
 *
 *     TimeZones::timeZonesForNumber('US', '2015550123'); // ['America/New_York']
 *     TimeZones::timeZonesForNumber('GB', '2070313000'); // ['Europe/London']
 *     TimeZones::unknownTimeZone();                      // 'Etc/Unknown'
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class TimeZones
{
    /** This class is never instantiated — the stateless ABI has no state to hold. */
    private function __construct()
    {
    }

    private static function ffi(): FFI
    {
        return Native::load();
    }

    /**
     * The IANA time-zone ids for $input in $region, in order.
     *
     * A number with no known zone maps to a single-element list of the unknown
     * zone (`['Etc/Unknown']`).
     *
     * @return list<string>
     */
    public static function timeZonesForNumber(string $region, string $input): array
    {
        $ffi = self::ffi();
        $count = $ffi->aether_pn_embed_tz_count($region, $input);
        if ($count === 0) {
            return [self::unknownTimeZone()];
        }
        $out = [];
        for ($i = 0; $i < $count; $i++) {
            $out[] = Native::takeString($ffi, $ffi->aether_pn_embed_tz_at($region, $input, $i));
        }
        return $out;
    }

    /** How many time zones $input maps to in $region (0 = only the unknown zone). */
    public static function timeZoneCount(string $region, string $input): int
    {
        return self::ffi()->aether_pn_embed_tz_count($region, $input);
    }

    /** The unknown-zone sentinel, "Etc/Unknown". */
    public static function unknownTimeZone(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_tz_unknown());
    }
}
