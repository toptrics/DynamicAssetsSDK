//
//  AssetConfig.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 22/09/25.
//
import Foundation
import UIKit

// MARK: - Public API Models

public struct ConfigResponse: Codable {
    public let version: String?
    public let images: [ImageMeta]?
}


public struct ImageMeta: Codable, Equatable {
    public let key: String?
    public let url: String?
    public let version: String?
}

public struct DeviceConfig {
    let model: String
    let osVersion: String
    let locale: String
    let screenScale: CGFloat
    let screenSize: CGSize
    
    @MainActor
    public init() {
        self.model = UIDevice.current.model
        self.osVersion = UIDevice.current.systemVersion
        self.locale = Locale.current.identifier
        self.screenScale = UIScreen.main.scale
        self.screenSize = UIScreen.main.bounds.size
    }
    
    var queryString: String {
        return "scale=\(screenScale)"
    }
}
