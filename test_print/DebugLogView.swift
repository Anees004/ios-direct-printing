//
//  DebugLogView.swift
//  test_print
//
//  In-app debug log viewer for TestFlight users who don't have Xcode console access.
//

import SwiftUI

/// Simple in-memory logger for debugging without Xcode
@Observable
class DebugLogger {
    static let shared = DebugLogger()
    
    private(set) var logs: [LogEntry] = []
    private let maxLogs = 100
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
        
        enum LogType {
            case info, success, error, tspl
            
            var icon: String {
                switch self {
                case .info: return "ℹ️"
                case .success: return "✅"
                case .error: return "❌"
                case .tspl: return "📤"
                }
            }
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .success: return .green
                case .error: return .red
                case .tspl: return .orange
                }
            }
        }
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)
        }
    }
    
    func log(_ message: String, type: LogEntry.LogType = .info) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let entry = LogEntry(timestamp: Date(), message: message, type: type)
            self.logs.append(entry)
            
            // Keep only last maxLogs entries
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
            
            // Also print to console if available
            print("\(type.icon) [\(entry.formattedTime)] \(message)")
        }
    }
    
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
        }
    }
    
    func exportLogs() -> String {
        logs.map { entry in
            "\(entry.type.icon) [\(entry.formattedTime)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

struct DebugLogView: View {
    @State private var logger = DebugLogger.shared
    @State private var showShareSheet = false
    @State private var autoScroll = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats bar
                HStack {
                    Label("\(logger.logs.count) logs", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Toggle("Auto-scroll", isOn: $autoScroll)
                        .font(.caption)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Logs list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if logger.logs.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    Text("No logs yet")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    Text("Enable Debug Mode and try printing")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            } else {
                                ForEach(logger.logs) { entry in
                                    LogEntryRow(entry: entry)
                                        .id(entry.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: logger.logs.count) { _, _ in
                        if autoScroll, let lastLog = logger.logs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Export Logs", systemImage: "square.and.arrow.up")
                        }
                        .disabled(logger.logs.isEmpty)
                        
                        Button(role: .destructive) {
                            logger.clear()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        .disabled(logger.logs.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = saveLogsToFile() {
                    ShareSheet(url: url) {
                        showShareSheet = false
                    }
                }
            }
        }
    }
    
    private func saveLogsToFile() -> URL? {
        let logs = logger.exportLogs()
        let filename = "debug_logs_\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).txt"
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try logs.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}

struct LogEntryRow: View {
    let entry: DebugLogger.LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.type.icon)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                Text(entry.message)
                    .font(.system(.caption, design: entry.type == .tspl ? .monospaced : .default))
                    .foregroundStyle(entry.type.color)
                    .textSelection(.enabled)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(entry.type.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    DebugLogView()
}
