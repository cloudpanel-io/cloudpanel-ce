#!/usr/bin/env bash
# Fix for https://github.com/cloudpanel-io/cloudpanel-ce/issues/761
# SitePhpSettingsType::getPhpVersionChoices() uses `$phpVersion + 0` which
# throws TypeError on PHP 8.0+ when $phpVersion is a non-numeric string.
set -euo pipefail

TARGET_FILE="/home/clp/htdocs/app/files/src/Form/SitePhpSettingsType.php"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "ERROR: $TARGET_FILE not found. Is CloudPanel installed?" >&2
  exit 1
fi

BACKUP="${TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$TARGET_FILE" "$BACKUP"
echo "Backup created: $BACKUP"

php <<'PHP'
<?php
$file = '/home/clp/htdocs/app/files/src/Form/SitePhpSettingsType.php';
$content = file_get_contents($file);
$original = $content;

$replacements = [
    // Documented pattern from issue #761
    'if (true === is_float($phpVersion + 0))' => 'if (preg_match(\'/^\d+\.\d+$/\', $phpVersion))',
    'if (is_float($phpVersion + 0))' => 'if (preg_match(\'/^\d+\.\d+$/\', $phpVersion))',
    // Obfuscated variants may use different spacing
    'is_float($phpVersion + 0)' => 'preg_match(\'/^\d+\.\d+$/\', $phpVersion)',
    'is_float((float) $phpVersion)' => 'preg_match(\'/^\d+\.\d+$/\', $phpVersion)',
];

foreach ($replacements as $search => $replace) {
    $content = str_replace($search, $replace, $content);
}

// Fallback: regex for any variable name used in getPhpVersionChoices-style checks
$content = preg_replace(
    '/is_float\s*\(\s*(\$\w+)\s*\+\s*0\s*\)/',
    'preg_match(\'/^\\d+\\.\\d+$/\', $1)',
    $content
) ?? $content;

if ($content === $original) {
    fwrite(STDERR, "ERROR: No matching pattern found in $file.\n");
    fwrite(STDERR, "The file may already be patched or use a different code structure.\n");
    exit(1);
}

if (file_put_contents($file, $content) === false) {
    fwrite(STDERR, "ERROR: Failed to write $file\n");
    exit(1);
}

echo "SUCCESS: Patched SitePhpSettingsType.php for issue #761\n";
echo "PHP version directory detection now uses preg_match('/^\\d+\\.\\d+$/', \$phpVersion)\n";
PHP
