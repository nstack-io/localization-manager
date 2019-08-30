//
//  Store.swift
//  TranslationManager
//
//  Created by Dominik Hádl on 27/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

public protocol LocalizationConfigurationModel {}

public protocol Store {
    associatedtype LanguageType: LanguageModel
    associatedtype ConfigurationType: LocalizationConfigurationModel

    // MARK: Loading

    func data(for language: LanguageType) throws -> Data
    func data(for configuration: ConfigurationType) throws -> Data

    // MARK: Saving

    func save(_ data: Data, for language: LanguageType) throws
    func save(_ data: Data, for configuration: ConfigurationType) throws

    // MARK: Deleting

    /// <#Description#>
    ///
    /// - Parameter language: <#language description#>
    /// - Throws: <#throws value description#>
    func delete(for language: LanguageType) throws

    /// Deletes data for all localizations, ie. all languages.
    ///
    /// - Throws: A `StoreError`, if store inaccessible or deleting failed.
    func deleteAll() throws
}

internal extension Store {
    func asAnyStore() -> AnyStore<LanguageType, ConfigurationType> {
        return AnyStore(self)
    }
}
