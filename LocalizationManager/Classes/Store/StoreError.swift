//
//  StoreError.swift
//  LocalizationManager
//
//  Created by Dominik Hádl on 21/09/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation

public enum StoreError: Error {
    case dataNotFound
    case notSupported
    case inaccessible
}
