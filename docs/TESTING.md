# Testing Guide

## 1. Simulator smoke test

- Boot iPad simulator
- Build and launch app
- Open settings screen and verify UI flows
- Use export/share and AirPrint dialog paths

## 2. Virtual printer test (no hardware)

Run:

```bash
python3 /Users/geek/MY OWN PROJECTs/test_print/scripts/virtual_printer.py
```

In app settings:

- Simulator target: IP `127.0.0.1`, port `9100`
- Physical iPad target: host machine LAN IP, port `9100`

Verify received payload and command content.

## 3. Real printer test

- Set real printer IP and port
- Run **Print Minimal Test**
- Run **Print Test Label**
- Run normal label from main screen
- Repeat with AirPrint mode

## Acceptance criteria

- No app crashes during print workflows
- Direct TCP prints at least minimal test label
- AirPrint fallback always available
- Errors are actionable (not silent failures)
