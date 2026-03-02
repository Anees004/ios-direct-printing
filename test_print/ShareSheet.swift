//
//  ShareSheet.swift
//  test_print
//
//  Presents the system share sheet for a file URL (e.g. exported TSPL or PDF).
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        vc.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
