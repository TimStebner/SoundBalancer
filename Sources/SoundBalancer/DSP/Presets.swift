import Foundation

public struct EQPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let gains: [Float]

    public init(name: String, gains: [Float]) {
        self.id = name
        self.name = name
        self.gains = gains
    }

    public static let standardFrequencies: [Float] = [
        32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
    ]

    public static let standardFrequencyLabels: [String] = [
        "32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"
    ]

    public static let flat = EQPreset(
        name: "Flat",
        gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    )

    public static let bassBooster = EQPreset(
        name: "Bass Booster",
        gains: [5.5, 4.8, 3.8, 2.5, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0]
    )

    public static let bassReducer = EQPreset(
        name: "Bass Reducer",
        gains: [-5.0, -4.5, -3.5, -2.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    )

    public static let vocalBooster = EQPreset(
        name: "Vocal Enhancer",
        gains: [-1.5, -1.0, 0.0, 1.5, 3.5, 4.0, 3.2, 1.5, 0.5, 0.0]
    )

    public static let podcast = EQPreset(
        name: "Podcast / Speech",
        gains: [-3.0, -2.0, 0.5, 2.0, 3.0, 3.5, 2.5, 1.0, 0.0, -1.0]
    )

    public static let electronic = EQPreset(
        name: "Electronic",
        gains: [4.5, 3.8, 1.5, 0.0, -1.5, 1.8, 1.0, 2.0, 3.5, 4.2]
    )

    public static let rock = EQPreset(
        name: "Rock / Pop",
        gains: [4.2, 3.0, -1.0, -2.0, -0.5, 1.5, 3.0, 3.8, 4.0, 4.0]
    )

    public static let trebleBooster = EQPreset(
        name: "Treble Booster",
        gains: [0.0, 0.0, 0.0, 0.0, 0.5, 1.5, 3.0, 4.5, 5.5, 6.0]
    )

    public static let builtIns: [EQPreset] = [
        flat, bassBooster, bassReducer, vocalBooster, podcast, electronic, rock, trebleBooster
    ]
}
