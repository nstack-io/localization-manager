//
//  BundleMock.swift
//  NStackSDK
//
//  Created by Dominik Hádl on 09/12/2016.
//  Copyright © 2016 Nodes ApS. All rights reserved.
//

import Foundation

class BundleMock: Bundle {
    var resourcePathOverride: String?
    var resourceNameOverride: String?
    var returnParametersAsString: Bool = false
    var pathCallsCount = 0

    override func path(forResource name: String?, ofType ext: String?) -> String? {
        pathCallsCount += 1
        if returnParametersAsString {
            return (name ?? "") + (ext ?? "")
        }
        return resourcePathOverride ?? super.path(forResource: resourceNameOverride ?? name, ofType: ext)
    }

    override func path(forResource name: String?,
                       ofType ext: String?,
                       inDirectory subpath: String?) -> String? {
        pathCallsCount += 1
        if returnParametersAsString {
            return (name ?? "") + (ext ?? "") + (subpath ?? "")
        }
        return resourcePathOverride ?? super.path(forResource: name, ofType: ext, inDirectory: subpath)
    }
}
