//
//  StorageService.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 24/09/25.
//
import Foundation
import UIKit

public protocol StorageServiceProtocol {
    func getStoredConfig(for url: URL) -> ConfigResponse?
    func saveConfig(_ config: ConfigResponse, for url: URL)

    func getImageData(forKey key: String) async -> (data: Data, version: String)?
    func saveImageData(_ data: Data, version: String, forKey key: String)
}

public class StorageService: @unchecked Sendable, StorageServiceProtocol {
    private let fileManager = FileManager.default
    private let directory: URL
    private let queue = DispatchQueue(label: "FileStorageService.queue", attributes: .concurrent)

    public init(subdirectory: String = "DynamicAssets") throws {
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        directory = caches.appendingPathComponent(subdirectory, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func configFileURL(for url: URL) -> URL {
        let name = "config_" + (url.absoluteString.sha256())
        return directory.appendingPathComponent(name).appendingPathExtension("json")
    }

    private func imageFileURL(forKey key: String) -> URL {
        let name = "img_" + key.sha256()
        return directory.appendingPathComponent(name)
    }

    public func getStoredConfig(for url: URL) -> ConfigResponse? {
        queue.sync {
            let file = self.configFileURL(for: url)
            guard self.fileManager.fileExists(atPath: file.path) else {
                return nil
            }
            do {
                let data = try Data(contentsOf: file)
                let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
                return config
            } catch {
                return nil
            }
        }
    }

    public func saveConfig(_ config: ConfigResponse, for url: URL) {
        queue.async(flags: .barrier) {
            let file = self.configFileURL(for: url)
            do {
                let data = try JSONEncoder().encode(config)
                try data.write(to: file, options: .atomic)
            } catch {
                // swallow errors for now
            }
        }
    }

    public func getImageData(forKey key: String) async -> (data: Data, version: String)? {
        await withCheckedContinuation { continuation in
            queue.async {
                let metaFile = self.directory.appendingPathComponent("meta_" + key.sha256()).appendingPathExtension("json")
                let imgFile = self.imageFileURL(forKey: key)
                guard self.fileManager.fileExists(atPath: imgFile.path), self.fileManager.fileExists(atPath: metaFile.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    let data = try Data(contentsOf: imgFile)
                    let metaData = try Data(contentsOf: metaFile)
                    let meta = try JSONDecoder().decode([String: String].self, from: metaData)
                    if let version = meta["version"] {
                        continuation.resume(returning: (data, version))
                        return
                    }
                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    public func saveImageData(_ data: Data, version: String, forKey key: String) {
        queue.async(flags: .barrier) {
            let imgFile = self.imageFileURL(forKey: key)
            let metaFile = self.directory.appendingPathComponent("meta_" + key.sha256()).appendingPathExtension("json")
            do {
                try data.write(to: imgFile, options: .atomic)
                let meta = ["version": version]
                let metaData = try JSONEncoder().encode(meta)
                try metaData.write(to: metaFile, options: .atomic)
            } catch {
                // ignore
            }
        }
    }
}


// MARK: - Helpers

extension String {
    func sha256() -> String {
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        return self
    }
}

extension URL {
    func addingQueryItems(_ items: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var existing = components.queryItems ?? []
        existing.append(contentsOf: items)
        components.queryItems = existing
        return components.url ?? self
    }
}
