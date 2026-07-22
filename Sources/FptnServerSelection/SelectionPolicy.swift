/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

public struct SelectionPolicy: Sendable, Codable {
    public let maximumActiveProbes: Int
    public let liveRaceDeadline: Duration
    public let overallSelectionDeadline: Duration
    public let authenticationQuorum: Int
    public let rateLimitQuorum: Int
    public let explorationSlots: Int

    public var selectionDeadline: Duration {
        liveRaceDeadline
    }

    public init(
        maximumActiveProbes: Int,
        liveRaceDeadline: Duration,
        overallSelectionDeadline: Duration? = nil,
        authenticationQuorum: Int = 2,
        rateLimitQuorum: Int = 3,
        explorationSlots: Int = 1
    ) {
        self.maximumActiveProbes = max(1, maximumActiveProbes)
        self.liveRaceDeadline = liveRaceDeadline
        self.overallSelectionDeadline = overallSelectionDeadline ?? (liveRaceDeadline + .seconds(5))
        self.authenticationQuorum = max(1, authenticationQuorum)
        self.rateLimitQuorum = max(1, rateLimitQuorum)
        self.explorationSlots = max(0, explorationSlots)
    }

    public init(
        maximumActiveProbes: Int,
        selectionDeadline: Duration,
        authenticationQuorum: Int = 2,
        rateLimitQuorum: Int = 3,
        explorationSlots: Int = 1
    ) {
        self.init(
            maximumActiveProbes: maximumActiveProbes,
            liveRaceDeadline: selectionDeadline,
            overallSelectionDeadline: selectionDeadline + .seconds(5),
            authenticationQuorum: authenticationQuorum,
            rateLimitQuorum: rateLimitQuorum,
            explorationSlots: explorationSlots
        )
    }

    public static let production = SelectionPolicy(
        maximumActiveProbes: 4,
        liveRaceDeadline: .seconds(15),
        overallSelectionDeadline: .seconds(20),
        authenticationQuorum: 2,
        rateLimitQuorum: 3,
        explorationSlots: 1
    )
}
