#!/usr/bin/env bash
# Fix for https://github.com/cloudpanel-io/cloudpanel-ce/issues/758
# site:delete removes /etc/cron.d/<user> but leaves /var/spool/cron/crontabs/<user>,
# causing cron "Authentication failure" spam after user deletion.
set -euo pipefail

APP_SRC="/home/clp/htdocs/app/files/src"
CRONTAB_SPOOL="/var/spool/cron/crontabs"

if [[ ! -d "$APP_SRC" ]]; then
  echo "ERROR: $APP_SRC not found. Is CloudPanel installed?" >&2
  exit 1
fi

mapfile -t CANDIDATES < <(grep -rl 'userdel' "$APP_SRC" 2>/dev/null || true)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "ERROR: No files containing 'userdel' found under $APP_SRC" >&2
  exit 1
fi

TARGET_FILE=""
for candidate in "${CANDIDATES[@]}"; do
  if grep -qE 'site:delete|SiteDelete|DeleteSite|domainName' "$candidate" 2>/dev/null; then
    TARGET_FILE="$candidate"
    break
  fi
done

if [[ -z "$TARGET_FILE" ]]; then
  for candidate in "${CANDIDATES[@]}"; do
    if grep -qE "userdel.*-rf|'userdel',\s*'-rf'" "$candidate" 2>/dev/null; then
      TARGET_FILE="$candidate"
      break
    fi
  done
fi

if [[ -z "$TARGET_FILE" ]]; then
  echo "ERROR: Could not locate site delete command file." >&2
  exit 1
fi

if grep -qE 'crontab.*-r|/var/spool/cron/crontabs' "$TARGET_FILE"; then
  echo "Already patched: $TARGET_FILE handles crontab cleanup"
  exit 0
fi

BACKUP="${TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$TARGET_FILE" "$BACKUP"
echo "Backup created: $BACKUP"
echo "Patching: $TARGET_FILE"

php <<PHP
<?php
\$file = '$TARGET_FILE';
\$content = file_get_contents(\$file);
\$original = \$content;

\$userVar = null;
\$patterns = [
    "/['\"]userdel['\"]\s*,\s*['\"]-rf['\"]\s*,\s*(\\\$[a-zA-Z_][a-zA-Z0-9_]*)/",
    "/userdel\\s+-rf\\s+['\"]?\\.?\\.?\\.?\\s*(\\\$[a-zA-Z_][a-zA-Z0-9_]*)/",
    "/userdel\\s+-rf\\s+\\.\\s*(\\\$[a-zA-Z_][a-zA-Z0-9_]*)/",
];

foreach (\$patterns as \$pattern) {
    if (preg_match(\$pattern, \$content, \$matches)) {
        \$userVar = \$matches[1];
        break;
    }
}

if (\$userVar === null) {
    fwrite(STDERR, "ERROR: Could not detect site user variable near userdel in \$file\n");
    exit(1);
}

\$injection = <<<PATCH

        // Remove user crontab before deleting the system user (issue #758)
        if (class_exists(Process::class)) {
            (new Process(['crontab', '-r', '-u', {$userVar}]))->run();
        } else {
            exec(sprintf('crontab -r -u %s 2>/dev/null', escapeshellarg({$userVar})));
        }
        @unlink(sprintf('/var/spool/cron/crontabs/%s', {$userVar}));

PATCH;

\$patched = false;
\$linePatterns = [
    "/^(\\s*)(\\\$process\\s*=\\s*new\\s+Process\\s*\\(\\s*\\[\\s*['\"]userdel['\"])/m",
    "/^(\\s*)(.*userdel.*-rf.*)/m",
];

foreach (\$linePatterns as \$pattern) {
    \$result = preg_replace(\$pattern, \$injection . "\$1\$2", \$content, 1, \$count);
    if (\$count > 0 && \$result !== null) {
        \$content = \$result;
        \$patched = true;
        break;
    }
}

if (!\$patched) {
    fwrite(STDERR, "ERROR: Could not inject crontab cleanup before userdel in \$file\n");
    exit(1);
}

if (\$content === \$original) {
    fwrite(STDERR, "ERROR: No changes applied to \$file\n");
    exit(1);
}

if (file_put_contents(\$file, \$content) === false) {
    fwrite(STDERR, "ERROR: Failed to write \$file\n");
    exit(1);
}

echo "SUCCESS: Patched site delete flow for issue #758\n";
echo "Detected site user variable: {\$userVar}\n";
PHP

echo ""
echo "Cleaning up existing orphan crontabs..."
bash "$(dirname "$0")/cleanup-orphan-crontabs.sh"
