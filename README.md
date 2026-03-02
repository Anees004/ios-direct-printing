# iOS Label Print Kit (TCP + AirPrint)

Production-focused iOS/iPadOS sample for label printing.

This repository is intentionally **print-only**:
- No web view
- No biometric/auth flows
- No unrelated client handoff artifacts

## What it does

- Direct TCP printing to network label printers (TSPL over port `9100`)
- AirPrint fallback using fixed-size PDF labels
- Label-size configuration (presets + custom)
- Printable test labels and diagnostics
- In-app debug logging for print troubleshooting

## Project layout

- `test_print/` app source
- `test_print.xcodeproj/` Xcode project
- `scripts/virtual_printer.py` local virtual printer for testing without hardware
- `docs/` integration and troubleshooting docs

## Quick start

1. Open `/Users/geek/MY OWN PROJECTs/test_print/test_print.xcodeproj` in Xcode.
2. Select an iPhone/iPad simulator or physical iPad.
3. Build and run.
4. Open **Settings** in-app and set printer IP/port.
5. Start with **Print Minimal Test**.

## Documentation

- `/Users/geek/MY OWN PROJECTs/test_print/docs/INTEGRATION.md`
- `/Users/geek/MY OWN PROJECTs/test_print/docs/TROUBLESHOOTING.md`
- `/Users/geek/MY OWN PROJECTs/test_print/docs/TESTING.md`

## License

Add your preferred license before publishing publicly.
