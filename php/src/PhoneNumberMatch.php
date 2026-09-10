<?php

/**
 * One phone number found in free text by {@see PhoneNumber::findNumbers()}.
 *
 * A plain value: the 0-based `start`/`end` offsets into the source text and the
 * `raw` substring that matched.
 *
 * @package PhoneNumberAe
 */

declare(strict_types=1);

namespace PhoneNumberAe;

final class PhoneNumberMatch
{
    public function __construct(
        public readonly int $start,
        public readonly int $end,
        public readonly string $raw,
    ) {
    }
}
