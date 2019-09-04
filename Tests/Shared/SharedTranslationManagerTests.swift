//
//  TranslationManagerTests.swift
//  TranslationManagerTests
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.

import XCTest

#if IOSTESTS
@testable import TranslationManager
#elseif TVOSTESTS
@testable import TranslationManager_tvOS
#elseif MACOSTESTS
@testable import TranslationManager_macOS
#endif

//swiftlint:disable file_length
//swiftlint:disable type_body_length
class SharedTranslationManagerTests: XCTestCase {
    typealias LanguageType = Language
    typealias LocalizationConfigType = LocalizationConfig

    var repositoryMock: TranslationsRepositoryMock<LanguageType>!
    var fileManagerMock: FileManagerMock!
    var manager: TranslatableManager<LanguageType, LocalizationConfigType>!

    let mockLanguage = Language(id: 0, name: "Danish",
                                direction: "lrm", acceptLanguage: "da-DK",
                                isDefault: false, isBestFit: false)

    var mockTranslations: TranslationResponse<Language> {
        return TranslationResponse(translations: [
            "default": ["successKey": "SuccessUpdated"],
            "otherSection": ["anotherKey": "HeresAValue"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "English",
                                                        direction: "LRM", acceptLanguage: "en-GB",
                                                        isDefault: true, isBestFit: true)))
    }

    var mockLocalizationConfigWithUpdate: LocalizationConfig {
        return LocalizationConfig(lastUpdatedAt: Date(),
                                  localeIdentifier: "da-DK",
                                  shouldUpdate: true,
                                  url: "",
                                  language: mockLanguage)
    }

    var mockLocalizationConfigWithoutUpdate: LocalizationConfig {
        return LocalizationConfig(lastUpdatedAt: Date(), localeIdentifier: "fr-FR", shouldUpdate: false, url: "", language: mockLanguage)
    }

    //    // MARK: - Test Case Lifecycle -

    override func setUp() {
        super.setUp()
        print()

        repositoryMock = TranslationsRepositoryMock()
        fileManagerMock = FileManagerMock()
        manager = TranslatableManager.init(repository: repositoryMock, contextRepository: repositoryMock, localizableModel: Translations.self)
        manager.languageOverride = nil
        manager.bestFitLanguage = nil
        manager.fallbackLocale = nil
        manager.lastUpdatedDate = nil
    }

    override func tearDown() {
        super.tearDown()

        do {
            try manager.clearTranslations(includingPersisted: true)
        } catch {
            XCTFail("Failed to clear translations")
        }

        manager = nil
        repositoryMock = nil
        fileManagerMock = nil

        // To separate test cases in output
        print("-----------")
        print()
    }

    // MARK: - Update -

    func testLoadLocalizations() {
        let localizations: [LocalizationConfig] = [mockLocalizationConfigWithUpdate,
                                                   mockLocalizationConfigWithUpdate,
                                                   mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        manager.updateTranslations()

        let fileURL = manager.localizationConfigFileURL()
        do {
            let data = try Data(contentsOf: fileURL!)
            let arrayOfConfigs = try manager.decoder.decode([LocalizationConfig].self, from: data)
            XCTAssertEqual(arrayOfConfigs.count, 3)
        } catch {
            XCTFail("Failed to decode localization configs")
        }
    }

    func testLoadLocalizationsFail() {
        //make sure the count of translations objects available (fallbacks) doesnt change when update failed
        let countBefore = manager.translatableObjectDictonary.count

        manager.updateTranslations { (error) in
            XCTAssertNotNil(error)
            XCTAssertEqual(self.manager.translatableObjectDictonary.count, countBefore)
        }
    }

    func testLastUpdatedDateIsSet() {
        let dateAtStartOfTest = Date()
        XCTAssertNil(manager.lastUpdatedDate)
        let localizations: [LocalizationConfig] = [mockLocalizationConfigWithUpdate,
                                                   mockLocalizationConfigWithUpdate,
                                                   mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        manager.updateTranslations()
        XCTAssertNotNil(manager.lastUpdatedDate)
        XCTAssertTrue(dateAtStartOfTest < manager.lastUpdatedDate ?? dateAtStartOfTest)
    }

    func testUpdateTranslations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = mockTranslations
        manager.updateTranslations()

        guard let localeId: String = mockTranslations.meta?.language?.acceptLanguage else {
            XCTFail("Failed to get locale id/accept language")
            return
        }

        let fileURL = manager.translationsFileUrl(localeId: localeId)
        do {
            let data = try Data(contentsOf: fileURL!)
            let translations = try manager.decoder.decode(TranslationResponse<Language>.self, from: data)
            XCTAssertNotNil(translations)
        } catch {
            XCTFail("Failed to decode language")
        }
    }

    func testUpdateTranslationsFail() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = nil
        manager.updateTranslations { (error) in
            XCTAssertNotNil(error)
        }
    }

    func testUpdateCurrentLanguageWithBestFit() {
        let lang = Language(id: 0, name: "Danish",
                                    direction: "lrm",
                                    acceptLanguage: "da-DK",
                                    isDefault: false,
                                    isBestFit: true)
        let config = LocalizationConfig(lastUpdatedAt: Date(),
                                        localeIdentifier: "da-DK",
                                        shouldUpdate: true,
                                        url: "",
                                        language: lang)
        let localizations: [LocalizationConfig] = [config]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "SuccessUpdated"],
            "otherSection": ["anotherKey": "HeresAValue"]
            ], meta: TranslationMeta(language: lang))

        // Create an expectation
        let expectation = self.expectation(description: "update")
        manager.updateTranslations { (error) in
            if error != nil {
                XCTFail()
            } else {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5, handler: nil)
        XCTAssertEqual(self.manager.bestFitLanguage?.acceptLanguage, "da-DK")

    }

    func testDoNotUpdateCurrentLanguageWithBestFit() {
        let lang = Language(id: 0, name: "Danish",
                            direction: "lrm",
                            acceptLanguage: "da-DK",
                            isDefault: false,
                            isBestFit: true)
        let config = LocalizationConfig(lastUpdatedAt: Date(),
                                        localeIdentifier: "da-DK",
                                        shouldUpdate: true,
                                        url: "",
                                        language: lang)
        let localizations: [LocalizationConfig] = [config]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "SuccessUpdated"],
            "otherSection": ["anotherKey": "HeresAValue"]
            ], meta: TranslationMeta(language: lang))
        // Create an expectation
        let expectation = self.expectation(description: "update")
        manager.updateTranslations { (error) in
            if error != nil {
                XCTFail()
            } else {
                //current language should be danish
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
        XCTAssertEqual(self.manager.bestFitLanguage?.acceptLanguage, "da-DK")

        repositoryMock.availableLocalizations = [LocalizationConfig(lastUpdatedAt: Date(), localeIdentifier: "en-GB", shouldUpdate: true, url: "", language: mockLanguage)]
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "SuccessUpdated"],
            "otherSection": ["anotherKey": "HeresAValue"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "English",
                                                        direction: "LRM", acceptLanguage: "en-GB",
                                                        isDefault: false, isBestFit: false)))

        let expectationTwo = self.expectation(description: "dontUpdate")
        manager.updateTranslations { (error) in
            if error != nil {
                XCTFail()
            } else {
                //current language should still be Danish as English is not 'best fit'
                expectationTwo.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
        XCTAssertEqual(self.manager.bestFitLanguage?.acceptLanguage, "da-DK")
    }

    // MARK: - Test Clear

    func testClearPersistedTranslations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = mockTranslations
        manager.updateTranslations()

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Localization/Locales")
        do {
            let filePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertFalse(filePaths.isEmpty)
            try manager.clearTranslations(includingPersisted: true)
            let newFilePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertTrue(newFilePaths.isEmpty)
        } catch {
            XCTFail("Failed to get contents of directories")
        }
    }

    func testClearTranslations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = mockTranslations
        manager.updateTranslations()

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Localization/Locales")
        do {
            let filePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertFalse(filePaths.isEmpty)
            try manager.clearTranslations()
            XCTAssertTrue(manager.translatableObjectDictonary.isEmpty)
            let newFilePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertFalse(newFilePaths.isEmpty)
        } catch {
            XCTFail("Failed to get contents of directories")
        }
    }

    // MARK: - Translation for key

    func testTranslationForKeySuccessWithCurrentLanguage() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        manager.updateTranslations()

        do {
            guard let str = try manager.translation(for: "default.successKey") else {
                XCTFail("String doesnt exist")
                return
            }
            XCTAssertEqual(str, "Success")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFullTranslationsResponse() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        manager.updateTranslations()
        do {
            if let translations = try manager.translations() as? Translations {
                XCTAssertEqual(translations.defaultSection.testURL, "www.test.com")
            } else {
                XCTFail()
            }
        } catch {
            XCTFail()
        }
    }

    func testFullTranslationsResponseFallbackJSON() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        //manager.updateTranslations()
        do {
            try manager.clearTranslations(includingPersisted: true)
            if let translations = try manager.translations() as? Translations {
                XCTAssertEqual(translations.defaultSection.testURL, "www.test.com")
            } else {
                XCTFail()
            }
        } catch {
            XCTFail()
        }
    }

    func testFullTranslationsResponseFallback() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        do {
            try manager.clearTranslations(includingPersisted: false)
            if let translations = try manager.translations() as? Translations {
                XCTAssertEqual(translations.defaultSection.successKey, "Success")
                XCTAssertEqual(translations.defaultSection.testURL, "www.test.com")
            } else {
                XCTFail()
            }
        } catch {
            XCTFail()
        }
    }

    func testTranslationForKeyFailure() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = mockTranslations
        manager.updateTranslations()

        do {
            let str = try manager.translation(for: "default.nonExistingString")
            XCTAssertNil(str)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Fallback

    func testFallbackToJsonInNonMainBundle() throws {

        try manager.clearTranslations(includingPersisted: true)
        repositoryMock.customBundles = []

        do {
            guard let str = try manager.translation(for: "other.otherKey") else {
                XCTFail("String doesnt exist")
                return
            }
            XCTAssertEqual(str, "FallbackValue")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackToDefaultLocale() {
        do {
            guard let str = try manager.translation(for: "other.otherKey") else {
                XCTFail("String doesnt exist")
                return
            }
            XCTAssertEqual(str, "FallbackValue")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackToDefaultLocaleForTranslations() {
        do {
            let tr = try manager.translations() as? Translations
            XCTAssertEqual(tr?.otherSection.otherKey, "FallbackValue")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackToSetFallbackLocale() {
        manager.bestFitLanguage = nil
        repositoryMock.preferredLanguages = ["ja-JP"]
        let locale = Locale(identifier: "da-DK")
        XCTAssertNotNil(locale)

        manager.fallbackLocale = locale
        do {
            try manager.clearTranslations(includingPersisted: true)
            let str = try manager.translation(for: "other.otherKey")
            XCTAssertEqual(str, "DenmarkFallbackValue")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackToFirstLocaleAvailableIfWeHaveNotSetFallbackLocale() {
        manager.defaultLanguage = nil
        XCTAssertNil(manager.bestFitLanguage)
        do {
            let str = try manager.translation(for: "other.otherKey")
            XCTAssertNotNil(str)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackTranslationsInvalidLocale() {
        let locale = Locale(identifier: "ja-JP")
        XCTAssertNotNil(locale)
        manager.fallbackLocale = locale
        XCTAssertNil(manager.bestFitLanguage)

        do {
            guard let str = try manager.translation(for: "other.otherKey") else {
                XCTFail("String doesnt exist")
                return
            }
            XCTAssertEqual(str, "FallbackValue") //sets to default language as fallback is not found
        } catch {
            XCTFail("Failed to get translation for key")
        }
    }

    func testFallbackToPreferredLanguages() {
        manager.defaultLanguage = nil
        XCTAssertNil(manager.bestFitLanguage)
        repositoryMock.preferredLanguages = ["en", "da-DK"]
        do {
            let str = try manager.translation(for: "other.otherKey")
            XCTAssertEqual(str, "DenmarkFallbackValue") //sets to denmark as we dont have a best fit language or an override
        } catch {
            XCTFail("Failed to get translation for key")
        }
    }

    func testFallbackTranslationsInvalidJSON() {
        let locale = Locale(identifier: "fr-FR")
        XCTAssertNotNil(locale)

        manager.bestFitLanguage = nil
        manager.fallbackLocale = locale
        XCTAssertNil(manager.bestFitLanguage)
        do {
            let str = try manager.translation(for: "other.otherKey")
            XCTAssertEqual(str, "FallbackValue") //sets to default language as fallback is not found
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Accept -

    func testAcceptLanguage() {
        // Test simple language
        repositoryMock.preferredLanguages = ["en"]
        XCTAssertEqual(manager.acceptLanguageProvider.createHeaderString(languageOverride: nil), "en;q=1.0")

        // Test two languages with locale
        repositoryMock.preferredLanguages = ["da-DK", "en-GB"]
        XCTAssertEqual(manager.acceptLanguageProvider.createHeaderString(languageOverride: nil), "da-DK;q=1.0,en-GB;q=0.9")

        // Test max lang limit
        repositoryMock.preferredLanguages = ["da-DK", "en-GB", "en", "cs-CZ", "sk-SK", "no-NO"]
        XCTAssertEqual(manager.acceptLanguageProvider.createHeaderString(languageOverride: nil),
                       "da-DK;q=1.0,en-GB;q=0.9,en;q=0.8,cs-CZ;q=0.7,sk-SK;q=0.6",
                       "There should be maximum 5 accept languages.")

        // Test fallback
        repositoryMock.preferredLanguages = []
        XCTAssertEqual(manager.acceptLanguageProvider.createHeaderString(languageOverride: nil), "en;q=1.0",
                       "If no accept language there should be fallback to english.")
    }

    func testLastAcceptHeader() {
        manager.lastAcceptHeader = nil
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")
        manager.lastAcceptHeader = "da-DK;q=1.0,en;q=1.0"
        XCTAssertEqual(manager.lastAcceptHeader, "da-DK;q=1.0,en;q=1.0")
        manager.lastAcceptHeader = nil
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil.")
    }

    // MARK: - Language Override -

    func testLanguageOverride() {
        repositoryMock.availableLocalizations = [mockLocalizationConfigWithUpdate]
        manager.lastAcceptHeader = nil
        XCTAssertEqual(manager.updateMode, UpdateMode.automatic)
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")

        manager.languageOverride = Language(id: 1, name: "Japanese",
                                            direction: "LRM", acceptLanguage: "ja-JP",
                                            isDefault: true, isBestFit: true)

        guard let acceptHeader = manager.lastAcceptHeader else {
            XCTFail("accept header should be present at this point")
            return
        }
        XCTAssertTrue(acceptHeader.hasPrefix("ja-JP"))
    }

    func testRemovingLanguageOverride() {
        repositoryMock.availableLocalizations = [mockLocalizationConfigWithUpdate]
        manager.lastAcceptHeader = nil
        XCTAssertEqual(manager.updateMode, UpdateMode.automatic)
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")

        manager.languageOverride = Language(id: 1, name: "Japanese",
                                            direction: "LRM", acceptLanguage: "ja-JP",
                                            isDefault: true, isBestFit: true)
        guard let acceptHeader = manager.lastAcceptHeader else {
            XCTFail("accept header should be present at this point")
            return
        }
        XCTAssertTrue(acceptHeader.hasPrefix("ja-JP"))

        manager.lastAcceptHeader = nil
        XCTAssertEqual(manager.updateMode, UpdateMode.automatic)
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")
    }

    func testEncodingAndDecodingPersisted() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        do {
            try manager.deletePersistedTranslations()
        } catch {
            XCTFail()
        }
        let expectation = self.expectation(description: "update")
        manager.updateTranslations { (error) in
            if error != nil {
                XCTFail()
            } else {
                //current language should be danish
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
        do {
            guard let persisted = try self.manager.persistedTranslations(localeId: "en-GB") else {
                XCTFail()
                return
            }
            XCTAssertFalse(persisted.translations.isEmpty)
        } catch {
            XCTFail()
        }
    }

    func testDecodingFallbackJSON() {
        do {
            let fallback = try self.manager.fallbackTranslations(localeId: "en-GB")
            XCTAssertFalse(fallback.translations.isEmpty)
        } catch {
            XCTFail()
        }
    }
}
