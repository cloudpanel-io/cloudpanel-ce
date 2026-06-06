<?php
/**
 * Validates the PHP version directory detection logic from issue #761.
 * Run: php community-fixes/test-761-fix-logic.php
 */

function isValidPhpVersionDirectory(string $phpVersion): bool
{
    return (bool) preg_match('/^\d+\.\d+$/', $phpVersion);
}

$tests = [
    ['8.4', true],
    ['8.1', true],
    ['7.4', true],
    ['conf.d', false],
    ['.', false],
    ['..', false],
    ['php-fpm', false],
    ['8', false],
    ['8.4.1', false],
];

$failed = 0;
foreach ($tests as [$input, $expected]) {
    $actual = isValidPhpVersionDirectory($input);
    if ($actual !== $expected) {
        echo "FAIL: '$input' expected " . ($expected ? 'true' : 'false') . ", got " . ($actual ? 'true' : 'false') . PHP_EOL;
        $failed++;
    }
}

if ($failed > 0) {
    echo "$failed test(s) failed." . PHP_EOL;
    exit(1);
}

echo 'All tests passed.' . PHP_EOL;
