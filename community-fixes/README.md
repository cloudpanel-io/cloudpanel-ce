# Community Fixes

CloudPanel CE tracks issues in this repository, but the application source is distributed via the `cloudpanel` Debian package and is not published here. These scripts patch installed CloudPanel servers for well-defined bugs reported in GitHub issues.

## Available Fixes

| Issue | Script | Description |
|-------|--------|-------------|
| [#761](https://github.com/cloudpanel-io/cloudpanel-ce/issues/761) | [fix-761-site-php-settings-type.sh](./fix-761-site-php-settings-type.sh) | Fixes PHP 8+ TypeError in `SitePhpSettingsType::getPhpVersionChoices()` |
| [#758](https://github.com/cloudpanel-io/cloudpanel-ce/issues/758) | [fix-758-site-delete-crontab.sh](./fix-758-site-delete-crontab.sh) | Removes orphan user crontabs during `site:delete` |
| [#758](https://github.com/cloudpanel-io/cloudpanel-ce/issues/758) | [cleanup-orphan-crontabs.sh](./cleanup-orphan-crontabs.sh) | One-time cleanup for existing orphan crontab files |

## Usage

Run as root on a CloudPanel server:

```bash
curl -fsSL https://raw.githubusercontent.com/cloudpanel-io/cloudpanel-ce/master/community-fixes/fix-761-site-php-settings-type.sh | sudo bash
```

Or clone this repository and run the script directly:

```bash
sudo bash community-fixes/fix-761-site-php-settings-type.sh
```

Each script creates a timestamped backup before modifying files.

## Reverting

Backups are written next to the patched file with a `.bak.YYYYMMDDHHMMSS` suffix. To revert:

```bash
cp /path/to/file.bak.TIMESTAMP /path/to/file
```

## Contributing

If you have a fix for another open issue, add a script here and reference the issue number in the filename and script header.
