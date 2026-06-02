//
//  AdTelemetryProtocols.swift
//  AdsDebugKit
//
//  Created on 2025.
//

import Foundation

/// Protocol for ad ID types that can be used with AdTelemetry
/// App must implement this protocol for their ad ID enum
public protocol AdIDProvider: Hashable, Codable, CaseIterable {
    /// Raw string value of the ad ID
    var rawValue: String { get }
    
    /// Display name of the ad ID (usually same as rawValue)
    var name: String { get }
    
    /// Actual ad unit ID string to use for ad requests
    var id: String { get }
}

/// Configuration for AdTelemetry to work with app-specific ad IDs
public struct AdTelemetryConfiguration {
    /// Closure to get all available ad IDs
    public let getAllAdIDs: () -> [any AdIDProvider]
    public let adUnitMetadata: ((any AdIDProvider) -> AdDebugAdUnit?)?
    public let admobOnlyAdID: ((any AdIDProvider) -> (any AdIDProvider)?)?
    public let rawLogTapPolicy: AdRawLogTapPolicy
    
    public init(
        allAdIDs: @escaping () -> [any AdIDProvider],
        adUnitMetadata: ((any AdIDProvider) -> AdDebugAdUnit?)? = nil,
        admobOnlyAdID: ((any AdIDProvider) -> (any AdIDProvider)?)? = nil,
        rawLogTapPolicy: AdRawLogTapPolicy = .disabled
    ) {
        self.getAllAdIDs = allAdIDs
        self.adUnitMetadata = adUnitMetadata
        self.admobOnlyAdID = admobOnlyAdID
        self.rawLogTapPolicy = rawLogTapPolicy
    }
}
