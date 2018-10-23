//
//  TranslationResponse.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public struct TranslationResponse<L: LanguageModel>: Codable {
    public internal(set) var translations: [String: Any]
    public let language: L?
    
    enum CodingKeys: String, CodingKey {
        case translations = "data"
        case languageData = "meta"
    }
    
    enum LanguageCodingKeys: String, CodingKey {
        case language
    }
    
    init(translations: [String: Any] = [:], language: L? = nil) {
        self.translations = [:]
        self.language = nil
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        translations = try values.decodeIfPresent([String: Any].self, forKey: .translations) ?? [:]
        
        let languageData = try values.nestedContainer(keyedBy: LanguageCodingKeys.self, forKey: .languageData)
        language = try languageData.decodeIfPresent(L.self, forKey: .language)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(translations, forKey: .translations)
        
        var languageData = container.nestedContainer(keyedBy: LanguageCodingKeys.self, forKey: .languageData)
        try languageData.encode(language, forKey: .language)
    }
}
