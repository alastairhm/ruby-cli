# dnscheck.rb

[#dnscheck](#dnscheck)

Resolves one or more hostnames against one or more DNS servers and prints the
result, timing, and any disagreement between servers as a table. Handy for
confirming a resolver (e.g. a local Pi-hole) is actually being used, or that
internal and external DNS agree on a name.

Self-contained — installs its own dependencies at runtime via `bundler/inline`,
just `ruby dnscheck.rb`.

## Usage

[#usage](#usage)

```
dnscheck.rb [hostnames...] [options]
```

### Options

| Flag | Description |
| --- | --- |
| `-s, --servers list` | Comma-separated DNS server IPs. Use `system` to include your machine's default resolver. Default: `system,1.1.1.1,8.8.8.8` |
| `-f, --file path` | File with one hostname per line (`#` comments and blank lines ignored) |
| `--type string` | Record type: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`. Default: `A` |
| `-t, --timeout float` | Per-query timeout in seconds. Default: `2.0` |
| `--strict` | Exit non-zero if any query fails or servers disagree |
| `-h, --help` | Print usage |

## Examples

[#examples](#examples)

Check a single host against the default servers (system resolver, Cloudflare, Google):

```
$ ruby dnscheck.rb example.com
```

Check several hosts against your Pi-hole and a public resolver, to confirm they agree:

```
$ ruby dnscheck.rb example.com github.com --servers 192.168.1.2,1.1.1.1
```

Batch-check a list of internal hosts from a file, AAAA records, with a tighter timeout:

```
$ ruby dnscheck.rb --file hosts.txt --servers 192.168.1.2 --type AAAA --timeout 1
```

Use in a script/CI step, failing the run if anything looks wrong:

```
$ ruby dnscheck.rb --file hosts.txt --strict || echo "DNS check failed"
```

## Notes

[#notes](#notes)

- `system` as a server label uses Ruby's default `Resolv::DNS` resolver (whatever
  your OS/network is configured to use) rather than querying a specific IP.
- A spinner shows which host/server is being queried while lookups run. It's
  only drawn when output is a terminal, so redirecting or piping the output
  gives just the table.
- A "servers disagree" warning means the servers returned different (but
  successful) answers for the same host and record type — not necessarily a
  problem, but worth a look if you expect consistency (e.g. split-horizon DNS
  gone wrong). Answers are sorted before comparing, so the same records
  returned in a different order don't count as a disagreement.
- Failures are reported per-server so one broken resolver doesn't hide results
  from the others.
