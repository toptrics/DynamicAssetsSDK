//
//  File.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 24/09/25.
//

import Foundation
import UIKit

protocol DynamicAssetsServiceProtocol {
    
}

public class DynamicAssetsService: @unchecked Sendable {
    private let network: NetworkServiceProtocol
    private let storage: StorageServiceProtocol
    
    private(set) var configURL: URL
    private var cachedConfig: ConfigResponse?
    private var deviceScale: Int = 3
    private let queue = DispatchQueue(label: "DynamicAssetsService.queue", attributes: .concurrent)
    
    
    public init(configURL: URL,
                network: NetworkServiceProtocol,
                storage: StorageServiceProtocol) {
        self.configURL = configURL
        self.network = network
        self.storage = storage
    }
    
    public func fetchConfig() {
        if let stored = storage.getStoredConfig(for: configURL) {
            self.cachedConfig = stored
        } else {
            Task {
                let serverConfig = try await network.fetchConfig(from: configURLWithDeviceParams())
                storage.saveConfig(serverConfig, for: configURL)
                cachedConfig = serverConfig
            }
        }
    }
    
    
    private func configURLWithDeviceParams() -> URL {
        let currentScale: Int = self.deviceScale
        let items = [
            URLQueryItem(name: "scale", value: String(currentScale))
        ]
        return configURL.addingQueryItems(items)
    }
    
    
    public func imageData(forKey key: String) async throws -> Data {
        guard let config = self.cachedConfig,
              let meta = config.images?.first(where: { $0.key == key }),
              let imageURL = URL(string:  meta.url ?? "") else {
            throw NSError(domain: "DynamicAssetsSDK", code: 404, userInfo: [NSLocalizedDescriptionKey: "Image meta for key not found"]) }
        
        
        if let stored = await storage.getImageData(forKey: key) {
            print("getting image for caching key: \(key)")
            if stored.version == meta.version {
                return stored.data
            }
        }
        
        
        let data = try await network.downloadData(from: imageURL)
        storage.saveImageData(data, version: meta.version ?? "1", forKey: key)
        print("getting image for download for key: \(key)")
        return data
    }
}
