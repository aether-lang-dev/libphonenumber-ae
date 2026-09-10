<?php

/**
 * A short tour of the PHP binding. Run it with the engine built:
 *
 *   aeb core/.build.ae
 *   cd php && LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
 *       php -d ffi.enable=1 example/main.php
 */

declare(strict_types=1);

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

use PhoneNumberAe\AsYouTypeFormatter;
use PhoneNumberAe\PhoneNumber;

printf(
    "engine: %s (ABI v%d)\n",
    PhoneNumber::nativeLibraryPath() ?? '(unknown)',
    PhoneNumber::abiVersion()
);

// 1. country codes
printf("US -> +%s, GB -> +%s\n", PhoneNumber::countryCode('US'), PhoneNumber::countryCode('GB'));

// 2. parse into a ParsedNumber and read its fields
$num = PhoneNumber::parse('+1 201 555 0123 ext 42', 'US');
printf(
    "parsed: nsn=%s ext=%s cc=%s region=%s\n",
    $num->nationalNumber(),
    $num->extension(),
    $num->countryCode(),
    $num->regionCode()
);

// 3. validate and classify
printf("US 2015550123 valid? %s\n", PhoneNumber::isValidNumber('US', '2015550123') ? 'yes' : 'no');
printf("US 2015550123 type:  %d\n", PhoneNumber::numberType('US', '2015550123'));

// 4. format it four ways
printf("national:      %s\n", PhoneNumber::formatNational('US', '2015550123'));
printf("international:  %s\n", PhoneNumber::formatInternational('US', '2015550123'));
printf("e164:          %s\n", PhoneNumber::formatE164('US', '2015550123'));
printf("rfc3966:       %s\n", PhoneNumber::formatRfc3966('US', '2015550123'));

// 5. format as it is typed
$ayt = new AsYouTypeFormatter('US');
$typed = '';
foreach (str_split('6502530000') as $c) {
    $typed = $ayt->inputDigit($c);
}
printf("as-you-type:   %s\n", $typed);

// 6. find numbers in free text
$matches = PhoneNumber::findNumbers('call 201-555-0123 or +1 202 555 0199', 'US');
printf("%d matches, first raw: %s\n", count($matches), $matches[0]->raw);

// 7. the region table
$regs = PhoneNumber::regions();
printf("%d regions, first: %s\n", count($regs), $regs[0]);
