//
//  ContentView.swift
//  test_print
//
//  Main screen for one-tap label printing.
//  Supports Direct TCP (TSPL) and AirPrint (PDF).
//

import SwiftUI

struct ContentView: View {
    @State private var printerService = PrinterService()
    @State private var showSettings = false
    @State private var showLabelEditor = false
    @State private var showSizePicker = false
    @State private var selectedLabel: LabelData = .sample
    @State private var printMode: PrintMode = .directTCP
    @State private var showPrintConfirmation = false
    @State private var recentPrints: [String] = []
    @State private var airPrintErrorMessage: String?
    @State private var directPrintErrorMessage: String?
    /// For "Test without printer" — share sheet
    @State private var fileToShare: ShareableFile?
    
    enum PrintMode: String, CaseIterable {
        case directTCP = "Direct TCP (TSPL)"
        case airPrint = "AirPrint (PDF)"
        
        var icon: String {
            switch self {
            case .directTCP: return "bolt.fill"
            case .airPrint: return "airplayaudio"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Status Card
                    statusCard
                    
                    // MARK: - Label Preview
                    labelPreviewCard
                    
                    // MARK: - ONE TAP PRINT BUTTON
                    printButton
                    
                    // MARK: - Print Mode Toggle
                    printModeSelector
                    
                    // MARK: - Quick Actions
                    quickActionsGrid
                    
                    // MARK: - Test without printer
                    testWithoutPrinterSection
                    
                    // MARK: - Recent Prints
                    if !recentPrints.isEmpty {
                        recentPrintsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Label Printer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLabelEditor = true
                    } label: {
                        Image(systemName: "pencil.and.list.clipboard")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                PrinterSettingsView(printerService: printerService)
            }
            .sheet(isPresented: $showLabelEditor) {
                LabelEditorView(label: $selectedLabel)
            }
            .sheet(isPresented: $showSizePicker) {
                LabelSizePickerView(printerService: printerService)
            }
            .alert("AirPrint", isPresented: Binding(get: { airPrintErrorMessage != nil }, set: { if !$0 { airPrintErrorMessage = nil } })) {
                Button("OK") { airPrintErrorMessage = nil }
            } message: {
                if let msg = airPrintErrorMessage {
                    Text(msg)
                }
            }
            .alert("Print Failed", isPresented: Binding(get: { directPrintErrorMessage != nil }, set: { if !$0 { directPrintErrorMessage = nil } })) {
                Button("OK") { directPrintErrorMessage = nil }
            } message: {
                if let msg = directPrintErrorMessage {
                    Text(msg)
                }
            }
            .sheet(item: $fileToShare) { shareable in
                ShareSheet(url: shareable.url) { fileToShare = nil }
            }
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        HStack(spacing: 16) {
            // Connection indicator — tappable to toggle
            Button {
                printerService.toggleConnection()
            } label: {
                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 4)
                    )
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(printerService.connectionState.displayText)
                    .font(.subheadline.weight(.medium))
                Text(printerService.config.ipAddress + ":" + String(printerService.config.port))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            
            Spacer()
            
            // Label size badge — tappable to change size
            Button {
                showSizePicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("\(formatInches(printerService.config.labelWidthInches))\" x \(formatInches(printerService.config.labelHeightInches))\"")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Label Preview Card
    
    private var labelPreviewCard: some View {
        let w = printerService.config.labelWidthInches
        let h = printerService.config.labelHeightInches
        
        return VStack(spacing: 8) {
            HStack {
                Text("LABEL PREVIEW")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatInches(w))\" x \(formatInches(h))\"")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            
            // Label at correct aspect ratio
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedLabel.title)
                    .font(.system(.headline, design: .monospaced))
                    .bold()
                    .lineLimit(1)
                
                Text(selectedLabel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Divider()
                
                // Barcode representation
                HStack(spacing: 1) {
                    ForEach(0..<30, id: \.self) { i in
                        Rectangle()
                            .fill(.black)
                            .frame(width: CGFloat([1.5, 2.5, 1.0, 3.0, 1.5][i % 5]),
                                   height: 35)
                    }
                }
                .padding(.vertical, 4)
                
                Text(selectedLabel.barcodeValue)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer(minLength: 0)
                
                Text(selectedLabel.detailLine)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(w / h, contentMode: .fit)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
    
    // MARK: - THE Print Button
    
    private var printButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                performPrint()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PRINT LABEL")
                            .font(.headline.weight(.bold))
                        Text(printMode == .directTCP ? "Direct to printer — no dialog" : "AirPrint — size is set in Settings (gear)")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    if case .printing = printerService.connectionState {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.6)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(printerService.connectionState.isPrintingOrConnecting)
            .opacity(printerService.connectionState.isPrintingOrConnecting ? 0.8 : 1)
            .sensoryFeedback(.success, trigger: showPrintConfirmation)
            
            if case .printing = printerService.connectionState, let stage = printerService.printStageMessage, !stage.isEmpty {
                Text(stage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            if case .error(let msg) = printerService.connectionState {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
            if let result = printerService.lastPrintResult, !result.contains("Failed") {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.leading, 4)
            }
        }
    }
    
    // MARK: - Print Mode Selector
    
    private var printModeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRINT METHOD")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            if printMode == .airPrint {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AirPrint uses the label size from Settings. You can’t change size in the print dialog — tap the size badge or open Settings to change it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Rollo X1040 is **AirPrint-certified**. AirPrint is the recommended way to print. Direct TCP sends TSPL (Rollo’s language) over port 9100.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.bottom, 2)
            }
            
            Picker("Print Mode", selection: $printMode) {
                ForEach(PrintMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("Direct: set printer IP in Settings (gear). AirPrint: choose your printer in the dialog. Use same Wi‑Fi as the printer.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionButton(
                    title: "Test Print",
                    icon: "checkmark.rectangle",
                    color: .green
                ) {
                    printTestLabel()
                }
                .disabled(printerService.connectionState.isPrintingOrConnecting)
                
                quickActionButton(
                    title: "Print x5",
                    icon: "square.stack.3d.up",
                    color: .orange
                ) {
                    printMultiple(count: 5)
                }
                .disabled(printerService.connectionState.isPrintingOrConnecting)
                
                quickActionButton(
                    title: printerService.connectionState.isReady ? "Disconnect" : "Connect",
                    icon: printerService.connectionState.isReady ? "wifi.slash" : "wifi",
                    color: printerService.connectionState.isReady ? .red : .purple
                ) {
                    printerService.toggleConnection()
                }
                
                quickActionButton(
                    title: "Change Size",
                    icon: "doc.text.magnifyingglass",
                    color: .teal
                ) {
                    showSizePicker = true
                }
            }
        }
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Test without printer
    
    private var testWithoutPrinterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEST WITHOUT PRINTER")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Export the exact TSPL or PDF the app would send. Inspect the file or send to someone with a Rollo to verify.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 12) {
                Button {
                    exportTSPL()
                } label: {
                    Label("Export TSPL file", systemImage: "doc.text")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                Button {
                    exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Recent Prints
    
    private var recentPrintsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ForEach(recentPrints.suffix(5).reversed(), id: \.self) { entry in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(entry)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func performPrint() {
        switch printMode {
        case .directTCP:
            printerService.printLabel(selectedLabel) { result in
                switch result {
                case .success:
                    recentPrints.append("\(selectedLabel.title) — TCP Direct")
                    showPrintConfirmation = true
                case .failure(let error):
                    directPrintErrorMessage = PrinterService.friendlyMessage(for: error)
                }
            }
            
        case .airPrint:
            AirPrintService.printLabel(selectedLabel, config: printerService.config) { errorMessage in
                if let msg = errorMessage {
                    airPrintErrorMessage = msg
                } else {
                    recentPrints.append("\(selectedLabel.title) — AirPrint")
                }
            }
        }
    }
    
    private func printTestLabel() {
        let testTSPL = TSPLGenerator.testLabel(config: printerService.config)
        printerService.printRaw(testTSPL) { result in
            switch result {
            case .success:
                recentPrints.append("Test Label — OK")
            case .failure(let error):
                directPrintErrorMessage = PrinterService.friendlyMessage(for: error)
            }
        }
    }
    
    private func printMultiple(count: Int) {
        var label = selectedLabel
        label.quantity = count
        printerService.printLabel(label) { result in
            switch result {
            case .success:
                recentPrints.append("\(label.title) x\(count) — TCP Direct")
            case .failure(let error):
                directPrintErrorMessage = PrinterService.friendlyMessage(for: error)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        switch printerService.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .printing: return .blue
        case .error: return .red
        }
    }
    
    private func formatInches(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
    
    // MARK: - Export for testing (no printer needed)
    
    private func exportTSPL() {
        let tspl = TSPLGenerator.generate(label: selectedLabel, config: printerService.config)
        let name = "label_\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).tspl"
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let fileURL = dir.appendingPathComponent(name)
        do {
            try tspl.write(to: fileURL, atomically: true, encoding: .utf8)
            fileToShare = ShareableFile(url: fileURL)
        } catch {
            airPrintErrorMessage = "Could not save TSPL: \(error.localizedDescription)"
        }
    }
    
    private func exportPDF() {
        let w = CGFloat(printerService.config.labelWidthInches) * 72
        let h = CGFloat(printerService.config.labelHeightInches) * 72
        let pdfData = AirPrintService.generateLabelPDF(selectedLabel, widthPoints: w, heightPoints: h)
        let name = "label_\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).pdf"
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let fileURL = dir.appendingPathComponent(name)
        do {
            try pdfData.write(to: fileURL)
            fileToShare = ShareableFile(url: fileURL)
        } catch {
            airPrintErrorMessage = "Could not save PDF: \(error.localizedDescription)"
        }
    }
}

// MARK: - Shareable file (for sheet item)

struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Label Size Picker (Quick Sheet)

struct LabelSizePickerView: View {
    @Bindable var printerService: PrinterService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Common Sizes") {
                    ForEach(LabelSize.presets) { size in
                        Button {
                            var config = printerService.config
                            config.labelWidthInches = size.widthInches
                            config.labelHeightInches = size.heightInches
                            config.save()
                            printerService.config = config
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(size.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(size.widthDots) x \(size.heightDots) dots")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Spacer()
                                
                                Text(size.displayText)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.blue)
                                
                                if abs(printerService.config.labelWidthInches - size.widthInches) < 0.01 &&
                                   abs(printerService.config.labelHeightInches - size.heightInches) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .font(.caption.weight(.bold))
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
                
                Section {
                    Button {
                        dismiss()
                        // User can go to full Settings for custom size
                    } label: {
                        Label("Custom size (use Settings)", systemImage: "ruler")
                    }
                    .tint(.orange)
                }
            }
            .navigationTitle("Label Size")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Label Editor Sheet

struct LabelEditorView: View {
    @Binding var label: LabelData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Label Content") {
                    TextField("Title / SKU", text: $label.title)
                        .font(.system(.body, design: .monospaced))
                    TextField("Subtitle / Description", text: $label.subtitle)
                    TextField("Barcode Value", text: $label.barcodeValue)
                        .font(.system(.body, design: .monospaced))
                    TextField("Detail Line", text: $label.detailLine)
                }
                
                Section("Quantity") {
                    Stepper("Print \(label.quantity) label\(label.quantity > 1 ? "s" : "")", value: $label.quantity, in: 1...100)
                }
                
                Section("Presets") {
                    ForEach(LabelData.sampleList) { preset in
                        Button {
                            label = preset
                        } label: {
                            VStack(alignment: .leading) {
                                Text(preset.title)
                                    .font(.subheadline.weight(.medium))
                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Edit Label")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
