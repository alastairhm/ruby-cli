# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of standalone Ruby CLI scripts built on the TTY toolkit (tty-prompt, tty-table, tty-spinner, tty-progressbar). Ruby version is pinned via `.tool-versions` (3.4.7, asdf-style).

Each script is a single self-contained file — there is no shared library code, no Gemfile, and no test suite. Every script begins with `require "bundler/inline"` and declares its own gems in a `gemfile(true) do ... end` block, so dependencies are installed automatically on first run (internet access required the first time a script runs, or after gems change).

## Running scripts

Each script is executed directly with Ruby, e.g.:

```bash
ruby cidr.rb 10.0.0.0/16
ruby organise.rb
ruby qrgen.rb generate "https://example.com"
```

There is no build, lint, or test command configured in this repo.

## Adding a new script

Follow the existing pattern (see `cidr.rb`, `organise.rb`, `qrgen.rb`):

- `#!/usr/bin/env ruby` shebang, `# frozen_string_literal: true` where used.
- `require "bundler/inline"` followed by a `gemfile(true) do ... end` block listing only the gems that script needs — do not introduce a shared Gemfile.
- Use `TTY::Prompt` for interactive input (with `q.required` / `q.validate` as needed) and accept the same value via `ARGV` so the script can run non-interactively.
- Scripts that support subcommands (see `qrgen.rb`) use a plain `case ARGV.shift` dispatcher rather than an external CLI framework.
- If the script is non-trivial, add a companion `<name>.md` documenting usage (see `organise.md`, `qrgen.md`).
