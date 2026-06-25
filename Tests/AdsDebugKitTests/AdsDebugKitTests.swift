import XCTest
@testable import AdsDebugKit

final class AdsDebugKitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AdTelemetry.shared.resetForTesting()
        AdTelemetry.initialize(AdTelemetryConfiguration(
            allAdIDs: { TestAdID.allCases },
            admobOnlyAdID: { provider in
                provider.name == TestAdID.priority.name ? TestAdID.admobOnly : nil
            }
        ))
    }

    override func tearDown() {
        AdTelemetry.shared.resetForTesting()
        super.tearDown()
    }

    func testResolverReturnsOriginalWhenDebugDisabled() {
        let id = AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority)
        XCTAssertEqual(id, TestAdID.priority.id)
    }

    func testResolverFailPrimaryOnlyAffectsPriorityPlacements() {
        enableDebug(mode: .failPrimary)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority),
            GoogleMobileAdsTestUnitIds.invalid
        )
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.banner),
            TestAdID.banner.id
        )
    }

    func testResolverFailPrimaryAlsoAffectsHFPlacements() {
        enableDebug(mode: .failPrimary)

        let hfPlacement = "ADSInterstitialOpenFirstHFID"
        let hfAdUnitId = "ca-app-pub-1234567890123456/5555555555"

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(
                placement: hfPlacement,
                primaryAdUnitId: hfAdUnitId,
                unit: .interstitial
            ),
            GoogleMobileAdsTestUnitIds.invalid
        )

        let hfUnit = AdDebugAdUnit(
            name: hfPlacement,
            adUnitId: hfAdUnitId,
            unit: .interstitial
        )
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: hfUnit), .falseAd)
        XCTAssertEqual(
            AdTelemetry.shared.resolvedAdUnitIdForDisplay(hfUnit),
            GoogleMobileAdsTestUnitIds.invalid
        )
    }

    func testResolverForceAdMobOnlyUsesFallbackForAdMobRole() {
        enableDebug(mode: .forceAdMobOnly)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority, role: .primary),
            GoogleMobileAdsTestUnitIds.invalid
        )
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority, role: .admobOnly),
            TestAdID.admobOnly.id
        )
    }

    func testResolverDoesNotOverrideAppId() {
        enableDebug(mode: .failAll)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.appId),
            TestAdID.appId.id
        )
    }

    func testCustomDebugModeUsesIOSAdMobTestId() {
        enableDebug(mode: .custom)
        AdTelemetry.shared.setCustomMode(.debug, forAdUnitName: TestAdID.banner.name)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.banner),
            GoogleMobileAdsTestUnitIds.fixedBanner
        )
    }

    func testDisplayModeMirrorsGlobalOverrideMode() {
        enableDebug(mode: .failAll)

        let units = AdTelemetry.shared.getAdUnits()
        let priority = units.first { $0.name == TestAdID.priority.name }!
        let banner = units.first { $0.name == TestAdID.banner.name }!

        XCTAssertEqual(AdTelemetry.shared.displayMode(for: priority), .falseAd)
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: banner), .falseAd)
        XCTAssertEqual(
            AdTelemetry.shared.resolvedAdUnitIdForDisplay(banner),
            GoogleMobileAdsTestUnitIds.invalid
        )
    }

    func testCustomModeSnapshotsCurrentGlobalModeLikeAndroid() {
        enableDebug(mode: .failAll)

        let units = AdTelemetry.shared.getAdUnits()
        let priority = units.first { $0.name == TestAdID.priority.name }!
        let banner = units.first { $0.name == TestAdID.banner.name }!

        AdTelemetry.shared.setCustomMode(.release, forAdUnitName: TestAdID.banner.name)

        XCTAssertEqual(AdTelemetry.shared.settings.adIdOverrideMode, .custom)
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: banner), .release)
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: priority), .falseAd)
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.banner),
            TestAdID.banner.id
        )
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority),
            GoogleMobileAdsTestUnitIds.invalid
        )
    }

    func testCustomModeAllReleaseFallsBackToNormalLikeAndroid() {
        enableDebug(mode: .failPrimary)

        AdTelemetry.shared.setCustomMode(.release, forAdUnitName: TestAdID.priority.name)

        XCTAssertEqual(AdTelemetry.shared.settings.adIdOverrideMode, .normal)
        XCTAssertEqual(AdTelemetry.shared.settings.customAdUnitModes, [:])
    }

    func testCustomAdMobOnlyModeUsesFallbackForPrimaryRole() {
        enableDebug(mode: .custom)
        AdTelemetry.shared.setCustomMode(.admobOnly, forAdUnitName: TestAdID.priority.name)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority),
            TestAdID.admobOnly.id
        )
    }

    func testAdStatesDisplayResolvedIdAfterModeChange() {
        enableDebug(mode: .failAll)

        let states = AdTelemetry.shared.getAdStates()
        let banner = states.first { $0.adIdName == TestAdID.banner.name }

        XCTAssertEqual(banner?.adId, GoogleMobileAdsTestUnitIds.invalid)
    }

    func testLoadStartAfterSuccessShowsLoadingDuringRefresh() {
        enableDebug()

        AdTelemetry.shared.log(AdEvent(unit: .native, action: .loadSuccess, adId: TestAdID.banner))
        waitUntil {
            AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.banner.name }?.loadState == .success
        }

        AdTelemetry.shared.log(AdEvent(unit: .native, action: .loadStart, adId: TestAdID.banner))
        waitUntil {
            AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.banner.name }?.loadState == .loading
        }

        let banner = AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.banner.name }
        XCTAssertEqual(banner?.successCount, 1)
    }

    func testShowSuccessAndImpressionCountAsOnePresentation() {
        enableDebug()

        AdTelemetry.shared.log(AdEvent(unit: .interstitial, action: .showStart, adId: TestAdID.priority))
        AdTelemetry.shared.log(AdEvent(unit: .interstitial, action: .showSuccess, adId: TestAdID.priority))
        AdTelemetry.shared.log(AdEvent(unit: .interstitial, action: .impression, adId: TestAdID.priority))

        waitUntil {
            AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.priority.name }?.showedCount == 1
        }

        AdTelemetry.shared.log(AdEvent(unit: .interstitial, action: .showStart, adId: TestAdID.priority))
        AdTelemetry.shared.log(AdEvent(unit: .interstitial, action: .showSuccess, adId: TestAdID.priority))

        waitUntil {
            AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.priority.name }?.showedCount == 2
        }

        let priority = AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.priority.name }
        XCTAssertEqual(priority?.showedCount, 2)
    }

    func testStructuredParserLogsAdExternalAndCustomEvents() {
        enableDebug()

        AdTelemetry.shared.logStructuredLine("ads_debug=1 event=loadSuccess unit=interstitial placement=ADSInterstitialOpenFirst2FID adUnit=ca-app-pub-test/1 network=admob")
        AdTelemetry.shared.logStructuredLine("external_debug=1 provider=adjust event=purchase status=success message='tracked ok'")
        AdTelemetry.shared.logStructuredLine("custom_debug=1 event=remote_config status=submitted message='loaded'")

        waitUntil {
            AdTelemetry.shared.eventsSnapshot().count == 1 &&
            AdTelemetry.shared.externalEventsSnapshot().count == 1 &&
            AdTelemetry.shared.customEventsSnapshot().count == 1
        }

        XCTAssertEqual(AdTelemetry.shared.eventsSnapshot().first?.action, .loadSuccess)
        XCTAssertEqual(AdTelemetry.shared.externalEventsSnapshot().first?.provider, "adjust")
        XCTAssertEqual(AdTelemetry.shared.customEventsSnapshot().first?.event, "remote_config")
    }

    func testDebugLinesDeduplicateSameRawLine() {
        enableDebug()

        let line = "Adjust Response message: Ad revenue tracked"
        AdTelemetry.shared.logDebugLines([line, line])

        waitUntil {
            AdTelemetry.shared.debugLines.count == 1
        }

        XCTAssertEqual(AdTelemetry.shared.debugLines.first?.contains(line), true)

        AdTelemetry.shared.clearEvents()
        waitUntil {
            AdTelemetry.shared.debugLines.isEmpty
        }

        AdTelemetry.shared.logDebugLine(line)
        waitUntil {
            AdTelemetry.shared.debugLines.count == 1
        }
    }

    func testAdjustRawLogParserAcceptsLegacyAndOSLogForms() {
        let messageToken = "[Adjust]d: Got JSON response with message:"
        let responseToken = "[Adjust]v: Response:"

        XCTAssertEqual(
            normalizedAdjustLine(
                "[Adjust]d: Got JSON response with message: Ad revenue tracked",
                messageToken: messageToken,
                responseToken: responseToken
            ),
            "Adjust Response message: Ad revenue tracked"
        )
        XCTAssertEqual(
            normalizedAdjustLine(
                "Got JSON response with message: Event request failed (Invalid event token)",
                messageToken: messageToken,
                responseToken: responseToken
            ),
            "Adjust Response message: Event request failed (Invalid event token)"
        )
        XCTAssertEqual(
            normalizedAdjustLine(
                #"[Adjust]v: Response: {"timestamp":"2026-06-02T06:35:26.852Z+0000","message":"Ad revenue tracked"}"#,
                messageToken: messageToken,
                responseToken: responseToken
            ),
            "Adjust Response message: Ad revenue tracked"
        )
    }

    func testSettingsDecodeOldPayloadWithDefaults() throws {
        let data = #"{"debugEnabled":true,"showToasts":true,"keepEvents":12}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AdDebugSettings.self, from: data)

        XCTAssertTrue(settings.debugEnabled)
        XCTAssertTrue(settings.showToasts)
        XCTAssertEqual(settings.keepEvents, 12)
        XCTAssertEqual(settings.adIdOverrideMode, .normal)
        XCTAssertEqual(settings.customAdUnitModes, [:])
        XCTAssertFalse(settings.rawLogTapEnabled)
    }

    func testEventTrimAppliesToAllStreams() {
        enableDebug()
        var settings = AdTelemetry.shared.settings
        settings.keepEvents = 1
        AdTelemetry.shared.settings = settings

        AdTelemetry.shared.log(AdEvent(unit: .banner, action: .loadStart, adId: TestAdID.banner))
        AdTelemetry.shared.log(AdEvent(unit: .banner, action: .loadSuccess, adId: TestAdID.banner))
        AdTelemetry.shared.logExternal(provider: "adjust", event: "a", status: .submitted)
        AdTelemetry.shared.logExternal(provider: "adjust", event: "b", status: .success)
        AdTelemetry.shared.logCustom(event: "a")
        AdTelemetry.shared.logCustom(event: "b")

        waitUntil {
            AdTelemetry.shared.eventsSnapshot().count == 1 &&
            AdTelemetry.shared.externalEventsSnapshot().count == 1 &&
            AdTelemetry.shared.customEventsSnapshot().count == 1
        }

        XCTAssertEqual(AdTelemetry.shared.eventsSnapshot().first?.action, .loadSuccess)
        XCTAssertEqual(AdTelemetry.shared.externalEventsSnapshot().first?.event, "b")
        XCTAssertEqual(AdTelemetry.shared.customEventsSnapshot().first?.event, "b")
    }

    func testConsoleTabsMatchAndroidOrder() {
        XCTAssertEqual(AdsDebugVC.tabTitles, ["Ad States", "Ad Events", "Externals", "Custom", "Settings", "Ad Units"])

        let vc = AdsDebugVC()
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.children.count, 1)
    }

    func testConsoleBackgroundLeavesStatusAreaBlurredAndDimmedLikeAndroid() {
        let vc = AdsDebugVC()
        vc.loadViewIfNeeded()

        guard let background = vc.view.adsDebugFirstSubview(of: AdsDebugBackgroundView.self) else {
            return XCTFail("Expected console background view")
        }

        let pinsBackgroundToSafeArea = vc.view.constraints.contains { constraint in
            constraint.firstItem as? UIView === background &&
            constraint.firstAttribute == .top &&
            constraint.secondItem as? UILayoutGuide === vc.view.safeAreaLayoutGuide &&
            constraint.secondAttribute == .top
        }

        XCTAssertTrue(pinsBackgroundToSafeArea)

        guard let statusBackdrop = vc.view.adsDebugFirstSubview(of: UIVisualEffectView.self) else {
            return XCTFail("Expected status area blur backdrop")
        }

        let pinsBackdropToStatusArea = vc.view.constraints.contains { constraint in
            constraint.firstItem as? UIView === statusBackdrop &&
            constraint.firstAttribute == .bottom &&
            constraint.secondItem as? UILayoutGuide === vc.view.safeAreaLayoutGuide &&
            constraint.secondAttribute == .top
        }

        XCTAssertTrue(pinsBackdropToStatusArea)
        XCTAssertNotNil(statusBackdrop.effect)
        XCTAssertGreaterThan(statusBackdrop.contentView.subviews.first?.backgroundColor?.cgColor.alpha ?? 0, 0)
    }

    func testSettingsSwitchStaysInsideAndroidStyleRowLayout() {
        let vc = AdsDebugSettingsVC()
        vc.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: vc.view.frame)
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()

        let table = vc.view.adsDebugFirstSubview(of: UITableView.self)
        XCTAssertNotNil(table)
        table?.layoutIfNeeded()

        guard let cell = table?.cellForRow(at: IndexPath(row: 0, section: 0)),
              let toggle = cell.adsDebugFirstSubview(of: UISwitch.self) else {
            return XCTFail("Expected first settings row to contain a switch")
        }

        cell.layoutIfNeeded()
        let switchFrame = toggle.convert(toggle.bounds, to: cell.contentView)
        XCTAssertLessThanOrEqual(switchFrame.maxX, cell.contentView.bounds.maxX - 16)
    }

    func testSettingsAdIdOverrideCardDoesNotOpenModePickerLikeAndroid() {
        let vc = AdsDebugSettingsVC()
        vc.view.frame = CGRect(x: 0, y: 0, width: 768, height: 1024)
        let window = UIWindow(frame: vc.view.frame)
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()

        guard let table = vc.view.adsDebugFirstSubview(of: UITableView.self) else {
            return XCTFail("Expected settings table")
        }

        let overrideModeIndexPath = IndexPath(row: 5, section: 0)
        table.layoutIfNeeded()
        vc.tableView(table, didSelectRowAt: overrideModeIndexPath)

        XCTAssertNil(vc.presentedViewController)
        XCTAssertEqual(
            table.cellForRow(at: overrideModeIndexPath)?.selectionStyle,
            UITableViewCell.SelectionStyle.none
        )
    }

    func testSettingsCycleModeLongPressCanOpenModePicker() {
        let vc = AdsDebugSettingsVC()
        vc.view.frame = CGRect(x: 0, y: 0, width: 768, height: 1024)
        let window = UIWindow(frame: vc.view.frame)
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()

        guard let table = vc.view.adsDebugFirstSubview(of: UITableView.self) else {
            return XCTFail("Expected settings table")
        }

        let cycleModeIndexPath = IndexPath(row: 6, section: 0)
        table.layoutIfNeeded()
        guard let cell = table.cellForRow(at: cycleModeIndexPath) else {
            return XCTFail("Expected Cycle mode row")
        }

        let longPress = cell.contentView.gestureRecognizers?
            .compactMap { $0 as? UILongPressGestureRecognizer }
            .first { $0.name == "AdsDebugCycleModeLongPress" }
        XCTAssertNotNil(longPress)

        vc.showOverrideModePicker(from: cell.contentView)

        waitUntil {
            vc.presentedViewController is UIAlertController
        }

        guard let alert = vc.presentedViewController as? UIAlertController else {
            return XCTFail("Expected override mode action sheet")
        }

        XCTAssertEqual(alert.preferredStyle, .actionSheet)
        XCTAssertNotNil(alert.popoverPresentationController?.sourceView)
        XCTAssertNotEqual(alert.popoverPresentationController?.sourceRect, .zero)
    }

    func testSettingsAdIdOverrideInfoButtonShowsDescriptionDialogLikeAndroid() {
        let vc = AdsDebugSettingsVC()
        vc.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: vc.view.frame)
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()

        guard let table = vc.view.adsDebugFirstSubview(of: UITableView.self) else {
            return XCTFail("Expected settings table")
        }

        let overrideModeIndexPath = IndexPath(row: 5, section: 0)
        table.layoutIfNeeded()
        guard let cell = table.cellForRow(at: overrideModeIndexPath),
              let infoButton = cell.adsDebugFirstSubview(of: UIButton.self) else {
            return XCTFail("Expected Ad ID override info button")
        }

        XCTAssertEqual(infoButton.accessibilityIdentifier, "AdsDebugAdIdOverrideInfoButton")
        XCTAssertEqual(infoButton.actions(forTarget: vc, forControlEvent: .touchUpInside), ["showAdIdOverrideInfo"])
        vc.showAdIdOverrideInfo()

        waitUntil {
            vc.presentedViewController is UIAlertController
        }

        guard let alert = vc.presentedViewController as? UIAlertController else {
            return XCTFail("Expected info dialog")
        }

        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.title, "Ad ID override modes")
        XCTAssertTrue(alert.message?.contains("FAIL_PRIMARY") == true)
        XCTAssertTrue(alert.message?.contains("CUSTOM") == true)
        XCTAssertTrue(alert.message?.contains("Long-press Cycle mode") == true)
    }

    func testDebugComboGestureDefaultSequenceMatchesAndroidStyleUnlock() {
        XCTAssertEqual(DebugComboGestureStep.defaultSequence, [.swipeDown, .tap(count: 2), .swipeUp])

        let view = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        let helper = DebugComboGestureHelper()
        helper.setup(on: view) {}

        XCTAssertEqual(view.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.count, 1)
        XCTAssertEqual(
            view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.map(\.numberOfTapsRequired),
            [2]
        )
    }

    func testDebugComboGestureAcceptsCustomUnlockSequence() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        let helper = DebugComboGestureHelper()
        helper.setup(on: view, sequence: [.tap(count: 5)])

        XCTAssertEqual(view.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.count, 0)
        XCTAssertEqual(
            view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.map(\.numberOfTapsRequired),
            [5]
        )
    }

    func testTableReloadPreservesVisibleItemWhenRowsAreInsertedBeforeIt() {
        let dataSource = ScrollAnchorDataSource(items: (0..<12).map(String.init))
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 120), style: .plain)
        let viewController = UIViewController()
        let window = UIWindow(frame: table.frame)
        viewController.view.frame = table.frame
        viewController.view.addSubview(table)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        table.dataSource = dataSource
        table.rowHeight = 40
        table.estimatedRowHeight = 40
        table.reloadData()
        table.layoutIfNeeded()

        table.scrollToRow(at: IndexPath(row: 4, section: 0), at: .top, animated: false)
        table.layoutIfNeeded()
        XCTAssertEqual(table.cellForRow(at: IndexPath(row: 4, section: 0))?.accessibilityIdentifier, "4")

        dataSource.items.insert(contentsOf: ["new-0", "new-1"], at: 0)
        table.adsDebugReloadDataPreservingVisibleItem(
            anchorKeyForVisibleCell: { _, cell in cell.accessibilityIdentifier },
            indexPathForKey: { key in
                dataSource.items.firstIndex(of: key).map { IndexPath(row: $0, section: 0) }
            }
        )

        let topPoint = CGPoint(x: table.bounds.midX, y: table.contentOffset.y + table.adjustedContentInset.top + 1)
        guard let topIndexPath = table.indexPathForRow(at: topPoint) else {
            return XCTFail("Expected a visible row at the top of the table")
        }
        XCTAssertEqual(dataSource.items[topIndexPath.row], "4")
    }

    func testListDesignTokensKeepRoundedCardsAndShadowedHeaderText() {
        let cell = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.configure(title: "Card", detail: "Line")
        XCTAssertEqual(cell.contentView.subviews.first?.layer.cornerRadius, AdsDebugTheme.cardCornerRadius)

        let header = AdsDebugTheme.sectionHeader(title: "Ad Units (3)")
        header.frame = CGRect(x: 0, y: 0, width: 390, height: 38)
        header.layoutIfNeeded()
        XCTAssertEqual(header.backgroundColor, .clear)
        let label = header.adsDebugFirstSubview(of: UILabel.self)
        XCTAssertNotNil(label)
        XCTAssertGreaterThan(label?.layer.shadowOpacity ?? 0, 0)
    }

    private func enableDebug(mode: AdIdOverrideMode = .normal) {
        var settings = AdTelemetry.shared.settings
        settings.debugEnabled = true
        settings.adIdOverrideMode = mode
        AdTelemetry.shared.settings = settings
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: @escaping () -> Bool
    ) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if predicate() { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        XCTFail("Condition was not met in time", file: file, line: line)
    }
}

private extension UIView {
    func adsDebugFirstSubview<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let match = subview.adsDebugFirstSubview(of: type) {
                return match
            }
        }
        return nil
    }
}

private final class ScrollAnchorDataSource: NSObject, UITableViewDataSource {
    var items: [String]

    init(items: [String]) {
        self.items = items
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let item = items[indexPath.row]
        cell.textLabel?.text = item
        cell.accessibilityIdentifier = item
        return cell
    }
}

private enum TestAdID: String, CaseIterable, Codable, AdIDProvider {
    case priority = "ADSInterstitialOpenFirst2FID"
    case admobOnly = "ADSInterstitialOpenFirstAdMobOnlyID"
    case banner = "ADSBannerID"
    case appId = "GADApplicationIdentifier"

    var name: String { rawValue }

    var id: String {
        switch self {
        case .priority:
            return "ca-app-pub-1234567890123456/1111111111"
        case .admobOnly:
            return "ca-app-pub-1234567890123456/2222222222"
        case .banner:
            return "ca-app-pub-1234567890123456/3333333333"
        case .appId:
            return "ca-app-pub-1234567890123456~4444444444"
        }
    }
}
