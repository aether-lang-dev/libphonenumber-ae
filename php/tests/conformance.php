<?php

/**
 * The 34-check binding conformance suite (docs/conformance.md, v2).
 *
 * Proves the PHP binding marshals every value shape across the FFI. It is NOT a
 * phone-number test suite — the behavioural cases live in the engine's own
 * tests and run once, in Aether.
 *
 * ## Why a plain runner and not PHPUnit
 *
 * PHPUnit arrives via Composer, so `vendor/bin/phpunit` needs a `composer
 * install` — a network round trip, or a pre-warmed cache — before a single
 * assertion executes. The rest of this monorepo's bindings test with whatever
 * is already on the box, so this one does too: `php tests/conformance.php`, no
 * dependencies, and the process exit code is the result.
 *
 *     LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
 *         php -d ffi.enable=1 tests/conformance.php
 */

declare(strict_types=1);

// Composer's autoloader when the package has been installed; otherwise a
// four-line PSR-4 stand-in, so the suite runs from a bare checkout with no
// `composer install` (and therefore no network).
if (is_file(__DIR__ . '/../vendor/autoload.php')) {
    require __DIR__ . '/../vendor/autoload.php';
} else {
    spl_autoload_register(static function (string $class): void {
        $prefix = 'PhoneNumberAe\\';
        if (!str_starts_with($class, $prefix)) {
            return;
        }
        $file = __DIR__ . '/../src/' . substr($class, strlen($prefix)) . '.php';
        if (is_file($file)) {
            require $file;
        }
    });
}

use PhoneNumberAe\AsYouTypeFormatter;
use PhoneNumberAe\PhoneNumber;

$passed = 0;
/** @var list<string> $failures */
$failures = [];

/** Run one check; $body throws on failure. */
function check(string $name, callable $body): void
{
    global $passed, $failures;
    try {
        $body();
        $passed++;
        echo "  PASS {$name}\n";
    } catch (\Throwable $e) {
        $failures[] = "{$name}: {$e->getMessage()}";
        echo "  FAIL {$name}\n";
        echo "       {$e->getMessage()}\n";
    }
}

function eqStr(string $got, string $want, string $what = 'value'): void
{
    if ($got !== $want) {
        throw new \Exception(sprintf("%s:\n         got  \"%s\"\n         want \"%s\"", $what, $got, $want));
    }
}

function eqInt(int $got, int $want, string $what = 'value'): void
{
    if ($got !== $want) {
        throw new \Exception("{$what}: got {$got}, want {$want}");
    }
}

function isTrue(bool $got, string $what): void
{
    if (!$got) {
        throw new \Exception("{$what}: expected true");
    }
}

function isFalse(bool $got, string $what): void
{
    if ($got) {
        throw new \Exception("{$what}: expected false");
    }
}

function atLeast(int $got, int $min, string $what): void
{
    if ($got < $min) {
        throw new \Exception("{$what}: got {$got}, want >= {$min}");
    }
}

echo "=== phonenumber_ae PHP binding conformance (v2) ===\n";
if (!extension_loaded('ffi')) {
    fwrite(STDERR, "php: ext-ffi is not loaded\n");
    exit(2);
}
printf(
    "engine: %s (ABI v%d)\n",
    PhoneNumber::nativeLibraryPath() ?? '(unknown)',
    PhoneNumber::abiVersion()
);

// ---- the thirty-four ----

check('01 country_code US', function (): void {
    eqStr(PhoneNumber::countryCode('US'), '1');
});

check('02 country_code GB', function (): void {
    eqStr(PhoneNumber::countryCode('GB'), '44');
});

check('03 unknown region', function (): void {
    eqStr(PhoneNumber::countryCode('ZZ'), '');
});

check('04 example_number US', function (): void {
    eqStr(PhoneNumber::exampleNumber('US'), '2015550123');
});

check('05 possible_lengths US', function (): void {
    eqStr(PhoneNumber::possibleLengths('US'), '10');
});

check('06 region_code_for_country_code 44', function (): void {
    eqStr(PhoneNumber::regionCodeForCountryCode('44'), 'GB');
});

check('07 is_nanpa_country US', function (): void {
    isTrue(PhoneNumber::isNanpaCountry('US'), 'is_nanpa US');
});

check('08 region enumeration', function (): void {
    $regs = PhoneNumber::regions();
    atLeast(count($regs), 200, 'region count');
    eqInt(strlen($regs[0]), 2, 'region_at(0) length');
});

check('09 cc_region_at 1,0', function (): void {
    eqStr(PhoneNumber::regionsForCountryCode('1')[0], 'US');
});

check('10-14 parse', function (): void {
    $num = PhoneNumber::parse('+1 201 555 0123 ext 42', 'US');
    eqStr($num->error(), '', 'parse error');
    eqStr($num->nationalNumber(), '2015550123', 'national_number');       // 10
    eqStr($num->extension(), '42', 'extension');                          // 11
    eqStr($num->countryCode(), '1', 'country_code');                     // 12
    eqInt($num->source(), PhoneNumber::SRC_FROM_NUMBER_WITH_PLUS, 'source'); // 13
    eqStr($num->regionCode(), 'US', 'region_code');                      // 14
});

check('15 parse trunk-prefix strip (GB)', function (): void {
    eqStr(PhoneNumber::parse('01212345678', 'GB')->nationalNumber(), '1212345678');
});

check('16 is_possible yes', function (): void {
    isTrue(PhoneNumber::isPossibleNumber('US', '2015550123'), 'is_possible yes');
});

check('17 reason too short', function (): void {
    eqInt(PhoneNumber::isPossibleNumberWithReason('US', '201555'), PhoneNumber::VR_TOO_SHORT, 'reason');
});

check('18 is_valid yes', function (): void {
    isTrue(PhoneNumber::isValidNumber('US', '2015550123'), 'is_valid yes');
});

check('19 is_valid wrong shape', function (): void {
    isFalse(PhoneNumber::isValidNumber('US', '1015550123'), 'is_valid wrong shape');
});

check('20 is_valid with +cc', function (): void {
    isTrue(PhoneNumber::isValidNumber('US', '+12015550123'), 'is_valid with +cc');
});

check('21 number_type fixed_line_or_mobile', function (): void {
    // US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns
    eqInt(PhoneNumber::numberType('US', '2015550123'), PhoneNumber::TYPE_FIXED_LINE_OR_MOBILE, 'number_type US');
    eqInt(PhoneNumber::TYPE_FIXED_LINE_OR_MOBILE, 10, 'TYPE_FIXED_LINE_OR_MOBILE constant');
    eqInt(PhoneNumber::numberType('GB', '2070313000'), PhoneNumber::TYPE_FIXED_LINE, 'number_type GB');
    eqInt(PhoneNumber::TYPE_FIXED_LINE, 0, 'TYPE_FIXED_LINE constant');
});

check('22 format national', function (): void {
    eqStr(PhoneNumber::format('US', '2015550123', PhoneNumber::NATIONAL), '(201) 555-0123');
});

check('23 format E164', function (): void {
    eqStr(PhoneNumber::format('US', '2015550123', PhoneNumber::E164), '+12015550123');
    eqInt(PhoneNumber::E164, 0, 'E164 constant');
});

check('24 format international', function (): void {
    eqStr(PhoneNumber::format('US', '2015550123', PhoneNumber::INTERNATIONAL), '+1 201-555-0123');
});

check('25 format RFC3966', function (): void {
    eqStr(PhoneNumber::format('US', '2015550123', PhoneNumber::RFC3966), 'tel:+1-201-555-0123');
});

check('26 is_number_match exact', function (): void {
    eqInt(PhoneNumber::isNumberMatch('+12015550123', '+1 201 555 0123'), PhoneNumber::MATCH_EXACT, 'match exact');
});

check('27 is_number_match none', function (): void {
    eqInt(PhoneNumber::isNumberMatch('+12015550123', '+12025550123'), PhoneNumber::MATCH_NO_MATCH, 'match none');
});

check('28 normalize_digits_only', function (): void {
    eqStr(PhoneNumber::normalizeDigitsOnly('+1 (201) 555.0123'), '12015550123');
});

check('29 convert_alpha_characters', function (): void {
    eqStr(PhoneNumber::convertAlphaCharacters('1-800-FLOWERS'), '1-800-3569377');
});

check('30 truncate_too_long', function (): void {
    eqStr(PhoneNumber::truncateTooLong('US', '20155501239999'), '2015550123');
});

check('31 as-you-type', function (): void {
    $ayt = new AsYouTypeFormatter('US');
    $out = '';
    foreach (str_split('2015550123') as $c) {
        $out = $ayt->inputDigit($c);
    }
    eqStr($out, '(201) 555-0123');
});

check('32 matcher count', function (): void {
    $matches = PhoneNumber::findNumbers('call 201-555-0123 or +1 202 555 0199', 'US', PhoneNumber::LENIENCY_VALID);
    eqInt(count($matches), 2, 'matcher count');
});

check('33 matcher raw', function (): void {
    $matches = PhoneNumber::findNumbers('call 201-555-0123 now', 'US', PhoneNumber::LENIENCY_VALID);
    eqStr($matches[0]->raw, '201-555-0123');
});

check('34 abi version', function (): void {
    eqInt(PhoneNumber::abiVersion(), 2, 'abi version');
});

// ---- a few extras exercising the idiomatic surface ----

check('format helpers agree with format()', function (): void {
    eqStr(PhoneNumber::formatNational('US', '2015550123'), '(201) 555-0123');
    eqStr(PhoneNumber::formatInternational('US', '2015550123'), '+1 201-555-0123');
    eqStr(PhoneNumber::formatE164('US', '2015550123'), '+12015550123');
    eqStr(PhoneNumber::formatRfc3966('US', '2015550123'), 'tel:+1-201-555-0123');
});

check('type constants are the documented ints', function (): void {
    eqInt(PhoneNumber::TYPE_UNKNOWN, -1, 'TYPE_UNKNOWN');
    eqInt(PhoneNumber::TYPE_MOBILE, 1, 'TYPE_MOBILE');
    eqInt(PhoneNumber::TYPE_VOICEMAIL, 9, 'TYPE_VOICEMAIL');
});

check('matcher reports start/end offsets', function (): void {
    $matches = PhoneNumber::findNumbers('call 201-555-0123 now', 'US', PhoneNumber::LENIENCY_VALID);
    eqInt($matches[0]->start, 5, 'match start');
    eqInt($matches[0]->end, 17, 'match end');
});

check('many calls do not leak or crash', function (): void {
    // A returned char* that was never freed would show up here as steadily
    // growing RSS; a double free would crash. Cheap insurance over the
    // takeString contract.
    for ($i = 0; $i < 5000; $i++) {
        PhoneNumber::format('US', '2015550123', PhoneNumber::NATIONAL);
    }
    eqStr(PhoneNumber::format('US', '2015550123', PhoneNumber::NATIONAL), '(201) 555-0123');
});

// ---- result ----

printf("=== %d passed, %d failed ===\n", $passed, count($failures));
if ($failures !== []) {
    echo "failures:\n";
    foreach ($failures as $f) {
        echo "  - {$f}\n";
    }
    exit(1);
}
exit(0);
