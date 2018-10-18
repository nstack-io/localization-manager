//
//  TranslationManager.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

/// The Translations Manager handles everything related to translations.
///
/// Usually, direct interaction with the `Translations Manager` shouldn't be neccessary, since
/// it is setup automatically by the NStack manager, and the translations are accessible by the
/// global 'tr' variable defined in the auto-generated translations Swift file.
public class TranslationManager<T: Translatable, L: LanguageModel>: TranslationManagerType {
    
    /// Repository that provides translations.
    let repository: TranslationsRepository
    
    /// File manager handling persisting new translation data.
    let fileManager: FileManager
    
    /// User defaults used to store basic information and settings.
    let userDefaults: UserDefaults
    
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
    internal var translationsObject: Translatable?
    
    /// In memory cache of the last language object.
    public internal(set) var currentLanguage: L?
    
    /// Internal handler closure for language change.
    internal var languageChangedAction: (() -> Void)?
    
    /// The previous accept header string that was used.
    internal var lastAcceptHeader: String? {
        get {
            return UserDefaults.standard.string(forKey: Constants.Keys.previousAcceptLanguage)
        }
        set {
            guard let newValue = newValue else {
                // Last accept header deleted
                UserDefaults.standard.removeObject(forKey: Constants.Keys.previousAcceptLanguage)
                return
            }
            // Last accept header set to: \(newValue).
            UserDefaults.standard.set(newValue, forKey: Constants.Keys.previousAcceptLanguage)
        }
    }
    
    /// This language will be used instead of the phones' language when it is not `nil`. Remember
    /// to call `updateTranslations()` after changing the value.
    /// Otherwise, the effect will not be seen.
    internal var languageOverride: L? {
        get {
            return UserDefaults.standard.model(forKey: Constants.Keys.languageOverride)
        }
        set {
            if let newValue = newValue {
                // Override language set to: \(newValue.locale)
                UserDefaults.standard.set(newValue, forKey: Constants.Keys.languageOverride)
            } else {
                // Override language deleted.
                UserDefaults.standard.removeObject(forKey: Constants.Keys.languageOverride)
            }
            clearTranslations()
        }
    }
    
    // MARK: - Lifecycle -
    
    /// Instantiates and sets the type of the translations object and the repository from which
    /// translations are fetched. Usually this is invoked by the NStack start method, so under normal
    /// circumstances, it should not be neccessary to invoke it directly.
    ///
    /// - Parameters:
    ///   - repository: Repository that can provide translations.
    required public init(repository: TranslationsRepository,
                         fileManager: FileManager = .default,
                         userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.fileManager = fileManager
        self.userDefaults = userDefaults
    }
    
    ///Find a translation for a key.
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
        if translationsObject == nil {
            loadTranslations(T.self)
        }
        
        return translationsObject?[section]?[key]
    }
    
    // MARK: - Update & Fetch -
    
    /// Fetches the latest version of the translations. Normally, the translations are aquired
    /// when performing the NStack public call, so in most scenarios, this method won't have to
    /// be called directly. Use it if you need to force refresh the translations during
    /// app use, for example if manually switching language.
    ///
    /// - Parameter completion: Called when translation fetching has finished. Check if the error
    ///                         object is nil to determine whether the operation was a succes.
    public func updateTranslations(_ completion: ((_ error: TranslationError?) -> Void)? = nil) {
        // Starting translations update asynchronously.
        repository.getTranslations(acceptLanguage: acceptLanguage) { (result: Result<TranslationResponse<L>>) in
            switch result {
            case .success(let translationsData):
                // New translations downloaded
                
                var languageChanged = false
                if self.lastAcceptHeader != self.acceptLanguage {
                    // Language changed from last time, clearing first
                    self.clearTranslations(includingPersisted: true)
                    languageChanged = true
                }
                
                self.lastAcceptHeader = self.acceptLanguage
                self.set(response: translationsData)
                
                completion?(nil)
                
                if languageChanged {
                    // Running language changed action
                    self.languageChangedAction?()
                }
                
            case .failure(let error):
                // Error downloading translations data
                completion?(.updateFailed(error))
                
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
    
    /// Gets the language which is currently used for translations, based on the accept header.
    ///
    /// - Parameter completion: An Alamofire DataResponse object containing the language on success.
    public func fetchCurrentLanguage(_ completion: @escaping (Result<L>) -> Void) {
        // Fetching current language asynchronously
        repository.getCurrentLanguage(acceptLanguage: acceptLanguage, completion: completion)
    }
    
    // MARK: - Accept Language -
    
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
    
    // MARK: - Translations -
    
    /// The parsed translations object is cached in memory, but persisted as a dictionary.
    /// If a persisted version cannot be found, the fallback json file in the bundle will be used.
    ///
    /// - Returns: A translations object.
    public func translations<T: Translatable>() -> T {
        // Clear translations if language changed
        if let lastAcceptHeader = lastAcceptHeader,
            lastAcceptHeader != acceptLanguage {
            // Language changed from last time, clearing translations
            self.lastAcceptHeader = acceptLanguage
            clearTranslations()
        }
        
        // Check object in memory
        if let cachedObject = translationsObject as? T {
            return cachedObject
        }
        
        // Load persisted or fallback translations
        loadTranslations(T.self)
        
        // Now we must have correct translations, so return it
        return translationsObject as! T
    }
    
    /// Clears both the memory and persistent cache. Used for debugging purposes.
    ///
    /// - Parameter includingPersisted: If set to `true`, local persisted translation
    ///                                 file will be deleted.
    public func clearTranslations(includingPersisted: Bool = false) {
        // In memory translations cleared
        translationsObject = nil
        
        if includingPersisted {
            persistedTranslations = nil
        }
    }
    
    /// Loads and initializes the translations object from either persisted or fallback dictionary.
    internal func loadTranslations<T>(_ type: T.Type) where T: Translatable {
        // Loading translations
        
        // Set our language
        currentLanguage = languageOverride ?? translationsDictionary.language
        
        // Figure out and set translations
        guard let parsed = processAllTranslations(translationsDictionary),
            let data = try? JSONSerialization.data(withJSONObject: parsed, options: []) else {
                // logger?.log error couldn't get translations
                translationsObject = nil
                return
        }
        
        guard let translations = try? decoder.decode(T.self, from: data) else {
            // logger?.log error couldn't decode translations
            return
        }
        
        translationsObject = translations
    }
    
    // MARK: - Dictionaries -
    
    /// Saves the translations set.
    ///
    /// - Parameter translations: The new translations.
    internal func set(response: TranslationResponse<L>?) {
        //        guard let dictionary = response?.encodableRepresentation() as? NSDictionary else {
        //            logger?.logError("Failed to create dicitonary from translations API response.")
        //            return
        //        }
        //
        //        // Persist the object
        //        persistedTranslations = dictionary
        //
        //        // Reload the translations
        //        _ = loadTranslations()
        guard let object = response else {
            // logger?.logError()
            return
        }
        
        // Persist the object
        persistedTranslations = object
        
        // Reload the translations
        loadTranslations(T.self)
    }
    
    /// Returns the saved dictionary representation of the translations.
    internal var translationsDictionary: TranslationResponse<L> {
        return persistedTranslations ?? fallbackTranslations
    }
    
    /// Translations that were downloaded and persisted on disk.
    internal var persistedTranslations: TranslationResponse<L>? {
        get {
            // Getting persisted traslations
            guard let url = translationsFileUrl,
                let data = try? Data(contentsOf: url) else {
                    // No persisted translations available, returing nil
                    return nil
            }
            
            guard let object = try? decoder.decode(TranslationResponse<L>.self, from: data) else {
                // Invalid data saved
                return nil
            }
            
            return object
        }
        set {
            guard let translationsFileUrl = translationsFileUrl else {
                return
            }
            
            // Delete if new value is nil
            guard let newValue = newValue else {
                guard fileManager.fileExists(atPath: translationsFileUrl.path) else {
                    // No persisted translation file stored, aborting
                    return
                }
                
                do {
                    // Deleting persisted translations file
                    try fileManager.removeItem(at: translationsFileUrl)
                } catch {
                    // Failed to delete persisted translatons
                }
                return
            }
            
            guard let data = try? encoder.encode(newValue) else {
                // Failed at encoding
                // logger?.log something
                return
            }
            
            // Save to disk
            var url = translationsFileUrl
            do {
                try data.write(to: url, options: [.atomic])
            } catch {
                // Failed to persist translations to disk: \(error.localizedDescription)
                return
            }
            // Translations persisted to disk
            
            // Exclude from backup
            do {
                // Excluding persisted translations from backup
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try url.setResourceValues(resourceValues)
            } catch {
                // Failed to exclude translations from backup. \(error.localizedDescription)
            }
        }
    }
    
    /// Loads the local JSON copy, has a return value so that it can be synchronously
    /// loaded the first time they're needed. The local JSON copy contains all available languages,
    /// and the right one is chosen based on the current locale.
    ///
    /// - Returns: A dictionary representation of the selected local translations set.
    internal var fallbackTranslations: TranslationResponse<L> {
        for bundle in repository.fetchBundles() {
            guard let filePath = bundle.path(forResource: "Translations", ofType: "json") else {
                // Bundle did not contain Translations.json file
                continue
            }
            
            let fileUrl = URL(fileURLWithPath: filePath)
            let data: Data
            
            do {
                // Loading fallback translations file at: \(filePath)
                data = try Data(contentsOf: fileUrl)
            } catch {
                // Failed to get data from fallback translations file
                continue
            }
            
            do {
                // Converting loaded file to JSON object
                return try decoder.decode(TranslationResponse.self, from: data)
            } catch {
                // Error loading translations JSON file
            }
        }
        
        // Failed to load fallback translations, file non-existent
        return TranslationResponse()
    }
    
    // MARK: - Parsing -
    
    /// Unwraps and extracts proper language dictionary out of the dictionary containing
    /// all translations.
    ///
    /// - Parameter dictionary: Dictionary containing all translations under the `data` key.
    /// - Returns: Returns extracted language dictioanry for current accept language.
    internal func processAllTranslations(_ object: TranslationResponse<L>) -> [String: Any]? {
        // Processing translations dictionary
        guard !object.translations.isEmpty else {
            // Failed to get data from all translations dictionary
            return nil
        }
        
        return extractLanguageDictionary(fromDictionary: object.translations)
    }
    
    /// Uses the device's current locale to select the appropriate translations set.
    ///
    /// - Parameter json: A dictionary containing translation sets by language code key.
    /// - Returns: A translations set as a dictionary.
    internal func extractLanguageDictionary(fromDictionary dictionary: [String: Any]) -> [String: Any] {
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
            if let dictinoary = translationsMatching(locale: lanShort, inDictionary: dictionary) {
                // Found matching language for short language code
                return dictinoary
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
        return [:]
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
        return url?.appendingPathComponent("Translations.nstack")
    }
}
