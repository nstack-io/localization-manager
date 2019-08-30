//
//  StoreError.swift
//  TranslationManager
//
//  Created by Dominik Hádl on 27/06/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

// TODO: Add docs

public enum StoreError: Error {
    case notSupported
    case inaccessible
    case dataNotFound
}
