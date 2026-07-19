/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

public struct SelectionPolicy: Sendable, Codable {
    public let maximumActiveProbes: Int
    public let selectionDeadline: Duration
    public let authenticationQuorum: Int
    public let rateLimitQuorum: Int
    public let explorationSlots: Int

    public init(
        maximumActiveProbes: Int,
        selectionDeadline: Duration,
        authenticationQuorum: Int = 2,
        rateLimitQuorum: Int = 3,
        explorationSlots: Int = 1
    ) {
        self.maximumActiveProbes = max(1, maximumActiveProbes)
        self.selectionDeadline = selectionDeadline
        self.authenticationQuorum = max(1, authenticationQuorum)
        self.rateLimitQuorum = max(1, rateLimitQuorum)
        self.explorationSlots = max(0, explorationSlots)
    }

    public static let production = SelectionPolicy(
        maximumActiveProbes: 4,
        selectionDeadline: .seconds(15),
        authenticationQuorum: 2,
        rateLimitQuorum: 3,
        explorationSlots: 1
    )
}
