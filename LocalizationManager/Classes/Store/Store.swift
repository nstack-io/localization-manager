//
//  Store.swift
//  LocalizationManager
//
//  Created by Dominik Hádl on 27/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

/// A protocol used for handling files related to localization. If you create your own store
/// and adhere to the `Store` protocol, then you can use it to modify how localization data
/// is loaded and saved, eg. if you wish to change directories or the entire logic.
public protocol Store {
    associatedtype Language: LanguageModel
    associatedtype Descriptor: LocalizationDescriptor

    // MARK: Loading

    func descriptorData(for language: Language) throws -> Data
    func localizationData(for descriptor: Descriptor) throws -> Data

    // MARK: Saving

    func save(descriptorData: Data, for language: Language) throws
    func save(localizationData: Data, for descriptor: Descriptor) throws

    // MARK: Deleting

    /// <#Description#>
    ///
    /// - Parameter language: <#language description#>
    /// - Throws: <#throws value description#>
    func deleteLocalizationData(for language: Language) throws

    /// Deletes data for all localizations, ie. all languages.
    ///
    /// - Throws: A `StoreError`, if store inaccessible or deleting failed.
    func deleteAllData() throws
}

//internal extension Store {
//    func asAnyStore() -> AnyStore<LanguageType, ConfigurationType> {
//        return AnyStore(self)
//    }
//}
