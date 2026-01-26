# 📦 QRGen — Self‑Contained Ruby QR Generator

`qrgen` is a **single‑file, self‑contained Ruby CLI tool** for generating QR codes.  
It installs its own dependencies automatically, uses the TTY Toolkit for a smooth interactive experience, and includes a tiny dispatcher for subcommands.

No Gemfile.  
No setup.  
Just run it.

---

## ✨ Features

- **Self‑contained** — all dependencies auto‑install via `bundler/inline`
- **TTY Toolkit UI** — prompts, spinners, clean terminal UX
- **Tiny dispatcher** — supports multiple subcommands
- **Smart file numbering**
  - Creates `qr.png` if unused
  - Otherwise `qr_2.png`, `qr_3.png`, etc.
- **Batch mode** for generating multiple QR codes
- **WiFi QR mode** (WPA format)
- **PNG output** with crisp rendering

---

## 🚀 Installation

Save the script as `qrgen` (or any name you prefer):


