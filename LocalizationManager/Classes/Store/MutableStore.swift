//
//  MutableStore.swift
//  LocalizationManager
//
//  Created by Dominik Hádl on 21/09/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

internal final class MutableStore<
    Language: LanguageModel,
    Descriptor: LocalizationDescriptor
> {

    private let fileManager: FileManager

    internal init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        try ensureStructure()
    }
}

// MARK: - Private -

private extension MutableStore {

    /// Ensures the required directories are created
    func ensureStructure() throws {
        let directory = try storeDirectory()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Returns a URL that can be used for storing localization data.
    func storeDirectory() throws -> URL {
        guard var url = fileManager.urls(for: .documentDirectory,
                                         in: .userDomainMask).first else {
            throw StoreError.inaccessible
        }

        // Append directory name
        url.appendPathComponent(Constants.Store.localizationDirectory, isDirectory: true)

        return url
    }

    /// Generates a file path for a file with a given file name for a specific locale.
    /// - Parameter fileName: The filename of the file you want the path generated for.
    /// - Parameter language: Language from which the locale identifier will be taken.
    func filePath(for fileName: String, with language: LanguageModel) throws -> URL {
        var url = try storeDirectory()

        // Append file name and extension
        url.appendPathComponent(language.locale.identifier, isDirectory: true)
        url.appendPathComponent(fileName, isDirectory: false)
        url.appendPathExtension(Constants.Store.fileExtension)

        return url
    }

    /// Excludes a file from iCloud backup to prevent unnecessary data synchronization.
    /// - Parameter url: The URL of the file to exlcude from the backup.
    func excludeFromBackup(at url: URL) throws {
        // Make sure file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw StoreError.dataNotFound
        }

        // Add resource value for excluding from backup
        var mutableUrl = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableUrl.setResourceValues(resourceValues)
    }

    /// Creates a locale specific directory in the Localization folder.
    /// - Parameter url: The location where the directory should be created.
    /// - Parameter language: Language from which the locale identifier will be taken.
    func createDirectory(at url: URL, for language: LanguageModel) throws {
        try fileManager.createDirectory(
            at: url.appendingPathComponent(language.locale.identifier, isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}

// MARK: - Helpers -

extension MutableStore {
    func data(with fileName: String, language: LanguageModel) throws -> Data {
        let url = try filePath(for: fileName, with: language)

        // Validate file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw StoreError.dataNotFound
        }

        return try Data(contentsOf: url)
    }

    func save(with fileName: String, data: Data, language: LanguageModel) throws {
        // Get the file path
        let url = try filePath(for: fileName, with: language)

        // Create directory if needed
        try createDirectory(at: url, for: language)

        // Write data to the file atomically
        try data.write(to: url, options: .atomic)

        // Exclude from backup
        try excludeFromBackup(at: url)
    }
}

// MARK: - Store -

extension MutableStore: Store {

    func descriptorData(for language: Language) throws -> Data {
        return try data(with: Constants.Store.descriptorFileName, language: language)
    }

    func localizationData(for descriptor: Descriptor) throws -> Data {
        return try data(with: Constants.Store.dataFileName, language: descriptor.language)
    }

    func save(descriptorData: Data, for language: Language) throws {
        try save(with: Constants.Store.descriptorFileName, data: descriptorData, language: language)
    }

    func save(localizationData: Data, for descriptor: Descriptor) throws {
        try save(with: Constants.Store.dataFileName,
                 data: localizationData, language: descriptor.language)
    }

    func deleteLocalizationData(for language: Language) throws {
        var url = try storeDirectory()
        url.appendPathComponent(language.locale.identifier, isDirectory: true)

        // Validate file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw StoreError.dataNotFound
        }

        // Remove the localization directory
        try fileManager.removeItem(at: url)
    }

    /// Deletes all files in the store from disk.
    ///
    /// - Throws: A `StoreError`, if accessing folders/files or removing items fails.
    func deleteAllData() throws {
        let directory = try storeDirectory()
        let contents = try fileManager.contentsOfDirectory(atPath: directory.path)
        try contents.forEach { try fileManager.removeItem(atPath: $0) }
    }
}
