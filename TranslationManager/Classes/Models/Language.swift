//
//  Language.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public struct Language: LanguageModel {
    public let id: Int
    public let name: String
    public let locale: Locale
    public let direction: String
    public let acceptLanguage: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, locale, direction
        case acceptLanguage = "Accept-Language"
    }
    
}
