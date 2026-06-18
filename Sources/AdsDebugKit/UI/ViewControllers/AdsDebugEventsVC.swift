//
//  AdsDebugEventsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugEventsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
            indexPathForKey: indexPath(forEventKey:)
        )
    }
    
    // MARK: - TableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2 + AdTelemetry.shared.revenueByNetwork().count
        default:
            return AdTelemetry.shared.eventsSnapshot().count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let eventsCount = AdTelemetry.shared.eventsSnapshot().count
        let titles = ["Overview", "Events (\(eventsCount))"]
        return AdsDebugTheme.sectionHeader(title: titles[section])
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.selectionStyle = .none
        
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                c.configure(title: String(format: "Total revenue: $%.4f", AdTelemetry.shared.totalRevenueUSD()))
            } else if indexPath.row == 1 {
                c.configure(
                    title: "Events stored: \(AdTelemetry.shared.eventsSnapshot().count)",
                    detail: "Tap to copy JSON"
                )
                c.selectionStyle = .default
            } else {
                let pair = AdTelemetry.shared.revenueByNetwork()[indexPath.row - 2]
                c.configure(
                    title: pair.0.isEmpty ? "Unknown ad network" : pair.0,
                    detail: String(format: "$%.4f", pair.1)
                )
            }
            
        default:
            // Events are already newest-first (inserted at beginning)
            let eventArray = AdTelemetry.shared.eventsSnapshot()
            guard indexPath.row < eventArray.count else { break }
            
            let e = eventArray[indexPath.row]
            c.accessibilityIdentifier = Self.key(for: e)
            let time = DateFormatter.cached.string(from: e.time)
            let titleColor = e.action == .custom("Will appear") ? AdsDebugTheme.loading : nil
            
            var parts: [String] = []
            if let adIdName = e.adIdName {
                parts.append("name:\(adIdName)")
            }
            if let n = e.network { parts.append("nw:\(n)") }
            if let li = e.lineItem { parts.append("li:\(li)") }
            if let cp = e.eCPM { parts.append(String(format: "ecpm:$%.4f", cp)) }
            if let pr = e.precision { parts.append("prec:\(pr)") }
            if let err = e.error { parts.append("err:\(err)") }
            
            c.configure(
                title: "[\(time)] \(e.unit.raw) • \(e.action.rawValue)",
                detail: parts.joined(separator: " • "),
                titleColor: titleColor
            )
        }
        
        return c
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0, indexPath.row == 1 else { return }
        
        if let data = try? JSONEncoder().encode(AdTelemetry.shared.eventsSnapshot()),
           let str = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = str
            AdToast.show("Copied events JSON")
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func indexPath(forEventKey key: String) -> IndexPath? {
        let events = AdTelemetry.shared.eventsSnapshot()
        guard let row = events.firstIndex(where: { Self.key(for: $0) == key }) else { return nil }
        return IndexPath(row: row, section: 1)
    }

    private static func key(for event: AdEvent) -> String {
        let parts: [String] = [
            String(event.time.timeIntervalSinceReferenceDate),
            event.unit.raw,
            event.action.rawValue,
            event.adIdName ?? "",
            event.adId ?? "",
            event.network ?? "",
            event.lineItem ?? "",
            event.precision ?? "",
            event.error ?? "",
            event.eCPM.map { String($0) } ?? ""
        ]
        return parts.joined(separator: "|")
    }
}
