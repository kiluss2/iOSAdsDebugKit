import UIKit

final class AdsDebugCustomVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
            indexPathForKey: indexPath(forCustomKey:)
        )
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AdTelemetry.shared.customEventsSnapshot().count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Custom (\(AdTelemetry.shared.customEventsSnapshot().count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none

        let events = AdTelemetry.shared.customEventsSnapshot()
        guard indexPath.row < events.count else { return cell }

        let item = events[indexPath.row]
        cell.accessibilityIdentifier = Self.key(for: item)
        let time = DateFormatter.cached.string(from: item.time)

        var parts = item.values
            .filter { !["custom_debug", "event", "status", "message"].contains($0.key) }
            .map { "\($0.key):\($0.value)" }
            .sorted()
        if let message = item.message, !message.isEmpty {
            parts.insert(message, at: 0)
        }
        cell.configure(
            title: "[\(time)] \(item.event) • \(item.status.rawValue)",
            detail: parts.joined(separator: " • "),
            titleColor: AdsDebugTheme.statusColor(item.status),
            titleFont: .systemFont(ofSize: 13, weight: .semibold),
            detailFont: .systemFont(ofSize: 11, weight: .regular)
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let events = AdTelemetry.shared.customEventsSnapshot()
        guard indexPath.row < events.count else { return }
        let item = events[indexPath.row]
        UIPasteboard.general.string = "\(item.event) \(item.status.rawValue) \(item.message ?? "")"
        AdToast.show("Copied custom event")
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func indexPath(forCustomKey key: String) -> IndexPath? {
        let events = AdTelemetry.shared.customEventsSnapshot()
        guard let row = events.firstIndex(where: { Self.key(for: $0) == key }) else { return nil }
        return IndexPath(row: row, section: 0)
    }

    private static func key(for event: AdDebugCustomEvent) -> String {
        [
            String(event.time.timeIntervalSinceReferenceDate),
            event.event,
            event.status.rawValue,
            event.message ?? "",
            event.values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        ].joined(separator: "|")
    }
}
