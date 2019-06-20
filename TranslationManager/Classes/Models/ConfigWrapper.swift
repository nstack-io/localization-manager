//
//  ConfigWrapper.swift
//  TranslationManager
//
//  Created by Andrew Lloyd on 20/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

public struct ConfigWrapper: Codable {
    
    public var data: [LocalizationConfig]
    
    public init(data: [LocalizationConfig]) {
        self.data = data
    }
}
