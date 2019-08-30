//
//  BundleStore.swift
//  TranslationManager
//
//  Created by Dominik Hádl on 27/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

internal final class BundleStore<
    Language: LanguageModel,
    Configuration: LocalizationConfigurationModel
> {
    private let contextProvider: LocalizationContextProvider

    internal init(contextProvider: LocalizationContextProvider) {
        self.contextProvider = contextProvider
    }
}

// MARK: - Private -

private extension BundleStore {
    func directory(for language: Language) -> String {
        let base = Constants.Store.localizationDirectory
        return base + "/" + language.locale.identifier
    }

    func path(in bundle: Bundle, for language: Language) -> String? {
        // FIXME: Unhardcode here
        return bundle.path(
            forResource: "data",
            ofType: "lcfile",
            inDirectory: directory(for: language)
        )
    }
}

// MARK: - Store -

extension BundleStore: Store {

    // MARK: Loading

    func data(for language: Language) throws -> Data {
        // Check if bundle contains translations file
        guard let filePath = path(in: contextProvider.localizationBundle, for: language) else {
            throw StoreError.dataNotFound
        }

        // Get file URL and return Data with contents of that URL
        let fileUrl = URL(fileURLWithPath: filePath)
        return try Data(contentsOf: fileUrl)
    }

    func data(for configuration: Configuration) throws -> Data {
        // FIXME: Implement
        throw StoreError.notSupported
    }

    // MARK: Saving

    func save(_ data: Data, for language: Language) throws {
        throw StoreError.notSupported
    }

    func save(_ data: Data, for configuration: Configuration) throws {
        throw StoreError.notSupported
    }

    // MARK: Deleting

    func delete(for language: Language) throws {
        throw StoreError.notSupported
    }

    func deleteAll() throws {
        throw StoreError.notSupported
    }
}
