//
//  TranslationRepository.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public protocol TranslationsRepository {
    func getTranslations<L: LanguageModel>(acceptLanguage: String,
                                           completion: @escaping (Result<TranslationResponse<L>>) throws -> Void) rethrows
    func getAvailableLanguages<L: LanguageModel>(completion:  @escaping (Result<[L]>) throws -> Void) rethrows
    func fetchPreferredLanguages() -> [String]
    func fetchBundles() -> [Bundle]
}
