//
//  PrinterService.swift
//  test_print
//
//  TCP Socket printer service for direct label printing to Rollo X1040.
//  Uses Apple's Network framework (NWConnection) for modern, reliable TCP.
//

import Foundation
import Network
import Combine

// MARK: - Printer Connection State

enum PrinterConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case printing
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .printing: return "Printing..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var isReady: Bool {
        if case .connected = self { return true }
        return false
    }
    
    /// True when the app is connecting or sending a print job (button should be disabled).
    var isPrintingOrConnecting: Bool {
        switch self {
        case .connecting, .printing: return true
        default: return false
        }
    }
}

// MARK: - Common Label Sizes

struct LabelSize: Identifiable, Codable, Equatable, Hashable {
    var id: String { name }
    let name: String
    let widthInches: Double
    let heightInches: Double
    
    var displayText: String {
        let w = widthInches.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", widthInches)
            : String(format: "%.1f", widthInches)
        let h = heightInches.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", heightInches)
            : String(format: "%.1f", heightInches)
        return "\(w)\" x \(h)\""
    }
    
    /// Width in dots at 203 DPI
    var widthDots: Int { Int(widthInches * 203) }
    /// Height in dots at 203 DPI
    var heightDots: Int { Int(heightInches * 203) }
    
    // Common label sizes
    static let presets: [LabelSize] = [
        LabelSize(name: "Small (2\" x 1\")", widthInches: 2.0, heightInches: 1.0),
        LabelSize(name: "Standard (2\" x 1.5\")", widthInches: 2.0, heightInches: 1.5),
        LabelSize(name: "Medium (2.25\" x 1.25\")", widthInches: 2.25, heightInches: 1.25),
        LabelSize(name: "Address (2.63\" x 1\")", widthInches: 2.63, heightInches: 1.0),
        LabelSize(name: "Large (3\" x 2\")", widthInches: 3.0, heightInches: 2.0),
        LabelSize(name: "Wide (4\" x 2\")", widthInches: 4.0, heightInches: 2.0),
        LabelSize(name: "Shipping (4\" x 6\")", widthInches: 4.0, heightInches: 6.0),
    ]
    
    static let `default` = presets.first(where: { $0.widthInches == 4.0 && $0.heightInches == 6.0 }) ?? presets[1] // Default: 4" x 6" (Shipping)
}

// MARK: - Printer Configuration

struct PrinterConfig: Codable, Equatable {
    var ipAddress: String
    var port: UInt16
    var labelWidthInches: Double
    var labelHeightInches: Double
    
    static let `default` = PrinterConfig(
        ipAddress: "192.168.1.50",
        port: 9100,
        labelWidthInches: 4.0,
        labelHeightInches: 6.0
    )
    
    /// Label width in dots (203 DPI for Rollo X1040)
    var labelWidthDots: Int { Int(labelWidthInches * 203) }
    
    /// Label height in dots (203 DPI for Rollo X1040)
    var labelHeightDots: Int { Int(labelHeightInches * 203) }
    
    /// The current label size
    var labelSize: LabelSize {
        get {
            LabelSize(name: "Custom", widthInches: labelWidthInches, heightInches: labelHeightInches)
        }
        set {
            labelWidthInches = newValue.widthInches
            labelHeightInches = newValue.heightInches
        }
    }
    
    // MARK: - Persistence
    
    private static let storageKey = "printerConfig"
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
    
    static func load() -> PrinterConfig {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(PrinterConfig.self, from: data)
        else {
            return .default
        }
        return config
    }
}

// MARK: - Printer Service

@Observable
final class PrinterService {
    
    // MARK: - Properties
    
    var connectionState: PrinterConnectionState = .disconnected
    /// Shown during .printing: "Connecting to 192.168.1.50...", "Sending label...", etc.
    var printStageMessage: String?
    var config: PrinterConfig
    var lastPrintResult: String?
    
    /// Enable to see detailed TSPL commands and connection info in console
    var debugMode: Bool = false
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.testprint.printer", qos: .userInitiated)
    
    /// Serialize print jobs so only one runs at a time (prevents QUEUED buildup on printer)
    private let printQueue = DispatchQueue(label: "com.testprint.printQueue", qos: .userInitiated)
    private var isPrintInProgress = false
    private var pendingPrints: [(data: String, completion: (Result<Void, Error>) -> Void)] = []
    
    // MARK: - Init
    
    init(config: PrinterConfig = .load()) {
        self.config = config
    }
    
    // MARK: - Connection Management
    
    /// Connect to the printer and stay connected.
    /// The connection remains open until disconnect() is called.
    func connect() {
        // If already connected or connecting, do nothing
        if case .connected = connectionState { return }
        if case .connecting = connectionState { return }
        
        if debugMode {
            DebugLogger.shared.log("Connecting to \(config.ipAddress):\(config.port)...", type: .info)
        }
        
        connectionState = .connecting
        
        let host = NWEndpoint.Host(config.ipAddress)
        guard let port = NWEndpoint.Port(rawValue: config.port) else {
            connectionState = .error("Invalid port: \(config.port)")
            return
        }
        
        let connection = NWConnection(host: host, port: port, using: .tcp)
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.connectionState = .connected
                    if self.debugMode {
                        DebugLogger.shared.log("Connected successfully", type: .success)
                    }
                case .failed(let error):
                    let msg = PrinterService.friendlyMessage(for: error)
                    self.connectionState = .error(msg)
                    self.connection = nil
                    if self.debugMode {
                        DebugLogger.shared.log("Connection failed: \(msg)", type: .error)
                    }
                case .waiting(let error):
                    let msg = PrinterService.friendlyMessage(for: error)
                    self.connectionState = .error(msg)
                    if self.debugMode {
                        DebugLogger.shared.log("Connection waiting: \(msg)", type: .error)
                    }
                case .cancelled:
                    self.connectionState = .disconnected
                    self.connection = nil
                    if self.debugMode {
                        DebugLogger.shared.log("Connection cancelled", type: .info)
                    }
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
        
        // Timeout after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if case .connecting = self?.connectionState {
                self?.connectionState = .error("Connection timed out")
                self?.disconnect()
            }
        }
    }
    
    /// Disconnect from the printer
    func disconnect() {
        connection?.cancel()
        connection = nil
        if case .error = connectionState {
            // Keep error state visible
        } else {
            connectionState = .disconnected
        }
    }
    
    /// Toggle: connect if disconnected, disconnect if connected
    func toggleConnection() {
        switch connectionState {
        case .connected:
            disconnect()
        case .disconnected, .error:
            connect()
        default:
            break
        }
    }
    
    // MARK: - Printing
    
    /// Send raw data (TSPL for Rollo) directly to the printer over TCP port 9100.
    /// Jobs are serialized (one at a time) and we delay before closing the connection
    /// so the printer doesn't get stuck in QUEUED.
    func printRaw(_ data: String, completion: @escaping (Result<Void, Error>) -> Void) {
        printQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isPrintInProgress {
                self.pendingPrints.append((data, completion))
                return
            }
            self.isPrintInProgress = true
            self.performPrintRaw(data) { [weak self] result in
                completion(result)
                self?.printQueue.async {
                    self?.isPrintInProgress = false
                    guard let self = self, !self.pendingPrints.isEmpty else { return }
                    let next = self.pendingPrints.removeFirst()
                    self.isPrintInProgress = true
                    self.performPrintRaw(next.data) { [weak self] nextResult in
                        next.completion(nextResult)
                        self?.drainPrintQueue()
                    }
                }
            }
        }
    }
    
    private func drainPrintQueue() {
        printQueue.async { [weak self] in
            self?.isPrintInProgress = false
            guard let self = self, !self.pendingPrints.isEmpty else { return }
            let next = self.pendingPrints.removeFirst()
            self.isPrintInProgress = true
            self.performPrintRaw(next.data) { [weak self] result in
                next.completion(result)
                self?.drainPrintQueue()
            }
        }
    }
    
    /// Single print job. If already connected, sends on that connection (printer gets only one TCP connection).
    /// Otherwise opens a temporary connection, sends, then closes.
    private func performPrintRaw(_ data: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let normalizedData = Self.normalizePrinterCommands(data)

        if debugMode {
            let logger = DebugLogger.shared
            logger.log("===== PRINT JOB START =====", type: .info)
            logger.log("Target: \(config.ipAddress):\(config.port)", type: .info)
            logger.log("TSPL Commands (\(normalizedData.utf8.count) bytes):", type: .tspl)
            logger.log(normalizedData, type: .tspl)
            logger.log("========================", type: .info)
            
            // Also print to console if Xcode is attached
            print("🖨️ ===== TSPL DEBUG =====")
            print("📤 TSPL Commands to send:")
            print(normalizedData)
            print("📊 Total bytes: \(normalizedData.utf8.count)")
            print("🌐 Target: \(config.ipAddress):\(config.port)")
            print("========================")
        }
        
        guard let payloadData = normalizedData.data(using: .utf8) else {
            if debugMode {
                DebugLogger.shared.log("Failed to encode TSPL as UTF-8", type: .error)
                print("❌ Failed to encode TSPL as UTF-8")
            }
            DispatchQueue.main.async { completion(.failure(PrinterError.invalidData)) }
            return
        }
        
        let previousState = connectionState
        let ip = config.ipAddress
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .printing
            self?.printStageMessage = "Sending label..."
            self?.lastPrintResult = nil
        }
        
        // Reuse existing connection when connected — many printers (e.g. Rollo) accept only one TCP connection;
        // opening a second one causes the first to close and triggers "connection was closed".
        if case .connected = previousState, let existing = connection {
            // Some printers buffer until socket close. Close after each job for reliable output.
            sendOnConnection(existing, data: payloadData, keepOpen: false) { [weak self] result in
                DispatchQueue.main.async {
                    self?.printStageMessage = nil
                    self?.connectionState = .disconnected
                    switch result {
                    case .success:
                        self?.lastPrintResult = "Label printed successfully"
                        self?.reconnectAfterPrint()
                    case .failure(let err):
                        self?.connectionState = .error(PrinterService.friendlyMessage(for: err))
                    }
                    completion(result)
                }
            }
            return
        }
        
        // Not connected: open a temporary connection, send, then close
        let host = NWEndpoint.Host(config.ipAddress)
        guard let port = NWEndpoint.Port(rawValue: config.port) else {
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("Invalid port")
                self?.printStageMessage = nil
                completion(.failure(PrinterError.connectionFailed))
            }
            return
        }
        
        let printConnection = NWConnection(host: host, port: port, using: .tcp)
        let jobCompleted = Box(false)
        
        DispatchQueue.main.async { [weak self] in
            self?.printStageMessage = "Connecting to \(ip)..."
        }
        
        printConnection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async { [weak self] in
                    self?.printStageMessage = "Sending label..."
                }
                self?.sendOnConnection(printConnection, data: payloadData, keepOpen: false) { result in
                    if case .success = result {
                        jobCompleted.value = true
                        printConnection.cancel()
                    }
                    DispatchQueue.main.async {
                        self?.printStageMessage = nil
                        self?.connectionState = previousState == .connected ? .connected : .disconnected
                        if case .success = result {
                            self?.lastPrintResult = "Label printed successfully"
                        } else if case .failure(let error) = result {
                            self?.connectionState = .error(PrinterService.friendlyMessage(for: error))
                        }
                        completion(result)
                    }
                }
                
            case .failed(let error):
                if jobCompleted.value { return }
                DispatchQueue.main.async {
                    self?.printStageMessage = nil
                    self?.connectionState = .error(PrinterService.friendlyMessage(for: error))
                    completion(.failure(error))
                }
                
            case .waiting(let error):
                if jobCompleted.value { return }
                DispatchQueue.main.async {
                    self?.printStageMessage = nil
                    self?.connectionState = .error(PrinterService.friendlyMessage(for: error))
                    completion(.failure(PrinterError.networkUnavailable))
                }
                
            default:
                break
            }
        }
        
        printConnection.start(queue: queue)
        
        let ipForTimeout = config.ipAddress
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard case .printing = self?.connectionState, !jobCompleted.value else { return }
            jobCompleted.value = true
            self?.printStageMessage = nil
            self?.connectionState = .error("Print timed out. Check that the printer is on and reachable at \(ipForTimeout).")
            printConnection.cancel()
            completion(.failure(PrinterError.timeout))
        }
    }

    /// Reconnect after a print job when user had an active "connected" session.
    private func reconnectAfterPrint() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            if case .disconnected = self.connectionState {
                self.connect()
            }
        }
    }
    
    /// Send raw bytes on an existing connection. keepOpen: true = do not cancel when done (reused connection).
    private func sendOnConnection(
        _ conn: NWConnection,
        data: Data,
        keepOpen: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        conn.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                if !keepOpen { conn.cancel() }
                completion(.failure(error))
                return
            }
            if keepOpen {
                completion(.success(()))
            } else {
                self?.queue.asyncAfter(deadline: .now() + 0.6) {
                    conn.cancel()
                    completion(.success(()))
                }
            }
        })
    }
    
    /// Convenience: generate TSPL (Rollo’s language) from LabelData and print
    func printLabel(_ label: LabelData, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let tspl = TSPLGenerator.generate(label: label, config: config)
        printRaw(tspl) { [weak self] result in
            switch result {
            case .success:
                self?.lastPrintResult = "Printed: \(label.title)"
            case .failure(let error):
                self?.lastPrintResult = "Failed: \(Self.friendlyMessage(for: error))"
            }
            DispatchQueue.main.async {
                completion?(result)
            }
        }
    }
}

// MARK: - Friendly error messages

private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}

extension PrinterService {
    /// Normalize line endings to CRLF for better compatibility with TSPL parsers.
    static func normalizePrinterCommands(_ raw: String) -> String {
        let lfOnly = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return lfOnly.replacingOccurrences(of: "\n", with: "\r\n")
    }

    /// Replace technical NWError 53 etc. with a message the user can act on.
    static func friendlyMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "Network.NWError" || ns.domain.contains("NWError") {
            switch ns.code {
            case 53: // connection abort (we closed it or printer closed it)
                return "Printer connection was closed. Check that the printer is on, the IP in Settings is correct, and try again."
            case 54: // connection reset
                return "Printer reset the connection. Make sure the printer is ready and try again."
            case 61: // connection refused
                return "Printer refused the connection. Check the IP address and that the printer is on the same Wi‑Fi."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

// MARK: - Errors

enum PrinterError: LocalizedError {
    case invalidData
    case networkUnavailable
    case timeout
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid print data"
        case .networkUnavailable: return "Network unavailable"
        case .timeout: return "Connection timed out"
        case .connectionFailed: return "Could not connect to printer"
        }
    }
}
