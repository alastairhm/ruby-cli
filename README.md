# Ruby CLI

Some Ruby CLI style scripts for various things using the TTY toolkit.

Each script is self-contained and installs its own dependencies at runtime via `bundler/inline` — no `Gemfile` or setup required, just `ruby <script>.rb`.

## Scripts

| Script | Description | Docs |
| --- | --- | --- |
| [`cidr.rb`](cidr.rb) | Inspects an IPv4 CIDR block and prints network, range, and host count details as a table. | [cidr.md](cidr.md) |
| [`dnscheck.rb`](dnscheck.rb) | Resolves hostnames against several DNS servers and compares the answers and timings. | [dnscheck.md](dnscheck.md) |
| [`organise.rb`](organise.rb) | Tidies your `~/Downloads` folder by sorting files into category-based subdirectories. | [organise.md](organise.md) |
| [`qrgen.rb`](qrgen.rb) | Generates QR codes from text, URLs, WiFi credentials, or a batch file. | [qrgen.md](qrgen.md) |

## Linting

Pull requests are linted with [RuboCop](https://github.com/rubocop/rubocop) via GitHub Actions (see `.github/workflows/lint.yml`). To run it locally:

```bash
gem install rubocop
rubocop
```

See [CHANGELOG.md](CHANGELOG.md) for release history.
