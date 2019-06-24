//
//  TranslationManagerTests.swift
//  TranslationManagerTests
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.


import XCTest
@testable import TranslationManager

class TranslationManagerTests: XCTestCase {

    typealias L = Language
    typealias T = Localization
    typealias C = LocalizationConfig
    

    var repositoryMock: TranslationsRepositoryMock<L>!
    var fileManagerMock: FileManagerMock!
    var manager: TranslatableManager<T, L, C>!

    let mockLanguage = Language(id: 0, name: "Danish",
                                direction: "lrm", acceptLanguage: "da-DK",
                                isDefault: false, isBestFit: false)

    var mockTranslations: TranslationResponse<Language> {
        return TranslationResponse(translations: [
            "default" : ["successKey" : "SuccessUpdated"],
            "otherSection" : ["anotherKey" : "HeresAValue"],
            ], meta: TranslationMeta(language: Language(id: 1, name: "English",
                                                        direction: "LRM", acceptLanguage: "en-GB",
                                                        isDefault: true, isBestFit: true)))
    }
    
    var mockLocalizationConfigWithUpdate: LocalizationConfig {
        return LocalizationConfig(lastUpdatedAt: Date(), localeIdentifier: "da-DK", shouldUpdate: true)
    }
    
    var mockLocalizationConfigWithoutUpdate: LocalizationConfig {
        return LocalizationConfig(lastUpdatedAt: Date(), localeIdentifier: "fr-FR", shouldUpdate: false)
    }

//    // MARK: - Test Case Lifecycle -

    override func setUp() {
        super.setUp()
        print()

        repositoryMock = TranslationsRepositoryMock()
        fileManagerMock = FileManagerMock()
        manager = TranslatableManager.init(repository: repositoryMock, fallbackLocale: Locale.current)
        manager.languageOverride = nil
    }

    override func tearDown() {
        super.tearDown()

        do {
            try manager.clearTranslations(includingPersisted: true)
        }
        catch {
            XCTFail()
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
        let localizations: [LocalizationConfig] = [mockLocalizationConfigWithUpdate, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        manager.updateTranslations()

        let fileURL = manager.localizationConfigFileURL()
        do {
            let data = try Data(contentsOf: fileURL!)
            let wrapper = try manager.decoder.decode(ConfigWrapper.self, from: data)
            XCTAssertEqual(wrapper.data.count, 3)
        }
        catch {
            XCTFail()
        }
    }
    
    func testLoadLocalizationsFail() {
        XCTAssertTrue(manager.translatableObjectDictonary.isEmpty)

        manager.updateTranslations { (error) in
            XCTAssertNotNil(error)
        }
    }
    
    func testUpdateTranslations() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = mockTranslations
        manager.updateTranslations()
        
        
        guard let localeId: String = mockTranslations.meta?.language?.acceptLanguage else {
            XCTFail()
            return
        }
        
        let fileURL = manager.translationsFileUrl(localeId: localeId)
        do {
            let data = try Data(contentsOf: fileURL!)
            let translations = try manager.decoder.decode(TranslationResponse<Language>.self, from: data)
            XCTAssertNotNil(translations)
        }
        catch {
            XCTFail()
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
        let config = mockLocalizationConfigWithUpdate //mock Danish config
        let localizations: [LocalizationConfig] = [config]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default" : ["successKey" : "SuccessUpdated"],
            "otherSection" : ["anotherKey" : "HeresAValue"],
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        manager.updateTranslations()
        XCTAssertEqual(manager.currentLanguage?.acceptLanguage, "da-DK")
    }
    
    func testDoNotUpdateCurrentLanguageWithBestFit() {
        let config = mockLocalizationConfigWithUpdate //mock Danish config
        let localizations: [LocalizationConfig] = [config]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default" : ["successKey" : "SuccessUpdated"],
            "otherSection" : ["anotherKey" : "HeresAValue"],
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        manager.updateTranslations()
        
        //current language should be Danish
        XCTAssertEqual(manager.currentLanguage?.acceptLanguage, "da-DK")
        
        repositoryMock.availableLocalizations = [LocalizationConfig(lastUpdatedAt: Date(), localeIdentifier: "en-GB", shouldUpdate: true)]
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default" : ["successKey" : "SuccessUpdated"],
            "otherSection" : ["anotherKey" : "HeresAValue"],
            ], meta: TranslationMeta(language: Language(id: 1, name: "English",
                                                        direction: "LRM", acceptLanguage: "en-GB",
                                                        isDefault: false, isBestFit: false)))
        
        manager.updateTranslations()
        
        //current language should still be Danish as English is not 'best fit'
        XCTAssertEqual(manager.currentLanguage?.acceptLanguage, "da-DK")
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
        }
        catch {
            XCTFail()
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
            XCTAssertFalse(filePaths.isEmpty)
        }
        catch {
            XCTFail()
        }
    }

    // MARK: - Translation for key
    
    func testTranslationForKeySuccess() {
        let config = mockLocalizationConfigWithUpdate
        let localizations: [LocalizationConfig] = [config, mockLocalizationConfigWithoutUpdate, mockLocalizationConfigWithoutUpdate]
        repositoryMock.availableLocalizations = localizations
        repositoryMock.translationsResponse = TranslationResponse(translations: [
            "default" : ["successKey" : "DanishSuccessUpdated", "successKey2" : "DanishSuccessUpdated2"],
            "otherSection" : ["anotherKey" : "HeresAValue", "anotherKey2" : "HeresAValue2"]
            ], meta: TranslationMeta(language: Language(id: 1, name: "Danish",
                                                        direction: "LRM", acceptLanguage: "da-DK",
                                                        isDefault: true, isBestFit: true)))
        manager.updateTranslations()
        
        do {
            let str = try manager.translation(for: "default.successKey")
            XCTAssertEqual(str, "DanishSuccessUpdated")
        }
        catch {
            XCTFail(error.localizedDescription)
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
        }
        catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    //MARK: - Fallback
    
    func testFallbackToJSONLocale() {        
        let locale = Locale(identifier: "en-GB")
        XCTAssertNotNil(locale)
        
        manager.currentLanguage = nil
        manager.fallbackLocale = locale
        XCTAssertNil(manager.currentLanguage)
        do {
            try manager.clearTranslations(includingPersisted: true)
            let str = try manager.translation(for: "other.otherKey")
            XCTAssertEqual(str, "FallbackValue")
        }
        catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFallbackTranslationsInvalidLocale() {
        let locale = Locale(identifier: "da-DK")
        XCTAssertNotNil(locale)
        
        manager.currentLanguage = nil
        manager.fallbackLocale = locale
        XCTAssertNil(manager.currentLanguage)
        
        do {
            try manager.clearTranslations(includingPersisted: true)
            XCTAssertThrowsError(try manager.translation(for: "other.otherKey"))
        }
        catch {
            XCTFail()
        }
    }
    
    
    func testFallbackTranslationsInvalidJSON() {
        let locale = Locale(identifier: "fr-FR")
        XCTAssertNotNil(locale)
        
        manager.currentLanguage = nil
        manager.fallbackLocale = locale
        XCTAssertNil(manager.currentLanguage)
        do {
            try manager.clearTranslations(includingPersisted: true)
            XCTAssertThrowsError(try manager.translation(for: "other.otherKey"))
        }
        catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    // MARK: - Accept -

    func testAcceptLanguage() {
        // Test simple language
        repositoryMock.preferredLanguages = ["en"]
        XCTAssertEqual(manager.acceptLanguage, "en;q=1.0")

        // Test two languages with locale
        repositoryMock.preferredLanguages = ["da-DK", "en-GB"]
        XCTAssertEqual(manager.acceptLanguage, "da-DK;q=1.0,en-GB;q=0.9")

        // Test max lang limit
        repositoryMock.preferredLanguages = ["da-DK", "en-GB", "en", "cs-CZ", "sk-SK", "no-NO"]
        XCTAssertEqual(manager.acceptLanguage,
                       "da-DK;q=1.0,en-GB;q=0.9,en;q=0.8,cs-CZ;q=0.7,sk-SK;q=0.6",
                       "There should be maximum 5 accept languages.")

        // Test fallback
        repositoryMock.preferredLanguages = []
        XCTAssertEqual(manager.acceptLanguage, "en;q=1.0",
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
        
        manager.languageOverride = Locale(identifier: "ja-JP")
        XCTAssertEqual(manager.lastAcceptHeader, "ja-JP")
    }

    func testRemovingLanguageOverride() {
        repositoryMock.availableLocalizations = [mockLocalizationConfigWithUpdate]
        manager.lastAcceptHeader = nil
        XCTAssertEqual(manager.updateMode, UpdateMode.automatic)
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")
        
        manager.languageOverride = Locale(identifier: "ja-JP")
        XCTAssertEqual(manager.lastAcceptHeader, "ja-JP")
        
        manager.lastAcceptHeader = nil
        XCTAssertEqual(manager.updateMode, UpdateMode.automatic)
        XCTAssertNil(manager.lastAcceptHeader, "Last accept header should be nil at start.")
    }
}
