//
//  BundleStore.swift
//  LocalizationManager
//
//  Created by Dominik Hádl on 21/09/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

internal final class BundleStore<
    Language: LanguageModel,
    Descriptor: LocalizationDescriptor
> {
    private let contextProvider: LocalizationContextRepository

    internal init(contextProvider: LocalizationContextRepository) {
        self.contextProvider = contextProvider
    }
}

// MARK: - Private -

internal extension BundleStore {
    func directory(for language: LanguageModel) -> String {
        let base = Constants.Store.localizationDirectory
        return base + "/" + language.locale.identifier
    }

    func descriptorPath(in bundle: Bundle, for language: Language) -> String? {
        return bundle.path(
            forResource: Constants.Store.descriptorFileName,
            ofType: Constants.Store.fileExtension,
            inDirectory: directory(for: language)
        )
    }

    func dataPath(in bundle: Bundle, for descriptor: Descriptor) -> String? {
        return bundle.path(
            forResource: Constants.Store.dataFileName,
            ofType: Constants.Store.fileExtension,
            inDirectory: directory(for: descriptor.language)
        )
    }
}

// MARK: - Store -

extension BundleStore: Store {

    // MARK: Loading

    func descriptorData(for language: Language) throws -> Data {
        // Check if bundle contains descriptor file
        let bundle = contextProvider.localizationBundle
        guard let filePath = descriptorPath(in: bundle, for: language) else {
            throw StoreError.dataNotFound
        }

        // Get file URL and return Data with contents of that URL
        let fileUrl = URL(fileURLWithPath: filePath)
        return try Data(contentsOf: fileUrl)
    }

    func localizationData(for descriptor: Descriptor) throws -> Data {
        // Check if bundle contains localization data file
        let bundle = contextProvider.localizationBundle
        guard let filePath = dataPath(in: bundle, for: descriptor) else {
            throw StoreError.dataNotFound
        }

        // Get file URL and return Data with contents of that URL
        let fileUrl = URL(fileURLWithPath: filePath)
        return try Data(contentsOf: fileUrl)
    }

    // MARK: Saving

    func save(descriptorData: Data, for language: Language) throws {
        throw StoreError.notSupported
    }

    func save(localizationData: Data, for descriptor: Descriptor) throws {
        throw StoreError.notSupported
    }

    // MARK: Deleting

    func deleteLocalizationData(for language: Language) throws {
        throw StoreError.notSupported
    }

    func deleteAllData() throws {
        throw StoreError.notSupported
    }
}
