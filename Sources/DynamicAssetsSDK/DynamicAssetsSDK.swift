// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  DynamicAssetsSDK.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 22/09/25.
//

import Foundation
import UIKit


public final class DynamicAssetsSDK: @unchecked Sendable {
    public static let shared = DynamicAssetsSDK()

    private var service: DynamicAssetsService?
    private var deviceConfig: DeviceConfig?

    private init() {}

   public func initialize(configURL: URL) throws {
        let networkService = NetworkService()
        let storeService = try StorageService()

        let svc = DynamicAssetsService(configURL: configURL,
                                       network: networkService,
                                       storage: storeService)
        self.service = svc
        svc.fetchConfig()
    }

    public func image(forKey key: String) async -> UIImage? {
        guard let svc = service else { return nil }
        do {
            let data = try await svc.imageData(forKey: key)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
