# Troubleshooting

## Symptom: Connected but nothing prints

Check in order:

1. Printer IP/port are correct (`9100` for raw TCP).
2. iPad and printer are on the same Wi-Fi/VLAN.
3. Local Network permission is enabled for the app.
4. Run **Print Minimal Test** from settings.
5. Enable Debug Mode and inspect logs.

## Symptom: TCP connection refused

- Printer may not expose raw TCP on current network/firmware.
- Verify with a direct socket test from a laptop on same network.
- If unsupported, use AirPrint path.

## Symptom: AirPrint works, TCP fails

This is common on some wireless printer setups.
Use AirPrint as production fallback and keep TCP optional.

## Symptom: Output size/scaling is wrong

- Verify selected label size in app settings.
- Use diagnostic PDF tests to validate printer paper handling.
- Confirm printer media configuration matches app dimensions.

## Symptom: App crashes on launch or print screen

- Clean build folder and rebuild.
- Reinstall app on simulator/device.
- Confirm no stale build artifacts are used.

## Capture useful diagnostics

- Enable in-app Debug Mode.
- Export logs from `/Users/geek/MY OWN PROJECTs/test_print/test_print/DebugLogView.swift`.
- Record exact printer model, firmware, iOS version, network topology.
