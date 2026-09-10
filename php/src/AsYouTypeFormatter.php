<?php

/**
 * Formats a number as it is typed, digit by digit (ABI v5).
 *
 * The formatter state is a caller-owned ABI string; each {@see inputDigit()}
 * threads a new state and frees the old one through {@see Native::takeString()}.
 * Carries no phone-number logic — every method marshals to an
 * `aether_pn_embed_ayt_*` call.
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

use FFI;

final class AsYouTypeFormatter
{
    /** The caller-owned formatter-state string. */
    private string $state;

    public function __construct(string $region)
    {
        $ffi = self::ffi();
        $this->state = Native::takeString($ffi, $ffi->aether_pn_embed_ayt_new($region));
    }

    private static function ffi(): FFI
    {
        return Native::load();
    }

    /** Feed one character; return the formatted-so-far string. */
    public function inputDigit(string $ch): string
    {
        $ffi = self::ffi();
        $this->state = Native::takeString($ffi, $ffi->aether_pn_embed_ayt_input($this->state, $ch));
        return $this->result();
    }

    /** The formatted-so-far string. */
    public function result(): string
    {
        $ffi = self::ffi();
        return Native::takeString($ffi, $ffi->aether_pn_embed_ayt_result($this->state));
    }

    /** Reset the formatter. */
    public function clear(): void
    {
        $ffi = self::ffi();
        $this->state = Native::takeString($ffi, $ffi->aether_pn_embed_ayt_clear($this->state));
    }
}
