# Testing Guide

This guide helps you verify direct printing safely before production rollout.

## Test Strategy

Run tests in this order:
1. iPad simulator smoke test
2. Virtual printer payload test
3. Real device + real printer functional test
4. Stress and recovery test

## 1. iPad Simulator Smoke Test

Goal: verify UI flow and print trigger logic.

Checklist:
- App launches cleanly
- Settings screen saves printer config
- One-tap print button is enabled/disabled correctly
- State text changes (`connecting`, `printing`, `error`)
- No crash when repeating prints

## 2. Virtual Printer Test (No Hardware)

Start sink:

```bash
python3 /Users/geek/MY OWN PROJECTs/test_print/scripts/virtual_printer.py
```

App target settings:
- Simulator: `127.0.0.1:9100`
- Real iPad to Mac sink: `<mac_lan_ip>:9100`

Pass criteria:
- Connection opens
- Payload received
- Payload includes required TSPL commands
- Print action completion callback returns success

## 3. Real Device + Real Printer Test

Run on actual iPad/iPhone.

Test cases:
- Minimal test label
- Standard sample label
- Long text label (edge case)
- Multiple quantity print
- Back-to-back prints (queue behavior)

Pass criteria:
- Physical output appears for each case
- No duplicate, truncated, or missing labels
- Error messages are actionable when failure occurs

## 4. Stress and Recovery

Stress:
- Send 20 sequential print jobs
- Observe queue behavior and memory stability

Recovery:
- Turn printer off during send
- Bring printer back online
- Ensure app transitions to error, then recovers on retry

## Suggested Test Matrix

| Device | OS | Printer | Network | Expected |
|---|---|---|---|---|
| iPad Pro simulator | Latest | Virtual | localhost | Payload validated |
| iPad physical | Current stable | Real printer | Office Wi-Fi | Physical label output |
| iPhone physical | Current stable | Real printer | Office Wi-Fi | Physical label output |

## Release Gate Checklist

- No print-flow crashes on real device
- Minimal test label prints reliably
- 20-job stress test passes
- Reconnect/retry path verified
- Local network permission prompt handled clearly
- Docs updated with model/firmware notes

## Notes on Simulator Limits

Simulator is good for UI and payload checks, but only a real device can validate local network permissions and real printer behavior end-to-end.
