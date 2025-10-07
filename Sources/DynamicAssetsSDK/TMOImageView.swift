//
//  TMOImageView.swift
//  DynamicAssetsSDK
//
//  Created by Sunil on 22/09/25.
//

import Foundation
import SwiftUI

// MARK: - Custom UIImageView (Optional Enhancement)

public struct TMOImageView: View {
    @StateObject private var vm: TMOImageViewModel
    private let key: String
    private let placeholder: Image
    
    public init(key: String, placeholder: Image = Image(systemName: "photo")) {
        self.key = key
        _vm = StateObject(wrappedValue: TMOImageViewModel(key: key))
        self.placeholder = placeholder
    }
    
    public var body: some View {
        Group {
            if let ui = vm.uiImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else if vm.isLoading {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .redacted(reason: .placeholder)
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
            }
        }
        .task {
            await vm.loadIfNeeded()
        }
        .onChange(of: key) { newKey in
            Task {
                await vm.updateKey(newKey)
            }
        }
    }
}

@MainActor
final class TMOImageViewModel: ObservableObject {
    @Published var uiImage: UIImage?
    @Published var isLoading = false
    private(set) var key: String
    
    init(key: String) {
        self.key = key
    }
    
    func updateKey(_ newKey: String) async {
        guard newKey != key else { return }
        key = newKey
        uiImage = nil
        await loadIfNeeded()
    }
    
    func loadIfNeeded() async {
        guard uiImage == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if let image = await DynamicAssetsSDK.shared.image(forKey: key) {
            uiImage = image
        }
    }
}
