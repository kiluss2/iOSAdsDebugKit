//
//  AdsDebugExternalLogsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugExternalLogsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum LogEntry {
        case external(AdDebugExternalEvent)
        case raw(String, Date)

        var time: Date {
            switch self {
            case .external(let event): return event.time
            case .raw(_, let time): return time
            }
        }
    }

    private let table = AdsDebugTableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        table.dataSource = self
        table.delegate = self
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .adTelemetryUpdated,
            object: nil
        )
    }
    
    @objc private func reload() {
        table.adsDebugReloadDataPreservingVisibleItem(
            anchorKeyForVisibleCell: { _, cell in cell.accessibilityIdentifier },
            indexPathForKey: indexPath(forLogKey:)
        )
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logEntries().count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Logs (\(logEntries().count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.selectionStyle = .none

        let entries = logEntries()
        guard indexPath.row < entries.count else { return c }

        switch entries[indexPath.row] {
        case .external(let item):
            c.accessibilityIdentifier = Self.key(for: entries[indexPath.row])
            let time = DateFormatter.cached.string(from: item.time)
            var parts = item.values
                .filter { !["external_debug", "provider", "event", "status", "message"].contains($0.key) }
                .map { "\($0.key)=\(Self.compactValue($0.value))" }
                .sorted()
            if parts.count > 6 {
                parts = Array(parts.prefix(6)) + ["+\(parts.count - 6) more"]
            }
            if let message = item.message, !message.isEmpty {
                parts.insert(Self.compactValue(message), at: 0)
            }
            c.configure(
                title: "[\(time)] \(item.provider) • \(item.event) • \(item.status.rawValue)",
                detail: parts.joined(separator: " • "),
                titleColor: AdsDebugTheme.statusColor(item.status),
                titleFont: .systemFont(ofSize: 13, weight: .semibold),
                detailFont: .systemFont(ofSize: 11, weight: .regular)
            )
            return c
        case .raw(let line, _):
            let monoCell = AdsDebugMonoTableViewCell(style: .default, reuseIdentifier: nil)
            monoCell.accessibilityIdentifier = Self.key(for: entries[indexPath.row])
            monoCell.configure(text: line, color: Self.externalLineColor(line))
            return monoCell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entries = logEntries()
        guard indexPath.row < entries.count else { return }

        switch entries[indexPath.row] {
        case .external(let item):
            UIPasteboard.general.string = "\(item.provider) \(item.event) \(item.status.rawValue) \(item.message ?? "")"
            AdToast.show("Copied external event")
        case .raw(let line, _):
            UIPasteboard.general.string = line
            AdToast.show("Copied log line")
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func logEntries() -> [LogEntry] {
        let externalEntries = AdTelemetry.shared.externalEventsSnapshot().map(LogEntry.external)
        let rawEntries = AdTelemetry.shared.debugLines.map { line in
            LogEntry.raw(line, Self.rawLineDate(line) ?? Date.distantPast)
        }
        return (externalEntries + rawEntries).sorted { lhs, rhs in
            lhs.time > rhs.time
        }
    }

    private func indexPath(forLogKey key: String) -> IndexPath? {
        let entries = logEntries()
        guard let row = entries.firstIndex(where: { Self.key(for: $0) == key }) else { return nil }
        return IndexPath(row: row, section: 0)
    }

    private static func key(for entry: LogEntry) -> String {
        switch entry {
        case .external(let item):
            return [
                "external",
                String(item.time.timeIntervalSinceReferenceDate),
                item.provider,
                item.event,
                item.status.rawValue,
                item.message ?? "",
                item.values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            ].joined(separator: "|")
        case .raw(let line, let time):
            return ["raw", String(time.timeIntervalSinceReferenceDate), line].joined(separator: "|")
        }
    }

    private static func compactValue(_ value: String) -> String {
        let trimmed = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 140 else { return trimmed }
        return String(trimmed.prefix(137)) + "..."
    }

    private static func rawLineDate(_ line: String) -> Date? {
        guard line.hasPrefix("["),
              let closeIndex = line.firstIndex(of: "]") else { return nil }
        let timestamp = String(line[line.index(after: line.startIndex)..<closeIndex])
        let parts = timestamp.split(separator: ":", maxSplits: 2)
        guard parts.count == 3,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        let secondParts = parts[2].split(separator: ".", maxSplits: 1)
        guard let second = Int(secondParts[0]) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = second
        if secondParts.count == 2,
           let fraction = Double("0." + secondParts[1]) {
            components.nanosecond = Int(fraction * 1_000_000_000)
        }
        return Calendar.current.date(from: components)
    }

    private static func externalLineColor(_ line: String) -> UIColor {
        let lower = line.lowercased()
        if lower.contains("status=failed") ||
            lower.contains("status_code_failure") ||
            lower.contains("result=server_error") ||
            lower.contains("result=no_connectivity") {
            return AdsDebugTheme.failed
        }
        if lower.contains("status=success") ||
            lower.contains("ad revenue tracked") ||
            lower.contains("event tracked") ||
            lower.contains("tracked") ||
            lower.contains("track") ||
            lower.contains("success") ||
            lower.contains("transaction_id") ||
            lower.contains("failed=0") {
            return AdsDebugTheme.success
        }
        if lower.contains("status=submitted") || lower.contains("status=loading") {
            return AdsDebugTheme.loading
        }
        return AdsDebugTheme.textSecondary
    }
}
