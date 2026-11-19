import Foundation

/// A snapshot of everything `StoveBLEManager.readState()` fetches in one pass.
struct StoveState {
    var isOn: Bool
    var ambient: Double
    var target: Double
    var powerLevel: Int
    var automaticMode: Bool
    var relaxMode: Bool
    var fan1Speed: Int
    var fan2Speed: Int?  // nil when this stove doesn't have a Fan 2
    var fan3Speed: Int?  // nil when this stove doesn't have a Fan 3
    var pelletReserve: Bool
    var isChronoOn: Bool
    /// Chrono "Économie"/"Confort" preset temperatures — see
    /// `EdilkaminRegisters.writeChronoEconomyPreset` for the unverified encoding
    /// assumption (whole degrees, not tenths).
    var chronoEconomyPreset: Int
    var chronoComfortPreset: Int
    /// Operating/status code (7 = alarm) and the alarm code itself (0 = none).
    var operatingState: UInt16
    var alarmCode: UInt8
    var hasAlarm: Bool { operatingState == 7 && alarmCode != 0 }
}
