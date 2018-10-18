//
//  Result.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public enum Result<T> {
    case success(_ data: T)
    case failure(_ error: Error)
}
