//
//  ThumbnailService.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import UIKit
import AVFoundation

public protocol ThumbnailServiceProtocol: Sendable {
    func generateThumbnail(fromPhotoData data: Data, maxDimension: CGFloat) -> Data?
    func generateThumbnail(fromVideoURL url: URL, maxDimension: CGFloat) async -> Data?
    func getCachedImage(for id: UUID) -> UIImage?
    func setCachedImage(_ image: UIImage, for id: UUID)
    func clearMemoryCache()
}

public final class ThumbnailService: ThumbnailServiceProtocol, @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    public init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB max memory cache
    }

    public func generateThumbnail(fromPhotoData data: Data, maxDimension: CGFloat = 320) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let thumbnailCG = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let uiImage = UIImage(cgImage: thumbnailCG)
        return uiImage.jpegData(compressionQuality: 0.75)
    }

    public func generateThumbnail(fromVideoURL url: URL, maxDimension: CGFloat = 320) async -> Data? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let cgImage: CGImage
            if #available(iOS 16.0, *) {
                cgImage = try await generator.image(at: time).image
            } else {
                cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            }
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 0.75)
        } catch {
            return nil
        }
    }

    public func getCachedImage(for id: UUID) -> UIImage? {
        cache.object(forKey: id.uuidString as NSString)
    }

    public func setCachedImage(_ image: UIImage, for id: UUID) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: id.uuidString as NSString, cost: cost)
    }

    public func clearMemoryCache() {
        cache.removeAllObjects()
    }
}
