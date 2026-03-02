//
//  AirPrintService.swift
//  test_print
//
//  Fallback AirPrint service that generates a precisely-sized PDF
//  for 2" x 1.5" labels and sends via UIPrintInteractionController.
//
//  This is the "easy" option — shows the iOS print dialog but
//  with correct paper size pre-configured.
//
//  NOTE: UIPrintInteractionController is iOS/iPadOS only.
//  For macOS, use NSPrintOperation instead.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

enum AirPrintService {
    
    // MARK: - Constants (72 points per inch)
    
    static let pointsPerInch: CGFloat = 72
    
    // MARK: - Print via AirPrint
    
    /// Print a label using AirPrint. Uses `config` for page size (matches Settings).
    /// completion: called with error message if present (e.g. user cancelled or printer error).
    static func printLabel(_ label: LabelData, config: PrinterConfig? = nil, completion: ((String?) -> Void)? = nil) {
        let cfg = config ?? PrinterConfig.load()
        let widthPt = CGFloat(cfg.labelWidthInches) * pointsPerInch
        let heightPt = CGFloat(cfg.labelHeightInches) * pointsPerInch
        let pdfData = generateLabelPDF(label, widthPoints: widthPt, heightPoints: heightPt)
        
        let printController = UIPrintInteractionController.shared
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .photo
        printInfo.jobName = "Label: \(label.title)"
        printInfo.orientation = widthPt <= heightPt ? .portrait : .landscape
        printController.printInfo = printInfo
        
        printController.printingItem = pdfData
        
        printController.present(animated: true) { _, completed, error in
            if let error = error {
                completion?(error.localizedDescription)
            } else if !completed {
                completion?("Print was cancelled")
            } else {
                completion?(nil)
            }
        }
    }
    
    // MARK: - PDF Generation
    
    /// Generate a PDF with the given size in points (inches * 72).
    static func generateLabelPDF(_ label: LabelData, widthPoints: CGFloat = 144, heightPoints: CGFloat = 108) -> Data {
        let labelWidth = widthPoints
        let labelHeight = heightPoints
        let pageRect = CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            
            // Background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(pageRect)
            
            // Title — bold, large
            let titleFont = UIFont.boldSystemFont(ofSize: 14)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleString = label.title as NSString
            titleString.draw(
                in: CGRect(x: 8, y: 6, width: labelWidth - 16, height: 18),
                withAttributes: titleAttributes
            )
            
            // Subtitle — medium
            let subtitleFont = UIFont.systemFont(ofSize: 10)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.darkGray
            ]
            let subtitleString = label.subtitle as NSString
            subtitleString.draw(
                in: CGRect(x: 8, y: 26, width: labelWidth - 16, height: 14),
                withAttributes: subtitleAttributes
            )
            
            // Separator line
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(0.5)
            cgContext.move(to: CGPoint(x: 8, y: 43))
            cgContext.addLine(to: CGPoint(x: labelWidth - 8, y: 43))
            cgContext.strokePath()
            
            // Barcode text (visual representation — real barcode needs Core Image)
            if !label.barcodeValue.isEmpty {
                let barcodeFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
                let barcodeAttributes: [NSAttributedString.Key: Any] = [
                    .font: barcodeFont,
                    .foregroundColor: UIColor.black
                ]
                
                // Generate barcode image using Core Image
                if let barcodeImage = generateBarcode128(from: label.barcodeValue) {
                    let barcodeRect = CGRect(x: 8, y: 46, width: labelWidth - 16, height: 35)
                    barcodeImage.draw(in: barcodeRect)
                }
                
                // Barcode value text below
                let barcodeString = label.barcodeValue as NSString
                barcodeString.draw(
                    in: CGRect(x: 8, y: 83, width: labelWidth - 16, height: 12),
                    withAttributes: barcodeAttributes
                )
            }
            
            // Detail line at bottom
            let detailFont = UIFont.systemFont(ofSize: 8)
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: detailFont,
                .foregroundColor: UIColor.gray
            ]
            let detailString = label.detailLine as NSString
            detailString.draw(
                in: CGRect(x: 8, y: labelHeight - 16, width: labelWidth - 16, height: 12),
                withAttributes: detailAttributes
            )
        }
        
        return pdfData
    }
    
    // MARK: - Barcode Generation
    
    /// Generate a Code 128 barcode image using Core Image
    static func generateBarcode128(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CICode128BarcodeGenerator")
        else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0.0, forKey: "inputQuietSpace")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale up for clarity
        let scaleX = 2.0
        let scaleY = 1.0
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Diagnostic test PDFs (exact 2" × 1.5" = 144 × 108 pt)
    
    /// Test 1: 144 × 108 pt, border, big "TEST 1" — confirms AirPrint respects exact page size
    static func generateDiagnosticTest1PDF() -> Data {
        let w: CGFloat = 144
        let h: CGFloat = 108
        let pageRect = CGRect(x: 0, y: 0, width: w, height: h)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(pageRect)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(pageRect.insetBy(dx: 4, dy: 4))
            let font = UIFont.boldSystemFont(ofSize: 24)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            let str = "TEST 1" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (w - size.width) / 2, y: (h - size.height) / 2), withAttributes: attrs)
        }
    }
    
    /// Test 2: 108 × 144 pt (rotated) — confirms orientation / scaling
    static func generateDiagnosticTest2PDF() -> Data {
        let w: CGFloat = 108
        let h: CGFloat = 144
        let pageRect = CGRect(x: 0, y: 0, width: w, height: h)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(pageRect)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(pageRect.insetBy(dx: 4, dy: 4))
            let font = UIFont.boldSystemFont(ofSize: 24)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            let str = "TEST 2" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (w - size.width) / 2, y: (h - size.height) / 2), withAttributes: attrs)
        }
    }
    
    /// Test 3: 144 × 108 pt with outer border + inner safe-area box
    static func generateDiagnosticTest3PDF() -> Data {
        let w: CGFloat = 144
        let h: CGFloat = 108
        let pageRect = CGRect(x: 0, y: 0, width: w, height: h)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(pageRect)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(pageRect.insetBy(dx: 2, dy: 2))
            let margin: CGFloat = 12
            let inner = pageRect.insetBy(dx: margin, dy: margin)
            ctx.setLineWidth(1)
            ctx.setStrokeColor(UIColor.gray.cgColor)
            ctx.stroke(inner)
            let font = UIFont.systemFont(ofSize: 8)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.darkGray]
            ("Safe area " + String(format: "%.0f×%.0f pt", inner.width, inner.height) as NSString)
                .draw(at: CGPoint(x: margin, y: h - margin - 10), withAttributes: attrs)
        }
    }
    
    /// Print a PDF via AirPrint (e.g. diagnostic tests). Use default scaling; user should not change scale.
    static func printPDF(_ pdfData: Data, jobName: String, completion: ((String?) -> Void)? = nil) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = jobName
        printController.printInfo = printInfo
        printController.printingItem = pdfData
        printController.present(animated: true) { _, completed, error in
            if let error = error {
                completion?(error.localizedDescription)
            } else if !completed {
                completion?("Print was cancelled")
            } else {
                completion?(nil)
            }
        }
    }
}

#else

// MARK: - macOS Fallback (NSPrintOperation)

import AppKit

enum AirPrintService {
    
    static let labelWidth: CGFloat = 144
    static let labelHeight: CGFloat = 108
    
    /// macOS: Print using NSPrintOperation with exact label size
    static func printLabel(_ label: LabelData) {
        let pdfData = generateLabelPDF(label)
        
        guard let pdfDocument = NSImage(data: pdfData) else {
            print("Failed to create image from PDF data")
            return
        }
        
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: labelWidth, height: labelHeight))
        imageView.image = pdfDocument
        imageView.imageScaling = .scaleNone
        
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: labelWidth, height: labelHeight)
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.orientation = .portrait
        printInfo.horizontalPagination = .clip
        printInfo.verticalPagination = .clip
        
        let printOperation = NSPrintOperation(view: imageView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
    
    /// Generate PDF data for the label (macOS version using Core Graphics directly)
    static func generateLabelPDF(_ label: LabelData) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight)
        
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil)
        else {
            return Data()
        }
        
        var mediaBox = pageRect
        pdfContext.beginPDFPage([kCGPDFContextMediaBox as String: NSValue(rect: NSRect(origin: mediaBox.origin, size: mediaBox.size))] as CFDictionary)
        
        // White background
        pdfContext.setFillColor(NSColor.white.cgColor)
        pdfContext.fill(pageRect)
        
        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 14)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]
        let titleString = NSAttributedString(string: label.title, attributes: titleAttributes)
        titleString.draw(in: CGRect(x: 8, y: labelHeight - 24, width: labelWidth - 16, height: 18))
        
        // Subtitle
        let subtitleFont = NSFont.systemFont(ofSize: 10)
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: NSColor.darkGray
        ]
        let subtitleString = NSAttributedString(string: label.subtitle, attributes: subtitleAttributes)
        subtitleString.draw(in: CGRect(x: 8, y: labelHeight - 42, width: labelWidth - 16, height: 14))
        
        // Detail line
        let detailFont = NSFont.systemFont(ofSize: 8)
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: detailFont,
            .foregroundColor: NSColor.gray
        ]
        let detailString = NSAttributedString(string: label.detailLine, attributes: detailAttributes)
        detailString.draw(in: CGRect(x: 8, y: 4, width: labelWidth - 16, height: 12))
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

#endif
