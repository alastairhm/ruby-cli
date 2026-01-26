# 📁 Downloads Organiser

A small, self‑contained Ruby CLI that automatically tidies your `~/Downloads` folder by sorting files into category‑based subdirectories. It uses the **TTY toolkit** for prompts and progress bars, and installs its own dependencies at runtime via `bundler/inline`.

This script is intentionally minimal, modular, and easy to extend.

---

## ✨ Features

- Scans your `~/Downloads` directory  
- Classifies files by extension into categories:
  - Images  
  - Videos  
  - Audio  
  - Documents  
  - Archives  
  - Data files (CSV, JSON, SQL, etc.)  
  - Code files (Ruby, Python, JS, Go, Rust, etc.)  
  - Other (fallback)  
- Moves files into neatly named subfolders  
- Shows a **TTY progress bar** while processing  
- Uses **inline gem installation** — no Gemfile needed  
- Safe, predictable behaviour (moves only, no deletions)  

---

## 🧰 Requirements

- Ruby 3.x (or a reasonably recent 2.7+)  
- Internet access on first run (to install gems inline)

The script automatically installs:

- `tty-prompt`
- `tty-spinner`
- `fileutils`
- `tty-progressbar`

No manual gem installation required.

---

## 🚀 Usage

Run the script directly:

```bash
ruby organise.rb
```

