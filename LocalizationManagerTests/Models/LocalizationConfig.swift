//
//  Localization.swift
//  LocalizationManager
//
//  Created by Andrew Lloyd on 19/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

#if os(iOS)
import LocalizationManager
#elseif os(tvOS)
import LocalizationManager_tvOS
#elseif os(macOS)
import LocalizationManager_macOS
#endif

public struct LocalizationConfig: LocalizationDescriptor {

    public var language: DefaultLanguage
    public var lastUpdatedAt = Date()
    public var shouldUpdate: Bool = false
    public var localeIdentifier: String
    public var url: String

    public init(
        lastUpdatedAt: Date = Date(),
        localeIdentifier: String,
        shouldUpdate: Bool = false,
        url: String,
        language: DefaultLanguage
        ) {
        self.lastUpdatedAt = lastUpdatedAt
        self.localeIdentifier = localeIdentifier
        self.shouldUpdate = shouldUpdate
        self.url = url
        self.language = language
    }
}
