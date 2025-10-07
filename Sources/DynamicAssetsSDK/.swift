//
//  DynamicAssetsSDK.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 22/09/25.
//
import Foundation
import UIKit


public final class DynamicAssets {
    
    public static let shared = DynamicAssets()
    
    private var baseURL: URL?
    private let configManager: ConfigurationManager
    private let downloadManager: DownloadManager
    private let fileManager: AssetFileManager
    private let persistenceLayer: PersistenceLayer
    
    private var isInitialized = false
    private let initQueue = DispatchQueue(label: "com.dynamicassets.init", qos: .utility)
    
    private init() {
        // Initialize with default configuration - should be set via configure method
        self.baseURL = URL(string: "https://api.example.com")!
        self.configManager = ConfigurationManager()
        self.fileManager = AssetFileManager()
        self.persistenceLayer = PersistenceLayer()
        self.downloadManager = DownloadManager(
            fileManager: fileManager,
            persistenceLayer: persistenceLayer
        )
    }
    
    // MARK: - Public API
    
    public func configure(configURL: String) {
        self.baseURL = URL(string: configURL)
        // Note: In a real implementation, we'd make baseURL mutable
        print("SDK configured with base URL: \(configURL)")
    }
    
    public func initialize(completion: @escaping (Result<Void, DynamicAssetsError>) -> Void) {
        initQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.isInitialized {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }
            
            self.performInitialization { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
    
    public func getImage(for key: String, completion: @escaping (Result<UIImage, DynamicAssetsError>) -> Void) {
        guard isInitialized else {
            completion(.failure(.configurationError))
            return
        }
        
        // First check if image is cached locally
        if let cachedImage = fileManager.getCachedImage(for: key) {
            completion(.success(cachedImage))
            return
        }
        
        // If not cached, download it
        downloadAsset(key: key) { [weak self] result in
            switch result {
            case .success:
                if let image = self?.fileManager.getCachedImage(for: key) {
                    completion(.success(image))
                } else {
                    completion(.failure(.assetNotFound(key)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func checkForUpdates(completion: @escaping (Result<Bool, DynamicAssetsError>) -> Void) {
        guard isInitialized else {
            completion(.failure(.configurationError))
            return
        }
        
        let currentVersion = persistenceLayer.getCurrentVersion()
        let deviceConfig = configManager.getDeviceConfig()
        
        let urlString = "\(baseURL?.absoluteString ?? "")/assets/update?\(deviceConfig.queryString)&version=\(currentVersion)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.configurationError))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let updateResponse = try JSONDecoder().decode(UpdateResponse.self, from: data)
                
                if updateResponse.hasUpdates {
                    self?.processUpdates(updateResponse) { result in
                        switch result {
                        case .success:
                            completion(.success(true))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.success(false))
                }
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    // MARK: - Private Implementation
    
    private func performInitialization(completion: @escaping (Result<Void, DynamicAssetsError>) -> Void) {
        let deviceConfig = configManager.getDeviceConfig()
        let currentVersion = persistenceLayer.getCurrentVersion()
        
        let urlString = "\(baseURL?.absoluteString ?? "")/assets?\(deviceConfig.queryString)&version=\(currentVersion)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.configurationError))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let assetResponse = try JSONDecoder().decode(AssetResponse.self, from: data)
                self?.persistenceLayer.saveAssetConfiguration(assetResponse.assets)
                self?.persistenceLayer.saveCurrentVersion(assetResponse.version)
                self?.isInitialized = true
                completion(.success(()))
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    private func downloadAsset(key: String, completion: @escaping (Result<Void, DynamicAssetsError>) -> Void) {
        guard let assetConfig = persistenceLayer.getAssetConfig(for: key) else {
            completion(.failure(.assetNotFound(key)))
            return
        }
        
        downloadManager.downloadAsset(config: assetConfig, completion: completion)
    }
    
    private func processUpdates(_ updateResponse: UpdateResponse, completion: @escaping (Result<Void, DynamicAssetsError>) -> Void) {
        let group = DispatchGroup()
        var hasError = false
        
        // Process additions
        for assetConfig in updateResponse.additions {
            group.enter()
            downloadManager.downloadAsset(config: assetConfig) { result in
                if case .failure = result {
                    hasError = true
                }
                group.leave()
            }
        }
        
        // Process updates
        for assetConfig in updateResponse.updates {
            group.enter()
            downloadManager.downloadAsset(config: assetConfig) { result in
                if case .failure = result {
                    hasError = true
                }
                group.leave()
            }
        }
        
        // Process deletions
        for key in updateResponse.deletions {
            fileManager.deleteAsset(key: key)
            persistenceLayer.removeAssetConfig(for: key)
        }
        
        group.notify(queue: .main) {
            if hasError {
                completion(.failure(.networkError(NSError(domain: "UpdateError", code: -1))))
            } else {
                self.persistenceLayer.saveCurrentVersion(updateResponse.version)
                completion(.success(()))
            }
        }
    }
}
