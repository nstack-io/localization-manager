//
//  TranslatableManagerType.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public protocol TranslatableManagerType: class {
    associatedtype L: LanguageModel
    
    var updateMode: UpdateMode { get }
    
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
    
    var currentLanguage: L? { get }
    var acceptLanguage: String { get }
    
    func translation(for keyPath: String) throws -> String?
    func translations<T: Translatable>() throws -> T
    
    func updateTranslations(_ completion: ((_ error: Error?) -> Void)?)
    func fetchAvailableLanguages(_ completion: @escaping (Result<[L]>) -> Void)
    
    func set(languageOverride language: L?) throws
    func clearTranslations(includingPersisted: Bool) throws
}
