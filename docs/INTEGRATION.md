# Integration Guide

This guide shows how to integrate direct one-tap label printing into an existing iOS/iPadOS app with minimal friction.

## Integration Outcome

After integration, your app should be able to:
- Print with a single tap (no system dialog)
- Send TSPL directly over TCP
- Show clear print state to the user
- Recover from common network and printer failures

## Prerequisites

- Xcode 15+
- iOS/iPadOS target that supports `Network` framework
- Printer that accepts raw TCP jobs on `9100`
- Same network for mobile device and printer

## Step 1: Add Core Files

Copy these files into your app target:
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/PrinterService.swift`
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/TSPLGenerator.swift`
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/LabelData.swift`

If you also want the same UI scaffolding, copy:
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/PrinterSettingsView.swift`
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/DebugLogView.swift`

## Step 2: Add Info.plist Network Permissions

Add:
- `NSLocalNetworkUsageDescription`
- `NSBonjourServices`

Suggested Bonjour entries:
- `_pdl-datastream._tcp`
- `_printer._tcp`
- `_ipp._tcp`

## Step 3: Create Your Domain Mapping

Map your business model into `LabelData` before printing.

Example mapping:

```swift
let label = LabelData(
    title: order.customerName,
    subtitle: order.city,
    barcodeValue: order.trackingNumber,
    detailLine: "Order #\(order.id)",
    quantity: 1
)
```

## Step 4: Wire the One-Tap Print Action

Use a single action handler in your screen/view model:

```swift
let tspl = TSPLGenerator.generate(label: label, config: printerService.config)
printerService.printRaw(tspl) { result in
    switch result {
    case .success:
        // show success state
        break
    case .failure(let error):
        // show actionable error
        print(error.localizedDescription)
    }
}
```

## Step 5: Persist Printer Config

`PrinterConfig` already supports save/load through `UserDefaults`.

Typical UX pattern:
- First launch: open printer settings screen
- Save IP/port/label size once
- Reuse automatically for future prints

## Step 6: Handle UI State Explicitly

Drive button state from `PrinterConnectionState`:
- Disable while connecting/printing
- Show in-progress status text
- Keep last failure visible until next action

This is important for user trust and support debugging.

## Step 7: Validate with Virtual Printer First

Run:

```bash
python3 /Users/geek/MY OWN PROJECTs/test_print/scripts/virtual_printer.py
```

Then set printer target:
- Simulator: `127.0.0.1:9100`
- Real device: `<mac_lan_ip>:9100`

## Optional: Add AirPrint as Secondary Fallback

Direct TCP should stay primary for one-tap flow. If your product needs broad printer compatibility, keep AirPrint as an explicit fallback path, not as the default.

## Common Integration Mistakes

- Sending data before connection is ready
- Not serializing print jobs
- Missing local network permission
- Wrong line endings in printer commands
- Wrong label dimensions vs loaded media

## Production Checklist

- One-tap print latency measured on real Wi-Fi
- Clear UI states for connecting/printing/error
- Logs captured for failed jobs
- Retry policy documented
- Printer model + firmware matrix validated
