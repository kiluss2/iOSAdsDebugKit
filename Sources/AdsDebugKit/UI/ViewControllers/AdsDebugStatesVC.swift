//
//  AdsDebugStatesVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugStatesVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
    
    private func getAdStates() -> [AdStateInfo] {
        // Get states from AdTelemetry (already maintained and updated)
        return AdTelemetry.shared.getAdStates()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let states = getAdStates()
        return states.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        
        let states = getAdStates()
        guard indexPath.row < states.count else { return cell }
        
        let state = states[indexPath.row]
        let titleText = NSMutableAttributedString(string: state.adIdName)
        titleText.append(
            NSAttributedString(
                string: "\n\(state.adId)",
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10),
                    NSAttributedString.Key.foregroundColor: AdsDebugTheme.textMuted,
                ]
            )
        )
        
        // Build load status string with counts
        var loadText = state.loadState.rawValue
        var loadColor: UIColor = AdsDebugTheme.textMuted
        if state.loadState == .loading {
            loadColor = AdsDebugTheme.loading
        } else if state.loadState == .success {
            loadText += "(\(state.successCount))"
            loadColor = AdsDebugTheme.success
        } else if state.loadState == .failed {
            if state.failedCount > 0 { loadText += "(\(state.failedCount))" }
            loadColor = AdsDebugTheme.failed
        }
        
        // Build show status string with count
        let showText: String
        let showColor: UIColor?
        if state.showedCount > 0 {
            showText = "\(state.showedCount)"
            showColor = AdsDebugTheme.success
        } else {
            showText = "No"
            showColor = AdsDebugTheme.textMuted
        }
        
        // Build details as a list of tuples: (label, value, colorForValue)
        // Only the value part will be colored, not the label
        let details: [(String, String, UIColor?)] = [
            ("Load: ", loadText, loadColor),
            ("Show/impression: ", showText, showColor),
            ("Rev: ", String(format: "$%.4f", state.revenueUSD), state.revenueUSD > 0 ? AdsDebugTheme.loading : nil)
        ]

        let detailText = NSMutableAttributedString()
        for (i, item) in details.enumerated() {
            if i > 0 { detailText.append(.init(string: " • ")) }
            // Append label (no color)
            detailText.append(NSAttributedString(string: item.0))
            // Append value (with color if specified)
            let valueAttributes = item.2.map { [NSAttributedString.Key.foregroundColor: $0] }
            detailText.append(NSAttributedString(string: item.1, attributes: valueAttributes))
        }
        let titleColor: UIColor
        switch state.loadState {
        case .success: titleColor = AdsDebugTheme.success
        case .failed: titleColor = AdsDebugTheme.failed
        case .loading: titleColor = AdsDebugTheme.loading
        case .notLoad: titleColor = AdsDebugTheme.textMuted
        }

        cell.configure(
            title: titleText,
            detail: detailText,
            titleColor: titleColor,
            titleFont: .systemFont(ofSize: 15, weight: .regular),
            detailFont: .systemFont(ofSize: 12, weight: .regular)
        )
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "All IDs (\(getAdStates().count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }
}
