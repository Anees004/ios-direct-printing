# Demo
<img width="605" height="857" alt="image" src="https://github.com/user-attachments/assets/4f7d36b2-30cb-4142-b44f-8c37c96ee3a0" /> <img width="605" height="857" alt="image" src="https://github.com/user-attachments/assets/521a6d5e-6579-450e-94e4-f3ca7939f1b3" /> <img width="605" height="857" alt="image" src="https://github.com/user-attachments/assets/87072afe-6427-4cdf-832a-db9abfd209c3" />
<img width="605" height="857" alt="image" src="https://github.com/user-attachments/assets/fa28fb4d-e828-4919-800f-972360be0d73" />



# One-Tap iOS Direct Printing

A practical iOS/iPadOS reference project for **direct label printing with one tap**.

This repo is designed for teams that want:
- No AirPrint dialog in the core flow
- Fast and predictable label output
- A clean integration path into existing mobile apps
- Debuggable behavior on simulator and real devices

## What this solves

Many mobile print implementations fail in production because they rely on UI dialogs, hidden printer settings, or weak error handling. This project shows a deterministic approach:
- Build TSPL commands in-app
- Send directly to printer TCP socket (`9100`)
- Track print state and errors clearly
- Keep queueing and retries controlled

## How It Works

```mermaid
flowchart LR
    A[User taps Print] --> B[ContentView]
    B --> C[PrinterService.printRaw]
    C --> D[TSPLGenerator.generate]
    D --> E[NWConnection TCP 9100]
    E --> F[Label Printer]
    F --> G[Physical label output]
```

## Core Principles

- Direct first: direct TCP is the primary path
- One tap: user should not navigate system dialogs to print
- Deterministic output: label size and commands are controlled by app config
- Friendly failure: when print fails, user gets actionable error text

## Project Structure

- `test_print/` Swift source files
- `test_print.xcodeproj/` Xcode project
- `docs/ARCHITECTURE.md` system design and flow diagrams
- `docs/INTEGRATION.md` copy-paste integration guide
- `docs/TROUBLESHOOTING.md` production issue diagnosis
- `docs/TESTING.md` simulator, virtual printer, and real-device validation
- `scripts/virtual_printer.py` local TCP sink to inspect payloads

## Quick Start

1. Open `test_print.xcodeproj`.
2. Run on iPad simulator or real iPad.
3. In app settings, set printer IP + port (`9100`).
4. Tap **Print Label**.
5. If needed, run the virtual printer from `scripts/virtual_printer.py` to validate payloads.

## Read These Next

1. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
2. [`docs/INTEGRATION.md`](docs/INTEGRATION.md)
3. [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)
4. [`docs/TESTING.md`](docs/TESTING.md)

## Scope

This repository intentionally focuses on print behavior only. It avoids unrelated app features so developers can integrate the print engine quickly.

## License

Add your preferred license before publishing.
