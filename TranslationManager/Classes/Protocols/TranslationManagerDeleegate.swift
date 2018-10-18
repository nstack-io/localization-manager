//
//  TranslationManagerDeleegate.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public protocol TranslationManagerDelegate: class {
    func translationManager<L>(_ manager: TranslationManagerType, languageUpdated: L?) where L: LanguageModel
}
