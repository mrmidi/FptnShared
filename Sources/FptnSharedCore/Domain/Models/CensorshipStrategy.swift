/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

/// Defines the transport and censorship circumvention strategy used by the C++ native layer.
public enum CensorshipStrategy: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case sniSpoofing = "SNI"
    case obfuscation = "OBFUSCATION"
    case sniReality = "SNI-REALITY"
    case sniRealityChrome147 = "sni-reality-chrome147"
    case sniRealityChrome146 = "sni-reality-chrome146"
    case sniRealityChrome145 = "sni-reality-chrome145"
    case sniRealityFirefox149 = "sni-reality-firefox149"
    case sniRealityYandex26 = "sni-reality-yandex26"
    case sniRealityYandex25 = "sni-reality-yandex25"
    case sniRealityYandex24 = "sni-reality-yandex24"
    case sniRealitySafari26 = "sni-reality-safari26"

    public var id: String { rawValue }

    public static let simpleCases: [CensorshipStrategy] = [
        .sniSpoofing,
        .obfuscation,
        .sniReality
    ]

    public static let advancedCases: [CensorshipStrategy] = [
        .sniRealityChrome147,
        .sniRealityChrome146,
        .sniRealityChrome145,
        .sniRealityFirefox149,
        .sniRealityYandex26,
        .sniRealityYandex25,
        .sniRealityYandex24,
        .sniRealitySafari26
    ]

    public var displayName: String {
        switch self {
        case .sniSpoofing: return "SNI"
        case .obfuscation: return "TLS Obfuscation"
        case .sniReality: return "Reality"
        case .sniRealityChrome147: return "Reality · Chrome 147"
        case .sniRealityChrome146: return "Reality · Chrome 146"
        case .sniRealityChrome145: return "Reality · Chrome 145"
        case .sniRealityFirefox149: return "Reality · Firefox 149"
        case .sniRealityYandex26: return "Reality · Yandex 26"
        case .sniRealityYandex25: return "Reality · Yandex 25"
        case .sniRealityYandex24: return "Reality · Yandex 24"
        case .sniRealitySafari26: return "Reality · Safari 26"
        }
    }

    public var requiresSNI: Bool { self != .obfuscation }
    public var isAdvanced: Bool { Self.advancedCases.contains(self) }

    public init(storedValue: String?) {
        let normalized = (storedValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Self(rawValue: normalized) {
            self = value
            return
        }

        switch normalized.uppercased() {
        case "TLS", "TLS_OBFUSCATOR", "TLS-OBFUSCATOR":
            self = .obfuscation
        case "REALITY", "SNI_REALITY", "SNI-REALITY":
            self = .sniReality
        case "CHROME147", "SNI_REALITY_CHROME147", "SNI-REALITY-CHROME147":
            self = .sniRealityChrome147
        case "CHROME146", "SNI_REALITY_CHROME146", "SNI-REALITY-CHROME146":
            self = .sniRealityChrome146
        case "CHROME145", "SNI_REALITY_CHROME145", "SNI-REALITY-CHROME145":
            self = .sniRealityChrome145
        case "FIREFOX149", "SNI_REALITY_FIREFOX149", "SNI-REALITY-FIREFOX149":
            self = .sniRealityFirefox149
        case "YANDEX26", "SNI_REALITY_YANDEX26", "SNI-REALITY-YANDEX26":
            self = .sniRealityYandex26
        case "YANDEX25", "SNI_REALITY_YANDEX25", "SNI-REALITY-YANDEX25":
            self = .sniRealityYandex25
        case "YANDEX24", "SNI_REALITY_YANDEX24", "SNI-REALITY-YANDEX24":
            self = .sniRealityYandex24
        case "SAFARI26", "SNI_REALITY_SAFARI26", "SNI-REALITY-SAFARI26":
            self = .sniRealitySafari26
        default:
            self = .sniSpoofing
        }
    }
}
