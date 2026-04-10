# COBOL Design Document Generator

> A Windows desktop app that automatically generates design documents (Excel / Word) from COBOL source code — no manual work required.

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/cobol-bridge/batch-sekkei-maker/releases)

---

## Why we built this

In financial, insurance, and government systems, COBOL batch programs are still running in production.  
But in many organizations, **design documents don't exist, are outdated, or no longer match the actual source code**.

Even experienced engineers — sometimes the only person who ever touched the code — can no longer fully explain what a program does.

This tool solves that problem: **just select a COBOL source file and click a button**.  
It runs **completely offline**, so your confidential source code never leaves your machine.

---

## Features

| | |
|---|---|
| 🔒 **100% Offline** | Source code is never sent anywhere |
| ⚡ **One-click generation** | Select a file, click the button — done |
| 📊 **Excel & Word output** | Choose the format that fits your workflow |
| 🗂 **4 document sheets** | Cover, I/O definitions, Process flow, Exception handling |
| 📁 **Batch folder processing** | Process dozens of COBOL files at once |
| 🖥 **Windows .exe** | No Python required — just run it |

---

## What gets generated

| Sheet / Section | Content |
|---|---|
| **Cover** | Source file name, generation date, version |
| **I/O Definitions** | SELECT clauses, FD names, record length, physical file name, organization, access mode, record key |
| **Process Flow** | PERFORM call hierarchy (THRU / UNTIL / VARYING supported) |
| **Exception Handling** | INVALID KEY / AT END / ON SIZE ERROR list |

---

## Requirements

- Windows 10 / 11 (64-bit)
- No internet connection required
- No Python required (when using the .exe version)

---

## Installation & Usage

### .exe version (recommended)

1. Download `バッチ設計書メーカー.exe` from [Releases](https://github.com/cobol-bridge/batch-sekkei-maker/releases)
2. Double-click to launch
3. Select a COBOL source file → Select output folder → Click **"Generate Document"**

### For developers

```bash
# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run
python main.py

# Run tests
pytest tests/ -v

# Build .exe
pyinstaller batch_sekkei_maker.spec --distpath dist --workpath build --noconfirm
```

---

## Supported COBOL dialects

- IBM Enterprise COBOL (fixed format)
- Shift-JIS / UTF-8 encoding support

---

## License

MIT License — free to use, modify, and distribute.

---

## About COBOL BRIDGE

This tool is part of the **COBOL BRIDGE** project — building lightweight, free tools to help engineers understand and modernize legacy COBOL systems.

- GitHub: [cobol-bridge](https://github.com/cobol-bridge)
