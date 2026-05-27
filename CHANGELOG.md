# Changelog

## 0.0.1

### Added
- Added `1.Host/1.environment_install.sh` environment preflight checks for `rclone` and `rsync` binaries.
- Added `.env` validation for required sync parameters before running mount and sync workflows.
- Added automatic `rclone config` guidance when the configured remote is missing.

### Changed
- Implemented full `2.Drive/drive-update.sh` workflow: temporary mount creation, `rclone mount`, `rsync` sync, cleanup, and unmount handling.
- Standardized naming from target-oriented wording to remote-oriented wording (`RCLONE_REMOTE`, `RCLONE_REMOTE_SUBDIR`) while keeping backward compatibility for legacy `RCLONE_TARGET`.
- Updated `2.Drive/.env.example` comments to match the expected input style (`RCLONE_REMOTE` as remote name only, plus subdirectory path and exclude prefix usage).
