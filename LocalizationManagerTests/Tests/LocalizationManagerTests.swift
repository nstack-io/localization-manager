//
//  LocalizationManagerTests.swift
//  LocalizationManagerTests
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.

import XCTest

#if os(iOS)
@testable import LocalizationManager
#elseif os(tvOS)
@testable import LocalizationManager_tvOS
#elseif os(macOS)
@testable import LocalizationManager_macOS
#endif

//swiftlint:disable file_length
class LocalizationManagerTests: XCTestCase {
    typealias LanguageType = DefaultLanguage
    typealias LocalizationConfigType = LocalizationConfig

    var repositoryMock: LocalizationsRepositoryMock<LanguageType>!
    var fileManagerMock: FileManagerMock!
    var manager: LocalizationManager<LanguageType, LocalizationConfigType>!

    let mockDanishLanguage = DefaultLanguage(
        id: 0, name: "Danish",
        direction: "lrm", locale: Locale(identifier: "da-DK"),
        isDefault: false, isBestFit: false
    )

    let mockEnglishLanguage = DefaultLanguage(
        id: 1, name: "English",
        direction: "LRM", locale: Locale(identifier: "en-GB"),
        isDefault: true, isBestFit: true
    )

    let mockJapaneseLanguage = DefaultLanguage(
        id: 1, name: "Japanese",
        direction: "LRM", locale: Locale(identifier: "ja-JP"),
        isDefault: true, isBestFit: true
    )

    var mockLocalizations: LocalizationResponse<DefaultLanguage> {
        return LocalizationResponse(localizations: [
            "default": ["successKey": "SuccessUpdated"],
            "otherSection": ["anotherKey": "HeresAValue"]
            ], meta: LocalizationMeta(language: mockEnglishLanguage))
    }

    var mockLocalizationConfigWithUpdate: LocalizationConfig {
        return LocalizationConfig(lastUpdatedAt: Date(),
                                  localeIdentifier: "da-DK",
                                  shouldUpdate: true,
                                  url: "",
                                  language: mockDanishLanguage)
    }

    var mockLocalizationConfigWithoutUpdate: LocalizationConfig {
        return LocalizationConfig(lastUpdatedAt: Date(), localeIdentifier: "fr-FR",
                                  shouldUpdate: false, url: "", language: mockDanishLanguage)
    }

    // MARK: - Test Case Lifecycle -

    override func setUp() {
        super.setUp()
        print()

        repositoryMock = LocalizationsRepositoryMock()
        fileManagerMock = FileManagerMock()
        manager = LocalizationManager(repository: repositoryMock,
                                      contextRepository: repositoryMock,
                                      localizableModel: Localization.self,
                                      updateMode: .manual)
        manager.languageOverride = nil
        manager.bestFitLanguage = nil
        manager.fallbackLocale = nil
        manager.lastUpdatedDate = nil
    }

    override func tearDown() {
        super.tearDown()

        do {
            try manager.clearLocalizations(includingPersisted: true)
        } catch {
            XCTFail("Failed to clear localizations")
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
        manager.updateLocalizations()

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
        //make sure the count of localizations objects available (fallbacks) doesnt change when update failed
        let countBefore = manager.localizationObjectDictonary.count

        manager.updateLocalizations { (error) in
            XCTAssertNotNil(error)
            XCTAssertEqual(self.manager.localizationObjectDictonary.count, countBefore)
        }
    }

    func testLastUpdatedDateIsSet() {
        let dateAtStartOfTest = Date()
        XCTAssertNil(manager.lastUpdatedDate)
        let localizations: [LocalizationConfig] = [mockLocalizationConfigWithUpdate,
                                                   mockLocalizationConfigWithUpdate,
                                                   mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        manager.updateLocalizations()
        XCTAssertNotNil(manager.lastUpdatedDate)
        XCTAssertTrue(dateAtStartOfTest < manager.lastUpdatedDate ?? dateAtStartOfTest)
    }

    func testUpdateLocalizations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = mockLocalizations
        manager.updateLocalizations()

        guard let localeId: String = mockLocalizations.meta?.language?.locale.identifier else {
            XCTFail("Failed to get locale id/accept language")
            return
        }

        let fileURL = manager.localizationFileUrl(localeId: localeId)
        do {
            let data = try Data(contentsOf: fileURL!)
            let localizations = try manager.decoder.decode(LocalizationResponse<DefaultLanguage>.self, from: data)
            XCTAssertNotNil(localizations)
        } catch {
            XCTFail("Failed to decode language")
        }
    }

    func testUpdateLocalizationsFail() {
        let expect = expectation(description: "")
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = nil
        manager.updateLocalizations { (error) in
            XCTAssertNotNil(error)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1.0) { (_) in
            XCTFail()
        }
    }

    func testUpdateCurrentLanguageWithBestFit() {
        let config = mockLocalizationConfigWithUpdate //mock Danish config
        let localizations: [LocalizationConfig] = [config]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = LocalizationResponse(localizations: [
            "default": ["successKey": "SuccessUpdated"],
            "otherSection": ["anotherKey": "HeresAValue"]
            ], meta: LocalizationMeta(language: mockDanishLanguage))
        manager.updateLocalizations()
       // XCTAssertEqual(manager.bestFitLanguage?.acceptLanguage, "da-DK")
    }

    // MARK: - Test Clear

    func testClearPersistedLocalizations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = mockLocalizations
        manager.updateLocalizations()

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Localization/Locales")
        do {
            let filePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertFalse(filePaths.isEmpty)
            try manager.clearLocalizations(includingPersisted: true)
            let newFilePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertTrue(newFilePaths.isEmpty)
        } catch {
            XCTFail("Failed to get contents of directories")
        }
    }

    func testClearLocalizations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = mockLocalizations
        manager.updateLocalizations()

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Localization/Locales")
        do {
            let filePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertFalse(filePaths.isEmpty)
            try manager.clearLocalizations()
            XCTAssertTrue(manager.localizationObjectDictonary.isEmpty)
            let newFilePaths = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            XCTAssertFalse(newFilePaths.isEmpty)
        } catch {
            XCTFail("Failed to get contents of directories")
        }
    }

    // MARK: - Localization for key

    func testLocalizationForKeySuccessWithCurrentDefaultLanguage() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = LocalizationResponse(localizations: [
            "default": ["successKey": "Success", "successKey2": "SuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: LocalizationMeta(language: mockEnglishLanguage))
        manager.updateLocalizations()

        do {
            guard let str = try manager.localization(for: "default.successKey") else {
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
        repositoryMock.localizationsResponse = LocalizationResponse(localizations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: LocalizationMeta(language: mockDanishLanguage))
        manager.updateLocalizations()
        do {
            if let translations = try manager.localization() as? Localization {
                XCTAssertEqual(translations.defaultSection.testURL, "www.test.com")
            } else {
                XCTFail("fail")
            }
        } catch {
            XCTFail("fail")
        }
    }

    func testFullTranslationsResponseFallbackJSON() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = LocalizationResponse(localizations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: LocalizationMeta(language: mockDanishLanguage))
        //manager.updateTranslations()
        do {
            try manager.clearLocalizations(includingPersisted: true)
            if let translations = try manager.localization() as? Localization {
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
        repositoryMock.localizationsResponse = LocalizationResponse(localizations: [
            "default": ["successKey": "DanishSuccessUpdated", "successKey2": "DanishSuccessUpdated2"],
            "otherSection": ["anotherKey": "HeresAValue", "anotherKey2": "HeresAValue2"]
            ], meta: LocalizationMeta(language: mockDanishLanguage))
        do {
            try manager.clearLocalizations(includingPersisted: false)
            if let translations = try manager.localization() as? Localization {
                XCTAssertEqual(translations.defaultSection.successKey, "Success")
                XCTAssertEqual(translations.defaultSection.testURL, "www.test.com")
            } else {
                XCTFail()
            }
        } catch {
            XCTFail()
        }
    }

    func testLocalizationForKeyFailure() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.localizationsResponse = mockLocalizations
        manager.updateLocalizations()

        do {
            let str = try manager.localization(for: "default.nonExistingString")
            XCTAssertNil(str)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Fallback

    func testFallbackToJsonInNonMainBundle() throws {

        try manager.clearLocalizations(includingPersisted: true)
        repositoryMock.customBundles = []

        do {
            guard let str = try manager.localization(for: "other.otherKey") else {
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
            guard let str = try manager.localization(for: "other.otherKey") else {
                XCTFail("String doesnt exist")
                return
            }
            XCTAssertEqual(str, "FallbackValue")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackToDefaultLocaleForLocalizations() {
        do {
            let tr = try manager.localization() as? Localization
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
            try manager.clearLocalizations(includingPersisted: true)
            let str = try manager.localization(for: "other.otherKey")
            XCTAssertEqual(str, "DenmarkFallbackValue")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackToFirstLocaleAvailableIfWeHaveNotSetFallbackLocale() {
        manager.defaultLanguage = nil
        XCTAssertNil(manager.bestFitLanguage)
        do {
            let str = try manager.localization(for: "other.otherKey")
            XCTAssertNotNil(str)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackLocalizationsInvalidLocale() {
        let locale = Locale(identifier: "ja-JP")
        XCTAssertNotNil(locale)
        manager.fallbackLocale = locale
        XCTAssertNil(manager.bestFitLanguage)

        do {
            guard let str = try manager.localization(for: "other.otherKey") else {
                XCTFail("String doesnt exist")
                return
            }
            XCTAssertEqual(str, "FallbackValue") //sets to default language as fallback is not found
        } catch {
            XCTFail("Failed to get localization for key")
        }
    }

    func testFallbackToPreferredLanguages() {
        manager.defaultLanguage = nil
        XCTAssertNil(manager.bestFitLanguage)
        repositoryMock.preferredLanguages = ["en", "da-DK"]
        do {
            let str = try manager.localization(for: "other.otherKey")
            XCTAssertEqual(str, "DenmarkFallbackValue") //sets to denmark as we dont have a best fit language or an override
        } catch {
            XCTFail("Failed to get localization for key")
        }
    }

    func testFallbackLocalizationsInvalidJSON() {
        let locale = Locale(identifier: "fr-FR")
        XCTAssertNotNil(locale)

        manager.bestFitLanguage = nil
        manager.fallbackLocale = locale
        XCTAssertNil(manager.bestFitLanguage)
        do {
            let str = try manager.localization(for: "other.otherKey")
            XCTAssertEqual(str, "FallbackValue") //sets to default language as fallback is not found
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Accept -

    func testAcceptDefaultLanguage() {
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
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")

        manager.languageOverride = mockJapaneseLanguage

        guard let acceptHeader = manager.lastAcceptHeader else {
            XCTFail("accept header should be present at this point")
            return
        }
        XCTAssertTrue(acceptHeader.hasPrefix("ja-JP"))
    }

    func testRemovingLanguageOverride() {
        repositoryMock.availableLocalizations = [mockLocalizationConfigWithUpdate]
        manager.lastAcceptHeader = nil
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")

        manager.languageOverride = mockJapaneseLanguage
        guard let acceptHeader = manager.lastAcceptHeader else {
            XCTFail("accept header should be present at this point")
            return
        }
        XCTAssertTrue(acceptHeader.hasPrefix("ja-JP"))

        manager.lastAcceptHeader = nil
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")
    }
}
