//
//  DynamicAssetsError.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 22/09/25.
//
import Foundation


public enum DynamicAssetsError: Error {
    case networkError(Swift.Error)
    case invalidResponse
    case fileSystemError(Swift.Error)
    case checksumMismatch
    case assetNotFound(String)
    case configurationError
}
