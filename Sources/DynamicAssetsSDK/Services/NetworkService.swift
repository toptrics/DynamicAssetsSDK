//
//  NetworkService.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 24/09/25.
//
import Foundation

public protocol NetworkServiceProtocol {
    func fetchConfig(from url: URL) async throws -> ConfigResponse
    func downloadData(from url: URL) async throws -> Data
}


// MARK: - Default Network Implementation

public class NetworkService: NetworkServiceProtocol {
    let urlSession: URLSession
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func fetchConfig(from url: URL) async throws -> ConfigResponse {
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(ConfigResponse.self, from: data)
    }

    public func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
