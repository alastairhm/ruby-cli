# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] - 2026-10-26

First tagged release.

### Added

- `cidr.rb` to inspect an IPv4 CIDR block and print its network, range and host count as a table.
- `organise.rb` to tidy `~/Downloads` by sorting files into category subdirectories. Documented in `organise.md`.
- `qrgen.rb` to generate QR codes from text, URLs, WiFi credentials or a batch file. Documented in `qrgen.md`.
- `dnscheck.rb` to resolve hostnames against multiple DNS servers (system resolver, 1.1.1.1 and 8.8.8.8 by default) and flag failures or disagreement, with a progress spinner while lookups run. Documented in `dnscheck.md`.
- `dnscheck.rb` interactive TUI: run with no hostnames to get a full-screen results box and an input line for typing domains (optionally with a record type, e.g. `gmail.com mx`), with a spinner, input history and scrolling. A blank line exits.
- `CLAUDE.md` with guidance for working in this repo.
- `CHANGELOG.md` to track project history.
- `cidr.md` documenting the CIDR inspector script.
- Script overview table in `README.md` linking to each script's docs.
- RuboCop linting, configured in `.rubocop.yml` to match this repo's conventions (e.g. double-quoted strings), run on every PR via `.github/workflows/lint.yml`.

### Fixed

- `dnscheck.rb` no longer crashes (`undefined method 'rindex' for nil` inside tty-table) when a long answer, such as a domain's MX or TXT records, doesn't fit the terminal; multi-record answers are now shown one per line and over-long values are truncated.
- `dnscheck.rb` sorts IP addresses numerically and MX records by preference, rather than as text (which put `5 gmail-smtp-in…` after `40 alt4…`).
- `organise.rb` no longer silently overwrites an existing file in the destination category folder on a filename collision; it now appends a numeric suffix instead.
- `organise.rb` exits with a clear message instead of crashing when `~/Downloads` doesn't exist.
- `qrgen.rb` `batch` mode no longer silently overwrites existing `qr_N.png` files; it now uses the same collision-avoiding filename logic as `generate`/`wifi`.
- `qrgen.rb` no longer crashes with an unhandled exception when input text is too large to encode as a QR code; `generate`/`wifi` abort with a clear error, and `batch` skips the offending line and continues.

### Changed

- `dnscheck.rb` queries each host against all servers in parallel.
- `.rubocop.yml` disables `Metrics/ClassLength`, since a script's tty-option DSL alone runs to dozens of declarative lines.
- `organise.rb` freezes the `RULES` constant and `cidr.rb` gained a `# frozen_string_literal: true` comment, matching the other scripts and satisfying RuboCop.
- Ruby pinned in `.tool-versions` bumped from 3.4.7 to 3.4.12.

### Removed

- Unused `tty-spinner` and unnecessary `fileutils` gem declarations from `organise.rb`'s inline `Gemfile` (the latter caused a spurious Bundler version-resolution warning on every run).

[Unreleased]: https://github.com/alastairhm/ruby-cli/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/alastairhm/ruby-cli/releases/tag/v1.0.0
