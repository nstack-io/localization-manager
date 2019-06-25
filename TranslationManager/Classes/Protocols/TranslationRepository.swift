//
//  TranslationRepository.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public protocol TranslationRepository {
    typealias SwiftResult<T> = Swift.Result<T, Error>
    
    func getLocalizationConfig(acceptLanguage: String,
                               completion: @escaping (SwiftResult<[LocalizationModel]>) -> Void)
    func getTranslations(localization: LocalizationModel,
                         acceptLanguage: String,
                         completion: @escaping (SwiftResult<TranslationResponse<Language>>) -> Void)
    func getAvailableLanguages<L: LanguageModel>(completion:  @escaping (SwiftResult<[L]>) -> Void)
    func fetchPreferredLanguages() -> [String]
    func fetchBundles() -> [Bundle]
}
