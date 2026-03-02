//
//  LabelData.swift
//  test_print
//
//  Data model representing content to be printed on a 2" x 1.5" label.
//

import Foundation

struct LabelData: Identifiable, Equatable {
    let id = UUID()
    
    /// Primary text (e.g., product name, SKU)
    var title: String
    
    /// Secondary text (e.g., description, location)
    var subtitle: String
    
    /// Barcode value (Code128 format)
    var barcodeValue: String
    
    /// Small detail text (e.g., date, batch number)
    var detailLine: String
    
    /// Quantity to print
    var quantity: Int = 1
    
    // MARK: - Presets for Testing
    
    static let sample = LabelData(
        title: "SKU-001234",
        subtitle: "Widget A - Blue",
        barcodeValue: "001234567890",
        detailLine: "Loc: A1-B3 | Qty: 50"
    )
    
    static let sampleList: [LabelData] = [
        LabelData(
            title: "SKU-001234",
            subtitle: "Widget A - Blue",
            barcodeValue: "001234567890",
            detailLine: "Loc: A1-B3 | Qty: 50"
        ),
        LabelData(
            title: "SKU-005678",
            subtitle: "Gadget B - Red",
            barcodeValue: "005678901234",
            detailLine: "Loc: C2-D1 | Qty: 25"
        ),
        LabelData(
            title: "SKU-009012",
            subtitle: "Part C - Green",
            barcodeValue: "009012345678",
            detailLine: "Loc: E4-F2 | Qty: 100"
        ),
    ]
}
