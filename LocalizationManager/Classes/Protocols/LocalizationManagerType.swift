//
//  TranslatableManagerType.swift
//  LocalizationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

/*
public protocol TranslatableManagerType: class {
    var updateMode: UpdateMode { get }

    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
    var bestFitLanguage: LanguageModel? { get }
    var acceptLanguage: String { get }
    var languageOverride: Locale? { get set }

    func localization(for keyPath: String) throws -> String?
    func localizations<T: LocalizableModel>(localeId: String) throws -> T?
    func updateLocalizations(_ completion: ((_ error: Error?) -> Void)?)
    func fetchAvailableLanguages<L>(_ completion: @escaping (Result<[L]>) -> Void) where L: LanguageModel

    func set<L>(response: LocalizationResponse<L>, type: PersistedLocalizationType) throws where L: LanguageModel
    func set<L>(languageOverride language: L?) throws where L: LanguageModel
    func clearLocalizations(includingPersisted: Bool) throws
}
*/
