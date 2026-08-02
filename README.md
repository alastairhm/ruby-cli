# Ruby CLI

Some Ruby CLI style scripts for various things using the TTY toolkit.

Each script is self-contained and installs its own dependencies at runtime via `bundler/inline` — no `Gemfile` or setup required, just `ruby <script>.rb`.

## Scripts

| Script | Description | Docs |
| --- | --- | --- |
| [`cidr.rb`](cidr.rb) | Inspects an IPv4 CIDR block and prints network, range, and host count details as a table. | [cidr.md](cidr.md) |
| [`organise.rb`](organise.rb) | Tidies your `~/Downloads` folder by sorting files into category-based subdirectories. | [organise.md](organise.md) |
| [`qrgen.rb`](qrgen.rb) | Generates QR codes from text, URLs, WiFi credentials, or a batch file. | [qrgen.md](qrgen.md) |

See [CHANGELOG.md](CHANGELOG.md) for release history.
