//
//  AnyStore.swift
//  TranslationManager
//
//  Created by Dominik Hádl on 27/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

/// Type erased variant of the `Store` protocol.
internal class AnyStore<
    LanguageType: LanguageModel,
    ConfigurationType: LocalizationConfigurationModel
>: Store {

    private let _data: (_ langugage: LanguageType) throws -> Data
    private let _dataConfig: (_ configuration: ConfigurationType) throws -> Data
    private let _save: (_ data: Data, _ langugage: LanguageType) throws -> Void
    private let _saveConfig: (_ data: Data, _ configuration: ConfigurationType) throws -> Void
    private let _delete: (_ language: LanguageType) throws -> Void
    private let _deleteAll: () throws -> Void

    init<S: Store>(_ store: S) where S.LanguageType == LanguageType,
        S.ConfigurationType == ConfigurationType {
        _data = { try store.data(for: $0) }
        _dataConfig = { try store.data(for: $0) }
        _save = { try store.save($0, for: $1) }
        _saveConfig = { try store.save($0, for: $1) }
        _delete = { try store.delete(for: $0) }
        _deleteAll = { try store.deleteAll() }
    }

    func data(for language: LanguageType) throws -> Data {
        return try _data(language)
    }

    func data(for configuration: ConfigurationType) throws -> Data {
        return try _dataConfig(configuration)
    }

    func save(_ data: Data, for language: LanguageType) throws {
        try _save(data, language)
    }

    func save(_ data: Data, for configuration: ConfigurationType) throws {
        try _saveConfig(data, configuration)
    }

    func delete(for language: LanguageType) throws {
        try _delete(language)
    }

    func deleteAll() throws {
        try _deleteAll()
    }
}
