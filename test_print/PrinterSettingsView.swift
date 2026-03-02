//
//  PrinterSettingsView.swift
//  test_print
//
//  Configuration screen for printer IP, port, label size presets,
//  persistent connect/disconnect, and live label preview.
//

import SwiftUI

struct PrinterSettingsView: View {
    @Bindable var printerService: PrinterService
    @Environment(\.dismiss) private var dismiss
    
    @State private var ipAddress: String = ""
    @State private var port: String = ""
    @State private var customWidth: String = ""
    @State private var customHeight: String = ""
    @State private var selectedPreset: LabelSize? = nil
    @State private var useCustomSize: Bool = false
    @State private var diagnosticPrintMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Connection Settings
                connectionSection
                
                // MARK: - Connect / Disconnect
                connectionControlSection
                
                // MARK: - Label Size
                labelSizeSection
                
                // MARK: - Label Preview
                previewSection
                
                // MARK: - Test Print
                testPrintSection
                
                // MARK: - Diagnostic PDFs (AirPrint size test)
                diagnosticPDFSection

                // MARK: - Printer Info
                infoSection
            }
            .navigationTitle("Printer Settings")
            .alert("Print", isPresented: Binding(get: { diagnosticPrintMessage != nil }, set: { if !$0 { diagnosticPrintMessage = nil } })) {
                Button("OK") { diagnosticPrintMessage = nil }
            } message: {
                if let msg = diagnosticPrintMessage { Text(msg) }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfig()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadConfig()
            }
        }
    }
    
    // MARK: - Connection Settings
    
    private var connectionSection: some View {
        Section {
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                TextField("Printer IP Address", text: $ipAddress)
                    .textContentType(.URL)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .font(.system(.body, design: .monospaced))
            }
            
            HStack {
                Image(systemName: "number")
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                TextField("Port (default: 9100)", text: $port)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .font(.system(.body, design: .monospaced))
            }
        } header: {
            Text("Printer Connection")
        } footer: {
            Text("Find the IP address in your printer's Network settings panel. Port 9100 is standard for raw TCP printing.")
        }
    }
    
    // MARK: - Connect / Disconnect Control
    
    private var connectionControlSection: some View {
        Section {
            // Connect / Disconnect button
            Button {
                saveConfig()
                printerService.toggleConnection()
            } label: {
                HStack {
                    Image(systemName: connectButtonIcon)
                        .font(.title3)
                        .foregroundStyle(connectButtonColor)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connectButtonTitle)
                            .font(.body.weight(.semibold))
                        Text(connectButtonSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if case .connecting = printerService.connectionState {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(ipAddress.isEmpty)
            .tint(connectButtonColor)
            
            // Status row
            HStack {
                connectionStatusDot
                    .frame(width: 30)
                Text(printerService.connectionState.displayText)
                    .font(.subheadline)
                    .foregroundStyle(connectionStatusColor)
                
                Spacer()
                
                if printerService.connectionState.isReady {
                    Text("Ready to print")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        } header: {
            Text("Connection")
        }
    }
    
    // MARK: - Label Size Section
    
    private var labelSizeSection: some View {
        Section {
            // Preset picker
            ForEach(LabelSize.presets) { preset in
                Button {
                    selectedPreset = preset
                    useCustomSize = false
                    customWidth = String(preset.widthInches)
                    customHeight = String(preset.heightInches)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(preset.widthDots) x \(preset.heightDots) dots at 203 DPI")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        // Size badge
                        Text(preset.displayText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        
                        // Checkmark
                        if !useCustomSize && selectedPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .tint(.primary)
            }
            
            // Custom size toggle
            DisclosureGroup("Custom Size", isExpanded: $useCustomSize) {
                HStack {
                    Image(systemName: "rectangle.portrait")
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    TextField("Width", text: $customWidth)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("inches")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Image(systemName: "rectangle.landscape")
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    TextField("Height", text: $customHeight)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("inches")
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: useCustomSize) { _, isCustom in
                if isCustom {
                    selectedPreset = nil
                }
            }
        } header: {
            Text("Label / Page Size")
        } footer: {
            let config = currentConfig
            Text("Current: \(config.labelWidthDots) x \(config.labelHeightDots) dots (\(formatInches(config.labelWidthInches))\" x \(formatInches(config.labelHeightInches))\") at 203 DPI")
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        Section {
            VStack(spacing: 12) {
                // Size header
                HStack {
                    Text("LABEL PREVIEW")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentSizeDisplayText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                
                // Visual preview — scaled to fit within 300pt width
                labelVisualPreview
            }
            .padding(.vertical, 8)
        }
    }
    
    private var labelVisualPreview: some View {
        let w = Double(customWidth) ?? 2.0
        let h = Double(customHeight) ?? 1.5
        // Scale so the longest dimension fits in ~280pt
        let maxDim = max(w, h)
        let scale = min(280.0 / maxDim, 80.0)  // cap at 80pt per inch
        let previewW = CGFloat(w * scale)
        let previewH = CGFloat(h * scale)
        
        return VStack(spacing: 4) {
            ZStack {
                // Label background
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .frame(width: previewW, height: previewH)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                
                // Label content mock
                VStack(alignment: .leading, spacing: max(2, previewH * 0.04)) {
                    // Title
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.black.opacity(0.7))
                        .frame(width: previewW * 0.6, height: max(6, previewH * 0.08))
                    
                    // Subtitle
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.gray.opacity(0.4))
                        .frame(width: previewW * 0.45, height: max(4, previewH * 0.06))
                    
                    Spacer().frame(height: 1)
                    
                    // Barcode
                    HStack(spacing: 1) {
                        ForEach(0..<min(Int(previewW / 5), 30), id: \.self) { i in
                            Rectangle()
                                .fill(.black.opacity(0.8))
                                .frame(width: CGFloat([1.5, 2.5, 1.0, 2.0][i % 4]),
                                       height: max(10, previewH * 0.25))
                        }
                    }
                    
                    // Barcode text
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.gray.opacity(0.3))
                        .frame(width: previewW * 0.5, height: max(3, previewH * 0.04))
                    
                    Spacer()
                    
                    // Detail line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.gray.opacity(0.25))
                        .frame(width: previewW * 0.55, height: max(3, previewH * 0.04))
                }
                .padding(previewW * 0.06)
                .frame(width: previewW, height: previewH, alignment: .topLeading)
            }
            
            // Dimensions below preview
            Text("\(formatInches(w))\" x \(formatInches(h))\" — \(Int(w * 203)) x \(Int(h * 203)) dots")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Test Print Section
    
    private var testPrintSection: some View {
        Section {
            Button {
                saveConfig()
                let testTSPL = TSPLGenerator.testLabel(config: printerService.config)
                printerService.printRaw(testTSPL) { _ in }
            } label: {
                HStack {
                    Image(systemName: "printer.fill")
                        .frame(width: 30)
                    Text("Print Test Label")
                }
            }
            
            Button {
                saveConfig()
                let minimalTSPL = TSPLGenerator.minimalTest()
                printerService.printRaw(minimalTSPL) { _ in }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .frame(width: 30)
                    Text("Print Minimal Test (just \"TEST\")")
                }
            }
            
            if let result = printerService.lastPrintResult {
                HStack {
                    Image(systemName: result.contains("success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.contains("success") ? .green : .red)
                        .frame(width: 30)
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Test")
        } footer: {
            Text("Test Print: Full label with barcode. Minimal Test: Just prints \"TEST\" to verify basic connectivity.")
        }
    }
    
    // MARK: - Diagnostic PDFs (exact 2" × 1.5" — test if AirPrint respects size)
    private var diagnosticPDFSection: some View {
        Section {
            Button {
                let data = AirPrintService.generateDiagnosticTest1PDF()
                AirPrintService.printPDF(data, jobName: "Test 1 (144×108)") { msg in diagnosticPrintMessage = msg }
            } label: {
                Label("Print Test 1 (144×108 pt)", systemImage: "doc.fill")
            }
            Button {
                let data = AirPrintService.generateDiagnosticTest2PDF()
                AirPrintService.printPDF(data, jobName: "Test 2 (108×144)") { msg in diagnosticPrintMessage = msg }
            } label: {
                Label("Print Test 2 (108×144 rotated)", systemImage: "doc.fill")
            }
            Button {
                let data = AirPrintService.generateDiagnosticTest3PDF()
                AirPrintService.printPDF(data, jobName: "Test 3 (safe area)") { msg in diagnosticPrintMessage = msg }
            } label: {
                Label("Print Test 3 (safe area box)", systemImage: "doc.fill")
            }
        } header: {
            Text("Diagnostic PDFs")
        } footer: {
            Text("Exact 2″ × 1.5″ PDFs. Print with AirPrint; leave scaling default. If these print correctly, your system can use PDF labels instead of HTML.")
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            LabeledContent("Printer Model", value: "Rollo X1040 Wireless")
            LabeledContent("Protocol", value: "TCP/IP Raw (Port 9100)")
            LabeledContent("Direct TCP language", value: "TSPL (Rollo/TSC)")
            LabeledContent("Resolution", value: "203 DPI")
            
            Toggle("Debug Mode (Console Logging)", isOn: $printerService.debugMode)
            
            NavigationLink {
                DebugLogView()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .frame(width: 30)
                    Text("View Debug Logs")
                    Spacer()
                    if DebugLogger.shared.logs.count > 0 {
                        Text("\(DebugLogger.shared.logs.count)")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        } header: {
            Text("Printer Info")
        } footer: {
            if printerService.debugMode {
                Text("Debug mode enabled. TSPL commands and connection details will be logged. Tap 'View Debug Logs' to see them in-app, or check Xcode console if connected.")
            } else {
                Text("Enable Debug Mode to see detailed logs of print jobs and connection attempts.")
            }
        }
    }
    
    // MARK: - Connection Button Styling
    
    private var connectButtonIcon: String {
        switch printerService.connectionState {
        case .connected: return "wifi.slash"
        case .connecting: return "wifi"
        default: return "wifi"
        }
    }
    
    private var connectButtonTitle: String {
        switch printerService.connectionState {
        case .connected: return "Disconnect"
        case .connecting: return "Connecting..."
        default: return "Connect"
        }
    }
    
    private var connectButtonSubtitle: String {
        switch printerService.connectionState {
        case .connected: return "Tap to disconnect from printer"
        case .connecting: return "Establishing TCP connection..."
        default: return "Tap to connect to \(ipAddress.isEmpty ? "printer" : ipAddress)"
        }
    }
    
    private var connectButtonColor: Color {
        switch printerService.connectionState {
        case .connected: return .red
        case .connecting: return .orange
        default: return .blue
        }
    }
    
    // MARK: - Status Styling
    
    private var connectionStatusDot: some View {
        Group {
            switch printerService.connectionState {
            case .disconnected:
                Image(systemName: "circle")
                    .foregroundStyle(.gray)
            case .connecting:
                ProgressView()
                    .controlSize(.small)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .printing:
                ProgressView()
                    .controlSize(.small)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var connectionStatusColor: Color {
        switch printerService.connectionState {
        case .disconnected: return .secondary
        case .connecting: return .blue
        case .connected: return .green
        case .printing: return .blue
        case .error: return .red
        }
    }
    
    // MARK: - Config Helpers
    
    private var currentConfig: PrinterConfig {
        PrinterConfig(
            ipAddress: ipAddress,
            port: UInt16(port) ?? 9100,
            labelWidthInches: Double(customWidth) ?? 2.0,
            labelHeightInches: Double(customHeight) ?? 1.5
        )
    }
    
    private var currentSizeDisplayText: String {
        if let preset = selectedPreset, !useCustomSize {
            return preset.name
        }
        let w = Double(customWidth) ?? 2.0
        let h = Double(customHeight) ?? 1.5
        return "Custom \(formatInches(w))\" x \(formatInches(h))\""
    }
    
    private func loadConfig() {
        let config = printerService.config
        ipAddress = config.ipAddress
        port = String(config.port)
        customWidth = String(config.labelWidthInches)
        customHeight = String(config.labelHeightInches)
        
        // Try to match a preset
        selectedPreset = LabelSize.presets.first {
            abs($0.widthInches - config.labelWidthInches) < 0.01 &&
            abs($0.heightInches - config.labelHeightInches) < 0.01
        }
        useCustomSize = (selectedPreset == nil)
    }
    
    private func saveConfig() {
        var config = currentConfig
        if let preset = selectedPreset, !useCustomSize {
            config.labelWidthInches = preset.widthInches
            config.labelHeightInches = preset.heightInches
        }
        config.save()
        printerService.config = config
    }
    
    private func formatInches(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

#Preview {
    PrinterSettingsView(printerService: PrinterService())
}
