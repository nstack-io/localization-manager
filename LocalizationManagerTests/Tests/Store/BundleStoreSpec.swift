//
//  BundleStoreSpec.swift
//  LocalizationManager
//
//  Created by Dominik Hádl on 21/09/2019.
//  Copyright © 2019 Nodes. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LocalizationManager

final class BundleStoreSpec: QuickSpec {
    let language = DefaultLanguage(
        id: 0, name: "English", direction: "rtl",
        locale: Locale(identifier: "en-GB"),
        isDefault: true, isBestFit: false
    )

    let nonExistingLanguage = DefaultLanguage(
        id: 0, name: "Czech", direction: "rtl",
        locale: Locale(identifier: "cs-CZ"),
        isDefault: true, isBestFit: false
    )

    lazy var descriptor: DefaultLocalizationDescriptor = DefaultLocalizationDescriptor(
        localeIdentifier: "en-GB",
        url: "",
        language: language
    )

    lazy var nonExistingDescriptor: DefaultLocalizationDescriptor = DefaultLocalizationDescriptor(
        localeIdentifier: "cs-CZ",
        url: "",
        language: nonExistingLanguage
    )

    override func spec() {
        describe("A BundleStore") {
            let contextProviderMock = LocalizationContextRepositoryMock()
            let bundleStore = BundleStore<DefaultLanguage, DefaultLocalizationDescriptor>(contextProvider: contextProviderMock)
            contextProviderMock.localizationBundle = Bundle(for: BundleStoreSpec.self)

            context("provided with language") {
                it("should return valid directory name") {
                    let expected = "\(Constants.Store.localizationDirectory)/en-GB"
                    expect(bundleStore.directory(for: self.language)).to(equal(expected))
                }
            }

            context("provided with language and bundle") {
                let bundleMock = BundleMock()
                bundleMock.returnParametersAsString = true
                contextProviderMock.localizationBundle = bundleMock

                it("should return valid path for descriptor") {
                    let expectedDirectory = "\(Constants.Store.localizationDirectory)/en-GB"
                    let expected = "\(Constants.Store.descriptorFileName)\(Constants.Store.fileExtension)\(expectedDirectory)"
                    expect(bundleStore.descriptorPath(in: bundleMock, for: self.language)).to(equal(expected))
                    expect(bundleMock.pathCallsCount).to(equal(1))
                }

                it("should return valid path for data") {
                    let expectedDirectory = "\(Constants.Store.localizationDirectory)/en-GB"
                    let expected = "\(Constants.Store.dataFileName)\(Constants.Store.fileExtension)\(expectedDirectory)"
                    expect(bundleStore.dataPath(in: bundleMock, for: self.descriptor)).to(equal(expected))
                    expect(bundleMock.pathCallsCount).to(equal(2))
                }
            }

            context("loading an existing descriptor") {
                let testDataPath = Bundle(for: BundleStoreSpec.self).path(forResource: "TestDescriptor_en-GB", ofType: "json")!
                let testData = try! Data(contentsOf: URL(fileURLWithPath: testDataPath))

                it("should return data") {
                    let bundleMock = BundleMock()
                    bundleMock.resourcePathOverride = testDataPath
                    contextProviderMock.localizationBundle = bundleMock
                    
                    expect {
                        return try bundleStore.descriptorData(for: self.language)
                    }.to(equal(testData))
                }
            }

            context("loading localization for descriptor") {
                let testDataPath = Bundle(for: BundleStoreSpec.self).path(forResource: "Localization_en-GB", ofType: "json")!
                let testData = try! Data(contentsOf: URL(fileURLWithPath: testDataPath))

                it("should return data") {
                    let bundleMock = BundleMock()
                    bundleMock.resourcePathOverride = testDataPath
                    contextProviderMock.localizationBundle = bundleMock

                    expect {
                        return try bundleStore.localizationData(for: self.descriptor)
                    }.to(equal(testData))
                }
            }

            context("loading non-existing descriptor") {
                it("should throw data not found error") {
                    let bundleMock = BundleMock()
                    contextProviderMock.localizationBundle = bundleMock
                    expect {
                        return try bundleStore.descriptorData(for: self.nonExistingLanguage)
                    }.to(throwError(StoreError.dataNotFound))
                }
            }

            context("loading non-existing localization for descriptor") {
                it("should throw data not found error") {
                    let bundleMock = BundleMock()
                    contextProviderMock.localizationBundle = bundleMock
                    expect {
                        return try bundleStore.localizationData(for: self.nonExistingDescriptor)
                    }.to(throwError(StoreError.dataNotFound))
                }
            }

            context("saving a descriptor") {
                it("should fail with not supported error") {
                    expect {
                        try bundleStore.save(descriptorData: Data(), for: self.language)
                    }.to(throwError(StoreError.notSupported))
                }
            }

            context("saving data") {
                it("should fail with not supported error") {
                    expect {
                        try bundleStore.save(localizationData: Data(), for: self.descriptor)
                    }.to(throwError(StoreError.notSupported))
                }
            }

            context("deleting data for language") {
                it("should fail with not supported error") {
                    expect {
                        try bundleStore.deleteLocalizationData(for: self.language)
                    }.to(throwError(StoreError.notSupported))
                }
            }

            context("deleting all data") {
                it("should fail with not supported error") {
                    expect {
                        try bundleStore.deleteAllData()
                    }.to(throwError(StoreError.notSupported))
                }
            }
        }
    }
}
