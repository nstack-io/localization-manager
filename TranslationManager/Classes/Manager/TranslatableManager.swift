//
//  TranslatableManager.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

/// The TranslatableManager handles everything related to translations.
public class TranslatableManager<T: Translatable, L: LanguageModel>: TranslationManagerType {
    
    /// Repository that provides translations.
    let repository: TranslationRepository
    
    /// File manager handling persisting new translation data.
    let fileManager: FileManager
    
    /// User defaults used to store basic information and settings.
    let userDefaults: UserDefaults
    
    /// An observer used to observe application state.
    internal lazy var stateObserver: ApplicationStateObserverType = {
        return ApplicationStateObserver(delegate: self)
    }()
    
    /// The decoder used to decode on-the-fly downloaded translations into models.
    /// By default uses a `.convertFromSnakeCase` for the `keyDecodingStrategy` property,
    /// which you can change if your API works differently.
    public let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    /// The encoder used to encode on-the-fly downloaded translations into a file that can be loaded
    /// on future starts. By default uses a `.convertToSnakeCase` for the `keyEncodingStrategy` property,
    /// which you can change if your API works differently.
    public let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    /// In memory cache of the translations object.
    internal var translatableObject: Translatable?
    
    /// In memory cache of the last language object.
    public internal(set) var currentLanguage: L?
    
    /// Internal handler closure for language change.
    public weak var delegate: TranslationManagerDelegate?
    
    /// The previous accept header string that was used.
    internal var lastAcceptHeader: String? {
        get {
            return userDefaults.string(forKey: Constants.Keys.previousAcceptLanguage)
        }
        set {
            guard let newValue = newValue else {
                // Last accept header deleted
                userDefaults.removeObject(forKey: Constants.Keys.previousAcceptLanguage)
                return
            }
            // Last accept header set to: \(newValue).
            userDefaults.set(newValue, forKey: Constants.Keys.previousAcceptLanguage)
        }
    }
    
    /// This language will be used instead of the phones' language when it is not `nil`. Remember
    /// to call `updateTranslations()` after changing the value.
    /// Otherwise, the effect will not be seen.
    internal var languageOverride: L? {
        return userDefaults.model(forKey: Constants.Keys.languageOverride)
    }
    
    /// Returns a string containing the current locale's preferred languages in a prioritized
    /// manner to be used in a accept-language header. If no preferred language available,
    /// fallback language is returned (English). Format example:
    ///
    /// "da;q=1.0,en-gb;q=0.8,en;q=0.7"
    ///
    /// - Returns: An accept language header string.
    public var acceptLanguage: String {
        var components: [String] = []
        
        // If we should have language override, then append custom language code
        if let languageOverride = languageOverride {
            components.append(languageOverride.locale.identifier + ";q=1.0")
        }
        
        // Get all languages and calculate lowest quality
        var languages = repository.fetchPreferredLanguages()
        
        // Append fallback language if we don't have any provided
        if components.count == 0 && languages.count == 0 {
            languages.append("en")
        }
        
        let startValue = 1.0 - (0.1 * Double(components.count))
        let endValue = startValue - (0.1 * Double(languages.count))
        
        // Goes through max quality to the lowest (or 0.5, whichever is higher) by 0.1 decrease
        // and appends a component with the language code and quality, like this:
        // en-gb;q=1.0
        for quality in stride(from: startValue, to: max(endValue, 0.5), by: -0.1) {
            components.append("\(languages.removeFirst());q=\(quality)")
        }
        
        // Joins all components together to get "da;q=1.0,en-gb;q=0.8" string
        return components.joined(separator: ",")
    }
    
    // MARK: - Lifecycle -
    
    /// Instantiates and sets the type of the translations object and the repository from which
    /// translations are fetched.
    ///
    /// - Parameters:
    ///   - repository: Repository that can provide translations.
    required public init(repository: TranslationRepository,
                         fileManager: FileManager = .default,
                         userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        
        // Start observing state changes
        stateObserver.startObserving()
        // Try updating the translations
        updateTranslations()
    }
    
    deinit {
        // Stop observing on deinit
        stateObserver.stopObserving()
    }
    
    // MARK: - Public -
    
    /// Find a translation for a key.
    ///
    /// - Parameters:
    ///   - keyPath: The key that string should be found on.
    public func translationString(keyPath: String) throws -> String? {
        guard !keyPath.isEmpty else {
            return nil
        }
        
        // Split the key path
        let keys = keyPath.components(separatedBy: ".")
        
        // Make sure we only have section and key components
        guard keys.count == 2 else {
            throw TranslationError.invalidKeyPath
        }
        
        let section = keys[0]
        let key = keys[1]
        
        // Try to load if we don't have any translations
        if translatableObject == nil {
            try createTranslatableObject(T.self)
        }
        
        return translatableObject?[section]?[key]
    }
    
    // MARK: - Update & Fetch -
    
    /// Fetches the latest version of the translations.
    ///
    /// - Parameter completion: Called when translation fetching has finished. Check if the error
    ///                         object is nil to determine whether the operation was a succes.
    public func updateTranslations(_ completion: ((_ error: Error?) -> Void)? = nil) {
        // Starting translations update asynchronously.
        repository.getTranslations(acceptLanguage: acceptLanguage) { (result: Result<TranslationResponse<L>>) in
            switch result {
            case .success(let translationsData):
                // New translations downloaded
                
                if let lastAcceptHeader = self.lastAcceptHeader,
                    lastAcceptHeader != self.acceptLanguage {
                    do {
                        // Language changed from last time, clearing first
                        try self.clearTranslations(includingPersisted: true)
                    } catch {
                        completion?(error)
                    }

                    // Running language changed action
                    defer {
                        self.delegate?.translationManager(self, languageUpdated: self.currentLanguage)
                    }
                }
                
                self.lastAcceptHeader = self.acceptLanguage
                
                do {
                    try self.set(response: translationsData)
                } catch {
                    completion?(error)
                }
                
                completion?(nil)
                
            case .failure(let error):
                // Error downloading translations data
                completion?(error)
                
            }
        }
    }
    
    /// Gets the languages for which translations are available.
    ///
    /// - Parameter completion: An Alamofire DataResponse object containing the array or languages on success.
    public func fetchAvailableLanguages(_ completion: @escaping (Result<[L]>) -> Void) {
        // Fetching available language asynchronously
        repository.getAvailableLanguages(completion: completion)
    }
    
    /// Useful for setting language override, fx. if you want to choose language in the settings of your app.
    ///
    /// - Parameter language: The language you would like to use.
    /// - Throws: A `TranslationError` error if clearing translations fails.
    func set<L>(languageOverride language: L?) throws where L: LanguageModel {
        if let newValue = language {
            userDefaults.set(newValue, forKey: Constants.Keys.languageOverride)
        } else {
            userDefaults.removeObject(forKey: Constants.Keys.languageOverride)
        }
        try clearTranslations()
    }
    
    // MARK: - Translations -
    
    /// The parsed translations object is cached in memory, but persisted as a dictionary.
    /// If a persisted version cannot be found, the fallback json file in the bundle will be used.
    ///
    /// - Returns: A translations object.
    public func translations<T: Translatable>() throws -> T {
        // Clear translations if language changed
        if let lastAcceptHeader = lastAcceptHeader,
            lastAcceptHeader != acceptLanguage {
            // Language changed from last time, clearing translations
            self.lastAcceptHeader = acceptLanguage
            try clearTranslations()
        }
        
        // Check object in memory
        if let cachedObject = translatableObject as? T {
            return cachedObject
        }
        
        // Load persisted or fallback translations
        try createTranslatableObject(T.self)
        
        // Now we must have correct translations, so return it
        return translatableObject as! T
    }
    
    /// Clears both the memory and persistent cache. Used for debugging purposes.
    ///
    /// - Parameter includingPersisted: If set to `true`, local persisted translation
    ///                                 file will be deleted.
    public func clearTranslations(includingPersisted: Bool = false) throws {
        // In memory translations cleared
        translatableObject = nil
        
        if includingPersisted {
            try set(response: nil)
        }
    }
    
    /// Loads and initializes the translations object from either persisted or fallback dictionary.
    func createTranslatableObject<T>(_ type: T.Type) throws where T: Translatable {
        let translations = try loadTranslations()
        
        // Set our language
        currentLanguage = languageOverride ?? translations.language
        
        // Figure out and set translations
        guard let parsed = try processAllTranslations(translations)  else {
            translatableObject = nil
            return
        }

        let data = try JSONSerialization.data(withJSONObject: parsed, options: [])
        translatableObject = try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Dictionaries -
    
    /// Saves the translations set.
    ///
    /// - Parameter translations: The new translations.
    internal func set(response: TranslationResponse<L>?) throws {
        guard let translationsFileUrl = translationsFileUrl else {
            throw TranslationError.translationsFileUrlUnavailable
        }
        
        // Delete if new value is nil
        guard let newValue = response else {
            // No persisted translation file stored, no need to do anything
            guard fileManager.fileExists(atPath: translationsFileUrl.path) else { return }
            
            // Delete persisted translations file
            try fileManager.removeItem(at: translationsFileUrl)
            
            return
        }

        // Get encoded data
        let data = try encoder.encode(newValue)
        
        // Save to disk
        try data.write(to: translationsFileUrl, options: [.atomic])
        
        // Exclude from backup
        try excludeUrlFromBackup(translationsFileUrl)
        
        // Reload the translations
        try createTranslatableObject(T.self)
    }
    
    /// Returns the saved dictionary representation of the translations.
    internal func loadTranslations() throws -> TranslationResponse<L> {
        guard let persisted = try persistedTranslations() else {
            return try fallbackTranslations()
        }
        return persisted
    }
    
    /// Translations that were downloaded and persisted on disk.
    internal func persistedTranslations() throws -> TranslationResponse<L>? {
        // Getting persisted traslations
        guard let url = translationsFileUrl else {
            throw TranslationError.translationsFileUrlUnavailable
        }
        
        // If file doesn't exist, return nil
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode(TranslationResponse<L>.self, from: data)
    }
    
    /// Loads the local JSON copy, has a return value so that it can be synchronously
    /// loaded the first time they're needed. The local JSON copy contains all available languages,
    /// and the right one is chosen based on the current locale.
    ///
    /// - Returns: A dictionary representation of the selected local translations set.
    internal func fallbackTranslations() throws -> TranslationResponse<L> {
        // Iterate through bundle until we find the translations file
        for bundle in repository.fetchBundles() {
            // Check if bundle contains translations file, otheriwse continue with next bundle
            guard let filePath = bundle.path(forResource: "Translations", ofType: "json") else {
                continue
            }
            
            let fileUrl = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: fileUrl)
            return try decoder.decode(TranslationResponse.self, from: data)
        }
        
        // Failed to load fallback translations, file non-existent
        throw TranslationError.loadingFallbackTranslationsFailed
    }
    
    internal func excludeUrlFromBackup(_ url: URL) throws {
        var mutableUrl = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableUrl.setResourceValues(resourceValues)
    }
    
    // MARK: - Parsing -
    
    /// Unwraps and extracts proper language dictionary out of the dictionary containing
    /// all translations.
    ///
    /// - Parameter dictionary: Dictionary containing all translations under the `data` key.
    /// - Returns: Returns extracted language dictioanry for current accept language.
    internal func processAllTranslations(_ object: TranslationResponse<L>) throws -> [String: Any]? {
        // Processing translations dictionary
        guard !object.translations.isEmpty else {
            // Failed to get data from all translations dictionary
            throw TranslationError.noTranslationsFound
        }
        
        return try extractLanguageDictionary(fromDictionary: object.translations)
    }
    
    /// Uses the device's current locale to select the appropriate translations set.
    ///
    /// - Parameter json: A dictionary containing translation sets by language code key.
    /// - Returns: A translations set as a dictionary.
    internal func extractLanguageDictionary(fromDictionary dictionary: [String: Any]) throws -> [String: Any] {
        // Extracting language dictionary
        var languageDictionary: [String: Any]? = nil
        
        // First try overriden language
        if let languageOverride = languageOverride {
            // Language override enabled, trying it first
            languageDictionary = translationsMatching(language: languageOverride,
                                                      inDictionary: dictionary)
            if let languageDictionary = languageDictionary {
                return languageDictionary
            }
        }
        
        let languages = repository.fetchPreferredLanguages()
        // Finding language for matching preferred languages
        
        // Find matching language and region
        for lan in languages {
            // Try matching on both language and region
            if let dictionary = dictionary[lan] as? [String: Any] {
                // Found matching language for language with region
                return dictionary
            }
        }
        
        let shortLanguages = languages.map({ $0.substring(to: 2) })
        // Finding language for matching preferred  short languages
        
        // Find matching language only
        for lanShort in shortLanguages {
            // Match just on language
            if let dictionary = translationsMatching(locale: lanShort, inDictionary: dictionary) {
                // Found matching language for short language code
                return dictionary
            }
        }
        
        // Take preferred language from backend
        if let currentLanguage = currentLanguage,
            let languageDictionary = translationsMatching(locale: currentLanguage.locale.identifier,
                                                          inDictionary: dictionary) {
            // Finding translations for language recommended by API
            return languageDictionary
        }
        
        // Falling back to first language in dictionary
        languageDictionary = dictionary.values.first as? [String: Any]
        
        if let languageDictionary = languageDictionary {
            return languageDictionary
        }
        
        // Error loading translations. No translations available
        throw TranslationError.noTranslationsFound
    }
    
    /// Searches the translation file for a key matching the provided language code.
    ///
    /// - Parameters:
    ///   - language: The desired language. If `nil`, first language will be used.
    ///   - json: The dictionary containing translations for all languages.
    /// - Returns: Translations dictionary for the given language.
    internal func translationsMatching(language: L, inDictionary dictionary: [String: Any]) -> [String: Any]? {
        return translationsMatching(locale: language.locale.identifier, inDictionary: dictionary)
    }
    
    /// Searches the translation file for a key matching the provided language code.
    ///
    /// - Parameters:
    ///   - locale: A language code of the desired language.
    ///   - json: The dictionary containing translations for all languages.
    /// - Returns: Translations dictionary for the given language.
    internal func translationsMatching(locale: String, inDictionary dictionary: [String: Any]) -> [String: Any]? {
        // If we have perfect match on language and region
        if let dictionary = dictionary[locale] as? [String: Any] {
            return dictionary
        }
        
        // Try shortening keys in dictionary
        for key in dictionary.keys {
            if key.substring(to: 2) == locale {
                return dictionary[key] as? [String: Any]
            }
        }
        
        return nil
    }
    
    // MARK: - Helpers -
    
    /// The URL used to persist downloaded translations.
    internal var translationsFileUrl: URL? {
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        return url?.appendingPathComponent("Translations.tmfile")
    }
}

extension TranslatableManager: ApplicationStateObserverDelegate {
    func applicationStateHasChanged(_ state: ApplicationState) {
        switch state {
        case .foreground:
            // Update translations when we go to foreground
            break
        case .background:
            // Do nothing when we go to background
            break
        }
    }
}
