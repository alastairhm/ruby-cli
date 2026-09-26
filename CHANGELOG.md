# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `dnscheck.rb` to resolve hostnames against multiple DNS servers (system resolver, 1.1.1.1 and 8.8.8.8 by default) and flag failures or disagreement, with a progress spinner while lookups run. Documented in `dnscheck.md`.
- `CLAUDE.md` with guidance for working in this repo.
- `CHANGELOG.md` to track project history.
- `cidr.md` documenting the CIDR inspector script.
- Script overview table in `README.md` linking to each script's docs.
- RuboCop linting, configured in `.rubocop.yml` to match this repo's conventions (e.g. double-quoted strings), run on every PR via `.github/workflows/lint.yml`.

### Fixed

- `organise.rb` no longer silently overwrites an existing file in the destination category folder on a filename collision; it now appends a numeric suffix instead.
- `organise.rb` exits with a clear message instead of crashing when `~/Downloads` doesn't exist.
- `qrgen.rb` `batch` mode no longer silently overwrites existing `qr_N.png` files; it now uses the same collision-avoiding filename logic as `generate`/`wifi`.
- `qrgen.rb` no longer crashes with an unhandled exception when input text is too large to encode as a QR code; `generate`/`wifi` abort with a clear error, and `batch` skips the offending line and continues.

### Changed

- `.rubocop.yml` disables `Metrics/ClassLength`, since a script's tty-option DSL alone runs to dozens of declarative lines.
- `organise.rb` freezes the `RULES` constant and `cidr.rb` gained a `# frozen_string_literal: true` comment, matching the other scripts and satisfying RuboCop.

### Removed

- Unused `tty-spinner` and unnecessary `fileutils` gem declarations from `organise.rb`'s inline `Gemfile` (the latter caused a spurious Bundler version-resolution warning on every run).
