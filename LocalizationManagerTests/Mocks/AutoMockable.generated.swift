// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
@testable import LocalizationManager
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

// swiftlint:disable all














class LocalizationContextRepositoryMock: LocalizationContextRepository {


    var localizationBundle: Bundle {
        get { return underlyingLocalizationBundle }
        set(value) { underlyingLocalizationBundle = value }
    }
    var underlyingLocalizationBundle: Bundle!

    //MARK: - fetchPreferredLanguages

    var fetchPreferredLanguagesCallsCount = 0
    var fetchPreferredLanguagesCalled: Bool {
        return fetchPreferredLanguagesCallsCount > 0
    }
    var fetchPreferredLanguagesReturnValue: [String]!
    var fetchPreferredLanguagesClosure: (() -> [String])?

    func fetchPreferredLanguages() -> [String] {
        fetchPreferredLanguagesCallsCount += 1
        return fetchPreferredLanguagesClosure.map({ $0() }) ?? fetchPreferredLanguagesReturnValue
    }

    //MARK: - fetchCurrentPhoneLanguage

    var fetchCurrentPhoneLanguageCallsCount = 0
    var fetchCurrentPhoneLanguageCalled: Bool {
        return fetchCurrentPhoneLanguageCallsCount > 0
    }
    var fetchCurrentPhoneLanguageReturnValue: String?
    var fetchCurrentPhoneLanguageClosure: (() -> String?)?

    func fetchCurrentPhoneLanguage() -> String? {
        fetchCurrentPhoneLanguageCallsCount += 1
        return fetchCurrentPhoneLanguageClosure.map({ $0() }) ?? fetchCurrentPhoneLanguageReturnValue
    }

}
