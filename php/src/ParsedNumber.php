<?php

/**
 * A parsed phone number (ABI v5).
 *
 * Wraps the caller-owned parsed-number string the ABI returns from
 * {@see PhoneNumber::parse()}; its fields are read on demand through the pn_*
 * accessors. Carries no phone-number logic — every accessor marshals to an
 * `aether_pn_embed_*` call in {@see Native}.
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class ParsedNumber
{
    /**
     * The opaque parsed-number blob the ABI handed back. Only the accessors
     * here and {@see ParsedNumber::formatInOriginal()} should touch it.
     */
    private string $blob;

    public function __construct(string $blob)
    {
        $this->blob = $blob;
    }

    private static function ffi(): FFI
    {
        return Native::load();
    }

    /** The raw parsed-number blob (rarely needed directly). */
    public function blob(): string
    {
        return $this->blob;
    }

    /** The region the number was parsed against ("US"), or "". */
    public function region(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_pn_region($this->blob));
    }

    /** The country calling code ("1"), or "". */
    public function countryCode(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_pn_country_code($this->blob));
    }

    /** The national (significant) number ("2015550123"), or "". */
    public function nationalNumber(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_pn_national_number($this->blob));
    }

    /** The parsed extension ("42"), or "". */
    public function extension(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_pn_extension($this->blob));
    }

    /** True if the number keeps an Italian leading zero. */
    public function italianLeadingZero(): bool
    {
        return self::ffi()->aether_pn_embed_pn_italian_leading_zero($this->blob) !== 0;
    }

    /** How the country code was determined (a SRC_* CountryCodeSource). */
    public function source(): int
    {
        return self::ffi()->aether_pn_embed_pn_source($this->blob);
    }

    /** A non-empty error string if the parse failed, else "". */
    public function error(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_pn_error($this->blob));
    }

    /** The region the parsed number belongs to ("US"), or "". */
    public function regionCode(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_region_code_for_number($this->blob));
    }

    /** The national significant number. */
    public function nationalSignificantNumber(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_national_significant_number($this->blob));
    }

    /** The length of the national destination code (0 if none). */
    public function lengthOfNdc(): int
    {
        return self::ffi()->aether_pn_embed_length_of_ndc($this->blob);
    }

    /** The length of the area code (0 if none). */
    public function lengthOfAreaCode(): int
    {
        return self::ffi()->aether_pn_embed_length_of_area_code($this->blob);
    }

    /** True if the number is geographically associated with an area. */
    public function isGeographical(): bool
    {
        return self::ffi()->aether_pn_embed_is_geographical($this->blob) !== 0;
    }

    /** Format this parsed number as originally dialled, from $callingFrom. */
    public function formatInOriginal(string $callingFrom): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_format_in_original($this->blob, $callingFrom));
    }
}
