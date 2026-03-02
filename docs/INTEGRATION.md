# Integration Guide

## Goal

Integrate reliable label printing into an iOS/iPadOS app with two paths:

1. Direct TCP (TSPL) for zero-dialog printing
2. AirPrint (PDF) as fallback

## Core files

- `/Users/geek/MY OWN PROJECTs/test_print/test_print/PrinterService.swift`
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/TSPLGenerator.swift`
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/AirPrintService.swift`
- `/Users/geek/MY OWN PROJECTs/test_print/test_print/LabelData.swift`

## Print flow

1. User configures printer IP/port and label size
2. App builds TSPL with current label data
3. App opens TCP connection to printer and sends job
4. On failure, app can switch to AirPrint path

## Minimum app-side requirements

- `Info.plist`:
  - `NSLocalNetworkUsageDescription`
  - `NSBonjourServices` (`_pdl-datastream._tcp`, `_printer._tcp`, `_ipp._tcp`)
- iOS device and printer on same network
- Printer configured to accept raw TCP (`9100`) if using direct mode

## Suggested integration pattern

- Keep printer config in persisted settings
- Keep a dedicated print service (queue + state)
- Show user-facing state:
  - Connecting
  - Printing
  - Success
  - Actionable error
- Always keep AirPrint available as fallback

## Data model

`LabelData` includes:
- `title`
- `subtitle`
- `barcodeValue`
- `detailLine`
- `quantity`

Adapt this model to your domain object and map fields before printing.
