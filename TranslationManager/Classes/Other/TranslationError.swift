//
//  TranslationError.swift
//  TranslationManager
//
//  Created by Dominik Hadl on 18/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import Foundation

public enum TranslationError: Error {
    case invalidKeyPath
    case updateFailed(_ error: Error)
    case unknown
    
    public var localizedDescription: String {
        switch self {
        case .invalidKeyPath: return "Key path should only consist of section and key components."
        case .updateFailed(let error): return "Translations update has failed to download: \(error.localizedDescription)"
        case .unknown: return "Uknown error happened."
        }
    }
}
