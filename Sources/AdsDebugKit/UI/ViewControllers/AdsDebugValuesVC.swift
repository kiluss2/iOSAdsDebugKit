import UIKit

final class AdsDebugValuesVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let table = AdsDebugTableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.register(DebugValueCell.self, forCellReuseIdentifier: DebugValueCell.reuseID)
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
        AdTelemetry.shared.getDebugValues().count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Values (\(AdTelemetry.shared.getDebugValues().count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let definitions = AdTelemetry.shared.getDebugValues()
        guard indexPath.row < definitions.count,
              let cell = tableView.dequeueReusableCell(
                withIdentifier: DebugValueCell.reuseID,
                for: indexPath
              ) as? DebugValueCell else {
            return UITableViewCell()
        }

        let definition = definitions[indexPath.row]
        let override = AdTelemetry.shared.debugValueOverride(forKey: definition.key)
        let optionTitle = definition.options.first { $0.value == override }?.title
        cell.configure(definition: definition, selectionTitle: optionTitle)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let definitions = AdTelemetry.shared.getDebugValues()
        guard indexPath.row < definitions.count,
              let sourceView = tableView.cellForRow(at: indexPath)?.contentView else { return }
        showValuePicker(for: definitions[indexPath.row], sourceView: sourceView)
    }

    func showValuePicker(for definition: AdDebugValueDefinition, sourceView: UIView) {
        let current = AdTelemetry.shared.debugValueOverride(forKey: definition.key)
        let alert = UIAlertController(
            title: definition.title,
            message: "Select a debug override for \(definition.key)",
            preferredStyle: .actionSheet
        )

        let appValueTitle = current == nil ? "App Value ✓" : "App Value"
        alert.addAction(UIAlertAction(title: appValueTitle, style: .default) { [weak self] _ in
            AdTelemetry.shared.setDebugValueOverride(nil, forKey: definition.key)
            self?.table.reloadData()
        })

        for option in definition.options {
            let title = option.value == current ? "\(option.title) ✓" : option.title
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                AdTelemetry.shared.setDebugValueOverride(option.value, forKey: definition.key)
                self?.table.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
            popover.permittedArrowDirections = [.up, .down]
        }

        present(alert, animated: true)
    }
}

private final class DebugValueCell: UITableViewCell {
    static let reuseID = "DebugValueCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let keyLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = AdsDebugTheme.card
        cardView.layer.cornerRadius = AdsDebugTheme.cardCornerRadius
        cardView.layer.masksToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AdsDebugTheme.textPrimary
        titleLabel.numberOfLines = 0

        keyLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        keyLabel.textColor = AdsDebugTheme.textMuted
        keyLabel.numberOfLines = 0

        valueLabel.font = .systemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = AdsDebugTheme.textSecondary
        valueLabel.numberOfLines = 0

        let root = UIStackView(arrangedSubviews: [titleLabel, keyLabel, valueLabel])
        root.axis = .vertical
        root.spacing = 6
        root.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(root)

        let verticalGap = AdsDebugTheme.cardVerticalGap / 2
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalGap),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalGap),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AdsDebugTheme.cardHorizontalInset),

            root.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AdsDebugTheme.cardContentVerticalPadding),
            root.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AdsDebugTheme.cardContentVerticalPadding),
            root.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AdsDebugTheme.cardContentHorizontalPadding),
            root.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AdsDebugTheme.cardContentHorizontalPadding)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(definition: AdDebugValueDefinition, selectionTitle: String?) {
        titleLabel.text = definition.title
        keyLabel.text = "key=\(definition.key)"
        if let selectionTitle {
            valueLabel.text = "override=\(selectionTitle)"
            valueLabel.textColor = AdsDebugTheme.loading
        } else {
            valueLabel.text = "source=App Value"
            valueLabel.textColor = AdsDebugTheme.success
        }
        accessibilityIdentifier = "AdsDebugValue.\(definition.key)"
    }
}
