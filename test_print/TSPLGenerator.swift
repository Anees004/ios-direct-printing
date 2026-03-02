//
//  TSPLGenerator.swift
//  test_print
//
//  Generates TSPL/TSPL2 commands for Rollo X1040 (and other TSC/Rollo printers).
//  Rollo does NOT use ZPL; it uses TSPL. Use this for Direct TCP (port 9100).
//
//  Refs: Rollo X1040 uses TSPL; SIZE (mm), TEXT, BARCODE, PRINT, END.
//

import Foundation

enum TSPLGenerator {
    
    /// 203 DPI typical for Rollo
    static let dpi: Double = 203
    
    /// Convert inches to mm for SIZE command
    private static func mm(fromInches inches: Double) -> Double {
        inches * 25.4
    }
    
    /// Generate a full TSPL label for Rollo X1040.
    static func generate(label: LabelData, config: PrinterConfig) -> String {
        let widthMm = Self.mm(fromInches: config.labelWidthInches)
        let heightMm = Self.mm(fromInches: config.labelHeightInches)
        let hDots = config.labelHeightDots
        
        // Layout in dots (203 DPI): title, subtitle, barcode, detail
        var tspl = ""
        for _ in 0..<max(1, label.quantity) {
            // CRITICAL: SIZE must have space after comma, GAP is required for label detection
            tspl += "SIZE \(String(format: "%.1f", widthMm)) mm, \(String(format: "%.1f", heightMm)) mm\n"
            tspl += "GAP 3 mm, 0 mm\n"  // 3mm gap for die-cut labels (adjust if using continuous roll)
            tspl += "DIRECTION 0\n"      // 0 = normal orientation
            tspl += "CLS\n"
            
            // Title — large (font 4, scale 2,2)
            tspl += "TEXT 20,20,\"4\",0,2,2,\"\(sanitize(label.title))\"\n"
            // Subtitle — medium (font 3, scale 1,1)
            tspl += "TEXT 20,55,\"3\",0,1,1,\"\(sanitize(label.subtitle))\"\n"
            
            // Code 128 barcode: x,y,"128",height,humanReadable,rotation,narrow,wide,"data"
            if !label.barcodeValue.isEmpty {
                tspl += "BARCODE 20,85,\"128\",70,1,0,2,4,\"\(sanitize(label.barcodeValue))\"\n"
                // Barcode value text below (optional; BARCODE 1 = show text)
                // tspl += "TEXT 20,160,\"2\",0,1,1,\"\(sanitize(label.barcodeValue))\"\n"
            }
            
            // Detail line near bottom (30 dots from bottom)
            let detailY = max(80, hDots - 30)
            tspl += "TEXT 20,\(detailY),\"2\",0,1,1,\"\(sanitize(label.detailLine))\"\n"
            
            tspl += "PRINT 1\n"
        }
        // Note: Some printers need a blank line after the last command
        return tspl + "\n"
    }
    
    /// Sanitize for TSPL (escape backslash and quotes)
    private static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    /// Test label for connectivity and alignment (TSPL).
    static func testLabel(config: PrinterConfig) -> String {
        let widthMm = Self.mm(fromInches: config.labelWidthInches)
        let heightMm = Self.mm(fromInches: config.labelHeightInches)
        return """
        SIZE \(String(format: "%.1f", widthMm)) mm, \(String(format: "%.1f", heightMm)) mm
        GAP 3 mm, 0 mm
        DIRECTION 0
        CLS
        TEXT 20,20,"4",0,2,2,"Test Print"
        TEXT 20,60,"3",0,1,1,"Rollo X1040 - TSPL"
        TEXT 20,95,"2",0,1,1,"Port 9100 / TCP"
        BARCODE 20,130,"128",60,1,0,2,4,"TEST12345"
        PRINT 1
        
        """
    }
    
    /// Minimal test - just prints "TEST" to verify basic connectivity
    static func minimalTest() -> String {
        return """
        SIZE 101.6 mm, 152.4 mm
        GAP 3 mm, 0 mm
        DIRECTION 0
        CLS
        TEXT 50,50,"4",0,1,1,"TEST"
        PRINT 1
        
        """
    }
}
