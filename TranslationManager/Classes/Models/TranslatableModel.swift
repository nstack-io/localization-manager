//
//  TranslatableMockModel.swift
//  TranslationManagerTests
//
//  Created by Andrew Lloyd on 20/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

public struct TranslatableModel: Translatable {
    public subscript(key: String) -> TranslatableSection? {
        return nil
    }
}
