//
//  LocalizationResponse.swift
//  LocalizationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public struct LocalizationResponse<Language: LanguageModel>: Codable {
    public internal(set) var localization: [String: Any]
    public let language: Language?

    enum CodingKeys: String, CodingKey {
        case localization = "data"
        case meta
    }

    enum LanguageCodingKeys: String, CodingKey {
        case language
    }

    public init(localizations: [String: Any] = [:], language: Language? = nil) {
        self.localization = localizations
        self.language = language
    }

    public init(from decoder: Decoder) throws {
        // Get localization data
        let values = try decoder.container(keyedBy: CodingKeys.self)
        localization = try values.decodeIfPresent([String: Any].self, forKey: .localization) ?? [:]

        // Extract language
        let nestedContainer = try values.nestedContainer(keyedBy: LanguageCodingKeys.self, forKey: .meta)
        language = try nestedContainer.decodeIfPresent(Language.self, forKey: .language)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localization, forKey: .localization)

        var nested = container.nestedContainer(keyedBy: LanguageCodingKeys.self, forKey: .meta)
        try nested.encode(language, forKey: .language)
    }
}
