//
//  Album.swift
//  PrivateVaultPro
//
//  Created for PrivateVault Pro - Premium iOS Privacy Vault.
//  Copyright © 2026 PrivateVault Pro. All rights reserved.
//

import Foundation

public struct Album: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var createdDate: Date
    public var coverMediaItemID: UUID?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        coverMediaItemID: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.coverMediaItemID = coverMediaItemID
        self.sortOrder = sortOrder
    }
}
