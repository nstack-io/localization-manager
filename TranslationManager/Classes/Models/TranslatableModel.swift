//
//  TranslatableMockModel.swift
//  TranslationManagerTests
//
//  Created by Andrew Lloyd on 20/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

public struct TranslatableModel: Translatable {
    
    public let sectionDictionary: [String: TranslatableSectionModel] = [:]
    
    
    public subscript(key: String) -> TranslatableSection? {
        return sectionDictionary[key]
    }
}

public struct TranslatableSectionModel: TranslatableSection {
    
    public let valueDictionary: [String: String]?
    public subscript(key: String) -> String? {
        return valueDictionary?[key]
    }
}
