//
//  AdsDebugExternalLogsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugExternalLogsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
        table.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AdTelemetry.shared.externalEventsSnapshot().count + AdTelemetry.shared.debugLines.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Logs (\(AdTelemetry.shared.externalEventsSnapshot().count + AdTelemetry.shared.debugLines.count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.selectionStyle = .none
        
        let externalEvents = AdTelemetry.shared.externalEventsSnapshot()
        if indexPath.row < externalEvents.count {
            let item = externalEvents[indexPath.row]
            let time = DateFormatter.cached.string(from: item.time)
            var parts = item.values
                .filter { !["external_debug", "provider", "event", "status", "message"].contains($0.key) }
                .map { "\($0.key):\($0.value)" }
                .sorted()
            if let message = item.message, !message.isEmpty {
                parts.insert(message, at: 0)
            }
            c.configure(
                title: "[\(time)] \(item.provider) • \(item.event) • \(item.status.rawValue)",
                detail: parts.joined(separator: " • "),
                titleColor: AdsDebugTheme.statusColor(item.status),
                titleFont: .systemFont(ofSize: 13, weight: .semibold),
                detailFont: .systemFont(ofSize: 11, weight: .regular)
            )
            return c
        }

        let rawIndex = indexPath.row - externalEvents.count
        let linesArray = AdTelemetry.shared.debugLines
        guard rawIndex < linesArray.count else { return c }
        
        let line = linesArray[rawIndex]
        let titleColor: UIColor?
        if line.contains("[ViewAppear]") {
            titleColor = AdsDebugTheme.loading
        } else if line.contains("Ad revenue tracked") || line.contains("Flush Result : Success") {
            titleColor = AdsDebugTheme.success
        } else {
            titleColor = nil
        }
        c.configure(
            title: line,
            titleColor: titleColor,
            titleFont: .systemFont(ofSize: 11, weight: .regular)
        )
        
        return c
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let externalEvents = AdTelemetry.shared.externalEventsSnapshot()
        if indexPath.row < externalEvents.count {
            let item = externalEvents[indexPath.row]
            UIPasteboard.general.string = "\(item.provider) \(item.event) \(item.status.rawValue) \(item.message ?? "")"
            AdToast.show("Copied external event")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        let linesArray = AdTelemetry.shared.debugLines
        let rawIndex = indexPath.row - externalEvents.count
        guard rawIndex < linesArray.count else { return }
        
        let line = linesArray[rawIndex]
        UIPasteboard.general.string = line
        AdToast.show("Copied log line")
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
