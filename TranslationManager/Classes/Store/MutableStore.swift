//
//  MutableStore.swift
//  TranslationManager
//
//  Created by Dominik Hádl on 28/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

internal final class MutableStore<
    Language: LanguageModel,
    Configuration: LocalizationConfigurationModel
> {

    private let fileManager: FileManager

    internal init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        try ensureStructure()
    }
}

// MARK: - Private -

// FIXME: Unhardcode directory names and folders

private extension MutableStore {
    func ensureStructure() throws {
        // Ensures the required directories are created
        let directory = try storeDirectory()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// The URL used to persist downloaded translations.
    func storeDirectory() throws -> URL {
        guard var url = fileManager.urls(for: .documentDirectory,
                                         in: .userDomainMask).first else {
            throw StoreError.inaccessible
        }

        // Append directory name
        url.appendPathComponent("Localization", isDirectory: true)

        return url
    }

    func filePath(for language: Language) throws -> URL {
        var url = try storeDirectory()

        // Append file name and extension
        url.appendPathComponent(language.locale.identifier, isDirectory: false)
        url.appendPathExtension("tmfile")

        return url
    }

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

    func createDirectory(at url: URL, for language: Language) throws {
        // Create language specific directory
        try fileManager.createDirectory(
            at: url.appendingPathComponent(language.locale.identifier, isDirectory: true),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}

// MARK: - Store -

extension MutableStore: Store {
    func data(for language: Language) throws -> Data {
        let url = try filePath(for: language)

        // Validate file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw StoreError.dataNotFound
        }

        return try Data(contentsOf: url)
    }

    func data(for configuration: Configuration) throws -> Data {
        // FIXME: Implement
        throw StoreError.notSupported
    }

    func save(_ data: Data, for language: Language) throws {
        // Get the file path
        let url = try filePath(for: language)

        // Create directory if needed
        try createDirectory(at: url, for: language)

        // Write data to the file atomically
        try data.write(to: url, options: .atomic)

        // Exclude from backup
        try excludeFromBackup(at: url)
    }

    func save(_ data: Data, for configuration: Configuration) throws {
        // FIXME: Implement
    }

    func delete(for language: Language) throws {
        let url = try storeDirectory()

        // Validate file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw StoreError.dataNotFound
        }

        // Remove all files in this directory
        let paths = try fileManager.contentsOfDirectory(atPath: url.path)
        try paths.forEach({ try fileManager.removeItem(atPath: $0) })
    }

    /// Deletes all files in the store.
    ///
    /// - Throws: A `StoreError`, if accessing folders/files or removing items fails.
    func deleteAll() throws {
        let directory = try storeDirectory()
        let contents = try fileManager.contentsOfDirectory(atPath: directory.path)
        try contents.forEach { try fileManager.removeItem(atPath: $0) }
    }
}

