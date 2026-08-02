# 🌐 CIDR Inspector

A small, self‑contained Ruby CLI that inspects an IPv4 CIDR block and prints its network details in a table. It uses the **TTY toolkit** for prompts and table rendering, and installs its own dependencies at runtime via `bundler/inline`.

---

## ✨ Features

- Accepts a CIDR block as a CLI argument or via an interactive prompt
- Validates the input is a well‑formed CIDR (`x.x.x.x/y`)
- Prints network, range start, range end, and total host count
- Renders output as an ASCII table

---

## 🧰 Requirements

- Ruby 3.x (or a reasonably recent 2.7+)
- Internet access on first run (to install gems inline)

The script automatically installs:

- `tty-prompt`
- `tty-table`

No manual gem installation required.

---

## 🚀 Usage

Pass the CIDR block as an argument:

```bash
ruby cidr.rb 10.0.0.0/16
```

Or run without arguments to be prompted:

```bash
ruby cidr.rb
```
