//
//  LocalizationsRepositoryMock.swift
//  NStackSDK
//
//  Created by Dominik Hádl on 05/12/2016.
//  Copyright © 2016 Nodes ApS. All rights reserved.
//

import Foundation
#if IOSTESTS
@testable import LocalizationManager
#elseif TVOSTESTS
@testable import LocalizationManager_tvOS
#elseif MACOSTESTS
@testable import LocalizationManager_macOS
#endif

class LocalizationsRepositoryMock<L: LanguageModel>: LocalizationRepository {

    var localizationsResponse: LocalizationResponse<Language>?
    var availableLocalizations: [LocalizationConfig]?
    var availableLanguages: [L]?
    var currentLanguage: Language?
    var currentLocalization: LocalizationConfig?
    var preferredLanguages = ["en"]
    var customBundles: [Bundle]?

    func getLocalizationConfig<C>(acceptLanguage: String,
                                  lastUpdated: Date?,
                                  completion: @escaping (Result<[C]>) -> Void) where C: LocalizationDescriptor {
        let error = NSError(domain: "", code: 100, userInfo: nil) as Error
        let result: Result = availableLocalizations != nil ? .success(availableLocalizations!) : .failure(error)
        completion(result as! Result<[C]>)
    }

    func getLocalization<L>(localization: LocalizationDescriptor,
                            acceptLanguage: String,
                            completion: @escaping (Result<LocalizationResponse<L>>) -> Void) where L: LanguageModel {
        let error = NSError(domain: "", code: 0, userInfo: nil) as Error
        let result: Result = localizationsResponse != nil ? .success(localizationsResponse!) : .failure(error)
        completion(result as! Result<LocalizationResponse<L>>)
    }

    func getLocalizations<L>(localization: LocalizationDescriptor,
                            acceptLanguage: String,
                            completion: @escaping (Result<L>) -> Void) where L: LanguageModel {
        let error = NSError(domain: "", code: 0, userInfo: nil) as Error
        //let result: Result = localizationsResponse != nil ? .success(localizationsResponse!) : .failure(error)
        let result: Result = .success(currentLanguage!)
        completion(result as! Result<L>)
    }

    func getAvailableLanguages<L: LanguageModel>(completion:  @escaping (Result<[L]>) -> Void) {
//        let error = NSError(domain: "", code: 0, userInfo: nil)
//        let result: Result = availableLanguages != nil ? .success(availableLanguages!) : .failure(error)
//        completion(result)
    }
}

extension LocalizationsRepositoryMock: LocalizationContextRepository {

    func fetchPreferredLanguages() -> [String] {
        return preferredLanguages
    }

    func getLocalizationBundles() -> [Bundle] {
        return customBundles ?? Bundle.allBundles
    }

    func fetchCurrentPhoneLanguage() -> String? {
        return preferredLanguages.first
    }
}
